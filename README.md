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

## Building/Installing YDB Posix Plugin

First step is to Build/Install YottaDB and set the `ydb_dist` environment variable to point to the directory where YottaDB is installed. See https://gitlab.com/YottaDB/DB/YDB/raw/master/README.md for details on building YottaDB. The below steps assume YottaDB r1.22 is installed at /usr/local/lib/yottadb/r122.

```
sh
export ydb_dist=/usr/local/lib/yottadb/r122
```

Then make and make install:

```
mkdir build && cd build
cmake ..
make && sudo make install
```
