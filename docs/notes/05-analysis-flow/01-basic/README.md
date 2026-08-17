# 05-analysis-flow / 01-basic

## 功能

本目录记录基础分析类型在工程代码中的主线：`Simulator::runSimulation()` 如何进入分析层，`.OP / .DC / .TRAN` 如何注册、选择和执行。

本目录不讲 residual、Jacobian 或 Newton 求解数学。

## 本级模块职责

- `README.md`：说明本组笔记职责和阅读顺序。
- `01-simulation-entry-to-analysis-manager.md`：从 `Simulator::runSimulation()` 进入 `AnalysisManager` 的路径。
- `02-analysis-registration-and-selection.md`：基础分析类型的注册与选择。
- `03-analysis-lifecycle-dc-and-tran.md`：`DCSweep` 与 `Transient` 的生命周期。
- `04-analysis-manager-common-infrastructure.md`：`AnalysisManager` 创建和持有的共用基础设施。

## 使用建议

按编号顺序阅读即可。读完后，如果想理解底层方程，转到 [../../06-solver-and-assembly/01-basic/](../../06-solver-and-assembly/01-basic/)。

## 当前约定

- 本目录只讲“谁调用谁、谁持有谁、什么时候切换到下一层”。
- 方程推导和数值求解细节不在本目录展开。
