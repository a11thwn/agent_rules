# CHANGELOG

此文件用于记录项目的所有修改历史，确保每次修复、优化或新增功能都有迹可循。
请按照以下格式填写：

---

## [2026-01-04] - 修复 OpenCode 配置模板错误字段
### 问题描述
- `opencode_rules/opencode.json` 配置模板包含 OpenCode 不支持的字段
- 在其他项目中使用时报错：`Unrecognized keys: "temperature", "max_steps", "agents"`
- 导致配置文件验证失败，OpenCode 无法正常启动

### 分析原因
- 配置模板误用了非官方的配置项：
  - `temperature` - 不是 OpenCode 配置项
  - `max_steps` - 不是 OpenCode 配置项
  - `agents` - 正确字段应为 `agent`（单数），且格式不同
- 这些字段可能是从其他 AI 工具配置中误复制而来

### 解决方案
- 根据官方文档 [OpenCode Config](https://opencode.ai/docs/config/) 移除无效字段
- 保留有效的配置项：
  - `instructions` - 规则文件加载 ✓
  - `permission` - 权限配置 ✓
  - `tools` - 工具配置 ✓

### 改动内容
- 修改 `opencode_rules/opencode.json`：
  - 移除 `temperature: 0.3` 字段（第 38 行）
  - 移除 `max_steps: 50` 字段（第 39 行）
  - 移除整个 `agents` 对象（第 40-56 行）

### 影响范围
- 修复后的配置符合 OpenCode 官方规范，可在任何项目中正常使用
- 不影响原有功能，仅移除无效配置项
- OpenCode Agent 协作、并行任务等功能仍可正常使用

### 后续计划
- 已完成，配置验证通过

---

## [2026-01-04] - 新增 OpenCode 规则支持
### 问题描述
- 原有规则仅支持 Antigravity 和 Cursor/VS Code，未适配 OpenCode 平台
- OpenCode 拥有独特的 Agent 协作机制、并行任务和会话管理功能，原有规则无法充分利用

### 分析原因
- OpenCode 采用不同的规则加载方式（`AGENTS.md` 在项目根目录自动加载）
- OpenCode 支持 background_task 并行执行、多 Agent 协作、会话历史等功能
- 原有规则未针对 OpenCode 特性进行优化

### 解决方案
- 创建 `opencode_rules/` 目录，存放 OpenCode 专用规则
- 保留原有代码不变，采用增量策略添加 OpenCode 支持
- 新增 OpenCode Agent 协作规范、Background Task 最佳实践、会话管理指南
- 提供可复用的 Agent Skills（code-review、bug-fix、refactor）

### 改动内容
- 新增 `opencode_rules/` 目录结构
- 新增 `opencode_rules/AGENTS.md` - OpenCode 专用主规则（继承原有核心约束）
- 新增 `opencode_rules/opencode.json` - OpenCode 配置模板（权限、工具、Agent 配置）
- 新增 `opencode_rules/SKILLS/` 目录和 3 个技能文件
  - `code-review.mdc` - 代码审查技能
  - `bug-fix.mdc` - Bug 修复技能
  - `refactor.mdc` - 重构技能
- 新增 `opencode_rules/scripts/templates/opencode_parallel_tasks.sh` - 并行任务脚本模板
- 新增 `opencode_rules/README.md` - OpenCode 规则使用说明
- 修改主 `README.md` - 添加 OpenCode 规则说明章节

### 影响范围
- 原有规则和安装机制保持不变，向后兼容
- 新增的 OpenCode 规则可选使用，不影响现有工作流
- 支持 OpenCode 专属功能：Agent 协作、并行任务、会话管理

### 后续计划
- 收集 OpenCode 使用反馈，持续优化规则
- 考虑添加更多 Agent Skills（如 frontend-ui-ux、document-writer）
- 探索 OpenCode MCP 服务器集成

---

## [2025-12-25 15:21:08] - 前置优化
### 问题描述
- 现有规则与安装脚本偏 Cursor 语境，且安装路径与 Antigravity 最佳实践不一致  
- `setup_agent_rules.sh` 缺少幂等/备份/dry-run/可选 Cursor 同步等能力，难以作为稳定安装器  

### 分析原因
- 规则文本存在不可执行约束（例如“永远用中文思考”）与版本策略硬编码  
- 安装脚本以固定相对路径拷贝（`../agent_rules`），不适合复制到任意项目根目录直接运行  

### 解决方案
- 重写 `AGENTS.md`：以 Antigravity 为主，补齐规则加载约定、强护栏与“以仓库锁为准”的版本策略  
- 重构 `setup_agent_rules.sh`：做成项目内安装器，支持 `--src/--dir/--dry-run/--force/--no-backup/--no-cursor`，并默认安全不覆盖  

### 改动内容
- 修改 `AGENTS.md`：修复矛盾规则；增加 Antigravity 规则目录与 Cursor 同步约定；增加终端/破坏性操作护栏  
- 修改 `setup_agent_rules.sh`：安装到 `.agent/rules/*.mdc`；可选同步 `.cursor/rules/`；覆盖备份到 `.backup/<timestamp>/`；生成 `.editorconfig` 与 `pre-commit`（存在 `.git/` 时）  
- 修改 `Debugging-Rules.md`：标题与表述改为 Antigravity 优先、Cursor 兼容  
- 新增 `README.md`：补齐最简用法说明  
- 新增 `PACKING.md`：列出后续 all-in-one 打包建议范围  

### 影响范围
- 规则安装路径从“项目根目录”迁移为 `.agent/rules/`（并可选同步 `.cursor/rules/`）  
- 执行脚本的默认行为更安全：默认不覆盖，覆盖需 `--force`，且默认备份  

### 后续计划
- 为 `setup_agent_rules.sh` 增加更细的规则来源清单（便于 init 打包自动化）  
- 下一阶段再生成 `init_agent_rules.sh`（all-in-one）  

---

## [2025-12-25 17:17:56] - 生成 init_agent_rules.sh（all-in-one）
### 问题描述
- 需要单文件脚本支持 `wget/curl | bash`，无需 clone/zip 即可复原关键文件并完成规则安装  
- 需要保证幂等、安全、可验证，且兼容 macOS/Linux bash  

### 分析原因
- 仅靠 `setup_agent_rules.sh` 仍需要“先拿到仓库文件”，无法满足一键初始化场景  
- 缺少可复现的打包机制，后续维护容易漂移  

### 解决方案
- 新增 `tools/build_init.sh`：从仓库内容生成 `init_agent_rules.sh`，把需要的文本文件用 heredoc 内嵌  
- 新增 `init_agent_rules.sh`：写出目录结构与文件，并合并安装逻辑（`.agent/rules/*.mdc` + 可选 `.cursor/rules` + `.editorconfig` + `pre-commit`）  

### 改动内容
- 新增 `init_agent_rules.sh`：支持 `--dir/--force/--no-cursor/--dry-run/--verify/--manifest`  
- 新增 `tools/build_init.sh`：一键重新生成 init，保证可复现  
- 更新 `README.md`：补充 wget/curl 一键初始化用法  
- 新增 `.gitignore`：忽略 `.backup/`、`logs/`、`.DS_Store` 等  

### 影响范围
- 增加推荐入口：使用 `init_agent_rules.sh` 可在任意项目中“一次写入 + 安装”  
- 规则安装核心仍以 `.agent/rules/` 为准，并可选同步 Cursor  

### 后续计划
- 扩展 init 的内嵌范围与校验（如新增更多规则文件时自动纳入）  
- 视需要补充更严格的内容一致性校验（按 MANIFEST.sha256 对比）  

## [2025-09-08 15:05:00] - [版本号/提交哈希]
### 问题描述
- 简要说明发现的问题或缺陷  
- 如果有 Issue ID 或任务编号，请写上  

### 分析原因
- 用简洁语言说明问题产生的原因  

### 解决方案
- 描述采取了什么方法修复或优化  

### 改动内容
- 列出修改的文件和主要变更点  
- 建议使用项目内的 `git diff` 输出节选  

### 影响范围
- 说明这次改动可能影响的功能模块或用户行为  

### 后续计划
- 如果需要进一步优化或测试，在这里写上 TODO  

---

## 示例

### [2025-09-04] - v1.0.1
**问题描述**
- 用户登录时偶发 500 错误（Issue #123）  

**分析原因**
- Session 管理逻辑中，未处理空 Token 的异常情况  

**解决方案**
- 在 `auth/session.py` 中添加 Token 校验逻辑  

**改动内容**
- 修改 `auth/session.py`  
- 更新 `tests/test_session.py`  

**影响范围**
- 登录相关接口  
- Session 校验逻辑  

**后续计划**
- 增加更多单元测试覆盖异常情况  
