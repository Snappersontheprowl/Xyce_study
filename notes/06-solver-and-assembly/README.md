# solver and assembly

记录日期：2026-06-04

这个专题只回答一个问题：

```text
当分析层已经决定“跑 DC 还是 transient”之后，
Xyce 到底在装配什么方程，又是怎样把这些方程解出来的？
```

所以 `06-solver-and-assembly` 的关键词是：

- `Q / F / B / dQdx / dFdx`
- residual / Jacobian
- time discretization
- Newton
- linear solve

## 这一专题不负责什么

这一专题**不再展开**下面这些问题：

- `Simulator::runSimulation()` 怎样进入分析层
- 分析类型在哪里注册
- `.OP / .DC / .TRAN` 在分析对象选择上是什么关系
- `DCSweep` / `Transient` 的生命周期是谁在调度

这些内容统一放在 [05-analysis-flow](../05-analysis-flow/README.md)。

## 目录结构

- [01-basic/README.md](01-basic/README.md)
  - 基础仿真：`DC`、`transient`
- [02-advanced/README.md](02-advanced/README.md)
  - 进阶仿真：`AC`、`NOISE`、`HB`、`MPDE`
- [03-sensitivity/README.md](03-sensitivity/README.md)
  - 灵敏度分析：解敏感度、输出敏感度、direct / adjoint

## 为什么要这样拆

原来那篇笔记把下面两件事揉在了一起：

1. 装配问题  
   也就是 device、`DeviceMgr`、`CktLoader`、`NonlinearEquationLoader` 分别负责什么。

2. 求解问题  
   也就是：
   - `f(x) = dQ/dt + F - B = 0`
   - `J = d(dQ/dt)/dx + dF/dx`
   - Newton 迭代怎么调用 linear solver

这两件事虽然相连，但阅读时的大脑切换成本很高。

拆开之后，可以更自然地形成两层理解：

- 先搞清“电路方程是怎么被建立出来的”
- 再搞清“方程建立好以后，数学上怎么解”

同时，也和 [05-analysis-flow](../05-analysis-flow/README.md) 保持明确边界：

- `05` 只讲“谁决定跑什么分析、什么时候创建公共对象”
- `06` 只讲“这些对象怎样形成方程并进入求解”

## 推荐阅读顺序

1. 先读 [01-basic/README.md](01-basic/README.md)
2. 再顺着基础主线读 `01-basic/` 下面四篇
3. 基础主线稳定后，再读 [02-advanced/README.md](02-advanced/README.md)
4. 需要系统学习灵敏度时，再读 [03-sensitivity/README.md](03-sensitivity/README.md)

这样读的时候，第二篇里的数学对象就不会显得凭空出现。

## 当前已经形成的主线

当前这组笔记，先只把最基本、最通用的两类分析讲透：

- `DC operating point`
- `transient`

暂时不继续扩展：

- `AC`
- `NOISE`
- `HB`
- `MPDE`

因为这一专题的主轴不是“列出更多分析类型”，而是先把最核心的：

```text
装配
+ 
DC / TR 求解骨架
```

讲清楚。

接下来会把这条主线进一步分层成：

- 基础仿真：`DC`、`transient`
- 进阶仿真：`AC`、`NOISE`、`HB`、`MPDE`

## 下一轮深化更适合补什么

如果后面继续补 `06`，更合理的方向不是加新的 analysis type，而是补清这几类细节：

1. residual / Jacobian 的符号约定和对象关系
2. transient 的步长控制与失败重试
3. nonlinear solver 的收敛控制
4. linear solver 后端栈

同时，在进阶仿真这一支上，最自然的下一步是先从 `AC` 开始。
