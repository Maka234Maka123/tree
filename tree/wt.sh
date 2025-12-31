# Git Worktree 工作流管理 - Shell 函数包装器
# 安装: 复制到 ~/.local/bin/ 并在 ~/.zshrc 中 source

# 设置 wt 脚本路径
WT_SCRIPT="${WT_SCRIPT:-$HOME/.local/bin/wt}"

# 获取当前脚本所在目录
_WT_SHELL_DIR="${_WT_SHELL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}"

# 加载库文件
source "$_WT_SHELL_DIR/lib/shell_helpers.sh"
source "$_WT_SHELL_DIR/lib/shell_commands.sh"
source "$_WT_SHELL_DIR/lib/completions.sh"
