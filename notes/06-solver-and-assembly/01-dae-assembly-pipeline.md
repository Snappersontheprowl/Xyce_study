# dae assembly pipeline

记录日期：2026-06-03

## 这次读了哪些文件

这次只盯“DAE 是怎么被装出来的”，按从上到下的装配顺序读了这些文件：

- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/LinearAlgebraServicesPKG/N_LAS_System.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_System.h)
- [src/LinearAlgebraServicesPKG/N_LAS_Problem.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Problem.h)
- [src/LoaderServicesPKG/N_LOA_Loader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_Loader.h)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.h)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)
- [src/LoaderServicesPKG/N_LOA_CktLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_CktLoader.C)

## 这次带着什么问题去读

这篇不讨论 Newton 细节，只回答：

- device 到底写的是什么量？
- 这些量是怎么被收集起来的？
- 哪一层把它们放进 `DataStore` 和矩阵/向量容器？
- 哪一层负责把“电路物理量”翻译成“DAE 组成部分”？

## 当前结论先写在前面

对于 Xyce 当前这条主线，更准确的说法不是：

```text
device 直接写 residual 和 Jacobian
```

而是：

```text
device 写 DAE 组成部分
-> DeviceMgr 汇总
-> CktLoader 收集
-> NonlinearEquationLoader 组织
-> WorkingIntegrationMethod 再组合成 residual / Jacobian
```

所以 device 层首先写的是：

- `Q`
- `F`
- `B`
- `dQdx`
- `dFdx`

这就是这篇笔记最核心的认识。

## 先从分析层往下看：谁把装配所需对象准备好

第五阶段已经看到，分析流程在真正调用 nonlinear solve 之前，会先准备公共基础设施。

这一步最关键的函数还是：

