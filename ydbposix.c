/****************************************************************
 *								*
 * Copyright (c) 2012-2022 Fidelity National Information	*
 * Services, Inc. and/or its subsidiaries. All rights reserved.	*
 *								*
 * Copyright (c) 2018-2023 YottaDB LLC and/or its subsidiaries. *
 * All rights reserved.						*
 *								*
 *	This source code contains the intellectual property	*
 *	of its copyright holder(s), and is made available	*
 *	under a license.  If you do not know the terms of	*
 *	the license, please stop and do not read further.	*
 *								*
 ****************************************************************/
/* Caution - these functions are not thread-safe */

#include <errno.h>
#include <regex.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>

#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/resource.h>

#include "libyottadb.h"

#define MAXREGEXMEM	65536	/* Maximum memory to allocate for a compiled regular expression */
#define MINMALLOC   	64	/* Minimum space to request from ydb_malloc - MAXREGEXMEM/MINMALLOC should be a power of 4 */
#define CP_BUF_SIZE	4096	/* Size of the buffer used for copying a file. */

/* On certain platforms the st_Xtime field of the stat structure got replaced by a timespec st_Xtim field, which in turn has tv_sec
 * and tv_nsec fields. For compatibility reasons, those platforms define an st_Xtime macro which points to st_Xtim.tv_sec. Whenever
 * we detect such a situation, we define a nanosecond flavor of that macro to point to st_Xtim.tv_nsec.
 *
 * Need to confirm whether we even need these #defines – Bhaskar 20190226
 *
 */
#if defined st_atime
#  define st_natime	st_atim.tv_nsec
#endif
#if defined st_ctime
#  define st_nctime	st_ctim.tv_nsec
#endif
#if defined st_mtime
#  define st_nmtime	st_mtim.tv_nsec
#endif

/* Translation tables for various include file #define names to the platform values for those names */
/* Names *must* be in alphabetic order of strings; otherwise search will return incorrect results */

#define EINTR_OPER(ACTION, RC)				\
{							\
	do						\
	{						\
		RC = ACTION;				\
	} while ((-1 == RC) && (EINTR == errno));	\
}

static const char *clocks[] =
{
	"CLOCK_BOOTTIME",
	"CLOCK_MONOTONIC",
	"CLOCK_MONOTONIC_COARSE"
	"CLOCK_MONOTONIC_RAW",
	"CLOCK_PROCESS_CPUTIME_ID",
	"CLOCK_REALTIME",
	"CLOCK_REALTIME_COARSE",
	"CLOCK_THREAD_CPUTIME_ID"
};
static const int clock_values[] =
{
	CLOCK_BOOTTIME,
	CLOCK_MONOTONIC,
	CLOCK_MONOTONIC_COARSE,
	CLOCK_MONOTONIC_RAW,
	CLOCK_PROCESS_CPUTIME_ID,
	CLOCK_REALTIME,
	CLOCK_REALTIME_COARSE,
	CLOCK_THREAD_CPUTIME_ID
};

static const char *fmodes[] =
{
	"S_IFBLK",  "S_IFCHR", "S_IFDIR", "S_IFIFO", "S_IFLNK", "S_IFMT",  "S_IFREG",
	"S_IFSOCK", "S_IRGRP", "S_IROTH", "S_IRUSR", "S_IRWXG", "S_IRWXO", "S_IRWXU",
	"S_ISGID",  "S_ISUID", "S_ISVTX", "S_IWGRP", "S_IWOTH", "S_IWUSR", "S_IXGRP",
	"S_IXOTH",  "S_IXUSR"
};
static const int fmode_values[] =
{
	S_IFBLK,  S_IFCHR, S_IFDIR, S_IFIFO, S_IFLNK, S_IFMT,  S_IFREG,
	S_IFSOCK, S_IRGRP, S_IROTH, S_IRUSR, S_IRWXG, S_IRWXO, S_IRWXU,
	S_ISGID,  S_ISUID, S_ISVTX, S_IWGRP, S_IWOTH, S_IWUSR, S_IXGRP,
	S_IXOTH,  S_IXUSR
};

