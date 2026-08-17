# analysis manager common infrastructure

记录日期：2026-06-04

## 这篇的定位

这一篇只回答：

```text
AnalysisManager 在进入具体分析之前，
会统一准备哪些基础设施？
```

这篇很重要，因为它正好是 `05` 和 `06` 的边界层。

- 在 `05` 里，我们只看到“什么时候创建这些对象”
- 到 `06` 里，才继续看“这些对象怎样参与方程装配和求解”

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_AnalysisManager.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h)
- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)

## 当前结论先写在前面

`AnalysisManager` 不只是挑一个分析对象出来，它还会在运行前统一准备几类公共基础设施：

- `DataStore`
- `WorkingIntegrationMethod`
- `StepErrorControl`
- `NonlinearEquationLoader`

这一层最该先记住的不是“对象内部细节”，而是：

```text
这些对象是在分析层被创建出来，
然后交给后面的装配层和求解层使用。
```

## initializeSolverSystem() 在做什么

最关键的函数是：

- [N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
  里的 `initializeSolverSystem(...)`

从当前学习阶段看，它最值得先记住的是“创建时机”和“角色边界”。

也就是：

```text
在真正进入 DC / transient 主循环前，
AnalysisManager 会先把求解系统需要的公共对象准备好
```

## 1. DataStore

`DataStore` 可以先理解成：

```text
分析和求解过程中共享的状态容器
```

这里会承载：

- solution / state / store 向量
- DAE 向量与矩阵相关对象
- 时间推进和 nonlinear solve 共享的运行数据

这篇先不继续展开 `DataStore` 里具体有哪些 `dae*Vector`，因为那已经进入 `06` 的装配专题。

## 2. WorkingIntegrationMethod

它可以先理解成：

```text
当前分析使用的 time integration 工作对象
```

关键点是：

- `Transient` 会真正依赖它来做时间离散
- `DC` 虽然没有时间推进，但仍然通过统一框架走 `NO_TIME_INTEGRATION`

所以在 `05` 里你只需要先记住：

```text
AnalysisManager 负责把“当前分析使用哪一种 integration method”这件事组织起来
```

## 3. StepErrorControl

它是分析层和瞬态时间推进之间的一个关键桥梁。

先从角色上理解就够了：

- 管 breakpoints
- 管 next time / stop time / final time
- 管时间步相关控制信息

但关于：

- 步长调整
- accept / reject
- 重试逻辑

这些细节都应该放到 `06` 后续深化，而不是在 `05` 里展开。

## 4. NonlinearEquationLoader

这一层很容易一不小心就讲到装配数学里去，所以这里要故意压住边界。

在 `05` 里，我们只把它理解成：

```text
分析层为后续 nonlinear residual / Jacobian 装配准备的桥接对象
```

也就是说：

- 它在分析层被创建和接线
- 但它真正怎样把 `Q/F/B/dQdx/dFdx` 组织成求解器对象，要到 `06` 再讲

## 这一篇最想让你先吃下来的本质

`AnalysisManager` 和 `06-solver-and-assembly` 的边界，最适合画在这里：

```text
05 负责回答：这些公共对象什么时候创建、由谁持有、服务哪类分析
06 负责回答：这些对象内部到底怎样形成 residual / Jacobian / time-discretized equation
```

只要这条边界立住，`05` 和 `06` 就不会再显得互相侵入。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `NonlinearEquationLoader` 同时出现在 `05` 和 `06`，但并不算真正的重复？
2. `StepErrorControl` 在 `05` 里为什么只讲“谁创建、服务谁”，而不马上讲“步长怎么调”？
