# transient time discretization and solving

记录日期：2026-06-04

## 这次读了哪些文件

这次只盯 transient 的数学本质与代码对应，按“原始 DAE -> 时间离散 -> 每步 nonlinear solve”的顺序读了这些文件：

- [src/AnalysisPKG/N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)
- [src/TimeIntegrationPKG/N_TIA_WorkingIntegrationMethod.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_WorkingIntegrationMethod.C)
- [src/TimeIntegrationPKG/N_TIA_OneStep.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_OneStep.C)
- [src/TimeIntegrationPKG/N_TIA_Gear12.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_Gear12.C)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)
- [src/NonlinearSolverPKG/N_NLS_DampedNewton.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_DampedNewton.C)

## 这次带着什么问题去读

这篇只回答 transient 的问题：

- 原始电路 DAE 是什么？
- time integration 到底做了什么数学变换？
- 为什么 transient 不是“直接解 DAE”，而是“每个时间步解一个 nonlinear algebraic equation”？
- `doInit()`、`doTranOP()`、`takeAnIntegrationStep_()` 在数学上分别对应什么阶段？
- 每个时间步里的 Newton / linear solve 又是怎么展开的？

## 当前结论先写在前面

transient 原始上要解的是：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

但数值上并不是直接对这个连续时间方程“一次性求解”，而是：

1. 选一个时间积分方法
2. 把 ${dQ}/{dt}$ 离散成依赖当前步和历史步的代数项
3. 在每个时间步上，形成一个新的 nonlinear equation
4. 对这个新的 nonlinear equation 做 Newton

所以 transient 的本质是：

$$
\text{time stepping}
\;+\;
\text{nonlinear solve at each step}
$$

## 第零步：为什么 transient 研究的是“轨迹”，不是“一个点”

如果 `DCOP` 研究的是：

```text
有没有一个平衡点 x*
```

那么 `transient` 研究的就是：

```text
在给定初始状态和随时间变化的激励下，
整条 x(t) 轨迹怎样演化
```

所以 `transient` 从一开始就和 `DC` 不同：

- `DC` 的未知对象更像一个静态点 $x^*$
- `transient` 的未知对象是一条时间函数 $x(t)$

也正因为如此，`transient` 不可能像 `DC` 一样只解一个方程就结束。

## 第一步：原始方程是什么

在电路 DAE 这一层，最原始的形式就是：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

其中：

- $Q(x)$ 通常可以理解成电荷 / 动态状态相关量
- $F(x)$ 是静态或导通类贡献
- $B(t)$ 是源激励

这个式子和 DC 最大的区别就在于：

$$
\frac{dQ(x)}{dt}
$$

这一项真实存在。

## 第二步：为什么 transient 不能直接“把 DAE 一次解完”

因为这里的未知量不是单独一个时刻的 $x$，而是一个随时间变化的轨迹 $x(t)$。

所以 transient 不能简单理解成：

$$
\text{solve one nonlinear system}
$$

而要理解成：

$$
t_0 \rightarrow t_1 \rightarrow t_2 \rightarrow \cdots
$$

在每个时间步 $t_n$，都构造一个新的方程：

$$
\Phi_n(x_n)=0
$$

这里的 $\Phi_n$ 来自把 $\frac{dQ}{dt}$ 离散化之后得到的代数表达式。

## 第三步：时间离散在数学上到底做了什么

`transient` 最关键的一步，不是“又做一次 Newton”，而是先把连续时间问题变成离散时间问题。

原始上你面对的是：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

这里难点在于：

- $x(t)$ 是一个连续时间函数
- $Q(x(t))$ 的导数不是一个现成代数量

时间积分方法做的事情，本质上就是：

```text
把 dQ/dt 用“当前步 + 历史步”的代数组合近似掉
```

一旦这一步完成，连续时间问题就会被改写成“当前时刻未知量 $x_n$ 满足的一条代数方程”。

所以时间积分的本质不是“求解器技巧”，而是：

```text
把“轨迹问题”变成“一步一步的代数问题”
```

## 第四步：最朴素地看 backward Euler，当前步方程怎么来

先用最简单的直觉来看。  
假设当前时刻是 $t_n$，上一步是 $t_{n-1}$，时间步长是：

