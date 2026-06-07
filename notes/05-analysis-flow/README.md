# analysis flow

记录日期：2026-06-04

这个专题只回答一个问题：

```text
Xyce 在完成初始化之后，
是谁决定“跑哪种分析”，
以及这些分析对象是怎样被组织和启动的？
```

所以 `05-analysis-flow` 的关键词是：

- 分析入口
- 分析注册
- 分析对象选择
- 分析生命周期
- 共用基础设施初始化

## 这一专题不负责什么

这一专题**不展开**下面这些内容：

- `Q / F / B / dQdx / dFdx` 如何装配
- residual / Jacobian 数学形式
- `DC` operating point 的 Newton 细节
- `transient` 每个时间步上的离散方程

这些内容统一放到 [06-solver-and-assembly](../06-solver-and-assembly/README.md)。

## 目录结构

- [01-basic/README.md](01-basic/README.md)
  - 基础分析调度：`.OP / .DC / .TRAN`
- [02-advanced/README.md](02-advanced/README.md)
  - 进阶分析地图：`AC / NOISE / HB / MPDE`
- [03-sensitivity/README.md](03-sensitivity/README.md)
  - 灵敏度作为附着在主分析上的能力层：`.SENS`、`SENSITIVITY`

## 推荐阅读顺序

1. 先读 [01-basic/README.md](01-basic/README.md)
2. 再顺着基础主线读 `01-basic/` 下面四篇
3. 基础主线稳定后，再读 [02-advanced/README.md](02-advanced/README.md)
4. 需要系统学习灵敏度时，再读 [03-sensitivity/README.md](03-sensitivity/README.md)

## 这一专题最想回答的 4 个问题

1. `Simulator::runSimulation()` 之后，是谁接管了分析流程？
2. `.OP`、`.DC`、`.TRAN` 在分析层面分别是怎样被注册和选出来的？
3. `DCSweep` 和 `Transient` 的生命周期结构分别是什么？
4. `AnalysisManager` 在什么时候创建 `workingIntgMethod`、`stepErrorControl`、`nonlinearEquationLoader`、`dataStore`？
