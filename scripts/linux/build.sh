#!/usr/bin/env bash

# 上面的 Shebang 让 Linux 从 PATH 中查找 bash 来解释本文件；它必须是第一行。

# 打开 Bash 严格模式：
# -e：普通命令返回非 0 时停止脚本，编译失败后不会继续打印 BUILD_OK；
# -u：读取未定义变量时报错；
# -o pipefail：管道中任意一个命令失败，整条管道都算失败。
set -euo pipefail

# $0 是当前脚本的启动路径，dirname "$0" 取得 scripts/linux。
# $(...) 是 Command Substitution，把 dirname 的输出放回 cd 命令。
# 本脚本位于 scripts/linux/，所以 /../.. 向上两级回到仓库根目录。
# 整个路径放在双引号中，防止目录名中的空格触发参数拆分。
cd "$(dirname "$0")/../.."

# 新 Clone 中没有 third_party/skynet；先调用 Bootstrap 恢复固定版本源码。
# [[ ... ]] 是 Bash 条件表达式，! 表示取反，-f 判断普通文件是否存在。
# 已有 Makefile 时条件为 False，跳过下载，使日常增量编译保持快速。
if [[ ! -f third_party/skynet/Makefile ]]; then
    ./scripts/bootstrap_skynet.sh
fi

# 使用 Skynet 官方 Makefile 的 linux Target，编译 Runtime、Bundled Lua、
# C Service 和 Lua C Module。-C 只切换 Make 的工作目录，不改变当前 Shell。
make -C third_party/skynet linux

# 只有前面的 Make 成功时才会执行到这里，供人工和 CI 判断构建完成。
echo "BUILD_OK"