$$
\Delta t = t_n - t_{n-1}
$$

如果用最朴素的 backward Euler / BDF1 思路，那么：

$$
\frac{dQ}{dt}(t_n)
\approx
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t}
$$

把它代回原始 DAE：

$$
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t} + F(x_n) - B(t_n) = 0
$$

这就是当前时间步上的 nonlinear algebraic equation。

这里最值得先抓住的点是：

- $x_n$ 是当前步未知量
- $x_{n-1}$ 是历史已知量

所以当前步真正要解的是：

$$
\Phi_n(x_n)=0
$$

其中：

$$
\Phi_n(x_n)=
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t}+F(x_n)-B(t_n)
$$

这就是“为什么 transient 每一步最终还是要解一个 nonlinear equation”的最直接来源。

## 第五步：为什么每一步仍然可能是非线性的

虽然时间导数已经被离散成代数形式了，但当前步方程仍然可能是非线性的。  
原因在于：

- $Q(x_n)$ 可能非线性
- $F(x_n)$ 也可能非线性

所以把时间离散之后，事情并没有变成一个固定线性系统，而只是变成：

```text
当前步对 x_n 的 nonlinear algebraic equation
```

这就是为什么 transient 每个时间步里仍然需要：

- residual
- Jacobian
- Newton

## 第六步：当前步 Jacobian 为什么会多出 dQdx 项

继续用 backward Euler 的最朴素形式：

$$
\Phi_n(x_n)=
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t}+F(x_n)-B(t_n)
$$

对 $x_n$ 求导：

$$
J_n =
\frac{\partial \Phi_n}{\partial x_n}
=
\frac{1}{\Delta t}\frac{\partial Q}{\partial x}(x_n)
+
\frac{\partial F}{\partial x}(x_n)
$$

这一步非常关键，因为它正好解释了：

```text
为什么 transient 的 Jacobian 和 DC 不一样
```

在 `DC` 里，主角是：

$$
\frac{\partial F}{\partial x}
$$

在 `transient` 里，还会多出一块由时间离散带来的：

$$
\frac{1}{\Delta t}\frac{\partial Q}{\partial x}
$$

这就是 transient Jacobian 里“电容型项”的根源。

## 第七步：高阶 Gear / BDF 只是把“一个历史点”推广成“多个历史点”

上面用的是最简单的 BDF1 直觉。  
而在更高阶的 Gear / BDF 里，区别只是：

$$
\frac{dQ}{dt}(t_n)
\approx
\frac{1}{\Delta t}
\left(
\alpha_0 Q(x_n)
+
\alpha_1 Q(x_{n-1})
+
\alpha_2 Q(x_{n-2})
\cdots
\right)
$$

所以当前步方程会变成：

$$
\Phi_n(x_n)=
\frac{1}{\Delta t}
\left(
\alpha_0 Q(x_n)
+
\alpha_1 Q(x_{n-1})
+
\alpha_2 Q(x_{n-2})
\cdots
\right)
+
F(x_n)-B(t_n)=0
$$

这里最重要的不是每个系数的细节，而是要吃住这件事：

```text
不管是一阶还是二阶，
当前步未知量仍然只出现在 x_n 上，
历史项都已经变成已知量。
```

所以更高阶的 Gear / BDF 不会改变 transient 的本质，只会改变：

- 当前步方程里历史项怎样加权
- Jacobian 里 `dQdx` 前面的系数

## 第八步：代码里哪一层在做“时间离散”

这一层先看：

- [N_TIA_WorkingIntegrationMethod.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_WorkingIntegrationMethod.C)

它的角色不是直接装 device，而是把真正的 time integration method 包起来。

对当前阶段最关键的两个接口是：

- `obtainResidual()`
- `obtainJacobian()`

也就是说：

```text
device / loader 层先把 Q, F, B, dQdx, dFdx 装出来
time integration 层再决定“如何用这些量构造当前时间步的方程”
```

## 第九步：OneStep / backward-Euler 在代码里怎么对应

先看：

- [N_TIA_OneStep.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_OneStep.C)

在 `OneStep::obtainResidual()` 里，你可以看出它先做：

