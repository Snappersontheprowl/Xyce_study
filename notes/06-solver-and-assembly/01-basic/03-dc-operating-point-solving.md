# dc operating point solving

记录日期：2026-06-04

## 这次读了哪些文件

这次只盯 DC operating point 的数学求解与代码对应，按“分析触发 -> time integration 退化 -> Newton -> linear solve”的顺序读了这些文件：

- [src/AnalysisPKG/N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
- [src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C)
- [src/NonlinearSolverPKG/N_NLS_Manager.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.C)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)
- [src/NonlinearSolverPKG/N_NLS_DampedNewton.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_DampedNewton.C)
- [src/LinearAlgebraServicesPKG/N_LAS_Solver.h](../../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Solver.h)

## 这次带着什么问题去读

这篇只回答 DC 的问题：

- DC operating point 数学上到底在解什么？
- 为什么在代码里它会走 `NO_TIME_INTEGRATION`？
- residual / Jacobian 在 DC 下具体退化成什么？
- Newton 每一步是怎么展开的？
- linear solver 在 DC 求解里具体扮演什么角色？

## 当前结论先写在前面

DC operating point 的本质是求一个稳态解 $x^*$，使得：

$$
F(x^*) - B = 0
$$

也就是：

$$
f(x) = F(x) - B = 0
$$

在 Xyce 里，这件事会被实现成：

1. 把 time integration method 设成 `NO_TIME_INTEGRATION`
2. 让 residual 退化成只含 `F-B`
3. 让 Jacobian 退化成基本只含 `dF/dx`
4. 对这个 nonlinear algebraic equation 做 Newton
5. 在每个 Newton 步里调用 linear solver 解：

$$ 
J(x_k)\,\Delta x_k = -f(x_k)
$$

## 第零步：原始方程是什么，DC 到底从哪里来

如果从最一般的电路 DAE 出发，原始方程仍然是：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

这里：

- $$x(t)$$ 是电路未知量
- $$Q(x)$$ 是动态电荷/状态项
- $$F(x)$$ 是静态导通项
- $$B(t)$$ 是外部激励

而 `DC operating point` 的问题，不是“再发明一条新方程”，而是对这条原始方程施加两个稳态假设：

1. 我们只关心**时间不再变化的平衡点**
2. 外部激励也先看成恒定的直流激励 $$B_0$$

一旦进入稳态，就有：

$$
\frac{dQ(x)}{dt}=0
$$

于是原始 DAE 直接退化成：

$$
F(x) - B_0 = 0
$$

这就是 `DC operating point` 的本体。

所以最值得先吃住的一句是：

```text
DC 不是另一种完全不同的方程，
而是把原始 DAE 放在“时间不再变化”的稳态条件下得到的退化形式。
```

## 第一步：为什么 DC 先看成“平衡点问题”

求 `DCOP` 时，我们真正关心的是：

```text
有没有一个 x*，
让所有节点和支路在当前直流激励下都达到自洽平衡
```

这个“平衡”有两个层次：

### 1. 动态量不再变化

如果某个电容或内部状态还在继续变化，那就说明系统还在演化，不是 `DCOP`。

所以对 `DC` 来说，所有动态项都被压到了：

$$
\frac{dQ(x)}{dt}=0
$$

### 2. 静态导通和源激励正好平衡

也就是：

$$
F(x^\*) - B_0 = 0
$$

这就是为什么 `DCOP` 更像“找平衡点”，而不是“沿时间往前推一个轨迹”。

## 第二步：为什么 DC 仍然可能是非线性的

虽然 `DC` 没有时间项，但它并不自动变成线性问题。  
原因很简单：

- `F(x)` 往往是非线性的
- 比如 diode、BJT、MOS 的电流都依赖当前工作点

所以 `DC` 真正解的是：

$$
f(x)=F(x)-B_0=0
$$

如果 `F(x)` 非线性，那么 $$f(x)=0$$ 仍然是一个 nonlinear algebraic equation。

这就是为什么 `DCOP` 需要 Newton，而不是直接“一次矩阵求逆”。

## 第三步：Newton 在 DC 里到底在解什么

到了这一步，`DC` 的数学任务就很明确了：

$$
f(x)=F(x)-B_0=0
$$

对当前猜测点 $$x_k$$ 做一阶线性化：

$$
f(x_k+\Delta x) \approx f(x_k) + J(x_k)\Delta x
$$

其中：

$$
J(x_k)=\frac{\partial f}{\partial x}(x_k)=\frac{\partial F}{\partial x}(x_k)
$$

