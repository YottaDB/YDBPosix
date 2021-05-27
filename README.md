# YDB POSIX Plugin

## Overview

YDBposix is a plugin that allows M application code to use selected POSIX; it does not implement the underlying functionality. A set of low level C functions closely matching their corresponding POSIX functions acts as a software shim to connect M code to POSIX functions. A set of higher level entryrefs makes the functionality available in form more familiar to M programmers. M application code is free to call either level.

As C application code can call POSIX functions directly, the plugin has no value to C application code.

When installed in the `$ydb_dist/plugin` directory, YDBposix consists of the following files:

- `libydbposix.so` – a shared library with the C software shims

- `ydbposix.xc` – a call-out table to allow M code to call the functions in `libydbposix.so`

- `r/_ydbposix.m` – M source code for higher level `^%ydbposix` entryrefs that M application code can call.

- `r/_ydbposixtest.m` – M source code for `%ydbposixtest` routine to test plugin with `yottadb -run %ydbposix`

- `o/_ydbposix.so` – a shared library with M mode object code for `^%ydbposix` & `^%ydbposixtest` entryrefs

- `o/utf8/_ydbposix.so` – if YottaDB is installed with UTF-8 support, a shared library with UTF-8 mode object code

## Installing YDB POSIX Plugin

YottaDB must be installed and available before installing the POSIX plugin. https://yottadb.com/product/get-started/ has instructions on installing YottaDB. Download and unpack the POSIX plugin in a temporary directory, and make that the current directory. Then:

```shell
mkdir build && cd build
cmake ..
make
[(optional to test functionality)] make test ARGS="-V"
sudo make install
```

At any time after installing the POSIX plugin, you can always test it.

```shell
export ydb_dir=$(mktemp -d)
source $(pkg-config --variable=prefix yottadb)/ydb_env_set
yottadb -run %ydbposixtest
source $(pkg-config --variable=prefix yottadb)/ydb_env_unset
rm -r $ydb_dir
```

## Contributing

To contribute or help with further development, [fork the repository](https://docs.gitlab.com/ee/gitlab-basics/fork-project.html), clone your fork to a local copy and begin contributing! Please also set up the pre-commit script to automatically enforce some coding conventions. Assuming you are in the top-level directory, the following will work:

```sh
ln -s ../../pre-commit .git/hooks
```

Note that this script requires `tcsh`.

### YDBCMake

YDBPosix uses the upstream [YDBCMake] repository for building using YottaDB as the M compiler. Any changes to `ydbcmake/` should first be upstreamed to that repository.
Once the changes are upstreamed, you can merge them into YDBPosix using
```
git pull --no-rebase git@gitlab.com:YottaDB/Tools/YDBCMake.git
```

[YDBCMake]: https://gitlab.com/YottaDB/Tools/YDBCMake
