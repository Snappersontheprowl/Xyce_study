# solver and assembly

这个专题现在拆成两条大主线，并在“数学求解”下面继续细分出 DC 和 transient 两个子专题，目的是把“电路方程怎么装出来”和“方程装好之后数学上怎么解”彻底分开。

## 目录说明

- [01-dae-assembly-pipeline.md](01-dae-assembly-pipeline.md)
  关注 `Q`、`F`、`B`、`dQdx`、`dFdx` 这些 DAE 组成部分是如何从 device 层一路汇总到 loader 层的。
- [02-dae-math-solving.md](02-dae-math-solving.md)
  作为总览，先回答 DC 和 transient 在数学上各自到底在解什么。
- [03-dc-operating-point-solving.md](03-dc-operating-point-solving.md)
  专门看 DC operating point：$$F(x)-B=0$$、Newton、Jacobian 和代码对应。
- [04-transient-time-discretization-and-solving.md](04-transient-time-discretization-and-solving.md)
  专门看 transient：$$\frac{dQ}{dt}+F-B=0$$ 如何离散成每个时间步上的 nonlinear equation，并在代码里展开求解。

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

## 推荐阅读顺序

1. 先读 [01-dae-assembly-pipeline.md](01-dae-assembly-pipeline.md)
2. 再读 [02-dae-math-solving.md](02-dae-math-solving.md)
3. 然后按需要深入：
   - 想弄清 DC，就读 [03-dc-operating-point-solving.md](03-dc-operating-point-solving.md)
   - 想弄清 transient，就读 [04-transient-time-discretization-and-solving.md](04-transient-time-discretization-and-solving.md)

这样读的时候，第二篇里的数学对象就不会显得凭空出现。