static const char *rlimit[] =
{	/* skip NICE because it has evil implications in GT.M */
# ifndef _AIX
	"RLIMIT_MEMLOCK",	"RLIMIT_MSGQUEUE",	"RLIMIT_LOCKS",	"RLIMIT_NPROC",	"RLIMIT_RTPRIO",	"RLIMIT_SIGPENDING"
# endif
	"RLIMIT_AS",		"RLIMIT_CORE",		"RLIMIT_CPU",	"RLIMIT_DATA",	"RLIMIT_FSIZE",
	"RLIMIT_NOFILE",	"RLIMIT_STACK",		"RLIMIT_RSS"
};

static const int rlimit_values[]=
{
# ifndef _AIX
	RLIMIT_MEMLOCK,		RLIMIT_MSGQUEUE,	RLIMIT_LOCKS,	RLIMIT_NPROC,	RLIMIT_RTPRIO,		RLIMIT_SIGPENDING,
# endif
	RLIMIT_AS,		RLIMIT_CORE,		RLIMIT_CPU,	RLIMIT_DATA,	RLIMIT_FSIZE,
	RLIMIT_NOFILE,		RLIMIT_STACK,		RLIMIT_RSS
};

static const char *priority[] =
{
	"LOG_ALERT",  "LOG_CRIT",   "LOG_DEBUG",  "LOG_EMERG", "LOG_ERR",
	"LOG_INFO",   "LOG_LOCAL0", "LOG_LOCAL1", "LOG_LOCAL2",
	"LOG_LOCAL3", "LOG_LOCAL4", "LOG_LOCAL5", "LOG_LOCAL6",
	"LOG_LOCAL7", "LOG_NOTICE", "LOG_USER",   "LOG_WARNING"
};
static const int priority_values[] =
{
	LOG_ALERT,  LOG_CRIT,   LOG_DEBUG,  LOG_EMERG,  LOG_ERR,
	LOG_INFO,   LOG_LOCAL0, LOG_LOCAL1, LOG_LOCAL2,
	LOG_LOCAL3, LOG_LOCAL4, LOG_LOCAL5, LOG_LOCAL6,
	LOG_LOCAL7, LOG_NOTICE, LOG_USER,   LOG_WARNING
};

static const char *regxflags[] =
{
	"REG_BADBR",        "REG_BADPAT",         "REG_BADRPT",       "REG_EBRACE",      "REG_EBRACK",    "REG_ECOLLATE",
	"REG_ECTYPE",       "REG_EESCAPE",        "REG_EPAREN",       "REG_ERANGE",      "REG_ESPACE",    "REG_ESUBREG",
	"REG_EXTENDED",     "REG_ICASE",          "REG_NEWLINE",      "REG_NOMATCH",     "REG_NOSUB",
	"REG_NOTBOL",       "REG_NOTEOL",
	"sizeof(regex_t)",  "sizeof(regmatch_t)", "sizeof(regoff_t)"
};
static const int regxflag_values[] =
{
	REG_BADBR,         REG_BADPAT,         REG_BADRPT,       REG_EBRACE,     REG_EBRACK,    REG_ECOLLATE,
	REG_ECTYPE,        REG_EESCAPE,        REG_EPAREN,       REG_ERANGE,     REG_ESPACE,    REG_ESUBREG,
	REG_EXTENDED,      REG_ICASE,          REG_NEWLINE,      REG_NOMATCH,    REG_NOSUB,
	REG_NOTBOL,        REG_NOTEOL,
	sizeof(regex_t),   sizeof(regmatch_t), sizeof(regoff_t)
};

