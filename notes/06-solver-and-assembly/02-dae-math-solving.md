# dae math solving

记录日期：2026-06-04

## 这篇的定位

这篇不负责把所有细节一次讲完，而是作为“DAE 建好之后数学上怎么解”的总览入口。

前一篇 [01-dae-assembly-pipeline.md](01-dae-assembly-pipeline.md) 已经回答了：

- device 先写出哪些 DAE 组成部分
- `DeviceMgr`、`CktLoader`、`NonlinearEquationLoader` 分别如何把这些量汇总起来

这一篇往前走一步，先抓住最本质的问题：

```text
DC 仿真到底在解什么方程？
TR 仿真每一个时间步到底在解什么方程？
Newton 和 linear solve 在代码里落在哪？
```

## 当前结论先写在前面

对当前阶段，最核心的数学对象可以先压缩成下面两组。

### 1. DC operating point

稳态下没有时间导数，所以目标方程退化成：

$$
F(x) - B = 0
$$

或者写成更标准的 nonlinear equation：

$$
f(x) = F(x) - B = 0
$$

Newton 线性化后，每一步要解的是：

$$
J(x_k)\,\Delta x_k = -f(x_k)
$$

其中：

$$
J(x_k) = \frac{\partial F}{\partial x}(x_k)
$$

在 Xyce 里，这条主线最适合专门看：

- [03-dc-operating-point-solving.md](03-dc-operating-point-solving.md)

### 2. Transient

瞬态下要解的原始 DAE 是：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

这不是一个“直接一次解完”的代数方程，而是：

1. 先选一个 time integration method
2. 把 $$\frac{dQ}{dt}$$ 离散成代数形式
3. 在每一个时间步上，形成一个新的 nonlinear equation
4. 再对这个 nonlinear equation 做 Newton

所以 transient 的本质是：

```text
时间推进
+
每个时间步上的 nonlinear solve
```

在 Xyce 里，这条主线最适合专门看：

- [04-transient-time-discretization-and-solving.md](04-transient-time-discretization-and-solving.md)

## 从代码层看，总的求解骨架是什么

无论是 DC 还是 transient，真正触发 nonlinear solve 的外层入口都很像：

- `.DC` / `.OP` 一类会在 [N_ANP_DCSweep.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C) 里调用 `nonlinearManager_.solve()`
- `.TRAN` 会在 [N_ANP_Transient.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C) 里调用 `nonlinearManager_.solve()`

而一旦进入 nonlinear solver 这层，公共骨架都会回到：

- [N_NLS_NonLinearSolver.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)

里的三个关键动作：

1. `rhs_()`  
   生成当前点的 residual
2. `jacobian_()`  
   生成当前点的 Jacobian
3. `newton_()`  
   调用 linear solver，求 Newton 更新方向

所以总骨架可以先记成：

$$
\text{Analysis}
\rightarrow \text{nonlinearManager.solve()}
\rightarrow \text{rhs}
\rightarrow \text{jacobian}
\rightarrow \text{linear solve}
$$

## 为什么要把 DC 和 TR 分开

它们的“求解器骨架”很像，但“方程来源”不一样。

### DC

DC 里本质上是在解：

$$
F(x) - B = 0
$$

这更像一个纯稳态 nonlinear algebraic problem。

### TR

TR 里每个时间步解的是：

$$
\Phi_n(x_n) = 0
$$

其中 $$\Phi_n$$ 不是单纯的 $$F(x)-B$$，而是把时间离散也并进去了。

例如最朴素地理解 backward Euler 时，可以把它想成：

$$
\Phi_n(x_n)
=
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t}
 + F(x_n) - B(t_n)
= 0
$$

所以 transient 和 DC 最大的区别，不在“有没有 Newton”，而在：

```text
每一步 nonlinear solve 所对应的方程本身不同
```

## 这一小专题现在拆成哪几篇

建议按下面顺序读：

1. [01-dae-assembly-pipeline.md](01-dae-assembly-pipeline.md)  
   先弄清 DAE 量是怎么被装出来的

2. [02-dae-math-solving.md](02-dae-math-solving.md)  
   先建立 DC / TR 数学问题的总览

3. [03-dc-operating-point-solving.md](03-dc-operating-point-solving.md)  
   细看稳态 operating point 的方程、Newton 和代码

4. [04-transient-time-discretization-and-solving.md](04-transient-time-discretization-and-solving.md)  
   细看 time discretization、每一步 nonlinear solve 和代码

## 这一篇只想让你先记住的 3 句话

1. DC 在本质上是在解：

$$
F(x)-B=0
$$

2. transient 在本质上是在解：

$$
\frac{dQ(x)}{dt}+F(x)-B(t)=0
$$

但它会先被离散成“每一个时间步上的 nonlinear algebraic equation”。

3. 不管是 DC 还是 TR，一旦进入 Newton 主线，最终都会走到：

- residual load
- Jacobian load
- linear solve

只是它们对应的方程本体不同。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 transient 不是“一个大方程一次解完”，而是“时间推进 + 每步 nonlinear solve”？
2. 如果只从数学本质上看，DC 和 transient 最大的区别是“求解器不同”，还是“每一步要求解的方程不同”？
