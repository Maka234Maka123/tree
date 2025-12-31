#!/bin/bash
# 帮助文档

# 显示帮助
cmd_help() {
    cat << 'EOF'
Git Worktree 工作流管理工具

用法: wt <command> [options]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
基础命令 (单人工作流)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  new <branch> [base]   创建新的 worktree 并切换
                        base: 基于哪个分支创建 (默认: HEAD)

  back [-m|--merge]     返回上一个工作空间
                        -m: 自动合并当前分支

  go <branch>           切换到指定的 worktree

  list                  列出所有 worktree 和工作栈

  status                显示当前状态

  remove <branch>       删除指定的 worktree

  clean                 清理无效的 worktree 引用

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
并行工作流命令 (多 Claude Code 协作)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  spawn <base> <b1> <b2> ...
                        批量创建多个 worktree 用于并行开发
                        base: 基础分支
                        b1,b2,...: 要创建的分支名

  jobs                  查看并行任务状态

  done [branch]         标记分支工作完成 (默认当前分支)

  check                 预检查各分支之间的冲突

  merge-all             顺序合并所有已完成的分支

  abort                 中止当前合并，回滚冲突状态

  jobs-clean            清理所有并行任务和 worktree

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
同步命令
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  sync                  同步主分支更新到当前分支
  sync all              同步主分支更新到所有工作分支

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
示例
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

单人工作流:
  wt new feature-login          # 创建并进入 feature-login 分支
  wt new fix-bug main           # 基于 main 创建 fix-bug
  wt back -m                    # 返回上一个工作空间并合并

并行工作流 (多个 Claude Code):
  # 1. 创建三个并行工作空间
  wt spawn main task-1 task-2 task-3

  # 2. 在三个终端中分别进入各个工作空间
  #    终端1: cd .worktrees/myrepo/task-1 && claude
  #    终端2: cd .worktrees/myrepo/task-2 && claude
  #    终端3: cd .worktrees/myrepo/task-3 && claude

  # 3. 各个 Claude Code 完成后，在对应目录执行
  wt done                       # 标记当前分支完成

  # 4. 查看任务状态
  wt jobs

  # 5. 预检查冲突
  wt check

  # 6. 全部完成后合并
  wt merge-all

  # 7. 如果有冲突
  #    - 手动解决冲突
  #    - git add <冲突文件>
  #    - git commit
  #    - wt merge-all (继续合并剩余分支)
  #    或者: wt abort (放弃合并)
EOF
}