static const char *signals[] =
{
	"SIGABRT", "SIGALRM", "SIGBUS",  "SIGCHLD", "SIGCONT", "SIGFPE",  "SIGHUP", "SIGILL",
	"SIGINT",  "SIGKILL", "SIGPIPE", "SIGQUIT", "SIGSEGV", "SIGSTOP", "SIGTERM",
	"SIGTRAP", "SIGTSTP", "SIGTTIN", "SIGTTOU", "SIGURG",  "SIGUSR1", "SIGUSR2",
	"SIGXCPU", "SIGXFSZ"
};
static const int signal_values[] =
{
	SIGABRT, SIGALRM, SIGBUS,  SIGCHLD, SIGCONT, SIGFPE,  SIGHUP, SIGILL,
	SIGINT,  SIGKILL, SIGPIPE, SIGQUIT, SIGSEGV, SIGSTOP, SIGTERM,
	SIGTRAP, SIGTSTP, SIGTTIN, SIGTTOU, SIGURG,  SIGUSR1, SIGUSR2,
	SIGXCPU, SIGXFSZ
};

static const char *sysconfs[] =
{
	"ARG_MAX",          "BC_BASE_MAX",   "BC_DIM_MAX",      "BC_SCALE_MAX",    "BC_STRING_MAX",   "CHILD_MAX",
	"COLL_WEIGHTS_MAX", "EXPR_NEST_MAX", "HOST_NAME_MAX",   "LINE_MAX",        "LOGIN_NAME_MAX",  "OPEN_MAX",
	"PAGESIZE",         "POSIX2_C_DEV",  "POSIX2_FORT_DEV", "POSIX2_FORT_RUN", "POSIX2_SW_DEV",   "POSIX2_VERSION",
	"RE_DUP_MAX",       "STREAM_MAX",    "SYMLOOP_MAX",     "TTY_NAME_MAX",    "TZNAME_MAX",      "_POSIX2_LOCALEDEF",
	"_POSIX_VERSION"
};
static const int sysconf_values[] =
{
	_SC_ARG_MAX,          _SC_BC_BASE_MAX,   _SC_BC_DIM_MAX,    _SC_BC_SCALE_MAX, _SC_BC_STRING_MAX,  _SC_CHILD_MAX,
	_SC_COLL_WEIGHTS_MAX, _SC_EXPR_NEST_MAX, _SC_HOST_NAME_MAX, _SC_LINE_MAX,     _SC_LOGIN_NAME_MAX, _SC_OPEN_MAX,
	_SC_PAGESIZE,         _SC_2_C_DEV,       _SC_2_FORT_DEV,    _SC_2_FORT_RUN,   _SC_2_SW_DEV,       _SC_2_VERSION,
	_SC_RE_DUP_MAX,       _SC_STREAM_MAX,    _SC_SYMLOOP_MAX,   _SC_TTY_NAME_MAX, _SC_TZNAME_MAX,     _SC_2_LOCALEDEF,
	_SC_VERSION
};

/* Prototypes */

int posix_chmod(int argc, char *file, int mode, int *err_num);
int posix_clock_gettime(int argc, int clk_id, long *tv_sec, long *tv_nsec, int *err_num);
int posix_chmod(int argc, char *file, int mode, int *err_num);
int posix_clock_gettime(int argc, int clk_id, long *tv_sec, long *tv_nsec, int *err_num);
int posix_cp(int argc, char *source, char *dest, int *err_num);
int posix_getrlimit(int argc, int resource, unsigned long *cv, int *err_num);
int posix_gettimeofday(int argc, long *tv_sec, long *tv_usec, int *err_num);
int posix_getuid(int argc, unsigned long *id);
int posix_localtime(int argc, long timep, int *sec, int *min, int *hour,
			     int *mday, int *mon, int *year, int *wday,
			     int *yday, int *isdst, int *err_num);
int posix_mkdir(int argc, char *dirname, int mode, int *err_num);
int posix_mkdtemp(int argc, char *template, int *err_num);
int posix_mktime(int argc, int year, int mon, int mday, int hour,
			  int min, int sec, int *wday, int *yday, int *isdst,
			  long *unixtime, int *err_num);
