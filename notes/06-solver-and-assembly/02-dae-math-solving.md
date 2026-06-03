# dae math solving

记录日期：2026-06-04

## 这次读了哪些文件

这次只盯“DAE 已经装好之后，数学上怎么求解”，按从分析触发到 Newton / linear solve 的顺序读了这些文件：

- [src/AnalysisPKG/N_ANP_DCSweep.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
- [src/AnalysisPKG/N_ANP_Transient.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)
- [src/NonlinearSolverPKG/N_NLS_Manager.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.h)
- [src/NonlinearSolverPKG/N_NLS_Manager.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.C)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)
- [src/LinearAlgebraServicesPKG/N_LAS_System.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_System.h)
- [src/LinearAlgebraServicesPKG/N_LAS_Problem.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Problem.h)
- [src/LinearAlgebraServicesPKG/N_LAS_Solver.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Solver.h)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)

## 这次带着什么问题去读

这一篇专门回答：

- DAE 量已经齐备之后，数学上要解的方程到底是什么？
- residual 和 Jacobian 是哪一层真正组合出来的？
- 分析流程在哪一步发起 nonlinear solve？
- Newton 迭代里，谁负责 residual load、Jacobian load、linear solve？
- 这些数学步骤在代码里分别对应哪些函数？

## 当前结论先写在前面

这一篇最重要的主线是：

```text
分析流程
-> nonlinearManager_.solve()
-> NonLinearSolver::rhs_()
   -> NonlinearEquationLoader::loadRHS()
   -> obtainResidual()
-> NonLinearSolver::jacobian_()
   -> NonlinearEquationLoader::loadJacobian()
   -> obtainJacobian()
-> NonLinearSolver::newton_()
   -> Linear::Solver::solve()
```

如果只抓数学本质，可以先记成：

```text
目标方程：f(x) = dQ/dt + F(x) - B(t) = 0
Jacobian：J = d(dQ/dt)/dx + dF/dx
Newton 步：J * Δx = -f(x)
```

代码里这三步分别由：

- `loadRHS()`
- `loadJacobian()`
- `newton_()`

对应起来。

## 先把数学对象和代码对象对上

这是这一篇最关键的第一步。

前一篇已经知道，device 层先写出：

- `Q`
- `F`
- `B`
- `dQdx`
- `dFdx`

接下来数学上真正要解的不是这些量本身，而是：

```text
f(x) = dQ/dt + F - B = 0
```

以及它的 Jacobian：

```text
J = d(dQ/dt)/dx + dF/dx
```

这在代码里并不是由 device 直接完成，而是由：

- [N_LOA_NonlinearEquationLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)

里的：

- `loadRHS()`
- `loadJacobian()`

再加上 `WorkingIntegrationMethod` 去做最终组合。

### 代码对照：residual

数学上：

```text
f(x) = dQ/dt + F - B
```

代码上：

1. `NonlinearEquationLoader::loadRHS()` 先让下层装出 `daeQ`、`daeF`、`daeB`
2. `wim_.obtainResidual()` 再把它们组合成 nonlinear solver 真正看到的 residual

### 代码对照：Jacobian

数学上：

```text
J = d(dQ/dt)/dx + dF/dx
```

代码上：

1. `NonlinearEquationLoader::loadJacobian()` 先让下层装出 `dQdx`、`dFdx`
2. `wim_.obtainJacobian()` 再根据积分方法把最终 Jacobian 组合出来

所以这一篇的第一个核心认知是：

```text
NonlinearEquationLoader + WorkingIntegrationMethod
共同把 DAE 组成部分变成数学求解对象
```

## 数学求解是在哪一步被触发的

接下来要回答：

```text
谁决定“现在该解一次 f(x)=0 了”
```

这一层先回到分析代码。

### 在 `.DC` 里

看：

- [N_ANP_DCSweep.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)

在 `takeStep_()` 里有：

- `analysisManager_.getStepErrorControl().newtonConvergenceStatus = nonlinearManager_.solve();`

这说明 `.DC` 分析并不自己展开 Newton 细节，它只是：

```text
在一个需要求解 operating point 的时刻，
调用 nonlinearManager_.solve()
```

### 在 `.TRAN` 里

看：

