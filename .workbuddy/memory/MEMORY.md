# EServerBuildConfigure 项目长期记忆

## 项目约定

### OpenSSL 依赖映射
参考 Homebrew Formula 生成编译配置时，如果配方依赖 `openssl@3`，本项目统一使用 `openssl@3.5`（路径 `/Applications/EServer/Library/openssl@3.5`）。
所有脚本中的 `OPENSSL_PREFIX` 默认值应设为 `/Applications/EServer/Library/openssl@3.5`。

### pkg-config 路径设置规则（macOS 构建）
所有使用 pkg-config 的脚本只设置 `PKG_CONFIG_PATH`，不设置 `PKG_CONFIG_LIBDIR`。
- `PKG_CONFIG_PATH`：指向 EServer Library 内各依赖的 pkgconfig 目录，在默认路径前搜索
- 不要用 `PKG_CONFIG_LIBDIR`（会完全替换默认搜索路径，导致 libcurl 等库的 `Requires.private` 解析失败）

### 统一 pkgconfig 链接目录
`create-libs.sh`（位于项目根目录）把 `Library/*/lib/pkgconfig`（排除 `lib` 目录本身）下的 `.pc` 文件以相对路径符号链接集中到 `Library/lib/pkgconfig`，方便 pkg-config 一次性搜索所有库。
- 默认 `LIBRARY_DIR=$SCRIPT_DIR/Library`（脚本所在目录的 Library），自动检测 sudo
- 项目内 Library 可写，无需 sudo；可用 `LIBRARY_DIR=/Applications/EServer/Library ./create-libs.sh` 切换到部署目录
- 链接用相对路径 `../../<lib>/lib/pkgconfig/<file>`
- 各库 `.pc` 文件无重名，可直接链接无冲突

### 构建脚本结构约定
- `mac_arm64/` 下每个库一个 `.sh` 脚本
- 无外部依赖的基础库放在 `mac_arm64/base/`
- `PREFIX` 默认 `/Applications/EServer/Library/<库名>`
- `make install` 需 `sudo`（写入 /Applications 需要权限）
- 对应 `.github/workflows/build-<库名>.yml`，tag 格式 `<库名>-<版本>`
- 重打 tag 流程：`git tag -d <tag> && git push origin :refs/tags/<tag>` → `git tag <tag> && git push origin <tag>`
- GitHub Actions 的 tag 触发模式是 glob，版本号分隔符需与 tag 一致：tag 为 `php-8.5.7` 时写 `php-8.5.*`，不能写成 `php-8.5-*`（后者只匹配 `php-8.5-xxx`）

### 产物打包格式
- `mac_arm64/php/` 和 `mac_arm64/server/` 目录使用 `.tar.xz`（`tar -cJf`）。
- `mac_arm64/base/` 及其他基础库目录使用 `.tar.gz`（`tar -czf`）。

### 编译后清理规则
- `mac_arm64/php/` 和 `mac_arm64/server/` 目录下的构建脚本，编译完成后**不删除任何文件或目录**。
- 禁止在 `make install` 后执行 `rm -rf "$PREFIX/share"` 或类似的清理操作。
- 当前状态：php-7.4/8.0/8.1/8.2/8.4/8.5、nginx、redis 已遵守；php-5.6/7.0/7.1/7.2/7.3/8.3 仍残留 share 删除代码。

### 传递依赖陷阱（macOS）
otool 看到的依赖可能是传递依赖，而非直接依赖。当某库 A 链接了错误的 B（如 Homebrew openssl），
所有依赖 A 的库都会在 Mach-O load commands 中记录 B 的路径。修复时需检查整条依赖链，
不能只看直接构建目标的 configure 日志。

### PHP 7.3 opcache 链接修复（macOS arm64 + MACOSX_DEPLOYMENT_TARGET=11.0）
- 官方源码 + `--enable-opcache` 在 arm64 上，opcache.so（shared module）链接报 `_zend_sort` / `_OnUpdateBool` 未定义。
- 根因：PHP 7.3 的 libtool darwin 分支 `_lt_dar_allow_undefined` 只匹配 `10.*`，`11.0` 不匹配 → module 链接缺 `-undefined dynamic_lookup`，无法引用主程序符号。
- 修复：configure 之后、make 之前 sed 改生成的 `libtool`：`s/^allow_undefined_flag=""$/allow_undefined_flag=" -undefined dynamic_lookup"/`。
- 注意：不要把它塞进全局 LDFLAGS（会破坏 configure 的 conftest 链接检测导致 exit 1）。

