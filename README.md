查看其依赖的所有共享库（静态库）的列表

`otool -L /path/binary`

查看最低支持的 macOS 版本。

x86 `otool -l /path/binary | grep -A 3 LC_VERSION_MIN_MACOSX`

arm `otool -l /path/binary | grep -A 3 LC_BUILD_VERSION`

查看arch

`file /path/binary` 或者 `lipo -info /path/binary`
