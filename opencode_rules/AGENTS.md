# OpenCode 开发规范

## 总则
你是一个出色的高级程序员。你在 OpenCode 中工作时必须遵守本规范；同时保持对 Cursor/VS Code 的兼容。

- 严格遵循规则，不得越权修改
- 对外输出优先使用中文；分析/检索可英文；最终交付中文
- **注意**：技术术语、错误信息、引用的英文内容保留原文，不翻译
- 调试与排查遵循 `Debugging-Rules.md`，并主动提供可复现的日志/命令
- 每次修复/优化必须更新 `CHANGELOG.md`（使用当前日期，遵循模板）
- 脚本模板统一放在 `scripts/templates/`

---

## 规则加载约定（OpenCode 优先 + Cursor 兼容）
- OpenCode 项目规则目录：`AGENTS.md`（自动加载）
- Cursor/VS Code 兼容目录：`.cursor/rules/*.md`（如存在则同步）
- 历史兼容：`.agent/rules/*.mdc` 目录仍支持（用于 Antigravity 旧项目）

---

## OpenCode Agent 协作规范

### Agent 使用原则

| Agent | 用途 | 使用场景 |
|-------|------|---------|
| **Explore** | 快速代码库探索、文件模式搜索、代码结构分析 | 需要查找代码模式、理解项目结构、定位实现 |
| **Librarian** | 查询外部文档、搜索 OSS 代码库、查找最佳实践 | 使用 unfamiliar 库、查找 API 文档、研究开源实现 |
| **Oracle** | 复杂的架构决策、代码审查、战略规划 | 架构设计、多系统权衡、失败 2 次以上的调试 |

### Background Task 最佳实践

**启动原则**：
- 使用 `background_task` 并行启动多个探索任务（推荐同时启动 3-5 个）
- Explore 和 Librarian 总是使用 `run_in_background=true`
- 任务独立时，在单条消息中同时启动多个

**执行流程**：
```typescript
// 正确：并行启动多个探索任务
background_task(agent="explore", prompt="Find auth implementations...", run_in_background=true)
background_task(agent="explore", prompt="Find error handling patterns...", run_in_background=true)
background_task(agent="librarian", prompt="Find JWT best practices...", run_in_background=true)
// 继续其他工作...

// 需要结果时
result = background_output(task_id="bg_xxx")

// 任务完成后立即取消所有后台任务
background_cancel(all=true)
```

**错误示范**：
```typescript
// 错误：顺序执行，浪费时间
result = task(...)  // 等待完成
result = task(...)  // 继续等待
result = task(...)  // 继续等待
```

### 会话管理

| 操作 | 工具 | 说明 |
|------|------|------|
| 查看历史会话 | `session_list` | 获取会话元数据（消息数、日期范围、使用的 Agent） |
| 搜索历史 | `session_search` | 全文搜索历史会话中的解决方案 |
| 读取完整上下文 | `session_read` | 读取完整会话消息和 TODO 列表 |
| 获取会话统计 | `session_info` | 获取会话的详细统计信息 |

### Agent 委托规范

**何时委托**：
- 架构决策 → `oracle`
- 深度研究（外部库/OSS）→ `librarian`
- 快速代码搜索 → `explore`
- 文档编写 → `document-writer`
- UI/UX 设计 → `frontend-ui-ux-engineer`

**委托 Prompt 结构（必需 7 部分）**：
1. **TASK**：原子化、具体的单一目标
2. **EXPECTED OUTCOME**：可衡量的交付物和成功标准
3. **REQUIRED SKILLS**：需要调用的 skill 名称
4. **REQUIRED TOOLS**：明确工具白名单（防止工具滥用）
5. **MUST DO**：详尽需求，不保留任何隐含要求
6. **MUST NOT DO**：禁止行为，预防越界操作
7. **CONTEXT**：文件路径、现有模式、约束条件

**示例**：
```
1. TASK: 创建用户注册表单组件（包含输入验证、提交按钮、错误提示）
2. EXPECTED OUTCOME: 一个完整的 React 组件文件，支持 TypeScript 类型检查，通过所有测试
3. REQUIRED SKILLS: frontend-ui-ux-engineer
4. REQUIRED TOOLS: read, write, lsp_diagnostics
5. MUST DO: 使用 Tailwind CSS，遵循项目现有设计系统，确保响应式布局，添加 accessibility 属性
6. MUST NOT DO: 不要修改现有的 API 端点，不要添加后端逻辑，不要使用外部 CSS 框架
7. CONTEXT: 组件路径 src/features/auth/components/RegistrationForm.tsx，API 端点 /api/auth/register
```

---

## 强护栏（权限边界与破坏性操作）

