# OpenCode 规则说明

本目录包含 OpenCode 平台专用的开发规则、配置和技能模板。

## 目录结构

```
opencode_rules/
├── AGENTS.md                 # OpenCode 专用主规则
├── opencode.json            # OpenCode 配置模板
├── SKILLS/                  # Agent 技能模板
│   ├── code-review.mdc     # 代码审查技能
│   ├── bug-fix.mdc         # Bug 修复技能
│   └── refactor.mdc       # 重构技能
├── scripts/
│   └── templates/
│       └── opencode_parallel_tasks.sh  # 并行任务脚本模板
└── README.md               # 本说明文档
```

## 快速开始

### 1. 在项目中启用 OpenCode 规则

将以下文件复制到你的项目根目录：

```bash
# 复制规则文件
cp opencode_rules/AGENTS.md /your/project/root/
cp opencode_rules/opencode.json /your/project/root/

# 可选：复制技能文件
cp -r opencode_rules/SKILLS /your/project/root/

# 可选：复制脚本模板
cp -r opencode_rules/scripts/templates /your/project/root/scripts/
```

### 2. 在 OpenCode 中使用

启动 OpenCode，项目将自动加载 `AGENTS.md` 和 `opencode.json`。

### 3. 验证规则加载

在 OpenCode 中运行 `/init` 命令，或查看 Agent 配置确认规则已加载。

## 核心特性

### 1. Agent 协作规范

OpenCode 规则强调多 Agent 协作，充分利用平台的并行处理能力。

| Agent | 用途 | 使用场景 |
|-------|------|---------|
| **Explore** | 代码库探索 | 查找代码模式、理解项目结构 |
| **Librarian** | 外部文档查询 | 查找 API 文档、搜索 OSS 实现 |
| **Oracle** | 复杂决策 | 架构设计、战略规划 |

### 2. Background Task 并行执行

使用 `background_task` 实现真正的并行处理：

```typescript
// 并行启动多个探索任务
background_task(agent="explore", prompt="Find auth implementations...", run_in_background=true)
background_task(agent="explore", prompt="Find error handling...", run_in_background=true)
background_task(agent="librarian", prompt="Find JWT best practices...", run_in_background=true)

// 继续其他工作...

// 需要结果时收集
result = background_output(task_id="bg_xxx")

// 完成后取消所有后台任务
background_cancel(all=true)
```

### 3. 会话管理

利用 OpenCode 的会话历史功能：

- `session_list` - 查看历史会话
- `session_search` - 搜索历史解决方案
- `session_read` - 读取完整会话上下文

### 4. Agent Skills

可重用的 Agent 行为模式：

- **code-review** - 代码审查流程
- **bug-fix** - Bug 修复流程
- **refactor** - 重构流程

## 与原有规则的关系

| 特性 | 原有规则 | OpenCode 规则 | 兼容性 |
|------|---------|--------------|--------|
| **代码质量约束** | 有 | 有 | 完全兼容 |
| **Monocode 架构** | 有 | 有 | 完全兼容 |
| **强护栏机制** | 有 | 有 | 完全兼容 |
| **规则加载** | `.agent/rules/` | `AGENTS.md` | 不同的加载方式 |
| **Agent 协作** | 无 | 有 | OpenCode 专属 |
| **并行任务** | 无 | 有 | OpenCode 专属 |
| **会话管理** | 无 | 有 | OpenCode 专属 |

**说明**：
- 原有规则仍然适用于 Antigravity 和 Cursor/VS Code 环境
- OpenCode 规则增强了原有规则，添加了 OpenCode 特定功能
- 两者可以共存，根据运行环境自动选择

## 配置说明

### opencode.json

OpenCode 配置文件包含以下关键设置：

```json
{
  "instructions": ["AGENTS.md", "Debugging-Rules.md"],  // 加载的规则文件
  "permission": {                                        // 工具权限配置
    "bash": {
      "git push": "ask",                                // 危险操作需要确认
      "*": "allow"
    }
  },
  "tools": {                                            // 启用的工具
    "background_task": true,
    "session_list": true,
    "lsp_diagnostics": true
  },
  "agents": {                                           // Agent 配置
    "explore": {
      "temperature": 0.2,
      "max_steps": 20
    }
  }
}
```

