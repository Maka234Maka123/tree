#!/bin/bash
# Shell 函数包装器 - wt 命令实现

wt() {
    local command="$1"

    case "$command" in
        new|n)
            # 执行脚本并获取新目录路径
            local output
            output=$("$WT_SCRIPT" "$@" 2>&1)
            local exit_code=$?
            echo "$output"

            if [[ $exit_code -eq 0 ]]; then
                # 从输出中提取路径并切换
                local new_path
                new_path=$(echo "$output" | grep "路径:" | sed 's/.*路径: //' | sed 's/\x1b\[[0-9;]*m//g')
                if [[ -n "$new_path" ]] && [[ -d "$new_path" ]]; then
                    cd "$new_path"
                    echo ""
                    echo "已切换到: $(pwd)"
                fi
            fi
            ;;

        back|b)
            # 获取返回的目录
            local main_git_dir=$(_wt_get_main_git_dir)
            local stack_file="$main_git_dir/wt-stack"

            if [[ ! -f "$stack_file" ]] || [[ ! -s "$stack_file" ]]; then
                echo "错误: 工作栈为空，没有可返回的工作空间"
                return 1
            fi

            local prev_path=$(tail -1 "$stack_file")
            local current_branch=$(git branch --show-current)
            local current_path=$(pwd)

            # 检查未提交更改
            if [[ -n $(git status --porcelain) ]]; then
                echo "警告: 当前有未提交的更改"
                read -p "是否继续? (y/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    return 1
                fi
            fi

            # 删除栈顶
            if [[ "$(uname)" == "Darwin" ]]; then
                sed -i '' '$ d' "$stack_file"
            else
                sed -i '$ d' "$stack_file"
            fi

            # 切换目录
            cd "$prev_path"
            echo "已返回: $prev_path"
            echo "当前分支: $(git branch --show-current)"

            # 处理合并
            local do_merge=false
            if [[ "$2" == "--merge" ]] || [[ "$2" == "-m" ]]; then
                do_merge=true
            else
                echo ""
                read -p "是否合并分支 '$current_branch'? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    do_merge=true
                fi
            fi

            if $do_merge; then
                echo "合并 '$current_branch'..."
                if git merge "$current_branch" --no-edit; then
                    echo "合并成功"
                else
                    echo "合并冲突! 请手动解决"
                    return 1
                fi
            fi

            # 处理删除 worktree
            echo ""
            read -p "是否删除 worktree '$current_branch'? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git worktree remove "$current_path" --force 2>/dev/null && echo "Worktree 已删除"

                read -p "是否删除分支 '$current_branch'? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    git branch -d "$current_branch" 2>/dev/null || git branch -D "$current_branch"
                    echo "分支已删除"
                fi
            fi
            ;;

        go|g)
            # 切换到指定 worktree
            local branch_name="$2"
            if [[ -z "$branch_name" ]]; then
                echo "错误: 请指定分支名"
                return 1
            fi

            local main_git_dir=$(_wt_get_main_git_dir)
            local worktree_base=$(_wt_get_worktree_base)
            local worktree_path="$worktree_base/$branch_name"

            if [[ -d "$worktree_path" ]]; then
                echo "$(pwd)" >> "$main_git_dir/wt-stack"
                cd "$worktree_path"
                echo "已切换到: $worktree_path"
            else
                echo "Worktree 不存在: $branch_name"
                git worktree list
                return 1
            fi
            ;;

        spawn|sp)
            # 批量创建 worktree，不切换目录
            "$WT_SCRIPT" "$@"
            ;;

        merge-all|ma)
            # 合并所有分支，需要切换到主仓库
            local main_git_dir=$(_wt_get_main_git_dir)
            local jobs_file="$main_git_dir/wt-jobs"

            if [[ ! -f "$jobs_file" ]]; then
                echo "错误: 没有并行任务"
                return 1
            fi

            local main_repo=$(grep "^MAIN_REPO=" "$jobs_file" | cut -d= -f2)
            if [[ -n "$main_repo" ]] && [[ -d "$main_repo" ]]; then
                cd "$main_repo"
            fi

            "$WT_SCRIPT" "$@"
            ;;

        abort)
            # 中止合并，可能需要切换目录
            local main_git_dir=$(_wt_get_main_git_dir)
            local jobs_file="$main_git_dir/wt-jobs"

            if [[ -f "$jobs_file" ]]; then
                local main_repo=$(grep "^MAIN_REPO=" "$jobs_file" 2>/dev/null | cut -d= -f2)
                if [[ -n "$main_repo" ]] && [[ -d "$main_repo" ]]; then
                    cd "$main_repo"
                fi
            fi

            "$WT_SCRIPT" "$@"
            ;;

        *)
            # 其他命令直接执行脚本
            "$WT_SCRIPT" "$@"
            ;;
    esac
}
