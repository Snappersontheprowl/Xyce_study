# analysis flow

记录日期：2026-07-03

这个专题现在明确站在 **工程代码实现** 的角度来组织。

它主要回答的不是“方程在数学上怎么来”，而是：

```text
Xyce 在完成初始化之后，
是谁决定“跑哪种分析”，
这些分析对象在代码里怎样被组织，
以及控制流是怎样一步步往下走的？
```

所以 `05-analysis-flow` 的关键词应该理解成：

- 代码入口
- 对象关系
- 模块职责
- 生命周期与控制流
- 注册、选择、初始化、切换
- “谁持有谁”“谁调用谁”“什么时候切换到下一层”

## 这一专题不负责什么

这一专题**不负责系统展开底层数学原理**，例如：

- 原始电路 DAE 如何写成方程
- `DC` 方程怎样从稳态条件推出来
- `AC` 为什么能从时域转到频域
- `HB` 的有限谐波展开为什么成立
- `MPDE` 为什么会变成多时间尺度 PDE
- direct / adjoint sensitivity 的数学推导

这些内容统一放到 [06-solver-and-assembly](../06-solver-and-assembly/README.md)。

## 目录结构

- [01-basic/README.md](01-basic/README.md)
  - 基础分析的工程实现主线：`.OP / .DC / .TRAN`
- [02-advanced/README.md](02-advanced/README.md)
  - 进阶分析的工程实现主线：`AC / NOISE / HB / MPDE`
- [03-sensitivity/README.md](03-sensitivity/README.md)
  - 灵敏度作为附着能力层，在工程代码里怎样挂到主分析上

## 推荐阅读顺序

1. 先读 [01-basic/README.md](01-basic/README.md)
2. 再顺着基础实现主线读 `01-basic/` 下面几篇
3. 基础实现主线稳定后，再读 [02-advanced/README.md](02-advanced/README.md)
4. 最后再看 [03-sensitivity/README.md](03-sensitivity/README.md)，理解灵敏度怎样附着到现有分析对象上

## 这一专题最想回答的几个工程问题

1. `Simulator::runSimulation()` 之后，是谁接管了分析流程？
2. `.OP`、`.DC`、`.TRAN`、`AC`、`NOISE`、`HB`、`MPDE` 在代码里分别是怎样被注册和选出来的？
3. `DCSweep`、`Transient`、`HB`、`MPDE` 的生命周期结构分别是什么？
4. `AnalysisManager` 在什么时候创建 `workingIntgMethod`、`stepErrorControl`、`nonlinearEquationLoader`、`dataStore`？
5. 为什么有些能力是独立主分析，有些能力只是附着层，比如 `SENS`？
