#!/bin/bash
# 辅助函数

# 获取 git 仓库根目录
get_git_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# 获取主仓库的 .git 目录（处理 worktree 情况）
get_main_git_dir() {
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ -f "$git_dir" ]]; then
        # 这是一个 worktree，读取实际的 git 目录
        git_dir=$(cat "$git_dir" | sed 's/gitdir: //')
    fi
    # 如果是 worktree，路径会包含 /worktrees/xxx，需要获取主目录
    echo "$git_dir" | sed 's|/worktrees/.*||'
}

# 获取栈文件路径
get_stack_file() {
    local main_git_dir=$(get_main_git_dir)
    echo "$main_git_dir/wt-stack"
}

# 获取任务文件路径（用于并行工作流）
get_jobs_file() {
    local main_git_dir=$(get_main_git_dir)
    echo "$main_git_dir/wt-jobs"
}

# 获取合并队列文件
get_merge_queue_file() {
    local main_git_dir=$(get_main_git_dir)
    echo "$main_git_dir/wt-merge-queue"
}

# 获取 worktree 基础目录（桌面上的 worktrees 文件夹）
get_worktree_base() {
    local main_git_dir=$(get_main_git_dir)
    # 主仓库目录
    local main_repo=$(dirname "$main_git_dir")
    # worktree 放在桌面的 worktrees 文件夹下
    echo "$HOME/Desktop/worktrees/$(basename "$main_repo")"
}

# 推入栈
push_stack() {
    local stack_file=$(get_stack_file)
    local current_path=$(pwd)
    echo "$current_path" >> "$stack_file"
}

# 弹出栈
pop_stack() {
    local stack_file=$(get_stack_file)
    if [[ ! -f "$stack_file" ]] || [[ ! -s "$stack_file" ]]; then
        echo ""
        return
    fi
    local last_path=$(tail -1 "$stack_file")
    # 删除最后一行
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' '$ d' "$stack_file"
    else
        sed -i '$ d' "$stack_file"
    fi
    echo "$last_path"
}

# 查看栈顶
peek_stack() {
    local stack_file=$(get_stack_file)
    if [[ ! -f "$stack_file" ]] || [[ ! -s "$stack_file" ]]; then
        echo ""
        return
    fi
    tail -1 "$stack_file"
}

# 显示栈内容
show_stack() {
    local stack_file=$(get_stack_file)
    if [[ ! -f "$stack_file" ]] || [[ ! -s "$stack_file" ]]; then
        echo -e "${YELLOW}工作栈为空${NC}"
        return
    fi
    echo -e "${BLUE}工作栈 (从底到顶):${NC}"
    local i=1
    while IFS= read -r line; do
        echo "  $i. $line"
        ((i++))
    done < "$stack_file"
}

# 直接推入栈（用于恢复）
push_stack_direct() {
    local path="$1"
    local stack_file=$(get_stack_file)
    echo "$path" >> "$stack_file"
}

# 执行合并
do_merge() {
    local branch_to_merge="$1"
    local current_branch=$(git branch --show-current)

    echo -e "${BLUE}合并 '$branch_to_merge' 到 '$current_branch'...${NC}"

    if git merge "$branch_to_merge" --no-edit; then
        echo -e "${GREEN}✓ 合并成功${NC}"
    else
        echo -e "${RED}合并冲突! 请手动解决后提交${NC}"
        exit 1
    fi
}
