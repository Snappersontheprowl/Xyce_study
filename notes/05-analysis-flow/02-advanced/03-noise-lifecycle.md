# noise lifecycle

记录日期：2026-06-06

## 这篇的定位

这一篇只回答：

```text
NOISE analysis 在分析调度层是怎么被注册、创建并跑起来的？
```

这篇故意不展开噪声数学对象和频域噪声公式，只看控制流和生命周期。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)
- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/AnalysisPKG/N_ANP_NOISE.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.h)
- [src/AnalysisPKG/N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)

## 当前结论先写在前面

从分析调度视角看，`NOISE` 的主线可以先压成：

```text
registerNOISEFactory(...)
-> AnalysisManager 选中 NOISE analysis object
-> NOISE::doRun()
-> doInit()
-> doLoopProcess()
-> doFinish()
```

其中最值得先记住的一点是：

```text
NOISE 不是从零开始直接做“噪声专用 nonlinear 仿真”，
而是先做一次 DC operating point，
再沿用 AC 风格的 frequency sweep 和线性系统，
最后在每个频点上计算噪声贡献。
```

## NOISE 在哪里注册

先看：

- [N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)

这里会统一调用：

- `registerNOISEFactory(factory_block);`

再跳到：

- [N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
  里的 `registerNOISEFactory(...)`

这里做了几件关键事：

1. 创建 `NOISEFactory`
2. `addAnalysisFactory(factory_block, factory);`
3. 注册 `.NOISE` parser：

```cpp
factory_block.optionsManager_.addCommandParser(".NOISE", extractNOISEData);
```

4. 注册 `TIMEINT`、`LINSOL-AC`、`DATA` 这些 NOISE 相关选项入口

所以从注册视角看，`NOISE` 的入口关系是：

```text
.NOISE
-> extractNOISEData
-> NOISEFactory
-> AnalysisManager 可选中的 analysis creator
```

## NOISEFactory 在创建什么

继续看：

- [N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
  里的 `NOISEFactory::create()`

这里和 `ACFactory` 一样，核心动作是：

- `analysisManager_.setAnalysisMode(ANP_MODE_NOISE);`
- `new NOISE(...)`

然后把：

- analysis params
- time integrator options
- `LINSOL-AC`
- `DATA`

这些配置块灌进 `NOISE` 对象。

这一步从调度角度最值得记住的是：

```text
NOISE analysis object 不是 AnalysisManager 手写 new 出来的，
而是通过注册好的 NOISEFactory 统一创建的。
```

## NOISE::doRun() 的生命周期结构

再看：

- [N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
  里的 `NOISE::doRun()`

它的结构非常直接：

```cpp
return doInit() && doLoopProcess() && doFinish();
```

所以从生命周期层面看，`NOISE` 的总体骨架和 `AC` 很像：

```text
doInit()
-> doLoopProcess()
-> doFinish()
```

但它在 `doInit()` 里做的准备，比 `AC` 多一层“噪声源管理”。

## NOISE::doInit() 在做什么

`NOISE::doInit()` 里最关键的几步是：

1. 整理 frequency sweep 或 `DATA=<name>` 参数
2. 把 `baseIntegrationMethod_` 设成：
   - `NO_TIME_INTEGRATION`
3. 先求一次 DC operating point
4. 装载 AC 用的 `B` 向量
5. 处理输出节点
6. 为后面噪声计算准备噪声源数据结构

其中最值得先抓住的是三点。

### 1. NOISE 仍然先走 DCOP

在 `doInit()` 中也会显式调用：

- `nonlinearManager_.solve();`

而且这一步同样发生在 frequency loop 之前。

这说明从调度角度看：

```text
NOISE 和 AC 一样，
都先需要一个 DC working point，
后面的频域分析都建立在这个工作点上。
```

### 2. NOISE 在控制流上也不做 time stepping

它同样把 integration method 设成：

- `NO_TIME_INTEGRATION`

这意味着：

```text
NOISE 不是 transient 那种时间步进型 analysis object，
它的主循环是 frequency sweep，不是 time stepping。
```

### 3. NOISE 在初始化期就准备噪声源容器

在构造和初始化前后，你会看到：

- `loader_.setupNoiseSources(noiseDataVec_);`

这说明从生命周期角度看，`NOISE` 不只是“另一次 AC solve”，它还会：

- 先统计有哪些 noise device
- 为每个器件准备 noise source 数据容器
- 后面在每个频点上再把这些噪声源具体填起来

所以 `NOISE` 的控制流身份可以先记成：

```text
AC 风格频域主循环
+ 器件噪声源收集与处理
```

## NOISE::doLoopProcess() 在做什么

再看：

- [N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
  里的 `NOISE::doLoopProcess()`

这里的控制流可以先压成：

```text
更新 C / G
-> 创建 AC 风格线性系统
-> setupAdjointRHS_()
-> 进入 frequency sweep loop
   -> 更新当前频点
   -> 更新 AC 线性系统
   -> solveACLinearSystem_()
   -> resetAdjointNOISELinearSystem_()
   -> solveAdjointNOISE_()
   -> 累加 total noise integrals
   -> 处理成功/失败
```

这一段最值得先抓住两点。

### 1. NOISE 的主循环本质上还是 frequency sweep

也就是说，它和 `AC` 一样，也是：

```text
按频点循环
```

而不是：

- 按时间步循环
- 按 Newton 外层再嵌一层大 nonlinear solve

### 2. 每个频点上会做两类线性动作

从控制流角度看，每个频点上至少有两步值得先记：

1. `solveACLinearSystem_()`
   - 先得到这个频点下的 AC 小信号响应
2. `solveAdjointNOISE_()`
   - 再在这个频点上做噪声相关的 adjoint solve

所以从生命周期上，`NOISE` 比 `AC` 多出来的关键一层是：

```text
在 AC 小信号解之外，
还要额外做噪声源到输出端的噪声响应计算。
```

## 这一篇最想让你先吃下来的本质

从分析调度层看，`NOISE` 的身份可以先这样理解：

```text
它是一个“先做 DCOP，再做 frequency sweep，
并在每个频点上叠加噪声源计算”的 analysis object
```

所以这篇读完之后，最重要的不是记住所有 `NOISE` 成员，而是先把下面这条控制流站稳：

```text
.NOISE
-> registerNOISEFactory
-> NOISEFactory::create
-> NOISE::doRun
-> doInit 里先做 DCOP
-> doLoopProcess 里先做 AC 风格频点循环
-> 再在每个频点上做噪声源处理和 adjoint solve
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `NOISE` 在生命周期上更像“AC 的扩展”，而不是“另一种 transient”？
2. 为什么 `NOISE::doLoopProcess()` 里既会出现普通 AC 线性求解，又会出现额外的 adjoint noise solve？
