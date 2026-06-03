# matrix assembly and solver interface

记录日期：2026-06-03

## 这次读了哪些文件

这次按“从分析层进入装配层，再进入 nonlinear / linear solver”的顺序读了这些文件：

- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/AnalysisPKG/N_ANP_DCSweep.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
- [src/AnalysisPKG/N_ANP_Transient.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)
- [src/LinearAlgebraServicesPKG/N_LAS_System.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_System.h)
- [src/LinearAlgebraServicesPKG/N_LAS_Problem.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Problem.h)
- [src/LinearAlgebraServicesPKG/N_LAS_Solver.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Solver.h)
- [src/LoaderServicesPKG/N_LOA_Loader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_Loader.h)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.h)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)
- [src/LoaderServicesPKG/N_LOA_CktLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_CktLoader.C)
- [src/NonlinearSolverPKG/N_NLS_Manager.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.h)
- [src/NonlinearSolverPKG/N_NLS_Manager.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.C)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)

## 这次带着什么问题去读

第六阶段的大纲要求弄清：

- 矩阵抽象定义在哪里
- 器件是直接写矩阵结构，还是通过中间抽象层
- nonlinear 求解循环在哪里组织
- linear solver 调用出现在哪一层

前面第四阶段我们已经知道 resistor 最后会贡献 `F` 和 `dFdx`。这次的重点不再是“器件本身怎么写”，而是：

```text
器件贡献
-> 谁把它们收集成 DAE 向量 / 矩阵
-> 谁把这些量变成 nonlinear solver 看到的 residual / Jacobian
-> 谁在 Newton 里触发 linear solve
```

## 当前结论先写在前面

这一阶段最值得先记住的主线是：

```text
AnalysisManager::initializeSolverSystem()
-> DataStore + NonlinearEquationLoader + Linear::System
-> 分析过程里调用 nonlinearManager_.solve()
-> NonLinearSolver::rhs_() / jacobian_()
-> NonlinearEquationLoader::loadRHS() / loadJacobian()
-> CktLoader::loadDAEVectors() / loadDAEMatrices()
-> DeviceMgr::loadDAEVectors() / loadDAEMatrices()
-> 各器件写入 Q / F / B / dQdx / dFdx
-> WorkingIntegrationMethod::obtainResidual() / obtainJacobian()
-> Linear::Solver::solve()
```

如果只抓本质，可以先记成两句话：

- 器件不是直接面向 nonlinear solver 写“最终 residual / Jacobian”，而是先写 DAE 形式的 `Q`、`F`、`B`、`dQdx`、`dFdx`
- 真正把这些量组织成 nonlinear solver 所需方程的是 `NonlinearEquationLoader` 和 `WorkingIntegrationMethod`

## 先从分析层看：谁在准备 solver 系统

第五阶段已经看到，分析流程真正进入 `.DC`、`.TRAN` 前，`AnalysisManager` 会先准备公共基础设施。

这一层最关键的函数还是：

