## 说明
本仓库用于维护个人 AI 规则与项目初始化脚本。
OpenCode 优先，兼容 Antigravity 和 Cursor/VS Code。  

## 最简用法
把 `setup_agent_rules.sh` 复制到任意项目根目录并执行：  
`bash setup_agent_rules.sh`  

## 一键初始化（推荐）
- wget：`wget -O init_agent_rules.sh <raw-url> && bash init_agent_rules.sh --verify`  
- curl：`curl -fsSL <raw-url> | bash -s -- --verify`  

## 维护与生成
- 重新生成 `init_agent_rules.sh`：`bash tools/build_init.sh`  

## 安装结果
- 规则安装到：`.agent/rules/*.mdc`
- 可选同步到：`.cursor/rules/*.mdc`（默认开启，可用 `--no-cursor` 关闭）
- 生成：`AGENTS.md`、`.editorconfig`
- 若存在 `.git/`：生成 `pre-commit` 钩子

## OpenCode 规则使用

### 快速开始
将 `opencode_rules/` 目录中的文件复制到项目根目录：

```bash
# 复制主规则和配置
cp opencode_rules/AGENTS.md /your/project/root/
cp opencode_rules/opencode.json /your/project/root/

# 可选：复制技能和脚本
cp -r opencode_rules/SKILLS /your/project/root/
cp -r opencode_rules/scripts/templates /your/project/root/scripts/
```

### OpenCode 专用功能
- **Agent 协作**：使用 explore、librarian、oracle 代理进行并行探索
- **Background Task**：多任务并行执行，大幅提升效率
- **会话管理**：利用历史会话快速查找解决方案
- **Agent Skills**：可重用的行为模式（code-review、bug-fix、refactor）

详细说明请参考 `opencode_rules/README.md`。

