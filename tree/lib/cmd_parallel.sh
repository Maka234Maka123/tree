#!/bin/bash
# 并行工作流命令

# 批量创建多个 worktree (spawn)
cmd_spawn() {
    local base_branch="${1:-}"
    shift 2>/dev/null || true
    local branches=("$@")

    if [[ -z "$base_branch" ]] || [[ ${#branches[@]} -eq 0 ]]; then
        echo -e "${RED}错误: 请指定基础分支和要创建的分支${NC}"
        echo "用法: wt spawn <base-branch> <branch1> <branch2> ..."
        echo "示例: wt spawn main feature-1 feature-2 feature-3"
        exit 1
    fi

    local jobs_file=$(get_jobs_file)
    local worktree_base=$(get_worktree_base)
    local main_repo=$(dirname "$(get_main_git_dir)")

    # 检查是否已存在并行任务
    if [[ -f "$jobs_file" ]]; then
        echo -e "${YELLOW}警告: 已存在并行任务${NC}"
        echo ""
        cmd_jobs
        echo ""
        read -p "是否覆盖现有任务? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}提示: 使用 'wt jobs-clean' 清理后再创建新任务${NC}"
            exit 0
        fi
        echo ""
    fi

    # 创建基础目录
    mkdir -p "$worktree_base"

    # 初始化任务文件
    echo "# Parallel Worktree Jobs" > "$jobs_file"
    echo "# Format: branch|status|path|base_branch|created_at" >> "$jobs_file"
    echo "# Status: pending, working, done, merged, conflict" >> "$jobs_file"
    echo "BASE_BRANCH=$base_branch" >> "$jobs_file"
    echo "MAIN_REPO=$main_repo" >> "$jobs_file"
    echo "CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')" >> "$jobs_file"
    echo "---" >> "$jobs_file"

    echo -e "${BLUE}基于 '$base_branch' 创建 ${#branches[@]} 个并行工作空间...${NC}"
    echo ""

    local success_count=0
    for branch in "${branches[@]}"; do
        local worktree_path="$worktree_base/$branch"
        echo -n "  创建 $branch ... "

        if git show-ref --verify --quiet "refs/heads/$branch"; then
            echo -e "${YELLOW}分支已存在，检出...${NC}"
            if git worktree add "$worktree_path" "$branch" 2>/dev/null; then
                echo "$branch|working|$worktree_path|$base_branch|$(date '+%Y-%m-%d %H:%M:%S')" >> "$jobs_file"
                ((success_count++))
            else
                echo -e "${RED}失败${NC}"
                echo "$branch|error|$worktree_path|$base_branch|$(date '+%Y-%m-%d %H:%M:%S')" >> "$jobs_file"
            fi
        else
            if git worktree add -b "$branch" "$worktree_path" "$base_branch" 2>/dev/null; then
                echo -e "${GREEN}成功${NC}"
                echo "$branch|working|$worktree_path|$base_branch|$(date '+%Y-%m-%d %H:%M:%S')" >> "$jobs_file"
                ((success_count++))
            else
                echo -e "${RED}失败${NC}"
                echo "$branch|error|$worktree_path|$base_branch|$(date '+%Y-%m-%d %H:%M:%S')" >> "$jobs_file"
            fi
        fi
    done

    echo ""
    echo -e "${GREEN}✓ 成功创建 $success_count/${#branches[@]} 个工作空间${NC}"
    echo ""
    echo -e "${BLUE}工作空间路径:${NC}"
    for branch in "${branches[@]}"; do
        echo "  $branch: $worktree_base/$branch"
    done
    echo ""
    echo -e "${YELLOW}提示: 在各个终端中进入对应目录开始工作${NC}"
    echo -e "${YELLOW}完成后运行: wt done <branch> 标记完成${NC}"
    echo -e "${YELLOW}全部完成后: wt merge-all 合并所有分支${NC}"
}

# 查看并行任务状态
cmd_jobs() {
    local jobs_file=$(get_jobs_file)

    if [[ ! -f "$jobs_file" ]]; then
        echo -e "${YELLOW}没有并行任务${NC}"
        return
    fi

    echo -e "${BLUE}并行任务状态:${NC}"

    # 读取元信息
    local base_branch=$(grep "^BASE_BRANCH=" "$jobs_file" | cut -d= -f2)
    local created_at=$(grep "^CREATED_AT=" "$jobs_file" | cut -d= -f2-)

    echo "  基础分支: $base_branch"
    echo "  创建时间: $created_at"
    echo ""

    # 统计
    local total=0 working=0 done=0 merged=0 conflict=0

    echo -e "  ${BLUE}分支${NC}                ${BLUE}状态${NC}        ${BLUE}路径${NC}"
    echo "  ─────────────────────────────────────────────────────"

    while IFS='|' read -r branch status path base created; do
        [[ "$branch" =~ ^#.*$ ]] && continue
        [[ "$branch" =~ ^BASE_BRANCH.*$ ]] && continue
        [[ "$branch" =~ ^MAIN_REPO.*$ ]] && continue
        [[ "$branch" =~ ^CREATED_AT.*$ ]] && continue
        [[ "$branch" == "---" ]] && continue
        [[ -z "$branch" ]] && continue

        ((total++))

        local status_display=""
        case "$status" in
            working)
                status_display="${YELLOW}工作中${NC}"
                ((working++))
                ;;
            done)
                status_display="${GREEN}已完成${NC}"
                ((done++))
                ;;
            merged)
                status_display="${GREEN}已合并${NC}"
                ((merged++))
                ;;
            conflict)
                status_display="${RED}有冲突${NC}"
                ((conflict++))
                ;;
            error)
                status_display="${RED}错误${NC}"
                ;;
            *)
                status_display="$status"
                ;;
        esac

        printf "  %-20s %-18b %s\n" "$branch" "$status_display" "$path"
    done < "$jobs_file"

    echo ""
    echo -e "  总计: $total | 工作中: ${YELLOW}$working${NC} | 完成: ${GREEN}$done${NC} | 已合并: ${GREEN}$merged${NC} | 冲突: ${RED}$conflict${NC}"
}

