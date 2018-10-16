# YDB Posix Plugin

## Overview

ydbposix is a simple plugin to allow YottaDB application code to use selected POSIX functions on POSIX editions of YottaDB. ydbposix provides a set of low-level calls wrapping and closely matching their corresponding POSIX functions, and a set of high-level entryrefs that provide a further layer of wrapping to make the functionality available in a form more familiar to M programmers.

ydbposix is just a wrapper for POSIX functions; it does not actually implement the underlying functionality.

ydbposix consists of the following files:

- COPYING - the free / open source software (FOSS) license under which ydbposix is provided to you.

- ydbposix.c - C code that wraps POSIX functions for use by YottaDB.

- ydbposix.xc\_proto - a prototype to generate the call-out table used by YottaDB to map M entryrefs to C entry points, as described in the Programmers Guide.

- Makefile - for use by GNU make to build, test, install and uninstall the package.

- \_POSIX.m - wraps the C code with M-like functionality to provide ^%POSIX entryrefs.

- posixtest.m - a simple test to check for correct installation and operation of ydbposix.

- readme.txt - this file



Both the Makefile and CMake file can be used to compile, but the cmake build should be preferred.

## Installing

### With CMake

First, setup the YottaDB environment variables.

```
source /usr/local/lib/yottadb/r122/ydb_env_set
```

Then make and make install:

```
mkdir build && cd build
cmake ..
make && sudo make install
```

### With Makefile

ydbposix comes with a Makefile that you can use with GNU make to build, test, install and uninstall the package. Depending on the platform, GNU make may be available via "gmake" or "make" command. Building, testing, and using ydbposix does not require root access.  Installing the plugin in the $ydb\_dist/plugin subdirectory requires root access. The targets in the Makefile designated for external use are:

- all: creates libydbposix.so (the shared library of C code that wraps POSIX functions) and ydbposix.xc (although this is a text file, the first line points to libydbposix.so and ydbposix.xc must therefore be created by the Makefile

- clean: delete object files and ydbposix.xc

- install: executed as root to install ydbposix in $ydb\_dist/plugin

- test: after building ydbposix and before installation, a quick test for correct operation of the plugin

- uninstall: executed as root to remove an installed plugin from under a YottaDB installation

The following targets also exist, but are intended for use within the Makefile rather than for external invocation: ydbposix.o, ydbposix.xc, and libydbposix.so.

Make always needs the following environment variable to be set: ydb\_dist, the directory where YottaDB is installed. If you plan to install the plugin for multiple YottaDB versions, please use "make clean" before repeating the build, because the build includes libyottadb.h from $ydb\_dist.

Depending on your YottaDB installation, some make targets may need additional environment variables to be set:

- make test sends a LOG\_WARNING severity message and a LOG\_INFO severity message and reads the syslog file for each to verify the messages. Although posixtest.m tries to make reasonable guesses about the location of the files on your system, it has no way to know how you have syslog configured. If you see a "FAIL syslog ..." output message, repeat the test with the environment variable syslog\_warning set to the location of the syslog file for LOG\_WARNING messages. If you see a "FAIL SYSLOG ..." output message, repeat the test with the environment variable syslog\_info set to the location of the syslog file for LOG\_INFO messages. In particular, a test on Red Hat Enterprise Linux may require $syslog\_info to be "/var/log/messages".

- if your YottaDB installation includes UTF-8 support (i.e., if it has a utf8 sub-directory), make install requires the environment variable LC\_CTYPE to specify a valid UTF-8 locale, and depending on how libicu is built on your system, may require the ydb\_icu\_version to have the ICU version number.
