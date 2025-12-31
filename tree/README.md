# wt - Git Worktree 工作流管理工具

一个强大的 Git Worktree 管理工具，专为多任务并行开发设计，特别适合与多个 Claude Code 实例协作。

## 核心概念

```mermaid
graph TB
    subgraph "传统 Git 工作流"
        A[单一工作目录] --> B[只能处理一个任务]
        B --> C[切换分支需要 stash/commit]
    end

    subgraph "wt 工作流"
        D[主仓库 .git] --> E[worktree 1: feature-a]
        D --> F[worktree 2: feature-b]
        D --> G[worktree 3: hotfix]
        E --> H[Claude Code 1]
        F --> I[Claude Code 2]
        G --> J[Claude Code 3]
    end
```

## 安装

### 快速安装（一键）

```bash
# 创建目录并复制文件
mkdir -p ~/.local/bin && \
cp -r wt wt.sh lib ~/.local/bin/ && \
chmod +x ~/.local/bin/wt ~/.local/bin/lib/*.sh && \
echo 'export WT_SCRIPT="$HOME/.local/bin/wt"' >> ~/.zshrc && \
echo 'source "$HOME/.local/bin/wt.sh"' >> ~/.zshrc && \
source ~/.zshrc
```

### 手动安装

#### 1. 创建安装目录

```bash
mkdir -p ~/.local/bin
```

#### 2. 复制脚本文件

```bash
cp wt ~/.local/bin/
cp wt.sh ~/.local/bin/
cp -r lib ~/.local/bin/
```

#### 3. 添加执行权限

```bash
chmod +x ~/.local/bin/wt ~/.local/bin/lib/*.sh
```

#### 4. 配置 Shell

将以下内容添加到 `~/.zshrc` 或 `~/.bashrc`：

```bash
# Git Worktree 工作流管理
export WT_SCRIPT="$HOME/.local/bin/wt"
source "$HOME/.local/bin/wt.sh"
```

#### 5. 重新加载配置

```bash
source ~/.zshrc  # 或 source ~/.bashrc
```

#### 6. 验证安装

```bash
wt help
```

### 安装后目录结构

```
~/.local/bin/
├── wt                      # 主脚本
├── wt.sh                   # Shell 函数包装器
└── lib/                    # 库文件目录
    ├── colors.sh           # 颜色定义
    ├── helpers.sh          # 辅助函数
    ├── cmd_basic.sh        # 基础命令
    ├── cmd_parallel.sh     # 并行命令
    ├── cmd_sync.sh         # 同步命令
    ├── help.sh             # 帮助文档
    ├── shell_helpers.sh    # Shell 辅助函数
    ├── shell_commands.sh   # Shell 命令实现
    └── completions.sh      # 补全脚本
```

### 卸载

```bash
rm -rf ~/.local/bin/wt ~/.local/bin/wt.sh ~/.local/bin/lib
# 然后从 ~/.zshrc 中删除相关配置
```

## 功能概览

```mermaid
mindmap
  root((wt))
    基础命令
      new - 创建分支
      back - 返回合并
      go - 切换分支
      list - 列出所有
      status - 当前状态
    并行开发
      spawn - 批量创建
      jobs - 查看状态
      done - 标记完成
      check - 检查冲突
      merge-all - 全部合并
    同步更新
      sync - 同步当前
      sync all - 同步全部
```

## 使用场景

### 场景一：单人开发工作流

```mermaid
sequenceDiagram
    participant M as main 分支
    participant F as feature 分支

    M->>F: wt new feature-x
    Note over F: 开发新功能...
    F->>M: wt back -m
    Note over M: 自动合并并返回
```

**操作步骤：**

```bash
# 1. 创建新功能分支并进入
wt new feature-login

# 2. 开发完成后，返回 main 并合并
wt back -m

# 3. 或者不合并直接返回
wt back
```

### 场景二：多 Claude Code 并行开发

```mermaid
flowchart TB
    subgraph Step1["1. 创建并行工作空间"]
        A[main] -->|wt spawn main task-1 task-2 task-3| B[创建 3 个 worktree]
    end

    subgraph Step2["2. 并行开发"]
        B --> C1["终端1: task-1<br/>Claude Code 1"]
        B --> C2["终端2: task-2<br/>Claude Code 2"]
        B --> C3["终端3: task-3<br/>Claude Code 3"]
    end

    subgraph Step3["3. 完成并合并"]
        C1 -->|wt done| D1["task-1 ✓"]
        C2 -->|wt done| D2["task-2 ✓"]
        C3 -->|wt done| D3["task-3 ✓"]
        D1 --> E[wt merge-all]
        D2 --> E
        D3 --> E
        E --> F["main (已合并)"]
    end
```

**操作步骤：**

```bash
# 1. 创建三个并行工作空间
wt spawn main feature-auth feature-ui feature-api

# 2. 在三个终端中分别启动 Claude Code
# 终端 1:
cd /path/to/.worktrees/myrepo/feature-auth && claude

# 终端 2:
cd /path/to/.worktrees/myrepo/feature-ui && claude

# 终端 3:
cd /path/to/.worktrees/myrepo/feature-api && claude

# 3. 各个 Claude Code 完成后，确保已提交代码，然后标记完成
git add . && git commit -m "完成功能"
wt done

# 4. 查看任务状态
wt jobs

# 5. 预检查冲突（可选）
wt check

# 6. 合并所有分支
wt merge-all
```

