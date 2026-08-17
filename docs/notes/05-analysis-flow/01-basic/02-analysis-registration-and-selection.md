# analysis registration and selection

记录日期：2026-06-04

## 这篇的定位

这一篇只回答：

```text
.OP / .DC / .TRAN 在分析层面是怎么被注册、识别和挑选出来的？
```

这篇仍然不讨论方程数学，只讲分析对象的选择逻辑。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)
- [src/AnalysisPKG/N_ANP_AnalysisManager.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h)
- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/AnalysisPKG/N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
- [src/AnalysisPKG/N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

## 当前结论先写在前面

从当前源码看，分析对象不是写死在 `AnalysisManager` 里的，而是通过：

```text
registerAnalysisFactory(...)
-> creator / factory registry
-> allocateAnalysisObject(...)
```

这条路线接进来的。

其中最值得先记住的是：

- `.TRAN` 最终对应 `Transient`
- `.DC` 最终对应 `DCSweep`
- `.OP` 不是一个完全独立的主分析类，而更像“请求做 DC operating point”的一个开关

## 分析类型在哪里注册

先看：

- [N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)

这个文件里会统一注册各种 analysis factory，比如：

- `registerDCSweepFactory(...)`
- `registerACFactory(...)`
- `registerTransientFactory(...)`
- `registerHBFactory(...)`
- `registerMPDEFactory(...)`
- `registerNOISEFactory(...)`

所以分析层的第一层架构不是：

```text
AnalysisManager 手写 if/else 直接 new 某个分析类
```

而是：

```text
先注册分析工厂
-> 再由 AnalysisManager 选择当前要用哪个 creator
```

## `.DC` 和 `.TRAN` 的注册入口

### `.DC` / `.OP`

看：

- [N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
  里的 `registerDCSweepFactory(...)`

这里会把：

- `.DC` 挂到 `extractDCData`
- `.OP` 挂到 `extractOPData`

这个事实很重要，因为它说明：

```text
.DC 和 .OP 在注册层面本来就靠得很近
```

### `.TRAN`

看：

- [N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)
  里的 `registerTransientFactory(...)`

这里会把：

- `.TRAN`
- `.TR`

都挂到 `extractTRANData`

所以 `.TRAN` 的入口关系比较直接：

```text
.TRAN
-> TransientFactory
-> Transient analysis object
```

## allocateAnalysisObject() 在做什么

继续看：

- [N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
  里的 `allocateAnalysisObject(...)`

这是分析层最关键的选择函数之一。

它大致做三件事。

### 1. 处理只有 `.OP` 的特殊情况

如果：

- 有 `.OP`
- 但没有别的主分析

那么它会借用 `DCSweep` 作为 `primaryAnalysisObject_`。

这也再次说明：

```text
.OP 更像 operating point 请求
而不是一个完全独立的主分析类
```

### 2. 选出真正的 primary analysis

接着它会从 creator 列表里找出真正的主分析对象，例如：

- `DCSweep`
- `Transient`
- `AC`
- `HB`
- `MPDE`
- `NOISE`

### 3. 处理外层包装分析

像：

- `Step`
- `Sampling`
- `EmbeddedSampling`

这些更像外层驱动器。

所以要区分两个成员：

- `primaryAnalysisObject_`
- `analysisObject_`

可以先这样理解：

```text
primaryAnalysisObject_ = 真正干活的底层分析
analysisObject_        = 最终被 run() 调用的顶层对象，可能是包装器
```

## 这一篇的边界

这一篇只把“选择逻辑”讲清楚，不继续往下走到：

- `DCSweep::doRun()`
- `Transient::doRun()`

因为那已经属于分析生命周期本身，要放到下一篇。

而关于：

- `DC` 在数学上解什么
- `transient` 每步在解什么

这些则属于 [06-solver-and-assembly](../../06-solver-and-assembly/README.md)。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `.OP` 在 Xyce 里更像“请求做 operating point”，而不是一个完全独立的主分析类？
2. `primaryAnalysisObject_` 和 `analysisObject_` 的差别，本质上是不是“底层真实分析”和“顶层运行包装器”的差别？