令线性化后的残差为零：

$$
f(x_k) + J(x_k)\Delta x_k = 0
$$

于是得到 Newton 线性系统：

$$
J(x_k)\Delta x_k = -f(x_k)
$$

然后更新：

$$
x_{k+1}=x_k+\lambda_k \Delta x_k
$$

其中 $$\lambda_k$$ 在 `DampedNewton` 里可能不是 1，而是经过步长控制后的阻尼因子。

所以这一步最重要的理解是：

```text
DC 求解的主动作不是“解最终方程一次”，
而是反复在当前工作点附近做局部线性化，再解线性修正量。
```

## 第四步：为什么 DC 在代码里会走 `NO_TIME_INTEGRATION`

先看：

- [N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)

在 `DCSweep::doRun()` 的注释里，已经直接说了：

```text
DC sweep 是一系列 operating point calculations
也就是没有 time integration 的计算
```

继续看 `DCSweep::doInit()`，里面最关键的一句是：

- `baseIntegrationMethod_ = TimeIntg::methodsEnum::NO_TIME_INTEGRATION;`

然后调用：

- `analysisManager_.createTimeIntegratorMethod(tiaParams_, baseIntegrationMethod_);`

这一步的数学含义非常直接：

```text
告诉后面的 residual / Jacobian 组合层：
这不是瞬态，不要再构造 dQ/dt 项
```

所以 DC 不是“没有 time integration 类参与”，而是：

```text
time integration 仍然参与，
但它参与的方式是“明确告诉系统这次没有时间导数项”
```

## 第五步：DC 下 residual 退化成什么

这一层看：

- [N_TIA_NoTimeIntegration.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C)

关键函数是：

- `NoTimeIntegration::obtainResidual()`

它里面最关键的一句是：

- `ds.RHSVectorPtr->update(+1.0,*ds.daeFVectorPtr,-1.0,*ds.daeBVectorPtr,0.0);`

然后又有一句：

- `ds.RHSVectorPtr->scale(-1.0);`

这两句放在一起看，就非常重要了。

### 数学上

DC 下我们要解的是：

$$
f(x)=F(x)-B=0
$$

### 代码上

Xyce 的 nonlinear solver 约定，`RHSVectorPtr` 存的不是 $f(x)$，而是：$-f(x)$

所以这里实际构造的是：

$$
-(F(x)-B)
$$

也就是：

$$
B-F(x)
$$

这就是为什么在读代码时要一直记住：

```text
RHSVectorPtr 不是 f(x)，而是 -f(x)
```

否则很多符号会看反。

## 第六步：DC 下 Jacobian 退化成什么

继续看：

- `NoTimeIntegration::obtainJacobian()`

这里最关键的一句是：

- `Jac.linearCombo( 1.0e-20, dQdx, 1.0, dFdx );`

### 数学上

稳态下没有真实的 $$dQ/dt$$，所以 Jacobian 本应退化成：

$$
J(x)=\frac{\partial F}{\partial x}(x)
$$

### 代码上为什么还保留一点 `dQdx`

注释里已经解释了：

- 如果完全不加 `dQdx`，某些只通过电容连接的节点可能让矩阵变得奇异
- 所以 Xyce 人为加一个极小系数：

$$
10^{-20}\,dQdx + dFdx
$$

这不是说 DC 真的有时间导数，而是一个数值稳定性上的工程处理。

所以你可以把这一步记成：

$$
J_{\text{DC}} \approx \frac{\partial F}{\partial x}
$$

只是代码里为了避免奇异矩阵，保留了一个极小的电容型项。

## 第七步：DC 求解是在哪触发的

回到分析层。

在：

- [N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)

里，`takeStep_()` 做的事情非常直接：

1. `doHandlePredictor()`
2. `loader_.updateSources()`
3. `nonlinearManager_.solve()`
4. `stepLinearCombo()`

这里最关键的是第三步：

- `analysisManager_.getStepErrorControl().newtonConvergenceStatus = nonlinearManager_.solve();`

这说明 DC 分析层不直接写 Newton，而是：

```text
在一个 sweep 点或 operating point 点，
把当前 nonlinear equation 交给 nonlinear solver 去解
```

## 第八步：进入 nonlinear solver 后，Newton 是怎么展开的

这里最值得看的文件是：

- [N_NLS_DampedNewton.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_DampedNewton.C)

`DampedNewton::solve()` 的主循环，非常适合直接拿来对应 Newton 数学步骤。

### 初始 residual

进入 `solve()` 以后，第一件事是：

- `rhs_();`

这对应数学上：

