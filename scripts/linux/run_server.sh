#!/usr/bin/env bash

# 上面的 Shebang 必须位于第一行；直接执行脚本时，Linux 会从 PATH 中
# 找到 bash，并用它解释本文件。

# 打开 Bash 严格模式：
# -e：普通命令返回非 0 时停止脚本；
# -u：读取未定义变量时报错；
# -o pipefail：管道中任意一个命令失败，整条管道都算失败。
set -euo pipefail

# $0 是当前脚本的启动路径，dirname "$0" 取得 scripts/linux。
# $(...) 会先执行 dirname，再把输出替换进 cd 的参数。
# 本脚本位于 scripts/linux/，/../.. 向上两级就是仓库根目录。
# 双引号保护整个路径，避免路径中的空格被 Bash 拆成多个参数。
cd "$(dirname "$0")/../.."

# $1 是第一个位置参数。
# ${1:-config/game.lua} 表示 $1 未提供或为空时使用右侧默认值。
# 未传参数时使用开发配置；以后也可以显式传入 config/test.lua。
CONFIG="${1:-config/game.lua}"

# exec 用 Skynet Process 替换当前 Shell Script Process，不额外保留一层 Bash；
# Process PID 不变，退出码和 Ctrl+C 等 Signal 可以直接传递。
# "$CONFIG" 保证配置路径即使含有空格也作为一个完整参数传给 Skynet。
exec ./third_party/skynet/skynet "$CONFIG"