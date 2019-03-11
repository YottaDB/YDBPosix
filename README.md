# YDB POSIX Plugin

## Overview

YDBposix is a plugin that allows M application code to use selected POSIX; it does not implement the underlying functionality. A set of low level C functions closely matching their corresponding POSIX functions acts as a software shim to connect M code to POSIX functions. A set of higher level entryrefs makes the functionality available in form more familiar to M programmers. M application code is free to call either level.

As C application code can call POSIX functions directly, the plugin has no value to C application code.

When installed in the `$ydb_dist/plugin` directory, YDBposix consists of the following files:

- `libydbposix.so` – a shared library with the C software shims

- `ydbposix.xc` – a call-out table to allow M code to call the functions in `libydbposix.so`

- `r/_ydbposix.m` – M source code for higher level `^%ydbposix` entryrefs that M application code can call.

- `r/_ydbposixtest.m` – M source code for `%ydbposixtest` routine to test plugin with `mumps -run %ydbposix`

- `o/_ydbposix.so` – a shared library with M mode object code for `^%ydbposix` & `^%ydbposixtest` entryrefs

- `o/utf8/_ydbposix.so` – if YottaDB is installed with UTF-8 support, a shared library with UTF-8 mode object code

## Installing YDB POSIX Plugin

YottaDB must be installed and available before installing the POSIX plugin. https://yottadb.com/product/get-started/ has instructions on installing YottaDB. Download and unpack the POSIX plugin in a temporary directory, and make that the current directory. Then:

```shell
source $(pkg-config --variable=prefix yottadb)/ydb_env_set
mkdir build && cd build
cmake ..
make && sudo make install
```

If YottaDB is installed with UTF-8 support, use these additional commands to install the plugin compiled for UTF-8 mode:

```shell
cd ..
rm -rf build && mkdir build && cd build
cmake -DMUMPS_UTF8_MODE=1 ..
make && sudo make install
```

After installing the POSIX plugin, it is always a good idea to clear environment variables and set them again when you want to use the plugin, as the environment variables needed for the POSIX plugin go beyond those for YottaDB itself.

```shell
source $(pkg-config --variable=prefix yottadb)/ydb_env_unset
```


At any time after installing the POSIX plugin, you can always test it.

```shell
source $(pkg-config --variable=prefix yottadb)/ydb_env_set
mumps -run %ydbposixtest
```