- 当前 `Q` 与历史 `Q` 的差
- 再按当前时间步长缩放
- 再加上 `F-B`

从数学上最朴素地看，这就很接近：

$$
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t} + F(x_n) - B(t_n) = 0
$$

这就是“把连续时间 DAE 变成当前时间步上的 nonlinear algebraic equation”的最直观版本。

### Jacobian 对应什么

在 `OneStep::obtainJacobian()` 里，有一句注释已经直接写了：

$$
-(\text{sec.alphas\_}/h_n)\,dQdx(x)+dFdx
$$

也就是说，Jacobian 不再只是：

$$
\frac{\partial F}{\partial x}
$$

而是多了一个来自时间离散的“电容型项”：

$$
J_n =
\frac{\partial}{\partial x}
\left(
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t}
 + F(x_n) - B(t_n)
\right)
$$

直观地写，就是：

$$
J_n \approx \frac{1}{\Delta t}\frac{\partial Q}{\partial x}(x_n) + \frac{\partial F}{\partial x}(x_n)
$$

具体符号和系数由积分方法决定。

## 第十步：Gear/BDF 视角下要怎么理解

再看：

- [N_TIA_Gear12.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_Gear12.C)

在 `Gear12::obtainResidual()` 里可以看到，它不是只用一个历史点，而是会用：

- `alpha_[0]`
- `alpha_[1]`
- 如果二阶还会用 `alpha_[2]`
- 再配合 `qHistory`

从数学上，你可以把它理解成：

$$
\frac{dQ}{dt}(t_n)
\approx
\frac{1}{\Delta t}
\left(
\alpha_0 Q(x_n)
\alpha_1 Q(x_{n-1})
\alpha_2 Q(x_{n-2})
\cdots
\right)
$$

于是每个时间步上真正要求解的方程变成：

$$
\Phi_n(x_n)=
\frac{1}{\Delta t}
\left(
\alpha_0 Q(x_n)
\alpha_1 Q(x_{n-1})
\alpha_2 Q(x_{n-2})
\cdots
\right)
 + F(x_n) - B(t_n)=0
$$

这里不要把重点放在每个系数的正负号细节上。对当前学习阶段，更重要的是看懂这件事：

```text
当前步未知量只出现在 x_n 里，
历史步 x_{n-1}, x_{n-2}, ... 已经是已知量，
所以 transient 每一步最终都会落成一个“只对 x_n 求解”的 nonlinear algebraic equation。
```

如果先用最朴素的 BDF1 / backward Euler 直觉来理解，这个式子就会退化成：

$$
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t} + F(x_n) - B(t_n)=0
$$

而更高阶的 Gear/BDF，只是把这个“一个历史点”推广成“多个历史点加权组合”。

这就是为什么 transient 每一步虽然还是 “Newton + linear solve”，但它解的方程和 DC 已经不一样了。

### Gear12 的 Jacobian

在 `Gear12::obtainJacobian()` 里，对应的 Jacobian 也是：

$$
J_n =
\frac{\alpha_0}{\Delta t}\frac{\partial Q}{\partial x}(x_n)
 + \frac{\partial F}{\partial x}(x_n)
$$

代码里对应的就是：

- `qscalar(sec.alpha_[0]/sec.currentTimeStep);`
- `Jac.linearCombo( qscalar, dQdx, fscalar, dFdx );`

## 第十一步：Transient 分析流程在做什么

接着回到分析层：