int posix_realpath(int argc, char *file, ydb_string_t *result, int *err_num);
int posix_regcomp(int argc, ydb_string_t *pregstr, char *regex, int cflags, int *err_num);
int posix_regexec(int argc, ydb_string_t *pregstr, char *string, int nmatch, ydb_string_t *pmatch,
			   int eflags, int *matchsuccess);
int posix_regfree(int argc, ydb_string_t *pregstr);
int posix_rmdir(int argc, char *pathname, int *err_num);
int posix_setenv(int argc, char *name, char *value, int overwrite, int *err_num);
int posix_stat(int argc, char *fname, unsigned long *dev, unsigned long *ino, unsigned long *mode,
			unsigned long *nlink, unsigned long *uid, unsigned long *gid, unsigned long *rdev, long *size,
			long *blksize, long *blocks, long *atime, long *atimen, long *mtime,
			long *mtimen, long *ctime, long *ctimen, int *err_num);
int posix_symlink(int argc, char *target, char *name, int *err_num);
int posix_sysconf(int argc, int name, long *value, int *err_num);
int posix_syslog(int argc, int priority, char *message);
int posix_umask(int argc, int mode, int *prev_mode, int *err_num);
int posix_unsetenv(int argc, char *name, int *err_num);
int posix_utimes(int argc, char *file, int *err_num);

int posixutil_searchstrtab(const char *tblstr[], const int tblval[], int tblsize, char *str, int *strval);

int posixhelper_clockval(int argc, char *symconst, int *symval);
int posixhelper_filemodeconst(int argc, char *symconst, int *symval);
int posixhelper_rlimitconst(int argc, char *symconst, int *symval);
int posixhelper_regconst(int argc, char *symconst, int *symval);
int posixhelper_regofft2offsets(int argc, ydb_string_t *regofftbytes, int *rmso, int *rmeo);
int posixhelper_signalval(int argc, char *symconst, int *symval);
int posixhelper_sysconfval(int argc, char *symconst, int *symval);
int posixhelper_syslogconst(int argc, char *symconst, int *symval);


/* POSIX routines */

int posix_chmod(int argc, char *file, int mode, int *err_num)
{
	if (3 != argc)
		return (int)-argc;
	*err_num = (-1 == chmod(file, (mode_t)mode)) ? (int)errno : 0;
	return (int)*err_num;
}

int posix_clock_gettime(int argc, int clk_id, long *tv_sec, long *tv_nsec, int *err_num)
{
	struct timespec tp;

	if (4 != argc)
		return (int)-argc;
	if (0 == clock_gettime((clockid_t)clk_id, &tp))
	{
		*tv_sec = (long)tp.tv_sec;
		*tv_nsec = (long)tp.tv_nsec;
		*err_num = 0;
	} else
		*err_num = (int)errno;
	return (int)*err_num;
}

