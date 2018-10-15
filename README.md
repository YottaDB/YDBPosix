# YDB Posix Plugin

Please see readme for more detailed explanations; eventually, this file should be merged with that one. For now, both the Makefile and CMake file can be used to compile, but the cmake build should be preferred.

## Installing

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
