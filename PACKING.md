# 打包准备清单（init_agent_rules.sh）

## 目标
后续生成 `init_agent_rules.sh`（all-in-one）。  
要求稳定、可复现、幂等、安全。  

## 建议内嵌范围（包含）
- `setup_agent_rules.sh`  
- `AGENTS.md`  
- `Debugging-Rules.md`  
- `.context/*.md`  
- `.agent/workflows/*.md`  
- `scripts/templates/*.sh`  
- `.prettierrc`、`.prettierignore`（如需要统一格式化约束）  

## 建议排除范围（不包含）
- `.git/`、`.DS_Store`  
- `.backup/`、`logs/`、临时测试目录  
- 任何项目私有配置（例如业务 `.env`）  
- `antigravity-awesome-skills`（建议初始化时 git clone）  
