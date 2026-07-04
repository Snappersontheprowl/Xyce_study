# solver and assembly

记录日期：2026-07-03

这个专题现在明确站在 **底层数学原理** 的角度来组织。

它主要回答的不是“代码对象怎样组织”，而是：

```text
当分析层已经决定“跑 DC 还是 transient”之后，
Xyce 底层到底在解什么方程，
这些方程为什么会长成这样，
又是怎样从数学对象一步步落到实现里的？
```

所以 `06-solver-and-assembly` 的关键词应该理解成：

- 原始电路 DAE
- `Q / F / B / dQdx / dFdx`
- residual / Jacobian
- 线性化
- time discretization
- Newton / adjoint / transpose solve
- 频域、小信号、周期稳态、多时间尺度

## 这一专题不负责什么

这一专题**不负责展开工程控制流本身**，例如：

- `Simulator::runSimulation()` 怎样进入分析层
- 分析类型在哪里注册
- `.OP / .DC / .TRAN` 在分析对象选择上是什么关系
- `DCSweep` / `Transient` 的生命周期是谁在调度
- 哪个 factory 在哪里创建对象
- `HBBuilder / HBLoader / MPDE_Manager` 是在哪个初始化阶段接进来的

这些内容统一放在 [05-analysis-flow](../05-analysis-flow/README.md)。

## 目录结构

- [00-notation-conventions.md](00-notation-conventions.md)
  - 本专题统一符号约定
- [01-basic/README.md](01-basic/README.md)
  - 基础数学骨架：`DC`、`transient`
- [02-advanced/README.md](02-advanced/README.md)
  - 进阶数学骨架：`AC`、`NOISE`、`HB`、`MPDE`
- [03-sensitivity/README.md](03-sensitivity/README.md)
  - 灵敏度分析的数学主线：解敏感度、输出敏感度、direct / adjoint

## 推荐阅读顺序

1. 先读 [01-basic/README.md](01-basic/README.md)
2. 再顺着基础主线读 `01-basic/` 下面四篇
3. 基础主线稳定后，再读 [02-advanced/README.md](02-advanced/README.md)
4. 需要系统学习灵敏度时，再读 [03-sensitivity/README.md](03-sensitivity/README.md)

## 这一专题最想回答的几个数学问题

1. 原始电路 DAE 为什么是
   $$
   \frac{dQ(x)}{dt}+F(x)-B(t)=0
   $$
2. `DC`、`AC`、`HB`、`MPDE` 各自是怎样从这条原始方程出发，重组出不同问题形态的？
3. residual / Jacobian、time discretization、small-signal linearization、harmonic balance、multi-time PDE 各自是什么意思？
4. Newton、transpose solve、adjoint 为什么会自然出现？
