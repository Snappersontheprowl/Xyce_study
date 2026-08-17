# Xyce 功能验证工作区

## 功能

本目录用于记录当前项目内 Xyce 安装的功能验证计划、验证用例和结果汇总。

它不记录编译安装过程；编译与安装全过程以 [../docs/notes/build-and-install/](../docs/notes/build-and-install/) 为主。

## 本级模块职责

- `README.md`：说明功能验证工作区的职责、入口和维护约定。
- `00-current-install-scope.md`：记录当前验证对象、构建配置、已知能力和适用边界。
- `01-analog-functional-verification-plan.md`：定义模拟电路功能验证矩阵、用例优先级和验收标准。
- `02-verification-results.md`：汇总已执行用例的结果和数值验收结论。
- `03-gui-and-frontend-notes.md`：记录 Xyce GUI、前端和配套工具相关结论。
- `04-netlist-syntax-and-conversion-notes.md`：记录主流网表语法和转换工具相关结论。
- `05-xdm-binary-install-and-verification-plan.md`：记录 XDM binary 安装和验证计划。
- `06-interactive-mode-source-implementation-assessment.md`：记录 Xyce 交互式模式源码实现评估。
- `cases/`：保存每个可复现 netlist 用例、运行日志和输出结果。
- `logs/`：预留给跨用例或批量验证日志。
- `results/`：预留给汇总性结果产物。

## 使用建议

验证当前 Xyce 能力时，优先阅读：

1. [00-current-install-scope.md](./00-current-install-scope.md)
2. [01-analog-functional-verification-plan.md](./01-analog-functional-verification-plan.md)
3. [02-verification-results.md](./02-verification-results.md)
4. [cases/](./cases/)

## 命名规则

- 用例目录使用 `fvNNN-short-name/`，例如 `fv010-cube-resistor-equivalent/`。
- 每个用例目录至少保留 `README.md`、输入 netlist、`run.log` 和 Xyce 输出文件。
- 用例编号一旦进入结果汇总，不复用、不重排。

## 当前约定

- 本阶段验证目标是“学习和功能边界确认”，不是商业 PDK sign-off。
- 数值结论集中维护在 `02-verification-results.md`，单个 case README 只保留该用例的稳定验收标准。
- 新增 case 后同步检查验证矩阵、结果汇总和本目录 README 是否需要更新。