- [N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
  中的 `AnalysisManager::initializeSolverSystem(...)`

这个函数做了四件和第六阶段直接相关的事：

1. 创建 `TimeIntg::DataStore`
2. 创建 `TimeIntg::WorkingIntegrationMethod`
3. 创建 `TimeIntg::StepErrorControl`
4. 创建 `Loader::NonlinearEquationLoader`

这里最重要的认识是：

```text
solver 不是直接拿 device 去算，
而是先拿到一套“求解时公共上下文”
```

这套上下文里最关键的是：

- `DataStore`
  持有本轮求解需要的解向量、状态向量、存储向量、DAE 向量和 DAE 矩阵
- `NonlinearEquationLoader`
  负责把 device / time integration 的信息组装成 nonlinear solver 真正需要的 residual / Jacobian

## 矩阵和 RHS 的“容器层”在哪里

要理解“求解器接口”，先要知道矩阵和向量对象本身放在哪。

这一层先看：

- [N_LAS_System.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_System.h)

`Linear::System` 可以先理解成：

```text
线性系统容器
```

它里面最关键的几个对象是：

- `jacobianMatrixPtr_`
- `rhsVectorPtr_`
- `newtonVectorPtr_`
- `lasProblemPtr_`
- `dFdxdVpVectorPtr_`
- `dQdxdVpVectorPtr_`

这说明在 Xyce 里，linear algebra 这一层已经把最核心的对象准备成了：

- Jacobian matrix
- RHS vector
- Newton update vector
- 一个 `Problem`

继续看：

- [N_LAS_Problem.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Problem.h)

`Linear::Problem` 更像是：

```text
把 A, x, b 打包在一起的求解问题对象
```

它持有：

- `A_`
- `x_`
- `b_`

所以到了 linear solver 这层，核心接口其实已经非常数学化了：

```text
A x = b
```

而不是“电路器件列表”。

## 为什么器件不会直接面对 `Linear::Solver`

这个问题特别重要。

如果从直觉出发，你可能会以为：

- 器件直接往 Jacobian 和 RHS 写
- 然后 linear solver 就求解

但在 Xyce 里，中间有一层很明确的隔离：

- [N_LOA_Loader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_Loader.h)

这个头文件的注释其实已经把设计意图说得很直白了：

- `Nonlinear Equation loader` 这一层，是站在 nonlinear solver 和 time integrator 之间
- `CktLoader` 这一层，是站在 time integrator 和 device package 之间

也就是说，Xyce 有两层 loader：

```text
NonlinearSolver
-> NonlinearEquationLoader
-> CktLoader
-> DeviceMgr
-> Device
```

这就是第六阶段最容易混的地方，也是最需要先建立起来的边界。

## `NonlinearEquationLoader` 这一层到底负责什么

接着看：

- [N_LOA_NonlinearEquationLoader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.h)
- [N_LOA_NonlinearEquationLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)

这个类不是直接去遍历所有器件做物理计算，它更像：

```text
nonlinear solver 看到的“方程装配协调器”
```

最关键的两个函数是：

- `loadRHS()`
- `loadJacobian()`

### `loadRHS()` 的逻辑

`loadRHS()` 的顺序非常值得记：

1. 清零 `daeQVectorPtr`、`daeFVectorPtr`、`daeBVectorPtr`
2. 调 `loader_.updateState(...)`
3. 调 `loader_.loadDAEVectors(...)`
4. 调 `wim_.obtainResidual()`

这里的前因后果是：

- 设备层先给出 DAE 形式的 `Q`、`F`、`B`
- time integration 再根据当前积分方法把它们组合成真正的 residual

也就是说，device 并不是直接写：

```text
最终 residual = 0
```

而是先写：

```text
Q(x), F(x), B(t)
```

然后由 `WorkingIntegrationMethod` 组织成：

```text
f(x) = dQ/dt + F - B
```

### `loadJacobian()` 的逻辑

`loadJacobian()` 的顺序和上面对应：

1. 清零 `dQdxMatrixPtr`、`dFdxMatrixPtr`
2. 调 `loader_.loadDAEMatrices(...)`
3. 调 `wim_.obtainJacobian()`

所以 Jacobian 也不是设备层直接写“最终 Newton Jacobian”，而是先写：

- `dQdx`
- `dFdx`

然后 time integration 再把它们合成：

```text
J = d(dQ/dt)/dx + dF/dx
```

这就是第六阶段最核心的一句认识：

```text
device 写 DAE 组成部分
time integration 写最终 residual / Jacobian 组合规则
```

## 再往下一层：`CktLoader` 负责把 circuit/device 贡献收上来

既然 `NonlinearEquationLoader` 调的是 `loader_.loadDAEVectors()` 和 `loader_.loadDAEMatrices()`，下一步自然就应该看：

- [N_LOA_CktLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_CktLoader.C)

这里最重要的两个函数是：

- `CktLoader::loadDAEVectors(...)`
- `CktLoader::loadDAEMatrices(...)`

这一层的职责可以先概括成：

```text
把 device package 的贡献收集到 DAE 向量 / 矩阵对象里
```

### `loadDAEMatrices(...)`

它最终会调用：

- `deviceManager_.loadDAEMatrices(...)`

但这层还做了一些额外组织工作：

- 在并行模式下处理 overlap import
- 处理 `LINEAR` / `NONLINEAR` / `ALL` / `PDE` 这些 loadType
- 在 `separateLoad` 模式下缓存 linear 设备的矩阵贡献

这个 `separateLoad` 逻辑很值得记一下，因为它说明：

- Xyce 不只是“能算”
- 它还在做装配层面的优化

具体来说：

- linear 设备的矩阵部分可以缓存
- nonlinear 设备每次迭代重装
- 必要时再把缓存的 linear matrix 加回当前矩阵

所以这一层不只是“转发调用”，它已经开始承担性能优化和装配策略。

### `loadDAEVectors(...)`

这个函数同样会走到：

- `deviceManager_.loadDAEVectors(...)`

如果启用了 `separateLoad`，它甚至会：

- 对 nonlinear 设备正常重装向量贡献
- 对 linear 设备通过已缓存矩阵与当前解向量做 `axpy`
- 另外专门补 source 的 `BVector`

所以这一步也说明：

```text
在 Xyce 里，vector load 和 matrix load 都不是机械的一层转发，
而是带有“按设备类型拆分”和“复用 linear 贡献”的策略层
```

## 这时再回头看第四阶段：器件到底写到了哪里

到这里，第四阶段的 resistor 就可以重新放回系统里理解。

对于普通器件，真正的写入位置还是在 device 层，例如：

- `loadDAEVectors()` 写 `Q`、`F`、`B`
- `loadDAEMatrices()` 写 `dQdx`、`dFdx`

但现在我们能更准确地说：

- 器件没有直接面对 `Linear::Solver`
- 器件也没有直接构造最终 residual / Jacobian
- 它们是在 `DeviceMgr -> CktLoader -> NonlinearEquationLoader` 这条链里，被逐层汇总和转换的

这就是第六阶段把第四阶段“扫尾升级”的地方。

## nonlinear solve 真正在哪一层触发

装配链清楚之后，接下来要看：

```text
谁真正发起 Newton 求解
```

这一层先回到分析代码。

在：

- [N_ANP_DCSweep.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)

的 `takeStep_()` 里，可以直接看到：

- `analysisManager_.getStepErrorControl().newtonConvergenceStatus = nonlinearManager_.solve();`

在：

- [N_ANP_Transient.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

里也能看到同样的调用：

- `nonlinearManager_.solve()`

所以分析层对 nonlinear solver 的调用点其实很直接：

```text
分析算法在合适的时刻调用 nonlinearManager_.solve()
```

这说明：

- `.DC`、`.TRAN` 控制“什么时候需要求解”
- `Nonlinear::Manager` 决定“用哪种 nonlinear solver”
- 具体 `rhs / jacobian / linear solve` 则是 solver 内部细节

## `Nonlinear::Manager` 在这里扮演什么角色

继续看：

- [N_NLS_Manager.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.h)
- [N_NLS_Manager.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.C)

`Manager` 的头文件注释已经说得很清楚：

```text
Xyce 和 nonlinear solver 之间的统一接口
```

这层最重要的成员是：

- `nonlinearSolver_`
- `lasSolverPtr_`
- `lasPrecPtr_`

它最重要的职责有三件：

1. 选择并持有一个具体 nonlinear solver
2. 给这个 nonlinear solver 注册 `Linear::System`、`NonlinearEquationLoader`、`DataStore` 等对象
3. 在分析层调用 `solve()` 时转发到具体 solver

其中最直白的代码就是：

- `Manager::solve()` 里直接 `return nonlinearSolver_->solve();`

这说明 `Manager` 本身不是 Newton 算法实现，而是：

```text
nonlinear solver 的管理和分发层
```

另外，`allocateTranSolver(...)` 也很值得记：

- transient 阶段可以重新分配 solver
- 例如 DCOP 和 transient 可以用不同 nonlinear solver 配置

这和第五阶段里“分析类型会切换求解状态”是对上的。

## 真正的 Newton 装配和 linear solve 在 `NonLinearSolver` 里

接着看：

- [N_NLS_NonLinearSolver.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h)
- [N_NLS_NonLinearSolver.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)

这个类是所有 nonlinear solver 算法共享的抽象基类。

对第六阶段来说，最值得抓的是四个 protected helper：

- `setX0_()`
- `rhs_()`
- `jacobian_()`
- `newton_()`

### `initializeAll()`

`initializeAll()` 会从 `Linear::System` 里拿到：

- `rhsVectorPtr_`
- `NewtonVectorPtr_`
- `jacobianMatrixPtr_`
- `lasProblemPtr_`

然后再创建或拿到：

- `Linear::Solver`

这一步非常关键，因为它说明 nonlinear solver 自己并不持有一套私有线性系统，它是从 `Linear::System` 那边注册拿来的。

### `rhs_()`

`rhs_()` 做的事情非常简单但很关键：

- 调 `nonlinearEquationLoader_->loadRHS()`

也就是说，nonlinear solver 在每次 Newton 迭代需要 residual 时，不会自己去遍历器件，而是回到上面那条装配链。

### `jacobian_()`

`jacobian_()` 同样直接：

- 调 `nonlinearEquationLoader_->loadJacobian()`

于是第六阶段的装配路径就闭环了：

```text
NonLinearSolver::jacobian_()
-> NonlinearEquationLoader::loadJacobian()
-> CktLoader::loadDAEMatrices()
-> DeviceMgr::loadDAEMatrices()
-> Device
```

### `newton_()`

这是第六阶段里“线性求解器接口在哪一层”的最直接答案。

`newton_()` 里有：

- `lasSolverRCPtr_->setNewtonIter(...)`
- `lasSolverRCPtr_->solve(false)`

所以 linear solver 的真正调用层，不在 device 层，也不在 `CktLoader` 层，而是在：

```text
NonLinearSolver::newton_()
```

这就是第六阶段第四个问题的直接答案。

## `Linear::Solver` 对外暴露的接口长什么样

最后再看：

- [N_LAS_Solver.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Solver.h)

这里的抽象非常干净：

- `Solver` 持有一个 `Problem`
- 对外最核心的方法是 `solve(bool reuse_factors = false)`
- 真正的派生类实现入口是 `doSolve(...)`

也就是说，对 nonlinear solver 来说，linear solver 这一层的接口已经被压缩成：

```text
给你 Problem
你负责把 x = A^{-1} b 算出来
```

前面的电路、器件、DAE、time integration 这些都不会直接漏到这层接口里。

这也解释了为什么第六阶段应该把“装配”和“求解”分开理解：

- 装配层负责把电路问题翻译成矩阵和向量
- 求解层只面对抽象线性问题

## 这次最重要的路径图

这次建议把第六阶段的主线记成下面这张图：

```text
分析流程
-> nonlinearManager_.solve()
-> NonLinearSolver::rhs_()
   -> NonlinearEquationLoader::loadRHS()
   -> CktLoader::updateState()
   -> CktLoader::loadDAEVectors()
   -> DeviceMgr::loadDAEVectors()
   -> Device 写 Q / F / B
   -> WorkingIntegrationMethod::obtainResidual()

-> NonLinearSolver::jacobian_()
   -> NonlinearEquationLoader::loadJacobian()
   -> CktLoader::loadDAEMatrices()
   -> DeviceMgr::loadDAEMatrices()
   -> Device 写 dQdx / dFdx
   -> WorkingIntegrationMethod::obtainJacobian()

-> NonLinearSolver::newton_()
   -> Linear::Solver::solve()
```

如果想再压缩成一句话，可以记成：

```text
device 负责写 DAE 部件，loader 负责组装，nonlinear solver 负责迭代，linear solver 负责解线性方程
```

## 这一阶段回答了哪些问题

### 1. 矩阵抽象定义在哪里

在线性代数层，主要看：

- `Linear::System`
- `Linear::Problem`
- `Linear::Solver`

### 2. 器件是直接写矩阵结构，还是通过中间抽象层

不是直接面对 solver 写最终矩阵，而是通过：

- `Device`
- `DeviceMgr`
- `CktLoader`
- `NonlinearEquationLoader`

逐层汇总。

### 3. nonlinear 求解循环在哪里组织

在 `NonLinearSolver` 这一层组织：

- `rhs_()`
- `jacobian_()`
- `newton_()`

具体什么时候触发求解，则由 `.DC` / `.TRAN` 分析流程调用 `nonlinearManager_.solve()` 决定。

### 4. linear solver 调用出现在哪一层

最直接的调用点在：

- `NonLinearSolver::newton_()`

它调用：

- `lasSolverRCPtr_->solve(...)`

## 这一阶段还不必过早深挖的东西

第六阶段先到这里就够了，先不要急着陷进去：

- `DampedNewton::solve()` 的全部细节
- `NOX` 接口的全部分支
- 具体某个 Trilinos 线性 solver 的实现
- `HB`、`PCE`、`MPDE` 这些 block / matrix-free 分支

这些都重要，但属于第六阶段之后的“纵深阅读”。

先把这次最核心的分层关系记牢，后面再往某一层往下钻会轻松很多。

## 现在可以做的自检

如果你想检查自己有没有吃下这阶段，试着回答这三个问题：

1. 为什么器件层不直接写“最终 residual / Jacobian”，而是先写 `Q`、`F`、`B`、`dQdx`、`dFdx`？
2. `NonlinearEquationLoader` 和 `CktLoader` 的职责边界分别是什么？
3. 真正调用 `Linear::Solver::solve()` 的那一层，为什么应该放在 `NonLinearSolver`，而不是 `CktLoader`？