### PHP 7.4 源码与补丁（2026-11 起）
- 源码改用官方分支归档 `PHP-7.4-CVE-2026-109618-109619`（解压目录 `php-src-PHP-7.4-CVE-2026-109618-109619`）。
- patch 顺序：0002 OpenSSL3.0 → 0003 bug79589 → 0006 ITIMER_REAL → 0009 strict-prototypes → 0010 GH-16168。
- git 分支归档不含 `configure`，patch 后必须 `./buildconf --force`。
- libxml2 版本：`Library/libxml2` = 2.15.3（`xmlversion.h` 已无 `ATTRIBUTE_UNUSED`），
  `Library/libxml2@2.11` = 2.11.9（仍有该宏）。`Library/lib/pkgconfig/libxml-2.0.pc` 指向 2.15.3。
- PHP 7.4 的 `ext/libxml/config0.m4` **没有** `--with-libxml-dir` 选项（7.3 有），libxml2 只能经
  `PKG_CHECK_MODULES(libxml-2.0)` 从 `PKG_CONFIG_PATH` 解析。要让 7.4 用 2.11，把
  `libxml2@2.11/lib/pkgconfig` 放在 `PKG_CONFIG_PATH` 最前即可（不要改 `--with-libxml`）。
- 该 workflow 只有 tag 触发才能正确命名 release：`php-7.4.*`。

### PHP 8.0 源码与补丁（2026-11 起）
- 源码同样改用官方分支归档 `PHP-8.0-CVE-2026-109618-109619`，不再用 `php-src-backports-8.0.30.tar.gz`。
- patch 顺序：0002 OpenSSL3.0 → 0003 bug79589 → 0006 ITIMER_REAL → 0009 strict-prototypes → 0010 GH-16168。
- 0009 的文件名是 `...-PHP-8.0.patch`（带连字符），其余四个是 `...PHP8.0.patch`，易混。
- 脚本用 `apply_patch()` 幂等应用：`patch -p1 -R --dry-run` 成功即视为已应用并跳过，
  兼容「backports 包已内置补丁」的情况（直接 `patch -p1 <` 会因 reversed 而失败）。
- 直接编译（`PKG_CONFIG_PATH` 只含 `Library/lib/pkgconfig`）会失败：`ext/libxml/libxml.c:431` 的
  `int compression ATTRIBUTE_UNUSED` 报 `expected ')'`——libxml 解析到 2.15.3。解法与 7.4 相同：
  `PKG_CONFIG_PATH=/Applications/EServer/Library/libxml2@2.11/lib/pkgconfig:/Applications/EServer/Library/lib/pkgconfig`。
- 分支归档不含 `configure`，patch 后需 `./buildconf --force`；workflow tag 模式 `php-8.0.*`。

### macOS 脚本 sed 陷阱
- macOS 自带 BSD sed 的 ERE **不支持** `\s`（GNU 扩展），`s/a,\s+0/b/` 这类表达式会静默不匹配。
- 需要空白匹配时用 `[[:space:]]`；`-i` 必须带备份后缀（`-i.bak`）。

### CI 失败诊断（无法读取 Actions 日志时）
- 匿名 GitHub API 读不到 Actions 日志；脚本 ERR trap 把「行号 + make 中 `error:` 摘要」写入 `$GITHUB_WORKSPACE/failure.txt`，
  workflow 在 `if: failure()` 步骤用 `GITHUB_TOKEN` 上报到 commit status（context `diag-<job>-N`，每条 130 字符）。
- 上报前用 `sed "s#$PWD/##g"` 去掉源码绝对路径，否则长路径会把错误文案挤出 130 字符窗口。
### PHP 8.1 源码与补丁（2026-11 起）
- 源码改用官方分支归档 `PHP-8.1-CVE-2026-109618-109619`（分支版本 8.1.34，非 8.1.31）。
- 只打 1 个补丁：`0006-Use-ITIMER_REAL-for-timeout-handling-PHP-8.1.patch`（offset 15）。
- 必须 `CFLAGS += -std=gnu17`：`ext/bcmath/libbcmath` 的 K&R 风格定义在 C23 下属实报错
  （`unknown type name 'n1'`）。
- libxml2 覆盖：编译层面 8.1 分支已兼容 2.15（`int compression)` + `#if LIBXML_VERSION` const 保护），
  但运行期 `ext/xml/compat.c` 仍是旧条件，2.13+ 不再维护 `ATTRIBUTE_VALUE`/`ENTITY_VALUE`
  状态会让属性内实体误报，故最终统一改走 `PKG_CONFIG_PATH` 前置 `libxml2@2.11`（2.11.9），
  也因此不需要 `0007-Fix-PEAR-installation-with-libxml2.13-PHP-8.1.patch`。
- 分支归档不含 `configure`，需 buildconf，故 workflow 需安装 autoconf/bison 并加 Homebrew PATH。
