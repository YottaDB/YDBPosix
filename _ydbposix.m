;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;								;
; Copyright (c) 2012-2022 Fidelity National Information		;
; Services, Inc. and/or its subsidiaries. All rights reserved.	;
;								;
; Copyright (c) 2018-2023 YottaDB LLC and/or its subsidiaries.	;
; All rights reserved.						;
;								;
;	This source code contains the intellectual property	;
;	of its copyright holder(s), and is made available	;
;	under a license.  If you do not know the terms of	;
;	the license, please stop and do not read further.	;
;								;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Current ydbposix version.
YDBPOSIXVERSION	;v5.0.0

%ydbposix
	; High level wrappers to low level POSIX functions
	set $etrap="set $etrap=""use $principal write $zstatus,! zhalt 1"" set tmp1=$piece($ecode,"","",2),tmp2=$text(@tmp1) if $length(tmp2) write $text(+0),@$piece(tmp2,"";"",2),! zhalt +$extract(tmp1,2,$length(tmp1))"
	set $ecode=",U255,"	      ; must call an entryref
	quit

; Change the permissions of a file
CHMOD(name,mode)
	new retval
	set retval=$$chmod(name,mode)
	quit:$quit retval quit
chmod(name,mode)
	new errno
	if $&ydbposix.chmod(name,$select(mode'=+mode:$$filemodeconst(mode),1:mode),.errno)
	quit:$quit 1 quit

; Retrieve the time of the specified clock
CLOCKGETTIME(clock,sec,nsec)
	new retval
	set retval=$$clockgettime(clock,.sec,.nsec)
	quit:$quit retval quit
clockgettime(clock,sec,nsec)
	new errno
	if $&ydbposix.clockgettime($select(clock'=+clock:$$clockval(clock),1:clock),.sec,.nsec,.errno)
	quit:$quit 1 quit
clockval(clock)	; get numeric value for the specified clock
	quit:$data(%ydbposix("clock",clock)) %ydbposix("clock",clock)
	new clockval
	if $&ydbposix.clockval(clock,.clockval)
	set %ydbposix("clock",clock)=clockval
	quit clockval

; Copy a file
CP(source,dest)
	new retval
	set retval=$$cp(source,dest)
	quit:$quit retval quit
cp(source,dest)
	new errno
	if $&ydbposix.cp(source,dest,.errno)
	quit:$quit 1 quit

; Get value for symbolic file modes - only lower case because this is an internal utility routine
filemodeconst(sym)	; get numeric value for file mode symbolic constant
	quit:$data(%ydbposix("filemode",sym)) %ydbposix("filemode",sym)
	new symval
	if $&ydbposix.filemodeconst(sym,.symval)
	set %ydbposix("filemode",sym)=symval
	quit symval

; Create a directory
MKDIR(dirname,mode)
	new retval
	set retval=$$mkdir(dirname,mode)
	quit:$quit retval quit
mkdir(dirname,mode)
	new errno,retval
	set retval=$&ydbposix.mkdir(dirname,$select(mode'=+mode:$$filemodeconst(mode),1:mode),.errno)
	quit:$quit retval quit

; Get value for symbolic resource limits - only lower case because this is an internal utility routine
rlimitconst(sym)	; get numeric value for resource limit symbolic constant
	quit:$data(%ydbposix("rlimit",sym)) %ydbposix("rlimit",sym)
	new symval
	if $&ydbposix.rlimitconst(sym,.symval)
	set %ydbposix("rlimit",sym)=symval
	quit symval

; Get a resource limit
GETRLIMIT(rlimit,cv)
	new retval
	set retval=$$getrlimit(rlimit,.cv)
	quit:$quit retval quit
getrlimit(rlimit,cv)
	new errno
	if $&ydbposix.getrlimit($select(rlimit'=+rlimit:$$rlimitconst(rlimit),1:rlimit),.cv,.errno) quit:$quit *errno quit
	quit:$quit 1 quit

GETUID(id)
	do getuid(.id)
	quit:$quit 1 quit
getuid(id)
	set id=$&ydbposix.getuid()
	quit:$quit 1 quit

; Convert  a  broken-down  time  structure to calendar time representation.
MKTIME(year,mon,mday,hour,min,sec,wday,yday,isdst,unixtime)
	new retval
	set retval=$$mktime($get(year),$get(mon),$get(mday),$get(hour),$get(min),$get(sec),.wday,.yday,.isdst,.unixtime)
	quit:$quit retval quit
mktime(year,mon,mday,hour,min,sec,wday,yday,isdst,unixtime)
	new errno
	if $&ydbposix.mktime(year,mon,mday,hour,min,sec,.wday,.yday,.isdst,.unixtime,.errno)
	quit:$quit 1 quit

; Create a temporary directory
MKTMPDIR(template)
	new retval
	set retval=$$mktmpdir(.template)
	quit:$quit retval quit
mktmpdir(template)
	new errno,mode,retval,savetemplate
	set:"XXXXXX"'=$extract(template,$length(template)-5,$length(template)) $ecode=",U254,"
	set savetemplate=template
	do &ydbposix.mkdtemp(.template,.errno)	; discard return value since it is a pointer into heap space
	set retval=0
	if (savetemplate=template) do
	. set $extract(template,$length(template)-5,$length(template))=$$^%RANDSTR(6)
	. set retval='$$mkdir(template,"S_IRWXU")
	quit:$quit 'retval quit

; Obtain a real path to the file
REALPATH(name,realpath)
	new retval
	set retval=$$realpath(name,.realpath)
	quit:$quit retval quit
realpath(name,realpath)
	new errno
	if $&ydbposix.realpath(name,.realpath,.errno)
	quit:$quit 1 quit

; Discard a previously compiled regular expression - *must* be passed by variable name
REGFREE(pregstr)
	new retval
	set retval=$$regfree(pregstr)
	quit:$quit retval quit
regfree(pregstr)
	if $&ydbposix.regfree(@pregstr)
	zkill @pregstr
	quit:$quit 1 quit

; Match a regular expression
REGMATCH(str,patt,pattflags,matchflags,matchresults,maxresults)
	new retval
	set retval=$$regmatch($get(str),$get(patt),$get(pattflags),$get(matchflags),.matchresults,$get(maxresults))
	quit:$quit retval quit
regmatch(str,patt,pattflags,matchflags,matchresults,maxresults)
	new errno,i,j,mfval,matchsuccess,nextmf,nextpf,nextrmeo,nextrmso,pfval,pregstr,regmatchtsize,regofftsize,resultbuf
	if $length($get(pattflags)) for i=1:1:$length(pattflags,"+") do
	. set nextpf=$piece(pattflags,"+",i)
	. if $increment(pfval,$select(nextpf'=+nextpf:$$regsymval(nextpf),1:nextpf))
	else  set pfval=0
	do:'$data(%ydbposix("regmatch",patt,pfval))
	. do:'$&ydbposix.regcomp(.pregstr,patt,pfval,.errno)
	. . zkill %ydbposix("regcomp","errno")
	. . set %ydbposix("regmatch",patt,pfval)=pregstr
	; nothing matched and that is due to an error in regcomp
	if '$data(%ydbposix("regmatch",patt,pfval)) quit:$quit -errno_",regcomp" quit
	set:'$data(maxresults) maxresults=1
	set $zpiece(resultbuf,$zchar(0),maxresults*$$regsymval("sizeof(regmatch_t)")+1)=""
	if $length($get(matchflags)) for i=1:1:$length(matchflags,"+") do
	. set nextmf=$piece(matchflags,"+",i)
	. if $increment(mfval,$select(nextmf'=+nextmf:$$regsymval(nextmf),1:nextmf))
	else  set mfval=0
	if $&ydbposix.regexec(%ydbposix("regmatch",patt,pfval),str,maxresults,.resultbuf,mfval,.matchsuccess)
	zkill %ydbposix("regexec","errno")
	set i=0
	do:matchsuccess
	. kill matchresults
	. set regmatchtsize=$$regsymval("sizeof(regmatch_t)"),j=1
	. ; If we find `matchresults(i,"start")` is 0, it means match happened until `i-1` only hence the `kill` and `i-1` below
	. for i=1:1:maxresults do  if 'matchresults(i,"start") kill matchresults(i) set i=i-1 quit
	. . kill nextrmso,nextrmeo
	. . ; Note: `$&ydbposix.regofft2offsets()` returns 0 in all cases where 3 parameters (valid # of parms) are passed.
	. . ; Therefore, the `if` check always succeeds and the `do` code always executes.
	. . if '$&ydbposix.regofft2offsets($zextract(resultbuf,j,$increment(j,regmatchtsize)-1),.nextrmso,.nextrmeo) do
	. . . set matchresults(i,"start")=1+nextrmso
	. . . set matchresults(i,"end")=1+nextrmeo
	. . ; Because the `do` code above is always executed, `matchresults(i)` is guaranteed to be set at this point.
	quit:$quit i quit

; Get numeric value for regular expression symbolic constant - only lower case because this is an internal utility routine
regsymval(sym)
	quit:$data(%ydbposix("regmatch",sym)) %ydbposix("regmatch",sym)
	new symval
	if $&ydbposix.regconst(sym,.symval)
	set %ydbposix("regmatch",sym)=symval
	quit symval

; Remove a directory
RMDIR(dirname)
	new retval
	set retval=$$rmdir(dirname)
	quit:$quit retval quit
rmdir(dirname)
	new errno
	if $&ydbposix.rmdir(dirname,.errno)
	quit:$quit 1 quit

; Set an environment variable
; This function is deprecated and retained for backward compatibility.
; Use VIEW SETENV instead.
SETENV(name,value,overwrite)
	new retval
	set retval=$$setenv(name,value,$get(overwrite))
	quit:$quit retval quit
setenv(name,value,overwrite)
	new errno
	if $&ydbposix.setenv(name,value,$get(overwrite),.errno)
	quit:$quit 1 quit

; Return attributes for a file in a local variable passed in by reference
STATFILE(f,s)
	new retval
	set retval=$$statfile(f,.s)
	quit:$quit retval quit
statfile(f,s)
	new atime,blksize,blocks,ctime,dev,errno,gid,ino,mode,mtime,natime,nctime,nlink,nmtime,rdev,retval,size,uid
	set retval=$&ydbposix.stat(f,.dev,.ino,.mode,.nlink,.uid,.gid,.rdev,.size,.blksize,.blocks,.atime,.natime,.mtime,.nmtime,.ctime,.nctime,.errno)
	kill s
	set s("atime")=atime
	set s("blksize")=blksize
	set s("blocks")=blocks
	set s("ctime")=ctime
	set s("dev")=dev
	set s("gid")=gid
	set s("ino")=ino
	set s("mode")=mode
	set s("mtime")=mtime
	set s("natime")=natime
	set s("nctime")=nctime
	set s("nlink")=nlink
	set s("nmtime")=nmtime
	set s("rdev")=rdev
	set s("size")=size
	set s("uid")=uid
	quit:$quit retval  quit

; Create a symbolic link
SYMLINK(target,name)
	new retval
	set retval=$$symlink(target,name)
	quit:$quit retval quit
symlink(target,name)
	new errno
	if $&ydbposix.symlink(target,name,.errno)
	quit:$quit 1 quit

; Get configuration information
SYSCONF(name,value)
	new retval
	set retval=$$sysconf(name,.value)
	quit:$quit retval quit
sysconf(name,value)
	new errno
	if $&ydbposix.sysconf($select(name'=+name:$$sysconfval(name),1:name),.value,.errno)
	quit:$quit 1 quit
sysconfval(option)	; get numeric value for the specified configuration option
	quit:$data(%ydbposix("sysconf",option)) %ydbposix("sysconf",option)
	new sysconfval
	if $&ydbposix.sysconfval(option,.sysconfval)
	set %ydbposix("sysconf",option)=sysconfval
	quit sysconfval

; Log a message to the system log
; Unless you really need the fine-grained control this offers, the built-in function
; $ZSYSLOG() should suffice for most needs.
SYSLOG(message,facility,level)
	new retval
	set retval=$$syslog($get(message),$get(facility),$get(level))
	quit:$quit retval quit
syslog(message,facility,level)
	if $data(facility)#10 set:facility'=+facility facility=$$syslogval(facility)
	else  set facility=$$syslogval("LOG_USER")
	if $data(level)#10 set:level'=+level level=$$syslogval(level)
	else  set level=$$syslogval("LOG_INFO")
	if $&ydbposix.syslog(+facility+level,message)
	quit:$quit 1 quit
syslogval(msg)	; get numeric value for syslog symbolic constant
	quit:$data(%ydbposix("syslog",msg))#10 %ydbposix("syslog",msg)
	new msgval
	if $&ydbposix.syslogconst(msg,.msgval)
	set %ydbposix("syslog",msg)=msgval
	quit msgval

; Unset an environment variable
; This function is deprecated and retained for backward compatibility.
; Use VIEW UNSETENV instead.
UNSETENV(name)
	new retval
	set retval=$$unsetenv(name)
	quit:$quit retval quit
unsetenv(name)
	new errno
	if $&ydbposix.unsetenv(name,.errno)
	quit:$quit 1 quit

; Set user's file mode creation mask
UMASK(mode,prevMode)
	new retval
	set retval=$$umask(mode,.prevMode)
	quit:$quit retval quit
umask(mode,prevMode)
	new errno
	if $&ydbposix.umask($select(mode'=+mode:$$filemodeconst(mode),1:mode),.prevMode,.errno)
	quit:$quit 1 quit

; Update the timestamp of a file
UTIMES(name)
	new retval
	set retval=$$utimes(name)
	quit:$quit retval quit
utimes(name)
	new errno
	if $&ydbposix.utimes(name,.errno)
	quit:$quit 1 quit

; Provide a version number for this wrapper based on the value defined in YDBPOSIXVERSION's comment
VERSION() quit $$version
version()
	new ver
	set ver=$piece($text(YDBPOSIXVERSION),";",2)
	quit:$quit ver quit

; Extrinsic special variable that extends $HOROLOG and reports in microseconds
; This function is deprecated and retained for backward compatibility.
; Consider using $ZHOROLOG instead.
ZHOROLOG()   quit $$zhorolog()
zhorolog()
	new day,errno,hour,isdst,mday,min,mon,retval,sec,tvsec,tvusec,wday,yday,year
	if $&ydbposix.gettimeofday(.tvsec,.tvusec,.errno)
	if $&ydbposix.localtime(tvsec,.sec,.min,.hour,.mday,.mon,.year,.wday,.yday,.isdst,.errno)
	quit:$quit $$FUNC^%DATE(mon+1_"/"_mday_"/"_(1900+year))_","_(((hour*60)+min)*60+sec)_$select(tvusec:tvusec*1E-6,1:"") quit

;	Error message texts
U254	;"-F-BADTEMPLATE Template "_template_" does not end in ""XXXXXX"""
U255	;"-F-BADINVOCATION Must call an entryref in "_$text(+0)
