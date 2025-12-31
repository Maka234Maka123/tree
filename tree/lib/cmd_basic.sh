#!/bin/bash
# 基础命令

# 创建新的 worktree
cmd_new() {
    local branch_name="$1"
    local base_branch="${2:-HEAD}"

    if [[ -z "$branch_name" ]]; then
        echo -e "${RED}错误: 请指定分支名${NC}"
        echo "用法: wt new <branch-name> [base-branch]"
        exit 1
    fi

    local worktree_base=$(get_worktree_base)
    local worktree_path="$worktree_base/$branch_name"

    # 创建基础目录
    mkdir -p "$worktree_base"

    # 保存当前路径到栈
    push_stack

    # 检查分支是否存在
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo -e "${YELLOW}分支 '$branch_name' 已存在，检出到 worktree...${NC}"
        git worktree add "$worktree_path" "$branch_name"
    else
        echo -e "${GREEN}创建新分支 '$branch_name' (基于 $base_branch)...${NC}"
        git worktree add -b "$branch_name" "$worktree_path" "$base_branch"
    fi

    echo -e "${GREEN}✓ Worktree 创建成功${NC}"
    echo -e "${BLUE}路径: $worktree_path${NC}"
    echo ""
    echo -e "${YELLOW}执行以下命令进入工作空间:${NC}"
    echo -e "  cd $worktree_path"

    # 如果在交互式 shell 中，尝试直接切换
    cd "$worktree_path"
}

# 返回上一个工作空间
cmd_back() {
    local merge_flag="${1:-}"
    local current_branch=$(git branch --show-current)
    local current_path=$(pwd)

    # 从栈中获取上一个路径
    local prev_path=$(pop_stack)

    if [[ -z "$prev_path" ]]; then
        echo -e "${RED}错误: 工作栈为空，没有可返回的工作空间${NC}"
        exit 1
    fi

    # 检查是否有未提交的更改
    if [[ -n $(git status --porcelain) ]]; then
        echo -e "${YELLOW}警告: 当前有未提交的更改${NC}"
        read -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            # 恢复栈
            push_stack_direct "$prev_path"
            exit 1
        fi
    fi

    echo -e "${BLUE}返回: $prev_path${NC}"
    cd "$prev_path"

    # 询问是否合并
    if [[ "$merge_flag" == "--merge" ]] || [[ "$merge_flag" == "-m" ]]; then
        do_merge "$current_branch"
    else
        echo ""
        read -p "是否合并分支 '$current_branch'? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            do_merge "$current_branch"
        fi
    fi

    # 询问是否删除 worktree
    echo ""
    read -p "是否删除 worktree '$current_branch'? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git worktree remove "$current_path" --force 2>/dev/null || true
        echo -e "${GREEN}✓ Worktree 已删除${NC}"

        # 询问是否删除分支
        read -p "是否删除分支 '$current_branch'? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git branch -d "$current_branch" 2>/dev/null || git branch -D "$current_branch"
            echo -e "${GREEN}✓ 分支已删除${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}✓ 已返回工作空间${NC}"
    echo -e "${YELLOW}当前位置: $(pwd)${NC}"
    echo -e "${YELLOW}当前分支: $(git branch --show-current)${NC}"
}

# 列出所有 worktree
cmd_list() {
    echo -e "${BLUE}所有 Worktrees:${NC}"
    git worktree list
    echo ""
    show_stack
}

# 删除指定的 worktree
cmd_remove() {
    local branch_name="$1"

    if [[ -z "$branch_name" ]]; then
        echo -e "${RED}错误: 请指定要删除的分支名${NC}"
        echo "用法: wt remove <branch-name>"
        exit 1
    fi

    local worktree_base=$(get_worktree_base)
    local worktree_path="$worktree_base/$branch_name"

    if [[ -d "$worktree_path" ]]; then
        git worktree remove "$worktree_path" --force
        echo -e "${GREEN}✓ Worktree '$branch_name' 已删除${NC}"
    else
        echo -e "${YELLOW}尝试通过 git worktree 删除...${NC}"
        git worktree remove "$branch_name" --force 2>/dev/null || \
            echo -e "${RED}未找到 worktree: $branch_name${NC}"
    fi
}

# 清理所有已完成的 worktree
cmd_clean() {
    echo -e "${BLUE}清理无效的 worktree 引用...${NC}"
    git worktree prune
    echo -e "${GREEN}✓ 清理完成${NC}"

    # 清空栈中不存在的路径
    local stack_file=$(get_stack_file)
    if [[ -f "$stack_file" ]]; then
        local temp_file=$(mktemp)
        while IFS= read -r path; do
            if [[ -d "$path" ]]; then
                echo "$path" >> "$temp_file"
            else
                echo -e "${YELLOW}移除无效路径: $path${NC}"
            fi
        done < "$stack_file"
        mv "$temp_file" "$stack_file"
    fi
}

# 快速切换到指定 worktree
cmd_go() {
    local branch_name="$1"

    if [[ -z "$branch_name" ]]; then
        echo -e "${RED}错误: 请指定分支名${NC}"
        echo "用法: wt go <branch-name>"
        exit 1
    fi

    local worktree_base=$(get_worktree_base)
    local worktree_path="$worktree_base/$branch_name"

    if [[ -d "$worktree_path" ]]; then
        push_stack
        cd "$worktree_path"
        echo -e "${GREEN}✓ 已切换到: $worktree_path${NC}"
    else
        echo -e "${RED}Worktree 不存在: $branch_name${NC}"
        echo "可用的 worktrees:"
        git worktree list
        exit 1
    fi
}

# 显示状态
cmd_status() {
    local current_branch=$(git branch --show-current)
    local current_path=$(pwd)

    echo -e "${BLUE}当前状态:${NC}"
    echo "  路径: $current_path"
    echo "  分支: $current_branch"
    echo ""

    local prev_path=$(peek_stack)
    if [[ -n "$prev_path" ]]; then
        echo -e "${BLUE}上一个工作空间:${NC}"
        echo "  $prev_path"
    fi
    echo ""
    show_stack
    echo ""
    cmd_jobs
}