int posix_cp(int argc, char *source, char *dest, int *err_num)
{
	int		fd1, fd2, rc;
	char		*buf_ptr;
	char		buffer[CP_BUF_SIZE];
	struct stat	statbuf;
	ssize_t		read_count, written_count;

	if (3 != argc)
		return (int)-argc;
	if (-1 == stat((char *)source, &statbuf))
	{
		*err_num = (int)errno;
		return (int)*err_num;
	}
	EINTR_OPER(open(source, O_RDONLY), fd1);
	if (-1 == fd1)
	{
		*err_num = (int)errno;
		return (int)*err_num;
	}
	EINTR_OPER(open(dest, O_WRONLY | O_CREAT, statbuf.st_mode), fd2);
	if (-1 == fd2)
	{
		*err_num = (int)errno;
		EINTR_OPER(close(fd1), rc);
		return (int)*err_num;
	}
	EINTR_OPER(ftruncate(fd2, 0), rc);
	if (-1 == rc)
	{
		*err_num = (int)errno;
		EINTR_OPER(close(fd1), rc);
		EINTR_OPER(close(fd2), rc);
		return (int)*err_num;
	}
	*err_num = 0;
	do
	{
		EINTR_OPER(read(fd1, buffer, CP_BUF_SIZE), read_count);
		if (0 < read_count)
		{
			written_count = 0;
			buf_ptr = buffer;
			while (0 < read_count)
			{
				EINTR_OPER(write(fd2, buf_ptr, read_count), written_count);
				if (0 < written_count)
				{
					read_count -= written_count;
					buf_ptr += written_count;
				} else
				{
					if (-1 == written_count)
						*err_num = (int)errno;
					break;
				}
			}
		} else
		{
			if (-1 == read_count)
				*err_num = (int)errno;
			break;
		}
	} while (0 == *err_num);
	EINTR_OPER(close(fd1), rc);
	EINTR_OPER(close(fd2), rc);
	if (0 == *err_num)
		*err_num = (-1 == chmod(dest, statbuf.st_mode)) ? (int)errno : 0;
	return (int)*err_num;
}

int posix_getrlimit(int argc, int resource, unsigned long *cv, int *err_num)
{
        struct rlimit	rl;

	if (3 != argc)
		return (int)-argc;
	else if (-1 == getrlimit(resource, &rl))
		*err_num = errno;
	else
	{
		*cv = (unsigned long)rl.rlim_cur;
		*err_num = 0;
	}
	return (int)*err_num;
}

int posix_gettimeofday(int argc, long *tv_sec, long *tv_usec, int *err_num)
{
	struct timeval currtimeval;

	if (3 != argc)
		return (int)-argc;
	if (-1 == gettimeofday(&currtimeval, NULL))
		*err_num = (int)errno;
	else
	{
		*tv_sec = (long)currtimeval.tv_sec;
		*tv_usec = (long)currtimeval.tv_usec;
		*err_num = 0;
	}
	return (int)*err_num;
}

int posix_getuid(int argc, unsigned long *id)
{
	if (1 != argc)
		return (int)-argc;
	*id = (unsigned long)getuid();
	return 0;
}


int posix_localtime(int argc, long timep, int *sec, int *min, int *hour,
			     int *mday, int *mon, int *year, int *wday,
			     int *yday, int *isdst, int *err_num)
{
	struct tm *currtimetm;

	if (11 != argc)
		return (int)-argc;
	currtimetm = localtime((time_t *)&timep);
	if (currtimetm)
	{
		*sec	= (int)currtimetm->tm_sec;
		*min	= (int)currtimetm->tm_min;
		*hour	= (int)currtimetm->tm_hour;
		*mday	= (int)currtimetm->tm_mday;
		*mon	= (int)currtimetm->tm_mon;
		*year	= (int)currtimetm->tm_year;
		*wday	= (int)currtimetm->tm_wday;
		*yday	= (int)currtimetm->tm_yday;
		*isdst	= (int)currtimetm->tm_isdst;
		*err_num = 0;
	} else
	{
		/* Linux does not set errno as required by POSIX std as of "IEEE Std 1003.1-2001" */
		*err_num = (int)-1;
	}
	return (int)*err_num;
}

int posix_mkdir(int argc, char *dirname, int mode, int *err_num)
{
	if (3 != argc)
		return (int)-argc;
	/* Possible return codes on error are EACCESS, EDQUOT, EEXIST, EFAULT, ELOOP, EMLINK, ENAMETOOLONG,
	 * ENOENT, ENOMEM, ENOSPC, ENOTDIR, EPERM, and EROFS.
	 */
	*err_num = (-1 == mkdir((char *)dirname, (mode_t)mode)) ? (int)errno : 0;
	return (int)*err_num;
}

