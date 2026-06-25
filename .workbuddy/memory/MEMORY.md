# EServerBuildConfigure 项目长期记忆

## 项目约定

### OpenSSL 依赖映射
参考 Homebrew Formula 生成编译配置时，如果配方依赖 `openssl@3`，本项目统一使用 `openssl@3.5`（路径 `/Applications/EServer/Library/openssl@3.5`）。
所有脚本中的 `OPENSSL_PREFIX` 默认值应设为 `/Applications/EServer/Library/openssl@3.5`。

### pkg-config 路径设置规则（macOS 构建）
所有使用 pkg-config 的脚本只设置 `PKG_CONFIG_PATH`，不设置 `PKG_CONFIG_LIBDIR`。
- `PKG_CONFIG_PATH`：指向 EServer Library 内各依赖的 pkgconfig 目录，在默认路径前搜索
- 不要用 `PKG_CONFIG_LIBDIR`（会完全替换默认搜索路径，导致 libcurl 等库的 `Requires.private` 解析失败）

### 构建脚本结构约定
- `mac_arm64/` 下每个库一个 `.sh` 脚本
- 无外部依赖的基础库放在 `mac_arm64/base/`
- `PREFIX` 默认 `/Applications/EServer/Library/<库名>`
- `make install` 需 `sudo`（写入 /Applications 需要权限）
- 对应 `.github/workflows/build-<库名>.yml`，tag 格式 `<库名>-<版本>`
- 重打 tag 流程：`git tag -d <tag> && git push origin :refs/tags/<tag>` → `git tag <tag> && git push origin <tag>`
- GitHub Actions 的 tag 触发模式是 glob，版本号分隔符需与 tag 一致：tag 为 `php-8.5.7` 时写 `php-8.5.*`，不能写成 `php-8.5-*`（后者只匹配 `php-8.5-xxx`）

### 传递依赖陷阱（macOS）
otool 看到的依赖可能是传递依赖，而非直接依赖。当某库 A 链接了错误的 B（如 Homebrew openssl），
所有依赖 A 的库都会在 Mach-O load commands 中记录 B 的路径。修复时需检查整条依赖链，
不能只看直接构建目标的 configure 日志。