- [N_ANP_Transient.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

里面也能看到同样的调用：

- `nonlinearManager_.solve()`

这说明：

- `.TRAN` 控制“什么时候要解”
- `Nonlinear::Manager` 决定“把这个解交给哪种 nonlinear solver”
- 具体 residual / Jacobian / Newton 步的数学细节，不在分析类里展开

## `Nonlinear::Manager` 在数学求解专题里是什么角色

接着看：

- [N_NLS_Manager.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.h)
- [N_NLS_Manager.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.C)

在这个专题里，它最重要的身份不是“数学算法实现”，而是：

```text
nonlinear solver 的统一入口
```

它做的几件关键事情是：

1. 持有一个具体 `nonlinearSolver_`
2. 给它注册：
   - `Linear::System`
   - `NonlinearEquationLoader`
   - `DataStore`
   - `AnalysisManager`
3. 在外部调用 `solve()` 时直接转发：
   - `return nonlinearSolver_->solve();`

所以如果从“数学求解接口”角度看，`Manager` 更像：

```text
分析层 -> 数学求解层 的门面
```

## 真正展开 Newton 主线的是 `NonLinearSolver`

接下来才是真正的数学主角：

- [N_NLS_NonLinearSolver.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h)
- [N_NLS_NonLinearSolver.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)

这个类虽然是抽象基类，但已经把“通用数学骨架”搭好了。

这里最值得抓的四个 helper 是：

- `setX0_()`
- `rhs_()`
- `jacobian_()`
- `newton_()`

### `setX0_()`

这一步先不用想复杂，它做的是：

```text
准备本轮 Newton 迭代使用的当前解向量
```

也就是把当前解相关信息同步到 solver 看见的工作向量里。

### `rhs_()`

这一步对应的是：

```text
计算当前 x 下的 residual
```

代码上最关键的一句是：

- `nonlinearEquationLoader_->loadRHS();`

所以：

```text
NonLinearSolver::rhs_()
-> 不是自己算 residual
-> 而是回到 DAE 组合链去拿 residual
```

### `jacobian_()`

这一步对应的是：

```text
计算当前 x 下的 Jacobian
```

代码上最关键的一句是：

- `nonlinearEquationLoader_->loadJacobian();`

所以：

```text
NonLinearSolver::jacobian_()
-> 不是自己逐项微分 device
-> 而是回到 DAE 组合链去拿 Jacobian
```

### `newton_()`

这一步就是数学求解专题里最关键的那一下：

```text
解线性化方程，得到 Newton 更新方向
```

代码里最关键的是：

- `lasSolverRCPtr_->setNewtonIter(...)`
- `lasSolverRCPtr_->solve(false)`

把它和数学表达式对起来看，就是：

```text
J * Δx = -f(x)
```

所以如果要回答“linear solver 真正在哪一层被调用”，这里就是最直接的答案：

```text
NonLinearSolver::newton_()
```

## `Linear::System`、`Problem`、`Solver` 在数学求解里分别代表什么

这一层最好直接跟数学对象对照。

### `Linear::System`

看：

- [N_LAS_System.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_System.h)

它提供：

- Jacobian matrix
- RHS vector
- Newton vector
- `Problem`

可以先理解成：

```text
求解所需矩阵/向量的宿主
```

### `Linear::Problem`

看：

- [N_LAS_Problem.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Problem.h)

它把：

- `A`
- `x`
- `b`

打包到一起。

所以数学上，它最接近：

```text
A x = b
```

这一整个线性问题对象。

### `Linear::Solver`

看：

- [N_LAS_Solver.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Solver.h)

它对外暴露的核心就是：

- `solve(bool reuse_factors = false)`

所以从数学角度看，这一层的职责非常纯粹：

```text
给你一个线性问题
把它解出来
```

前面的电路、器件、DAE，都不会直接泄漏到这个接口里。

## 把数学主线和代码主线对齐

这一篇最有用的部分，我建议就记下面这张对照表。

### 1. 目标方程

数学：

```text
f(x) = dQ/dt + F - B = 0
```

代码：

- `NonlinearEquationLoader::loadRHS()`
- `WorkingIntegrationMethod::obtainResidual()`

### 2. Jacobian

数学：

```text
J = d(dQ/dt)/dx + dF/dx
```

代码：

- `NonlinearEquationLoader::loadJacobian()`
- `WorkingIntegrationMethod::obtainJacobian()`

### 3. Newton 线性化

数学：

```text
J * Δx = -f(x)
```

代码：

- `NonLinearSolver::newton_()`
- `Linear::Solver::solve()`

### 4. 外层触发点

数学语义：

```text
在当前分析步骤，需要做一次 nonlinear solve
```

代码：

- `.DC` / `.TRAN` 里的 `nonlinearManager_.solve()`

## 这篇最重要的路径图

这一篇建议记下面这张“数学求解图”：

```text
.DC / .TRAN
-> nonlinearManager_.solve()
-> NonLinearSolver::setX0_()
-> NonLinearSolver::rhs_()
   -> loadRHS()
   -> obtainResidual()
-> NonLinearSolver::jacobian_()
   -> loadJacobian()
   -> obtainJacobian()
-> NonLinearSolver::newton_()
   -> Linear::Solver::solve()
```

如果再压缩一句话：

```text
分析层决定何时求解，NonLinearSolver 展开 Newton 骨架，Linear::Solver 负责解每一步线性化方程
```

## 这一篇先不展开什么

为了让这个专题保持“数学求解”聚焦，这里先不继续深挖：

- `DampedNewton::solve()` 的全部迭代细节
- `NOX` 分支和 pseudo-transient 细节
- 线性 solver 背后具体是哪个 Trilinos 算法
- 收敛判据和步长控制的全部策略

这些都属于下一层纵深阅读。

## 现在可以做的自检

你可以试着回答这四个问题：

1. 数学上真正要求解的方程为什么不是单独的 `F(x)=0`，而是 `dQ/dt + F - B = 0`？
2. `NonlinearEquationLoader::loadRHS()` 和 `WorkingIntegrationMethod::obtainResidual()` 分别负责哪一半工作？
3. `nonlinearManager_.solve()` 是在分析层、装配层，还是数学求解层被触发的？
4. 为什么 `Linear::Solver::solve()` 应该放在 `NonLinearSolver::newton_()` 这一层，而不是 `CktLoader`？