- [N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

这一层的几个阶段，从数学上正好可以这样理解。

### `doInit()`

`doInit()` 的主要作用不是“开始解”，而是准备：

- 是否先做 DCOP
- 初始条件 / 初始猜测
- 初始积分方法
- 时间步控制

这里最值得记的一点是：

- 如果 `dcopFlag_` 为真，先把积分方法设成 `NO_TIME_INTEGRATION`
- 也就是先做一个 DC operating point

这说明 transient 不是一上来就直接时间推进，而是通常先找一个合理的初始稳态点。

### `doTranOP()`

这个函数就是：

```text
先做 precede transient loop 的 DCOP
```

从数学上说，就是先找一个 $x_0$，使得：

$$
F(x_0)-B(t_0)=0
$$

这样后面的时间步就有一个更稳定的起点。

### `takeAnIntegrationStep_()`

这一步才是真正的 transient 时间步主线。

它的结构非常清楚：

1. `doHandlePredictor()`
2. `loader_.updateSources()`
3. `nonlinearManager_.solve()`
4. `stepLinearCombo()`
5. `evaluateStepError(...)`

这一步的数学含义可以直接写成：

1. 先做 predictor，构造当前步的初始猜测 $x_n^{(0)}$
2. 用当前时刻的源激励构造当前步方程
3. 用 Newton 解当前步的 nonlinear equation $$\Phi_n(x_n)=0$$
4. 接受 / 更新当前步结果
5. 做误差估计，决定步长和阶数是否调整

## 第十二步：每个时间步里的 nonlinear solve 和 DC 有什么关系

一旦进入：

- `nonlinearManager_.solve()`

后面的骨架和 DC 很像，还是会回到：

- `rhs_()`
- `jacobian_()`
- `newton_()`

区别不在求解器形式，而在：

```text
这一次 rhs 和 Jacobian 对应的方程已经不是 DC 方程，
而是“离散化之后的当前时间步方程”
```

所以 transient 里的 Newton，本质上是在解：

$$
\Phi_n(x_n)=0
$$

而不是单纯解：

$$
F(x)-B=0
$$

## 把 transient 的数学主线和代码主线对齐

这一篇最值得记的对照表如下。

### 1. 原始 DAE

数学：

$$
\frac{dQ(x)}{dt}+F(x)-B(t)=0
$$

代码语境：

- `NonlinearEquationLoader` 先得到 `Q/F/B`
- `WorkingIntegrationMethod` 决定怎样离散 $dQ/dt$

### 2. 时间离散

数学：

$$
\Phi_n(x_n)=0
$$

例如可直观理解为：

$$
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t}+F(x_n)-B(t_n)=0
$$

代码：

- `OneStep::obtainResidual()`
- `Gear12::obtainResidual()`

### 3. 当前时间步 Jacobian

数学：

$$
J_n \approx \frac{\alpha_0}{\Delta t}\frac{\partial Q}{\partial x}(x_n)+\frac{\partial F}{\partial x}(x_n)
$$

代码：

- `OneStep::obtainJacobian()`
- `Gear12::obtainJacobian()`

### 4. 当前步的 nonlinear solve

数学：

$$
J_n(x_n^{(k)})\,\Delta x_n^{(k)} = -\Phi_n(x_n^{(k)})
$$

代码：

- `takeAnIntegrationStep_()`
- `nonlinearManager_.solve()`
- `NonLinearSolver::rhs_()`
- `NonLinearSolver::jacobian_()`
- `NonLinearSolver::newton_()`

## 这一篇最重要的路径图

这一篇建议你记住下面这张图：

```text
Transient::doInit()
-> 先决定是否做 DCOP

Transient::doTranOP()
-> 求初始稳态点 x0

Transient::takeAnIntegrationStep_()
-> predictor 给出 x_n^(0)
-> 更新当前时刻源
-> nonlinearManager_.solve()
   -> rhs_()
   -> jacobian_()
   -> newton_()
   -> Linear::Solver::solve()
-> stepLinearCombo()
-> evaluateStepError()
```

## 这一篇最想让你吃下来的本质

transient 不是“把 DAE 直接扔给 solver 一把解出来”，而是：

$$
\text{continuous-time DAE}
\rightarrow
\text{time discretization}
\rightarrow
\text{one nonlinear algebraic solve per time step}
$$

只要这句话你真的吃进去了，后面再读 Gear、BDF、步长控制，就会顺很多。

## 现在可以做的自检

你可以试着回答这四个问题：

1. transient 为什么必须先把 $\frac{dQ}{dt}$ 离散成代数形式，才能交给 Newton？
2. `OneStep::obtainResidual()` 和 `Gear12::obtainResidual()` 的共同点是什么？
3. `doTranOP()` 在 transient 里为什么通常很重要？
4. transient 每一个时间步的 Newton，和 DC 的 Newton，最大的区别是“算法不同”还是“要求解的方程不同”？
