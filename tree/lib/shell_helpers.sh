#!/bin/bash
# Shell 函数包装器 - 辅助函数

# 获取主仓库 git 目录的辅助函数
_wt_get_main_git_dir() {
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ -f "$git_dir" ]]; then
        git_dir=$(cat "$git_dir" | sed 's/gitdir: //')
    fi
    echo "$git_dir" | sed 's|/worktrees/.*||'
}

# 获取 worktree 基础目录
_wt_get_worktree_base() {
    local main_git_dir=$(_wt_get_main_git_dir)
    local main_repo=$(dirname "$main_git_dir")
    echo "$(dirname "$main_repo")/.worktrees/$(basename "$main_repo")"
}