int posix_mkdtemp(int argc, char *template, int *err_num)
{
	if (2 != argc)
		return (int)-argc;
	/* Possible return codes on error are EACCESS, EDQUOT, EEXIST, EFAULT, ELOOP, EMLINK, ENAMETOOLONG,
	 * ENOENT, ENOMEM, ENOSPC, ENOTDIR, EPERM, EROFS.
	 */
	*err_num = (mkdtemp((char *)template)) ? 0 : (int)errno;
	return (int)*err_num;
}

int posix_mktime(int argc, int year, int mon, int mday, int hour,
			  int min, int sec, int *wday, int *yday, int *isdst,
			  long *unixtime, int *err_num)
{
	struct tm time_str;

	if (11 != argc)
		return (int)-argc;
	time_str.tm_year	= (int)year;
	time_str.tm_mon		= (int)mon;
	time_str.tm_mday	= (int)mday;
	time_str.tm_hour	= (int)hour;
	time_str.tm_min		= (int)min;
	time_str.tm_sec		= (int)sec;
	time_str.tm_isdst	= (int)(*isdst);
	if (-1 == (*unixtime = (long)mktime(&time_str)))	/* Warning - assignment */
	{
		*err_num = (int)-1;
	} else
	{
		*wday = (int)time_str.tm_wday;
		*yday = (int)time_str.tm_yday;
		/* Only set DST if passed -1 */
		if (-1 == *isdst)
			*isdst = (int)time_str.tm_isdst;
		*err_num = 0;
	}
	return (int)*err_num;
}

int posix_realpath(int argc, char *file, ydb_string_t *result, int *err_num)
{
	if (3 != argc)
		return (int)-argc;
	if (realpath((const char *)file, result->address))
	{
		result->length = strlen(result->address);
		*err_num = 0;
	} else
	{
		result->length = 0;
		*err_num = (int)errno;
	}
	return (int)*err_num;
}

int posix_regcomp(int argc, ydb_string_t *pregstr, char *regex, int cflags, int *err_num)
{
	regex_t *preg;

	if (4 != argc)
		return (int)-argc;
	preg = (regex_t *)ydb_malloc(sizeof(regex_t));
	*err_num = (int)regcomp(preg, regex, (int)cflags);
	if (0 == *err_num)
	{
		(pregstr->length) = sizeof(char *);
		memcpy(pregstr->address, &preg, pregstr->length);
	}
	return (int)*err_num;
}

/* posix_regexec() does not entirely follow the implementation of the POSIX regexec(). The latter returns 0 for a
 * successful match, REG_NOMATCH otherwise. But returning non-zero to YottaDB from a C function will invoke the YottaDB
 * error trap, which is not desirable for the non-match of a pattern.  Therefore, posix_regexec() always returns
 * zero and the result of the match is in the parameter *matchsuccess with 1 meaning a successful match and 0
 * otherwise.
 */
int posix_regexec(int argc, ydb_string_t *pregstr, char *string, int nmatch, ydb_string_t *pmatch,
			   int eflags, int *matchsuccess)
{
        regex_t         *preg;
	regmatch_t	*result;
	size_t		resultsize;

	if (6 != argc)
		return (int)-argc;
	memcpy(&preg, pregstr->address, pregstr->length);
	resultsize = nmatch * sizeof(regmatch_t);
	result = (regmatch_t *)ydb_malloc(resultsize);
	*matchsuccess = (0 == regexec(preg, (char *)string, (size_t)nmatch, result, (int)eflags));
	if (*matchsuccess)
		memcpy(pmatch->address, result, resultsize);
	ydb_free((void*)result);
	return 0;
}

int posix_regfree(int argc, ydb_string_t *pregstr)
{
	regex_t	*preg;

	if (1 != argc)
		return (int)-argc;
	memcpy(&preg, pregstr->address, pregstr->length);
	/* regfree is a void function */
	regfree(preg);
	ydb_free((void *)preg);
	return 0;
}

int posix_rmdir(int argc, char *pathname, int *err_num)
{
	if (2 != argc)
		return (int)-argc;
	*err_num = (-1 == rmdir((const char *)pathname)) ? (int)errno : 0;
	return (int)*err_num;
}

