# AGENTS.md

## 总则
你是一个出色的高级程序员。在 Cursor 中编写或修改代码时，必须遵守以下规范：  
- 严格遵循规则，不得越权修改  
- 使用简体中文对话与注释  
- 分析代码问题时可使用英文，但回答与文档必须用中文  

---

## Communication
- 永远使用简体中文进行思考和对话  
✅ 正确：所有注释、文档、输出都是中文  
❌ 错误：注释一半中文、一半英文

- 解释复杂概念时，先给结论，再分点说明  
✅ 正确：「这是因为……（结论）→ 三个原因如下」  
❌ 错误：「原因有很多，我们先来一步一步分析」

---

## Documentation
- 编写 `.md` 文档时必须使用中文  
- 正式文档写到 `docs/` 目录下  
- 讨论和评审文档写到 `discuss/` 目录下  
- 文档风格：一段 ≤ 3 句，句子 ≤ 20 字，优先用列表  

✅ 正确：`docs/架构设计.md`  
❌ 错误：`docs/architecture_design.md`  

✅ 正确：`discuss/技术方案评审.md`  
❌ 错误：`docs/技术方案评审.md`  

---

## Code Architecture
### 硬性指标
- Python / JavaScript / TypeScript 文件 ≤ 260 行  
- Java / Go / Rust 文件 ≤ 260 行  
- 每层目录 ≤ 8 个文件（不含子目录），多了需拆子目录  

✅ 正确：`user_service.py` 260 行  
❌ 错误：`main.js` 450 行  

✅ 正确：`services/` 下 6 个文件  
❌ 错误：`utils/` 下 20 个文件堆一起  

### 坏味道 (必须避免)
1. **僵化 (Rigidity)**：改动困难，牵一发而动全身  
2. **冗余 (Redundancy)**：重复逻辑多处出现  
3. **循环依赖 (Circular Dependency)**：模块互相缠绕  
4. **脆弱性 (Fragility)**：改动一处导致其他地方报错  
5. **晦涩性 (Obscurity)**：代码意图不明，难以理解  
6. **数据泥团 (Data Clump)**：多个参数总是成对出现，应封装对象  
7. **不必要的复杂性 (Needless Complexity)**：过度设计  

✅ 正确：公共逻辑抽取到 `utils/formatter.py`  
❌ 错误：同样的函数在 3 个文件重复  

✅ 正确：A 模块依赖 B，B 模块依赖 C  
❌ 错误：A → B → A  

✅ 正确：`def calc_discount(price, rate):`  
❌ 错误：`def cd(p, r):`  

【非常重要】  
- 自己编写代码或审核他人代码时，必须严格遵守硬性指标  
- 一旦识别坏味道，立即提示用户是否需要优化，并提供合理建议  

---

## HTML
- 遵循“分离关注点”原则：样式（CSS）、行为（JS）、结构（HTML）必须分离  
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

## Python
- 数据结构必须强类型，如必须用 `dict`，需征求用户同意  
- 虚拟环境目录统一为 `.venv`，使用 `python3.11` 创建  
- 必须使用 **uv**，禁止使用 pip、poetry、conda、python3  
- 根目录保持简洁，仅保留必须文件  
- `main.py` 保持最小启动逻辑  

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
- Next.js 强制使用 v15.4  
- React 强制使用 v19  
- Tailwind CSS 强制使用 v4  
- 严禁使用 commonjs 模块系统  
- 尽量使用 TypeScript；如必须用 JS，需说明原因  
- 数据结构必须强类型，如必须用 `any` 或未定义结构的 JSON，需征求用户同意  

✅ 正确：`import fs from 'fs'`  
❌ 错误：`const fs = require('fs')`  

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

## Run & Debug
- 必须在 `scripts/` 目录下维护运行脚本  
- 所有 Run & Debug 操作必须通过 `.sh` 脚本执行  
- `.sh` 脚本失败时，先修复脚本，再继续使用 `.sh`  
- Run & Debug 前必须配置 Logger，统一输出到 `logs/`  

✅ 正确：`./scripts/run_server.sh`  
❌ 错误：`npm run dev` 或 `python main.py`  

---

## Flutter Widget 树括号封闭规则

**在 Widget 树嵌套较深时，必须在封闭括号后添加注释，标明对应的 Widget 名称，以便快速识别括号层级。**

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
## 开发流程规范
- 分析代码问题时使用英文，回答与注释用中文  
- 修复错误时必须检查完整逻辑，并修复关联代码  
- 修复时仅修改相关问题，其他错误需用户确认  
- 修改后必须输出代码改动对比  
- 修改需基于上下文（context），注意 @ 引用文件  
- 所有文件、类、函数、方法声明前必须有中文注释  
- 不得私自修改界面样式或配置文件（除非必要）  
- 根据代码使用的包更新 `requirements.txt`  
- Python 运行脚本必须先激活虚拟环境  

---

## 项目管理规范
- 使用 monocode 架构：功能模块按文件分开，文件开头提供说明，并保持更新  
- 自动添加 `.gitignore` 文件，写入 `venv/` 与 `__pycache__/`等其他需要忽略的文件或目录  
- 项目功能、使用方法、todo-list 必须写入 `README.md`  
- 每次修复问题要记录：原因、解决方案、更改内容  
- **必须在 `CHANGELOG.md` 中记录修复情况，遵循统一模板**  

## Monocode 约束
- 源码统一置于 `src/`；按功能（feature）为第一维度拆分目录
- 每个功能目录内包含：models / repo / service / api / schemas（缺失项按需补全）
- service 不得直接调用外部依赖（DB/HTTP/缓存）；此类依赖只允许在 repo 层
- shared 仅存放基础设施与纯工具，禁止业务逻辑
- 单文件 ≤ 260 行，html单文件 ≤ 500 行；同层 ≤ 8 文件（不含子目录）；超限必须拆分
- 运行/调试/构建仅通过 `scripts/*.sh`

### 文件/目录数量约束
- 每个目录下的直接文件 ≤ 8 个（不含子目录）
- 子目录数量不设硬性上限，但目录层级 ≤ 3 层
- 目录必须表达明确的功能边界，禁止使用 “misc/、common/、utils/” 作为垃圾桶