### 权限配置

建议将以下操作设置为 `"ask"`：
- `git push` - 推送到远程仓库
- `rm -rf` - 递归删除文件
- `git reset --hard` - 硬重置
- `git push -f` - 强制推送

## 最佳实践

### 1. 并行探索优先

遇到需要探索代码库的任务，立即启动多个 background_task：

```typescript
// ✅ 正确：并行探索
background_task(agent="explore", prompt="Find all auth endpoints", run_in_background=true)
background_task(agent="explore", prompt="Find all error handlers", run_in_background=true)
background_task(agent="librarian", prompt="Find JWT implementation examples", run_in_background=true)

// ❌ 错误：顺序探索
result1 = task("Find all auth endpoints")
result2 = task("Find all error handlers")
result3 = task("Find JWT implementation examples")
```

### 2. 委托给专业 Agent

根据任务类型选择合适的 Agent：

- 代码搜索 → `explore`
- 文档查询 → `librarian`
- 架构决策 → `oracle`
- 代码审查 → `code-review` skill
- Bug 修复 → `bug-fix` skill
- 重构 → `refactor` skill

### 3. 完整的委托 Prompt

使用标准的 7 部分 Prompt 结构：

```
1. TASK: [单一、具体的任务]
2. EXPECTED OUTCOME: [可衡量的结果]
3. REQUIRED SKILLS: [需要的技能]
4. REQUIRED TOOLS: [工具白名单]
5. MUST DO: [详尽需求]
6. MUST NOT DO: [禁止行为]
7. CONTEXT: [上下文信息]
```

### 4. 利用会话历史

遇到相似问题时，先搜索历史会话：

```typescript
// 搜索历史解决方案
session_search(query="JWT authentication error")

// 如果找到相关会话，读取完整上下文
session_read(session_id="ses_xxx")
```

### 5. 及时取消后台任务

任务完成后立即取消所有后台任务，释放资源：

```typescript
// 收集所有结果后
background_cancel(all=true)
```

## 常见问题

### Q: OpenCode 规则与原有规则冲突怎么办？

A: OpenCode 规则是在原有规则基础上的增强，两者在代码质量约束、架构规范等方面完全兼容。仅在规则加载方式和 Agent 协作机制上有差异。

### Q: 可以同时使用 OpenCode 规则和原有规则吗？

A: 可以。在 OpenCode 环境中使用 OpenCode 规则，在 Antigravity 或 Cursor/VS Code 中使用原有规则。规则文件会根据运行环境自动选择。

### Q: background_task 的并发数有限制吗？

A: 没有硬性限制，但建议同时启动 3-5 个任务。过多的并发任务可能导致资源紧张。

### Q: 如何确保代码质量？

A: OpenCode 规则继承了原有规则的所有代码质量约束（文件行数、目录结构、坏味道识别等），并添加了 lsp_diagnostics 检查和自动化测试验证。

### Q: 如何自定义权限配置？

A: 编辑项目根目录的 `opencode.json`，在 `permission` 字段中添加或修改权限规则。

## 进阶使用

### 创建自定义 Skill

在 `SKILLS/` 目录中创建 `.mdc` 文件，定义自己的 Agent 行为模式：

```markdown
# My Custom Skill

## 触发条件
[何时使用此技能]

## 执行步骤
1. [步骤 1]
2. [步骤 2]
3. [步骤 3]

## 输出格式
[标准的输出格式]
```

### 扩展并行任务脚本

参考 `scripts/templates/opencode_parallel_tasks.sh`，创建自己的并行任务脚本，用于特定的项目需求。

## 参考资源

- [OpenCode 官方文档](https://docs.opencode.dev)
- [Agent 协作最佳实践](https://docs.opencode.dev/agents/collaboration)
- [Background Task API](https://docs.opencode.dev/api/background-tasks)
- [会话管理 API](https://docs.opencode.dev/api/sessions)

## 贡献

如果你有改进建议或发现 Bug，欢迎提交 Issue 或 Pull Request。

## 许可证

与主项目保持一致。