int posix_setenv(int argc, char *name, char *value, int overwrite, int *err_num)
{
	if (4 != argc)
		return (int)-argc;
	*err_num = (-1 == setenv((char *)name, (char *)value, (int)overwrite)) ? (int)errno : 0;
	return (int)*err_num;
}

int posix_stat(int argc, char *fname, unsigned long *dev, unsigned long *ino, unsigned long *mode,
			unsigned long *nlink, unsigned long *uid, unsigned long *gid, unsigned long *rdev, long *size,
			long *blksize, long *blocks, long *atime, long *atimen, long *mtime,
			long *mtimen, long *ctime, long *ctimen, int *err_num)
{
	struct stat	thisfile;
	int	retval;

	if (18 != argc)
		return (int)-argc;
	*err_num = (-1 == stat((char *)fname, &thisfile)) ? (int)errno : 0;
	if (0 == *err_num)
	{
		*dev     = (unsigned long)thisfile.st_dev;	/* ID of device containing file */
		*ino     = (unsigned long)thisfile.st_ino;	/* inode number */
		*mode    = (unsigned long)thisfile.st_mode;	/* protection */
		*nlink   = (unsigned long)thisfile.st_nlink;	/* number of hard links */
		*uid     = (unsigned long)thisfile.st_uid;	/* user ID of owner */
		*gid     = (unsigned long)thisfile.st_gid;	/* group ID of owner */
		*rdev    = (unsigned long)thisfile.st_rdev;	/* device ID (if special file) */
		*size    = (long)thisfile.st_size;	/* total size, in bytes */
		*blksize = (long)thisfile.st_blksize;	/* blocksize for file system I/O */
		*blocks  = (long)thisfile.st_blocks;	/* number of 512B blocks allocated */
		*atime   = (long)thisfile.st_atime;	/* time (secs) of last access */
		*atimen  = (long)thisfile.st_natime;	/* time (nsecs) of last access */
		*mtime   = (long)thisfile.st_mtime;	/* time (secs) of last modification */
		*mtimen  = (long)thisfile.st_nmtime;	/* time (nsecs) of last modification */
		*ctime   = (long)thisfile.st_ctime;	/* time (secs) of last status change */
		*ctimen  = (long)thisfile.st_nctime;	/* time (nsecs) of last status change */
	}
	return (int)*err_num;
}

int posix_symlink(int argc, char *target, char *name, int *err_num)
{
	if (3 != argc)
		return (int)-argc;
	*err_num = (-1 == symlink(target, name)) ? (int)errno : 0;
	return (int)*err_num;
}

int posix_sysconf(int argc, int name, long *value, int *err_num)
{
	if (3 != argc)
		return (int)-argc;
	errno = 0;
	if (0 <= (*value = (long)sysconf(name)))	/* Warning - assignment */
		*err_num = 0;
	else
		*err_num = (0 == errno) ? 0 : (int)errno;
	return (int)*err_num;
}

/* posix_syslog() does not entirely follow the format of POSIX syslog(). For one thing, syslog() provides for a
 * variable number of arguments, whereas posix_syslog() can only accommodate a fixed number. Additionally, per
 * http://lab.gsi.dit.upm.es/semanticwiki/index.php/Category:String_Format_Overflow_in_syslog(), the safe way to
 * use syslog() is to force the format to "%s". Note that while POSIX syslog() returns no value, posix_syslog()
 * returns 0; otherwise, YottaDB will raise a runtime error.
 */
int posix_syslog(int argc, int priority, char *message)
{
	if (2 != argc)
		return (int)-argc;
	/* syslog() is a void function */
	syslog((int)priority, "%s", (char *)message);
	return (int)0;
}

int posix_umask(int argc, int mode, int *prev_mode, int *err_num)
{
	if (3 != argc)
		return (int)-argc;
	*prev_mode = (int)umask(mode);
	return 0;
}

