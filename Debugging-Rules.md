# Antigravity（优先）/ Cursor（兼容）调试与排查最佳实践

## 一、硬性规则
1. **可复现优先**：所有问题写最小复现 (`scripts/repro.sh`)。
2. **环境锁定**：Node `.nvmrc` / Python `.python-version` / Flutter `tools/.flutter-version`。
3. **Run & Debug 收敛到 `scripts/`**：dev.sh / debug.sh / test.sh / lint.sh / build.sh / start.sh。
4. **日志统一**：等级、落盘、轮转，生产与本地一致。
5. **失败快照**：报错时采集日志/截图/重放脚本。
6. **CI 失败重跑**：归档日志与截图。
7. **一键清理与重置**：`scripts/clean.sh` / `scripts/reset.sh`。

## 二、Antigravity / Cursor 内工作方式
- 问题卡片化（现象→期望→复现→已尝试→下一步）。
- 从断点到根因的最短路径，优先条件断点。
- 日志即断点，统一结构化。
- 对照编译：dev vs prod。
- 小步验证 + 快速回滚。

## 三、排查清单
1. 环境能跑吗？
2. 复现稳定吗？
3. 日志看了吗？
4. 外部依赖稳吗？
5. 构建链路正常吗？
6. 并发与时序？
7. 配置与环境差异？
8. 网络层（DNS/代理/证书）？
9. 资源与性能？
10. 回滚验证。

## 四、各技术栈要点
- **Nuxt/Next**：source map 必开；CORS/代理模拟生产；环境变量统一。
- **Flutter**：Dart/平台侧日志齐全；权限写齐；Crash 上报。
- **Node/Python**：错误边界+trace-id；外部调用封装重试与幂等；docker compose 拉依赖。
- **Nginx/OpenResty**：抓包脚本；SNI/默认站点配置明确。

## 五、工具与模板
- `scripts/diagnose.sh`：系统信息/端口/版本/磁盘。
- `scripts/tail.sh`：可带关键字 tail -f。
- `.editorconfig`：统一缩进/行尾。
- `.githooks/`：提交前 lint/test，禁止 console.log/print 泄漏。

## 六、Agent 协作提示模板
```
你是调试助手。每次只做一件事：定位或验证一个“可观察到的信号”。
输入：现象、期望、复现、已尝试、候选假设。
输出：1) 下一步命令或代码改动（≤10 行），2) 预期观察，3) 若失败的备选路径。
所有命令走 scripts/。
```

## 七、常见坑位速查
- “能在我机上跑”：未锁版本/全局依赖。
- “本地好好的，线上挂”：构建差异/反代错配。
- Flutter 方块字：字体未包含。
- 偶发 5xx：无幂等/重试风暴。
- HTTPS 404：SNI/默认站点错误。

## 八、落地顺序
1. 建 `scripts/` 六件套 + `diagnose.sh`/`tail.sh`。
2. 配置 Cursor Run 面板只跑脚本。
3. 加 `.editorconfig`、`pre-commit`。
4. 写入本文件和 `AGENTS.md`。
5. CI 锁版本、重跑失败、归档日志。
