# YDB Posix Plugin

## Overview

ydbposix is a simple plugin to allow YottaDB application code to use selected POSIX functions on POSIX editions of YottaDB. ydbposix provides a set of low-level calls wrapping and closely matching their corresponding POSIX functions, and a set of high-level entryrefs that provide a further layer of wrapping to make the functionality available in a form more familiar to M programmers.

ydbposix is just a wrapper for POSIX functions; it does not actually implement the underlying functionality.

ydbposix consists of the following files:

- COPYING - the free / open source software (FOSS) license under which ydbposix is provided to you.

- ydbposix.c - C code that wraps POSIX functions for use by YottaDB.

- ydbposix.xc\_proto - a prototype to generate the call-out table used by YottaDB to map M entryrefs to C entry points, as described in the Programmers Guide.

- CMakeLists.txt - To build, test, install and uninstall the package.

- \_POSIX.m - wraps the C code with M-like functionality to provide ^%POSIX entryrefs.

- posixtest.m - a simple test to check for correct installation and operation of ydbposix.

Both the Makefile and CMake file can be used to compile, but the cmake build should be preferred.

## Installing YDB Posix with CMake

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
