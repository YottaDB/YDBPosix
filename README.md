# YDB POSIX Plugin

## Overview

YDBposix is a plugin that allows M application code to use selected POSIX; it does not implement the underlying functionality. A set of low level C functions closely matching their corresponding POSIX functions acts as a software shim to connect M code to POSIX functions. A set of higher level entryrefs makes the functionality available in form more familiar to M programmers. M application code is free to call either level.

As C application code can call POSIX functions directly, the plugin has no value to C application code.

When installed in the `$ydb_dist/plugin` directory, YDBposix consists of the following files:

- `libydbposix.so` – a shared library with the C software shims

- `ydbposix.xc` – a call-out table to allow M code to call the functions in `libydbposix.so`

- `r/_ydbposix.m` – M source code for higher level `^%ydbposix` entryrefs that M application code can call.

- `o/_ydbposix.so` – a shared library with M mode object code for `^%ydbposix` entryrefs

- `o/utf8/_ydbposix.so` – if YottaDB is installed with UTF-8 support, a shared library with UTF-8 mode object code for `^%ydbposix` entryrefs

## Installing YDB POSIX Plugin

YottaDB must be installed and available before installing the POSIX plugin. https://yottadb.com/product/get-started/ has instructions on installing YottaDB. Download and unpack the POSIS plugin in a temporary directory, and make that the current directory. Then:

```shell
source $(pkg-config --variable=prefix yottadb)/ydb_env_set
mkdir build && cd build
cmake ..
make && sudo make install
```
