#!/bin/bash
# Shell 补全脚本

# 命令补全 (zsh)
if [[ -n "$ZSH_VERSION" ]]; then
    _wt_completion() {
        local -a commands
        commands=(
            'new:创建新的 worktree'
            'back:返回上一个工作空间'
            'go:切换到指定 worktree'
            'list:列出所有 worktree'
            'status:显示当前状态'
            'remove:删除指定 worktree'
            'clean:清理无效引用'
            'spawn:批量创建并行 worktree'
            'jobs:查看并行任务状态'
            'done:标记分支完成'
            'check:预检查合并冲突'
            'merge-all:合并所有已完成分支'
            'abort:中止当前合并'
            'jobs-clean:清理所有并行任务'
            'help:显示帮助'
        )

        if (( CURRENT == 2 )); then
            _describe 'command' commands
        elif (( CURRENT == 3 )); then
            case "${words[2]}" in
                new|go|remove|done)
                    local branches
                    branches=($(git branch --format='%(refname:short)' 2>/dev/null))
                    _describe 'branch' branches
                    ;;
                spawn)
                    local branches
                    branches=($(git branch --format='%(refname:short)' 2>/dev/null))
                    _describe 'base branch' branches
                    ;;
            esac
        fi
    }
    compdef _wt_completion wt
fi

# 命令补全 (bash)
if [[ -n "$BASH_VERSION" ]]; then
    _wt_completion() {
        local cur prev commands
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        commands="new back go list status remove clean spawn jobs done check merge-all abort jobs-clean help n b g ls st rm c sp j d ck ma jc h"

        if [[ ${COMP_CWORD} -eq 1 ]]; then
            COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
        elif [[ ${COMP_CWORD} -eq 2 ]]; then
            case "${prev}" in
                new|n|go|g|remove|rm|r|done|d|spawn|sp)
                    local branches=$(git branch --format='%(refname:short)' 2>/dev/null)
                    COMPREPLY=( $(compgen -W "${branches}" -- ${cur}) )
                    ;;
            esac
        fi
    }
    complete -F _wt_completion wt
fi