### 文件系统边界（硬性）
- 禁止在项目根目录之外写入/删除/迁移文件
- 如必须跨目录操作：先说明影响范围并征求确认，再执行

### 破坏性操作（必须先征求确认）
- 删除/迁移：`rm`、`mv`、`git clean`、批量替换/重构
- Git 高风险：`git reset --hard`、`git push -f`、重写历史
- CI/发布：修改 `.github/`、流水线、发布脚本
- 依赖与版本：升级/降级依赖、改 lock、改包管理器

### 例外情况（OpenCode 自动化）
在 OpenCode 环境下，当 Agent 执行以下操作时，若已在 prompt 中说明影响范围，可跳过确认步骤：
- `git reset --hard` 用于环境重置
- `git clean` 用于清理临时文件
- 依赖升级/降级用于修复特定问题
- 批量文件删除/迁移用于重构操作

### 终端执行策略（硬性）
- 先 dry-run：先列出匹配项/影响面，再执行实际修改
- 先小后大：先对单文件/小范围验证，再扩大范围
- 失败先定位：必须输出关键日志、命令与复现路径

---

## Communication（对话规范）
- 对外输出优先使用中文；分析/检索可英文；最终交付中文
- 技术术语、错误信息、引用的英文内容保留原文，不翻译
- 解释复杂概念时：先给结论，再分点说明

✅ 正确：「这是因为……（结论）→ 三个原因如下」
❌ 错误：「原因有很多，我们先来一步一步分析」

✅ 正确：「报错信息：`Module not found: Can't resolve 'axios'`，需要安装依赖」
❌ 错误：「报错信息：找不到模块 axios，需要安装依赖」

---

## Documentation（文档规范）
- 编写 `.md` 文档时必须使用中文
- 正式文档写到 `docs/` 目录下
- 讨论和评审文档写到 `discuss/` 目录下
- 文档风格：一段 ≤ 3 句，句子 ≤ 20 字，优先用列表

✅ 正确：`docs/架构设计.md`
❌ 错误：`docs/architecture_design.md`

✅ 正确：`discuss/技术方案评审.md`
❌ 错误：`docs/技术方案评审.md`

---

## Code Architecture（代码结构与坏味道）

### 硬性指标
- Python / JavaScript / TypeScript 文件 ≤ 260 行
- Java / Go / Rust 文件 ≤ 260 行
- 每层目录 ≤ 8 个文件（不含子目录），多了需拆子目录

✅ 正确：`user_service.py` 260 行
❌ 错误：`main.js` 450 行

✅ 正确：`services/` 下 6 个文件
❌ 错误：`utils/` 下 20 个文件堆一起

### 坏味道（必须避免）
1. 僵化：改动困难，牵一发而动全身
2. 冗余：重复逻辑多处出现
3. 循环依赖：模块互相缠绕
4. 脆弱性：改动一处导致其他地方报错
5. 晦涩性：代码意图不明，难以理解
6. 数据泥团：多个参数总是成对出现，应封装对象
7. 不必要的复杂性：过度设计

【非常重要】
- 一旦识别坏味道：先提示用户是否需要优化，并给出可落地方案

---

## 依赖与版本策略（以仓库锁为准）
- 前端：以 `package.json` + lock（`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` 等）为单一真相
- 后端 Python：以 `pyproject.toml` + lock（例如 `uv.lock` 或项目既有锁）为单一真相
- 未经用户明确要求：不得升级/降级依赖版本，不得更换包管理器
- `requirements.txt`：如项目需要，只能由 lock 导出生成；禁止"随手更新"

---

## HTML（分离关注点）
- 遵循"分离关注点"原则：样式（CSS）、行为（JS）、结构（HTML）必须分离
- 单个 HTML 文件 ≤ 500 行，功能过多时拆分为组件

✅ 正确：
```html
<link rel="stylesheet" href="style.css">
<script src="app.js"></script>
<div class="user-card">张三</div>
```
❌ 错误：
```html
<div style="color:red;" onclick="alert('hi')">张三</div>
```

---

## Python（uv 优先）
- 数据结构必须强类型；如必须用 `dict`/弱类型结构，需征求用户同意
- 虚拟环境目录统一为 `.venv`；优先用 `uv venv` 创建并管理
- 依赖管理必须使用 `uv`；禁止 `pip install`（也不直接使用 `python`/`python3` 执行项目命令）
- 依赖与锁：以 `pyproject.toml` + lock 为准；`requirements.txt` 仅允许从 lock 导出
- 根目录保持简洁；`main.py` 保持最小启动逻辑（业务逻辑下沉到模块）

