#!/usr/bin/env bash

# 上面的 Shebang 必须位于文件第一行。
# 直接执行 ./scripts/bootstrap_skynet.sh 时，Linux 会通过 /usr/bin/env
# 从当前 PATH 中找到 bash，并用它解释这个文件。

# 打开 Bash 严格模式：
# -e：普通命令返回非 0 时停止脚本；
# -u：读取未定义变量时报错；
# -o pipefail：管道中任意一个命令失败，整条管道都算失败。
set -euo pipefail

# $0 是当前脚本的启动路径。
# dirname "$0" 取得脚本所在目录。
# $(...) 先执行括号内的命令，再把输出替换到当前位置。
# 本脚本位于 scripts/，所以再进入上一级目录就是仓库根目录。
# 使用双引号，避免路径中包含空格时被 Bash 拆成多个参数。
cd "$(dirname "$0")/.."

# 第三方依赖必须固定版本。升级 Skynet 时应显式修改这里并完成回归测试，
# 不能在每次运行脚本时跟随上游 Branch。
# Bash 变量赋值时等号两侧不能有空格；读取变量时使用 "$变量名"。
VERSION="v1.8.0"
DEST="third_party/skynet"

# Makefile 存在时把目录视为已经下载，但仍检查它是否恰好位于目标 Tag。
# [[ ... ]] 是 Bash 条件表达式，-f 判断路径是否为普通文件。
if [[ -f "$DEST/Makefile" ]]; then
    # git -C "$DEST" 表示在目标目录中执行 Git，不改变当前 Shell 目录。
    # 2>/dev/null 把 Standard Error 丢弃；|| 表示左侧失败才执行右侧。
    # describe 失败时执行 true，把这一条复合命令变成成功，让脚本自行诊断版本。
    actual="$(git -C "$DEST" describe --tags --exact-match 2>/dev/null || true)"

    # != 做字符串不等比较。变量全部加双引号，避免空值或空格破坏参数边界。
    if [[ "$actual" != "$VERSION" ]]; then
        # ${actual:-unknown} 表示 actual 未定义或为空时使用 unknown。
        # >&2 把消息写到 Standard Error；exit 1 用非 0 状态结束脚本。
        echo "Skynet 目录存在，但版本不是 $VERSION：${actual:-unknown}" >&2
        exit 1
    fi

    # 版本正确说明 Bootstrap 已完成。exit 0 明确以成功状态结束，不再 Clone。
    echo "Skynet $VERSION already exists at $DEST"
    exit 0
fi

# 目标路径存在却没有 Makefile，可能是中断下载或人工放入的其他文件。
# 脚本拒绝自动覆盖或删除，保留现场给开发者检查。
# -e 判断任意类型的路径是否存在，包括目录、普通文件和 Symbolic Link。
if [[ -e "$DEST" ]]; then
    echo "$DEST 已存在但不是完整 Skynet 源码；请检查后处理，脚本不会覆盖" >&2
    exit 1
fi

# 只取得 v1.8.0 当前 Commit 的浅历史，并初始化 Skynet 记录的 Submodule。
# 行尾反斜杠表示当前命令尚未结束，下一物理行仍属于同一条 git clone。
git clone --recursive --branch "$VERSION" --depth 1 \
    https://github.com/cloudwu/skynet.git "$DEST"

# 再做一次显式恢复，使脚本的依赖条件清楚；若 Clone 期间某个 Submodule
# 没有完成，这里会失败并阻止后续构建。
git -C "$DEST" submodule update --init --recursive

echo "SKYNET_BOOTSTRAP_OK version=$VERSION"