## 说明
本仓库用于维护个人 AI 规则与项目初始化脚本。  
Antigravity 优先，兼容 Cursor/VS Code。  

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