- [N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
  中的 `AnalysisManager::initializeSolverSystem(...)`

这里和装配最直接相关的对象有：

1. `TimeIntg::DataStore`
2. `TimeIntg::WorkingIntegrationMethod`
3. `Loader::NonlinearEquationLoader`

这一步的本质是：

```text
先准备一个能承载“本轮 DAE 装配结果”的上下文
```

其中：

- `DataStore` 持有解向量、状态向量、DAE 向量、DAE 矩阵
- `NonlinearEquationLoader` 是 nonlinear solver 与装配层之间的桥

## 矩阵与向量的容器层在哪里

继续看：

- [N_LAS_System.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_System.h)

`Linear::System` 可以先当成：

```text
线性系统对象容器
```

它持有：

- `jacobianMatrixPtr_`
- `rhsVectorPtr_`
- `newtonVectorPtr_`
- `lasProblemPtr_`
- `dFdxdVpVectorPtr_`
- `dQdxdVpVectorPtr_`

而：

- [N_LAS_Problem.h](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_Problem.h)

把 `A`、`x`、`b` 打包成一个求解问题对象。

这一层先不用把它理解成“求解算法”，而要理解成：

```text
给后续装配和求解准备标准容器
```

## 为什么中间要插一个 `Loader` 抽象层

要理解装配专题，最好先看：

- [N_LOA_Loader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_Loader.h)

这个头文件的注释已经把架构目的写得很清楚：

- `Nonlinear Equation loader` 负责隔离 nonlinear solver 和 time integration
- `CktLoader` 负责隔离 time integration 和 device package

也就是说，Xyce 不希望 nonlinear solver 直接面对 device。

所以主链变成：

```text
NonlinearSolver
-> NonlinearEquationLoader
-> CktLoader
-> DeviceMgr
-> Device
```

这一步的工程意义是：

- solver 不必知道“这是电路器件”
- time integrator 不必知道每个 device 的物理细节
- device 不必知道外面的 Newton / linear solve 细节

## `NonlinearEquationLoader` 在装配专题里负责什么

接着看：

- [N_LOA_NonlinearEquationLoader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.h)
- [N_LOA_NonlinearEquationLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)

在这个专题里，它最重要的作用不是“求解”，而是：

```text
把 DAE 组成部分从 loader 层拿上来，并组织到 DataStore 中
```

### `loadRHS()` 里做了什么

`loadRHS()` 的主顺序是：

1. 清零 `daeQVectorPtr`、`daeFVectorPtr`、`daeBVectorPtr`
2. 调 `loader_.updateState(...)`
3. 调 `loader_.loadDAEVectors(...)`
4. 最后交给 `WorkingIntegrationMethod::obtainResidual()`

如果只从“装配”角度看，前 3 步最重要：

- `updateState(...)` 让 device 先更新状态
- `loadDAEVectors(...)` 让 device 把 `Q`、`F`、`B` 这些量写出来

也就是说，在 residual 被真正组合之前，`DataStore` 里先出现的是：

- `daeQ`
- `daeF`
- `daeB`

### `loadJacobian()` 里做了什么

`loadJacobian()` 的顺序和上面对应：

1. 清零 `dQdxMatrixPtr`、`dFdxMatrixPtr`
2. 调 `loader_.loadDAEMatrices(...)`
3. 最后交给 `WorkingIntegrationMethod::obtainJacobian()`

所以从装配角度看，这一步真正被 device 写出的不是“最终 Jacobian”，而是：

- `dQdx`
- `dFdx`

## 再往下一层：`CktLoader` 负责把 circuit/device 贡献收上来

这一层最关键的文件是：

- [N_LOA_CktLoader.C](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_CktLoader.C)

它最重要的两个接口是：

- `CktLoader::loadDAEVectors(...)`
- `CktLoader::loadDAEMatrices(...)`

这两个函数的职责可以先压缩成一句话：

```text
把 device package 的贡献真正装到 DAE 向量 / 矩阵里
```

### `loadDAEVectors(...)`

这个函数最终会走到：

- `deviceManager_.loadDAEVectors(...)`

也就是：

```text
DeviceMgr
-> 各个 device
-> 把 Q / F / B 写进对应向量
```

但 `CktLoader` 自己也不只是一个纯转发层，它还会处理：

- overlap import
- `LINEAR` / `NONLINEAR` / `ALL` / `PDE` 这些 loadType
- `separateLoad` 模式下对 linear 设备的复用策略

### `loadDAEMatrices(...)`

这个函数最终也会走到：

- `deviceManager_.loadDAEMatrices(...)`

也就是：

```text
DeviceMgr
-> 各个 device
-> 把 dQdx / dFdx 写进对应矩阵
```

这一层同样会处理：

- linear / nonlinear 分离装配
- linear matrix 缓存
- 必要时把缓存矩阵再加回当前矩阵

所以 `CktLoader` 这一层的关键词不是“数学”，而是：

- 汇总
- 转发
- 负责编排装配策略
- 做性能优化

## 这时再回头看第四阶段：resistor 到底写到了哪里

把第四阶段的 resistor 放回这条链里，现在可以更准确地说：

- resistor 不直接面对 `Linear::Solver`
- resistor 也不直接构造最终 residual / Jacobian
- resistor 先在 device 层写：
  - `Q`、`F`、`B`
  - `dQdx`、`dFdx`
- 然后这些量经过：
  - `DeviceMgr`
  - `CktLoader`
  - `NonlinearEquationLoader`

逐层汇总到 `DataStore`

这一步是“电路方程建立”的关键，而不是“数学求解”本身。

## 这一篇最重要的路径图

这一篇建议只记下面这张“装配图”：

```text
AnalysisManager::initializeSolverSystem()
-> DataStore + NonlinearEquationLoader

NonlinearEquationLoader::loadRHS()
-> loader_.updateState()
-> CktLoader::loadDAEVectors()
-> DeviceMgr::loadDAEVectors()
-> Device 写 Q / F / B

NonlinearEquationLoader::loadJacobian()
-> CktLoader::loadDAEMatrices()
-> DeviceMgr::loadDAEMatrices()
-> Device 写 dQdx / dFdx
```

如果想再压缩一句话：

```text
device 负责写 DAE 部件，loader 负责把这些部件汇总进统一的数据结构
```

## 这一篇先不展开什么

为了保持这个专题干净，这里先不展开：

- `f(x)=0` 的数学求解流程
- `NonLinearSolver::newton_()`
- `Linear::Solver::solve()`
- `DampedNewton` / `NOX` 的具体迭代逻辑

这些全部放到下一篇。

## 现在可以做的自检

你可以先试着回答这三个问题：

1. 为什么 device 先写的是 `Q`、`F`、`B`、`dQdx`、`dFdx`，而不是最终 residual / Jacobian？
2. `NonlinearEquationLoader` 和 `CktLoader` 都叫 loader，但它们各自隔离的是哪两层？
3. `CktLoader` 在装配专题里，为什么不能简单理解成“只是转发一下 `DeviceMgr`”？
