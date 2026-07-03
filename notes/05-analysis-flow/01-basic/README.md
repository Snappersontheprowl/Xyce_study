# basic analysis flow

记录日期：2026-07-03

这个子目录从 **工程实现** 的角度，只讲最基本的分析代码主线：

- `Simulator::runSimulation()` 怎样进入分析层
- `.OP / .DC / .TRAN` 怎样注册和选择
- `DCSweep` / `Transient` 的生命周期怎样组织
- `AnalysisManager` 什么时候创建共用基础设施

## 推荐阅读顺序

1. [01-simulation-entry-to-analysis-manager.md](01-simulation-entry-to-analysis-manager.md)
2. [02-analysis-registration-and-selection.md](02-analysis-registration-and-selection.md)
3. [03-analysis-lifecycle-dc-and-tran.md](03-analysis-lifecycle-dc-and-tran.md)
4. [04-analysis-manager-common-infrastructure.md](04-analysis-manager-common-infrastructure.md)

## 这一组的边界

这一组只讲：

```text
谁决定跑什么分析
谁持有分析对象
分析控制流程怎样展开
代码层的组织关系和调用顺序
```

不讲：

- 方程推导
- residual / Jacobian 数学形式
- `Q / F / B / dQdx / dFdx` 的数学意义
- Newton / linear solve 的底层原理

这些内容统一放到 [../../06-solver-and-assembly/README.md](../../06-solver-and-assembly/README.md)。
