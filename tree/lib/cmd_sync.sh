#!/bin/bash
# 同步命令

# 同步主分支更新到当前或所有工作分支
cmd_sync() {
    local target="${1:-current}"  # current, all, 或指定分支名
    local base_branch="${2:-}"
    local main_repo=$(dirname "$(get_main_git_dir)")
    local original_dir=$(pwd)

    # 自动检测主分支（不改变当前目录）
    if [[ -z "$base_branch" ]]; then
        if git show-ref --verify --quiet refs/heads/main; then
            base_branch="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            base_branch="master"
        else
            echo -e "${RED}错误: 无法检测主分支，请手动指定${NC}"
            echo "用法: wt sync [current|all] <base-branch>"
            exit 1
        fi
    fi

    echo -e "${BLUE}同步 $base_branch 的更新...${NC}"
    echo ""

    if [[ "$target" == "all" ]]; then
        # 同步所有 worktree 分支
        _sync_all_branches "$base_branch" "$main_repo"
        cd "$original_dir"
    else
        # 同步当前分支（确保在原目录）
        cd "$original_dir"
        _sync_current_branch "$base_branch"
    fi
}

# 同步当前分支
_sync_current_branch() {
    local base_branch="$1"
    local current_branch=$(git branch --show-current)

    if [[ "$current_branch" == "$base_branch" ]]; then
        echo -e "${YELLOW}当前已在 $base_branch 分支${NC}"
        return
    fi

    echo "当前分支: $current_branch"
    echo "同步来源: $base_branch"
    echo ""

    # 检查未提交更改
    if [[ -n $(git status --porcelain) ]]; then
        echo -e "${YELLOW}警告: 有未提交的更改${NC}"
        read -p "是否先 stash 再同步? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash push -m "wt-sync: auto stash before sync"
            local did_stash=true
        else
            echo -e "${RED}请先提交或 stash 更改${NC}"
            return 1
        fi
    fi

    # 执行合并
    echo -e "${BLUE}合并 $base_branch...${NC}"
    if git merge "$base_branch" --no-edit; then
        echo -e "${GREEN}✓ 同步成功${NC}"

        # 恢复 stash
        if [[ "$did_stash" == "true" ]]; then
            echo -e "${BLUE}恢复 stash...${NC}"
            git stash pop
        fi
    else
        echo -e "${RED}✗ 有冲突!${NC}"
        echo ""
        echo -e "${YELLOW}冲突文件:${NC}"
        git diff --name-only --diff-filter=U
        echo ""
        echo -e "${YELLOW}请手动解决冲突，然后:${NC}"
        echo "  git add <冲突文件>"
        echo "  git commit"
        if [[ "$did_stash" == "true" ]]; then
            echo "  git stash pop  # 恢复暂存的更改"
        fi
    fi
}

# 同步所有工作分支
_sync_all_branches() {
    local base_branch="$1"
    local main_repo="$2"

    cd "$main_repo"

    local worktree_branches=()
    while IFS= read -r line; do
        local wt_path=$(echo "$line" | awk '{print $1}')
        local wt_branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

        [[ "$wt_path" == "$main_repo" ]] && continue
        [[ "$wt_branch" == "$base_branch" ]] && continue
        [[ -z "$wt_branch" ]] && continue
        [[ "$wt_branch" == "detached" ]] && continue

        worktree_branches+=("$wt_branch|$wt_path")
    done < <(git worktree list)

    if [[ ${#worktree_branches[@]} -eq 0 ]]; then
        echo -e "${YELLOW}没有其他工作分支需要同步${NC}"
        return
    fi

    echo -e "${BLUE}发现 ${#worktree_branches[@]} 个工作分支:${NC}"
    for item in "${worktree_branches[@]}"; do
        local branch=$(echo "$item" | cut -d'|' -f1)
        echo "  • $branch"
    done
    echo ""

    local success=0 failed=0 skipped=0

    for item in "${worktree_branches[@]}"; do
        local branch=$(echo "$item" | cut -d'|' -f1)
        local path=$(echo "$item" | cut -d'|' -f2)

        echo -n "同步 $branch ... "
        cd "$path"

        if [[ -n $(git status --porcelain) ]]; then
            echo -e "${YELLOW}跳过 (有未提交更改)${NC}"
            ((skipped++))
            continue
        fi

        if git merge "$base_branch" --no-edit 2>/dev/null; then
            echo -e "${GREEN}成功${NC}"
            ((success++))
        else
            echo -e "${RED}冲突${NC}"
            git merge --abort 2>/dev/null
            ((failed++))
        fi
    done

    cd "$main_repo"

    echo ""
    echo -e "${BLUE}同步结果:${NC}"
    echo -e "  成功: ${GREEN}$success${NC}"
    echo -e "  冲突: ${RED}$failed${NC}"
    echo -e "  跳过: ${YELLOW}$skipped${NC}"

    if [[ $failed -gt 0 ]] || [[ $skipped -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}需要手动处理的分支:${NC}"
        for item in "${worktree_branches[@]}"; do
            local branch=$(echo "$item" | cut -d'|' -f1)
            local path=$(echo "$item" | cut -d'|' -f2)
            echo "  cd $path && git merge $base_branch"
        done
    fi
}