int posix_unsetenv(int argc, char *name, int *err_num)
{
	if (2 != argc)
		return (int)-argc;
	*err_num = (-1 == unsetenv(name)) ? (int)errno : 0;
	return (int)*err_num;
}

int posix_utimes(int argc, char *file, int *err_num)
{
	if (2 != argc)
		return (int)-argc;
	*err_num = (-1 == utimes(file, NULL)) ? (int)errno : 0;
	return (int)*err_num;
}

/* Utility routines used by Helper routines below */

int posixutil_searchstrtab(const char *tblstr[], const int tblval[], int tblsize, char *str, int *strval)
{
	int compflag, current, first, last;

	first = 0;
	last = tblsize - 1;
	for (; ;)
	{
		current = (first + last) / 2;
		compflag = strcmp(tblstr[current], str);
		if (0 == compflag)
		{
			*strval = tblval[current];
			return (int)0;
		}
		if (first == last)
			return (int)1;
		if (0 > compflag)
			first = (first == current) ? (current + 1) : current;
		else
			last = current;
	}
}
/* Helper routines */

/* Given a clock name, provide the numeric value */
int posixhelper_clockval(int argc, char *symconst, int *symval)
{
	if (2 != argc)
		return (int)-argc;
	return posixutil_searchstrtab(clocks, clock_values, sizeof(clocks) / sizeof(clocks[0]), symconst, symval);
}

/* Given a symbolic constant for file mode, provide the numeric value */
int posixhelper_filemodeconst(int argc, char *symconst, int *symval)
{
	if (2 != argc)
		return (int)-argc;
	return posixutil_searchstrtab(fmodes, fmode_values, sizeof(fmodes) / sizeof(fmodes[0]), symconst, symval);
}

/* Given a symbolic constant for limit, provide the numeric value */
int posixhelper_rlimitconst(int argc, char *symconst, int *symval)
{
	if (2 != argc)
		return (int)-argc;
	return posixutil_searchstrtab(rlimit, rlimit_values, sizeof(rlimit) / sizeof(rlimit[0]), symconst, symval);
}

/* Given a symbolic constant for regex facility or level, provide the numeric value */
int posixhelper_regconst(int argc, char *symconst, int *symval)
{
	if (2 != argc)
		return (int)-argc;
	return posixutil_searchstrtab(regxflags, regxflag_values, sizeof(regxflags) / sizeof(regxflags[0]), symconst, symval);
}

/* Endian independent conversion from regmatch_t bytestring to offsets */
int posixhelper_regofft2offsets(int argc, ydb_string_t *regofftbytes, int *rmso, int *rmeo)
{
	regmatch_t buf;

	if (3 != argc)
		return (int)-argc;
	memcpy(&buf, regofftbytes->address, sizeof(regmatch_t));
	*rmso = (int)((regoff_t)(buf.rm_so));
	*rmeo = (int)((regoff_t)(buf.rm_eo));
	return 0;
}

/* Given a signal name, provide the numeric value */
int posixhelper_signalval(int argc, char *symconst, int *symval)
{
	if (2 != argc)
		return (int)-argc;
	return posixutil_searchstrtab(signals, signal_values, sizeof(signals) / sizeof(signals[0]), symconst, symval);
}

/* Given a configuration name, provide the numeric value */
int posixhelper_sysconfval(int argc, char *symconst, int *symval)
{
	if (2 != argc)
		return (int)-argc;
	return posixutil_searchstrtab(sysconfs, sysconf_values, sizeof(sysconfs) / sizeof(sysconfs[0]), symconst, symval);
}

/* Given a symbolic constant for syslog facility or level, provide the numeric value */
int posixhelper_syslogconst(int argc, char *symconst, int *symval)
{
	if (2 != argc)
		return (int)-argc;
	return posixutil_searchstrtab(priority, priority_values, sizeof(priority) / sizeof(priority[0]), symconst, symval);
}