# 标记分支完成
cmd_done() {
    local branch_name="${1:-$(git branch --show-current)}"
    local jobs_file=$(get_jobs_file)

    if [[ ! -f "$jobs_file" ]]; then
        echo -e "${RED}错误: 没有并行任务${NC}"
        exit 1
    fi

    # 获取基础分支
    local base_branch=$(grep "^BASE_BRANCH=" "$jobs_file" | cut -d= -f2)

    # 检查是否有未提交的更改
    # 如果当前分支就是要标记的分支，直接在当前目录检查
    local current_branch=$(git branch --show-current)
    if [[ "$current_branch" == "$branch_name" ]]; then
        if [[ -n $(git status --porcelain) ]]; then
            echo -e "${RED}错误: 分支 '$branch_name' 有未提交的更改${NC}"
            echo "请先提交更改后再标记完成"
            exit 1
        fi
    else
        # 否则尝试进入对应的 worktree 目录检查
        local worktree_base=$(get_worktree_base)
        local worktree_path="$worktree_base/$branch_name"

        if [[ -d "$worktree_path" ]]; then
            cd "$worktree_path"
            if [[ -n $(git status --porcelain) ]]; then
                echo -e "${RED}错误: 分支 '$branch_name' 有未提交的更改${NC}"
                echo "请先提交更改后再标记完成"
                exit 1
            fi
        fi
    fi

    # 检查分支是否有新的提交
    local commit_count=$(git rev-list --count "$base_branch..$branch_name" 2>/dev/null || echo "0")
    if [[ "$commit_count" -eq 0 ]]; then
        echo -e "${YELLOW}警告: 分支 '$branch_name' 相对于 '$base_branch' 没有新的提交${NC}"
        read -p "确定要标记为完成吗? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # 更新状态
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/^$branch_name|working|/$branch_name|done|/" "$jobs_file"
    else
        sed -i "s/^$branch_name|working|/$branch_name|done|/" "$jobs_file"
    fi

    echo -e "${GREEN}✓ 分支 '$branch_name' 已标记为完成${NC}"
    echo ""
    cmd_jobs
}