#### 安全检查机制

**wt done 检查流程：**

```mermaid
flowchart TB
    A[wt done] --> B{有未提交的更改?}
    B -->|有| C[❌ 错误: 请先提交更改]
    B -->|无| D{有新的提交?}
    D -->|有| E[✓ 标记为完成]
    D -->|无| F[⚠️ 警告: 没有新提交]
    F --> G{确认继续?}
    G -->|是| E
    G -->|否| H[取消操作]
```

**merge-all 清理流程：**

```mermaid
flowchart TB
    A[wt merge-all] --> B[合并所有 done 状态的分支]
    B --> C{还有 working 状态的分支?}
    C -->|有| D[保留 jobs 文件]
    C -->|无| E[可删除 jobs 文件]
    D --> F[提示: 其他空间可继续工作]
    E --> G[清理完成]
```

#### 部分分支先完成的情况

支持分批合并，先完成的分支可以先合并，其他分支继续工作：

```bash
# 空间 A 先完成
wt done

# 先合并 A（其他空间仍在工作）
wt merge-all
# 提示：还有分支正在工作中，jobs 文件将保留

# 空间 B 后来完成
wt done

# 继续合并 B
wt merge-all
```

#### 常见问题

**问题：执行 wt done 提示"有未提交的更改"**

需要先提交代码才能标记完成：

```bash
git add .
git commit -m "your changes"
wt done
```

**问题：执行 wt done 提示"没有新的提交"**

分支相对于基础分支没有任何新提交，合并时不会有效果。确认是否已完成开发并提交。


### 场景三：同步主分支更新

```mermaid
flowchart TB
    A[main 有新更新] --> B{同步方式}
    B -->|wt sync| C[同步到当前分支]
    B -->|wt sync all| D[同步到所有工作分支]

    C --> E{有冲突?}
    E -->|无| F[继续开发]
    E -->|有| G[手动解决冲突]
    G --> F
```

**操作步骤：**

```bash
# 同步 main 到当前分支
wt sync

# 同步 main 到所有工作分支
wt sync all
```

## 命令参考

### 基础命令

| 命令 | 简写 | 说明 |
|------|------|------|
| `wt new <branch> [base]` | `wt n` | 创建新 worktree 并切换 |
| `wt back [-m\|--merge]` | `wt b` | 返回上一个工作空间，`-m` 自动合并 |
| `wt go <branch>` | `wt g` | 切换到指定 worktree |
| `wt list` | `wt ls` | 列出所有 worktree |
| `wt status` | `wt st` | 显示当前状态 |
| `wt remove <branch>` | `wt rm` | 删除指定 worktree |
| `wt clean` | `wt c` | 清理无效引用 |

### 并行开发命令

| 命令 | 简写 | 说明 |
|------|------|------|
| `wt spawn <base> <b1> <b2>...` | `wt sp` | 批量创建并行 worktree |
| `wt jobs` | `wt j` | 查看并行任务状态 |
| `wt done [branch]` | `wt d` | 标记分支完成（会检查是否有新提交） |
| `wt check` | `wt ck` | 预检查冲突 |
| `wt merge-all` | `wt ma` | 顺序合并所有已完成分支 |
| `wt abort` | - | 中止合并 |
| `wt jobs-clean` | `wt jc` | 清理所有并行任务 |

### 同步命令

| 命令 | 说明 |
|------|------|
| `wt sync` | 同步主分支到当前分支 |
| `wt sync all` | 同步主分支到所有工作分支 |

## 目录结构

```
your-project/                    # 主仓库
├── .git/
│   ├── wt-stack                 # 工作栈记录
│   └── wt-jobs                  # 并行任务记录
└── src/

../.worktrees/your-project/      # worktree 目录（与主仓库同级）
├── feature-auth/
└── feature-ui/
```

## 冲突处理

```mermaid
flowchart TB
    A[执行合并] --> B{有冲突?}
    B -->|无| C[合并成功]
    B -->|有| D[显示冲突文件]
    D --> E[手动解决冲突]
    E --> F[git add 冲突文件]
    F --> G[git commit]
    G --> H{还有分支?}
    H -->|有| I[wt merge-all 继续]
    H -->|无| C

    D --> J[或者 wt abort 放弃]
    J --> K[回到冲突前状态]
```

## 最佳实践

1. **频繁同步**：定期执行 `wt sync` 减少冲突
2. **小步提交**：在 worktree 中频繁提交，便于追踪
3. **预检查**：合并前用 `wt check` 检查潜在冲突
4. **及时清理**：完成后用 `wt clean` 清理无效 worktree
5. **命名规范**：使用有意义的分支名，如 `feature-*`、`fix-*`

## 故障排除

### 问题：worktree 目录被意外删除

```bash
# 清理无效引用
wt clean
# 或
git worktree prune
```

### 问题：分支已被其他 worktree 使用

```bash
# 查看所有 worktree
wt list

# 删除占用该分支的 worktree
wt remove <branch>
```

### 问题：忘记当前在哪个 worktree

```bash
# 查看当前状态
wt status
```

## License

MIT