$$
计算当前猜测点 x_0 的残差 f(x_0)
$$

当然，代码里实际存的是 $$-f(x_0)$$。

### 迭代主循环

在 while 循环里，每次迭代最关键的三步是：

1. `jacobian_();`
2. `direction_();`
3. `computeStepLength_();`

把它翻译成数学语言，就是：

1. 计算当前点的 Jacobian
2. 解线性化方程，得到 Newton 方向
3. 选择步长，更新解

### Newton 方向

再看：

- `DampedNewton::direction_()`

里面最关键的一句是：

- `linearStatus_ = newton_();`

而：

- `DampedNewton::newton_()` 又回到基类 `NonLinearSolver::newton_()`

最终真正发生 linear solve 的地方在：

- [N_NLS_NonLinearSolver.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)
  中的 `NonLinearSolver::newton_()`

那里调用：

- `lasSolverRCPtr_->solve(false);`

所以这一步就是在数学上解：

$$
J(x_k)\,\Delta x_k = -f(x_k)
$$

### 解更新

再看 `computeStepLength_()`、`divide_()`、`backtrack_()` 这些函数，会发现：

- 先拿一个方向 `searchDirectionPtr_`
- 再决定 `stepLength_`
- 然后 `updateX_()`

这对应的数学形式就是：

$$
x_{k+1}=x_k+\lambda_k \Delta x_k
$$

其中：

- $$\Delta x_k$$ 是 Newton 方向
- $$\lambda_k$$ 是阻尼 / backtracking 得到的步长

所以 Xyce 这里不是“永远 full Newton 一步到位”，而是：

```text
Newton 方向
+ 线搜索 / 阻尼步长
```

## 第六步：linear solver 在 DC 求解里扮演什么角色

再看：

- [N_LAS_Solver.h](../../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Solver.h)

它对外最核心的接口就是：

- `solve(bool reuse_factors = false)`

所以在 DC operating point 这个场景下，linear solver 的角色可以非常数学化地理解为：

```text
给定当前 Newton 迭代点的 Jacobian 和 residual，
解出本轮线性化方程的更新方向
```

换句话说：

- nonlinear solver 决定“这一步要解哪个线性化问题”
- linear solver 负责“把这个线性化问题解出来”

## 把 DC 的数学主线和代码主线对齐

这一篇最值得记的对照表就是下面这组。

### 1. 稳态方程

数学：

$$
F(x)-B=0
$$

代码：

- `DCSweep::doInit()` 选择 `NO_TIME_INTEGRATION`
- `NoTimeIntegration::obtainResidual()`

### 2. Jacobian

数学：

$$
J(x)=\frac{\partial F}{\partial x}(x)
$$

代码：

- `NoTimeIntegration::obtainJacobian()`

工程上实际使用的是：

$$
J \approx 10^{-20}dQdx + dFdx
$$

### 3. Newton 迭代

数学：

$$
J(x_k)\,\Delta x_k = -f(x_k)
$$

$$
x_{k+1}=x_k+\lambda_k\Delta x_k
$$

代码：

- `DampedNewton::solve()`
- `jacobian_()`
- `direction_()`
- `computeStepLength_()`
- `updateX_()`

### 4. 线性求解

数学：

$$
\text{solve linearized system}
$$

代码：

- `NonLinearSolver::newton_()`
- `Linear::Solver::solve()`

## 这一篇最重要的路径图

这一篇建议记住下面这张图：

```text
DCSweep::doInit()
-> 选择 NO_TIME_INTEGRATION

DCSweep::takeStep_()
-> nonlinearManager_.solve()

DampedNewton::solve()
-> rhs_()
-> while not converged:
   -> jacobian_()
   -> direction_()
      -> newton_()
      -> Linear::Solver::solve()
   -> computeStepLength_()
   -> updateX_()
   -> rhs_()
```

## 这一篇最想让你真正吃下来的本质

DC operating point 从数学上看，不是“做一次矩阵求解”这么简单，而是：

$$
\text{solve a nonlinear algebraic system}
$$

线性求解器只负责其中每一轮 Newton 迭代里的那一步线性化子问题。

## 现在可以做的自检

你可以试着回答这三个问题：

1. 为什么 DC operating point 的本质不是“解一次线性方程”，而是“解一个 nonlinear 方程组”？
2. `NoTimeIntegration::obtainResidual()` 为什么会构造 `-(F-B)`，而不是直接构造 `F-B`？
3. `DampedNewton::solve()` 里的 `computeStepLength_()`，在数学上对应的是哪个步骤？