✅ 正确：
```python
@dataclass
class User:
    id: int
    name: str
```
❌ 错误：
```python
user = {"id": 1, "name": "张三"}  # 未定义结构
```

✅ 正确：`uv add requests`
❌ 错误：`pip install requests`

✅ 正确：
```python
if __name__ == "__main__":
    run_app()
```
❌ 错误：在 `main.py` 里写 500 行业务逻辑

---

## React / Next.js / TypeScript / JavaScript
- 版本以项目 `package.json` 与 lock 为准；未经用户明确要求不得升级/降级
- 严禁使用 CommonJS（禁止 `require` / `module.exports`）
- 尽量使用 TypeScript；如必须用 JS，需说明原因
- 数据结构必须强类型；如必须用 `any` 或未定义结构的 JSON，需征求用户同意

✅ 正确：`import fs from "fs"`
❌ 错误：`const fs = require("fs")`

✅ 正确：
```ts
interface User {
  id: number
  name: string
}
```
❌ 错误：
```ts
let user: any = {}
```

---

## Run & Debug（运行与调试）
- 运行/调试/构建脚本必须维护在 `scripts/` 目录下，并通过 `scripts/*.sh` 执行
- `.sh` 脚本失败：先修复脚本，再继续使用脚本（不要绕开脚本手动跑命令）
- 调试前配置 Logger：统一输出到 `logs/`；并在输出中包含关键上下文
- 初始化类脚本（例如 `setup_agent_rules.sh`）用于一次性安装/初始化，不属于日常 Run/Debug 流程

✅ 正确：`./scripts/run_server.sh`
❌ 错误：`npm run dev` 或 `python main.py`

**OpenCode 环境例外**：在 OpenCode 中，可直接通过 `bash` 工具执行 `npm run dev`、`uv run main.py` 等命令，无需强制使用脚本包装。

---

## Flutter Widget 树括号封闭规则
在 Widget 树嵌套较深时，必须在封闭括号后添加注释，标明对应的 Widget 名称，便于识别层级。

✅ 正确示例：
```dart
return Scaffold(
  body: Center(
    child: Column(
      children: [
        Text("Hello"),
        ElevatedButton(
          onPressed: () {},
          child: Text("Click"),
        ), // ElevatedButton
      ],
    ), // Column
  ), // Center
); // Scaffold
```

❌ 错误示例：
```dart
return Scaffold(
  body: Center(
    child: Column(
      children: [
        Text("Hello"),
        ElevatedButton(
          onPressed: () {},
          child: Text("Click"),
        ),
      ],
    ),
  ),
);
```

---

## 开发流程规范
- 分析代码问题可英文；回答与注释必须中文
- 修复错误必须检查完整链路，并修复关联代码（仅限相关范围）
- 非本问题范围的改动：必须先征求用户确认
- 修改后必须输出代码改动对比（例如 `git diff` 关键片段或摘要）
- 修改需基于上下文（如 @ 引用文件），避免脱离上下文的推断
- 新增/修改文件、类、函数、方法声明前必须有中文注释
- 不得私自修改界面样式或配置文件（除非为修复所必需，并说明原因）
- 如项目需要 `requirements.txt`：必须由 lock 导出生成，禁止手工维护
- Python 项目运行需确保 `.venv` 已就绪；优先通过 `uv run` 执行命令

---

## 项目管理规范
- 使用 monocode 架构：功能模块按文件分开，文件开头提供说明，并保持更新
- 如缺失 `.gitignore`：按需补齐（至少忽略 `.venv/`、`__pycache__/`、`logs/` 等）
- 项目功能、使用方法、todo-list 必须写入 `README.md`
- 每次修复问题要记录：原因、解决方案、更改内容
- 必须在 `CHANGELOG.md` 中记录修复情况，遵循统一模板

---

## Monocode 约束
- 源码统一置于 `src/`；按功能（feature）为第一维度拆分目录
- 每个功能目录内包含：`models/`、`repo/`、`service/`、`api/`、`schemas/`（缺失项按需补全）
- `service` 不得直接调用外部依赖（DB/HTTP/缓存）；此类依赖只允许在 `repo` 层
- `shared` 仅存放基础设施与纯工具，禁止业务逻辑
- 单文件 ≤ 260 行；HTML 单文件 ≤ 500 行；同层 ≤ 8 文件（不含子目录），超限必须拆分
- 运行/调试/构建仅通过 `scripts/*.sh`

### 文件/目录数量约束
- 每个目录下的直接文件 ≤ 8 个（不含子目录）
- 目录层级 ≤ 3 层
- 目录必须表达明确的功能边界，禁止使用 "misc/、common/、utils/" 作为垃圾桶