# 预检查合并冲突
cmd_check() {
    local jobs_file=$(get_jobs_file)

    if [[ ! -f "$jobs_file" ]]; then
        echo -e "${RED}错误: 没有并行任务${NC}"
        exit 1
    fi

    local base_branch=$(grep "^BASE_BRANCH=" "$jobs_file" | cut -d= -f2)
    local main_repo=$(grep "^MAIN_REPO=" "$jobs_file" | cut -d= -f2)

    echo -e "${BLUE}预检查合并冲突...${NC}"
    echo ""

    # 收集所有 done 状态的分支
    local branches_to_check=()
    while IFS='|' read -r branch status path base created; do
        [[ "$branch" =~ ^#.*$ ]] && continue
        [[ "$branch" =~ ^BASE_BRANCH.*$ ]] && continue
        [[ "$branch" =~ ^MAIN_REPO.*$ ]] && continue
        [[ "$branch" =~ ^CREATED_AT.*$ ]] && continue
        [[ "$branch" == "---" ]] && continue
        [[ -z "$branch" ]] && continue

        if [[ "$status" == "done" ]] || [[ "$status" == "working" ]]; then
            branches_to_check+=("$branch")
        fi
    done < "$jobs_file"

    if [[ ${#branches_to_check[@]} -eq 0 ]]; then
        echo -e "${YELLOW}没有需要检查的分支${NC}"
        return
    fi

    cd "$main_repo"

    echo -e "${BLUE}检查各分支与 $base_branch 的冲突情况:${NC}"
    echo ""

    for branch in "${branches_to_check[@]}"; do
        echo -n "  $branch: "

        # 尝试模拟合并
        if git merge-tree $(git merge-base "$base_branch" "$branch") "$base_branch" "$branch" | grep -q "^<<<<<<<"; then
            echo -e "${RED}可能有冲突${NC}"
        else
            echo -e "${GREEN}无冲突${NC}"
        fi
    done

    echo ""
    echo -e "${BLUE}检查分支之间的冲突:${NC}"

    local len=${#branches_to_check[@]}
    for ((i=0; i<len; i++)); do
        for ((j=i+1; j<len; j++)); do
            local b1="${branches_to_check[$i]}"
            local b2="${branches_to_check[$j]}"
            echo -n "  $b1 vs $b2: "

            # 获取共同祖先
            local merge_base=$(git merge-base "$b1" "$b2")
            if git merge-tree "$merge_base" "$b1" "$b2" | grep -q "^<<<<<<<"; then
                echo -e "${RED}可能有冲突${NC}"
            else
                echo -e "${GREEN}无冲突${NC}"
            fi
        done
    done
}

# 合并所有已完成的分支
cmd_merge_all() {
    local jobs_file=$(get_jobs_file)
    local strategy="${1:-sequential}"  # sequential 或 octopus

    if [[ ! -f "$jobs_file" ]]; then
        echo -e "${RED}错误: 没有并行任务${NC}"
        exit 1
    fi

    local base_branch=$(grep "^BASE_BRANCH=" "$jobs_file" | cut -d= -f2)
    local main_repo=$(grep "^MAIN_REPO=" "$jobs_file" | cut -d= -f2)

    # 收集所有 done 状态的分支
    local branches_to_merge=()
    while IFS='|' read -r branch status path base created; do
        [[ "$branch" =~ ^#.*$ ]] && continue
        [[ "$branch" =~ ^BASE_BRANCH.*$ ]] && continue
        [[ "$branch" =~ ^MAIN_REPO.*$ ]] && continue
        [[ "$branch" =~ ^CREATED_AT.*$ ]] && continue
        [[ "$branch" == "---" ]] && continue
        [[ -z "$branch" ]] && continue

        if [[ "$status" == "done" ]]; then
            branches_to_merge+=("$branch")
        fi
    done < "$jobs_file"

    if [[ ${#branches_to_merge[@]} -eq 0 ]]; then
        echo -e "${YELLOW}没有已完成的分支需要合并${NC}"
        echo "请先使用 'wt done <branch>' 标记分支为完成"
        return
    fi

    echo -e "${BLUE}准备合并 ${#branches_to_merge[@]} 个分支到 '$base_branch'${NC}"
    echo "分支: ${branches_to_merge[*]}"
    echo ""

    # 切换到主仓库
    cd "$main_repo"
    git checkout "$base_branch"

    # 创建合并备份点
    local backup_branch="backup-before-merge-$(date +%Y%m%d-%H%M%S)"
    git branch "$backup_branch"
    echo -e "${BLUE}已创建备份分支: $backup_branch${NC}"
    echo ""

    local merged_count=0
    local conflict_branches=()

    for branch in "${branches_to_merge[@]}"; do
        echo -e "${BLUE}合并 '$branch'...${NC}"

        if git merge "$branch" --no-edit; then
            echo -e "${GREEN}✓ 合并成功${NC}"
            ((merged_count++))

            # 更新状态为 merged
            if [[ "$(uname)" == "Darwin" ]]; then
                sed -i '' "s/^$branch|done|/$branch|merged|/" "$jobs_file"
            else
                sed -i "s/^$branch|done|/$branch|merged|/" "$jobs_file"
            fi
        else
            echo -e "${RED}✗ 合并冲突!${NC}"
            conflict_branches+=("$branch")

            # 更新状态为 conflict
            if [[ "$(uname)" == "Darwin" ]]; then
                sed -i '' "s/^$branch|done|/$branch|conflict|/" "$jobs_file"
            else
                sed -i "s/^$branch|done|/$branch|conflict|/" "$jobs_file"
            fi

            echo ""
            echo -e "${YELLOW}冲突文件:${NC}"
            git diff --name-only --diff-filter=U
            echo ""
            echo -e "${YELLOW}请手动解决冲突，然后:${NC}"
            echo "  1. 解决冲突文件"
            echo "  2. git add <冲突文件>"
            echo "  3. git commit"
            echo "  4. 重新运行 wt merge-all 继续合并剩余分支"
            echo ""
            echo -e "${YELLOW}或者放弃合并: wt abort${NC}"
            exit 1
        fi
        echo ""
    done

    echo -e "${GREEN}✓ 成功合并 $merged_count/${#branches_to_merge[@]} 个分支${NC}"
    echo ""

    # 检查是否还有未完成的分支（working 状态）
    local has_working=false
    while IFS='|' read -r branch status path base created; do
        [[ "$branch" =~ ^#.*$ ]] && continue
        [[ "$branch" =~ ^BASE_BRANCH.*$ ]] && continue
        [[ "$branch" =~ ^MAIN_REPO.*$ ]] && continue
        [[ "$branch" =~ ^CREATED_AT.*$ ]] && continue
        [[ "$branch" == "---" ]] && continue
        [[ -z "$branch" ]] && continue

        if [[ "$status" == "working" ]]; then
            has_working=true
            break
        fi
    done < "$jobs_file"

    if $has_working; then
        echo -e "${YELLOW}注意: 还有分支正在工作中，jobs 文件将保留${NC}"
        echo ""
    fi

    # 询问是否清理
    read -p "是否删除已合并的 worktree 和分支? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for branch in "${branches_to_merge[@]}"; do
            local worktree_base=$(get_worktree_base)
            local worktree_path="$worktree_base/$branch"

            if [[ -d "$worktree_path" ]]; then
                git worktree remove "$worktree_path" --force 2>/dev/null || true
            fi
            git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || true
            echo "  已清理: $branch"
        done

        # 只有当没有 working 状态的分支时才删除 jobs 文件
        if ! $has_working; then
            rm -f "$jobs_file"
            echo ""
            echo -e "${GREEN}✓ 清理完成${NC}"
        else
            echo ""
            echo -e "${GREEN}✓ 已合并的分支已清理${NC}"
            echo -e "${YELLOW}提示: jobs 文件已保留，其他空间可继续执行 wt done${NC}"
        fi
    fi
}

# 中止合并
cmd_abort() {
    local jobs_file=$(get_jobs_file)
    local main_repo=$(grep "^MAIN_REPO=" "$jobs_file" 2>/dev/null | cut -d= -f2)

    if [[ -n "$main_repo" ]] && [[ -d "$main_repo" ]]; then
        cd "$main_repo"
    fi

    # 检查是否在合并中
    if git rev-parse --verify MERGE_HEAD > /dev/null 2>&1; then
        git merge --abort
        echo -e "${GREEN}✓ 已中止合并${NC}"
    else
        echo -e "${YELLOW}没有进行中的合并${NC}"
    fi

    # 恢复 conflict 状态为 done
    if [[ -f "$jobs_file" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' 's/|conflict|/|done|/g' "$jobs_file"
        else
            sed -i 's/|conflict|/|done|/g' "$jobs_file"
        fi
        echo "已重置冲突分支状态"
    fi
}

# 清理并行任务
cmd_jobs_clean() {
    local jobs_file=$(get_jobs_file)
    local worktree_base=$(get_worktree_base)

    if [[ ! -f "$jobs_file" ]]; then
        echo -e "${YELLOW}没有并行任务${NC}"
        return
    fi

    echo -e "${BLUE}清理所有并行任务...${NC}"

    while IFS='|' read -r branch status path base created; do
        [[ "$branch" =~ ^#.*$ ]] && continue
        [[ "$branch" =~ ^BASE_BRANCH.*$ ]] && continue
        [[ "$branch" =~ ^MAIN_REPO.*$ ]] && continue
        [[ "$branch" =~ ^CREATED_AT.*$ ]] && continue
        [[ "$branch" == "---" ]] && continue
        [[ -z "$branch" ]] && continue

        if [[ -d "$path" ]]; then
            echo "  删除 worktree: $branch"
            git worktree remove "$path" --force 2>/dev/null || true
        fi
    done < "$jobs_file"

    rm -f "$jobs_file"
    git worktree prune

    echo -e "${GREEN}✓ 清理完成${NC}"
}
