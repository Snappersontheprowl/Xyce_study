# hb lifecycle

记录日期：2026-06-06

## 这篇的定位

这一篇只回答：

```text
HB analysis 在分析调度层是怎么被注册、创建并跑起来的？
```

这篇故意不展开 harmonic balance 的完整数学推导，只看控制流、生命周期和它为什么需要一套比 `AC/NOISE` 更重的初始化。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)
- [src/AnalysisPKG/N_ANP_HB.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.h)
- [src/AnalysisPKG/N_ANP_HB.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.C)

## 当前结论先写在前面

从分析调度视角看，`HB` 的主线可以先压成：

```text
registerHBFactory(...)
-> AnalysisManager 选中 HB analysis object
-> HB::doRun()
-> doInit()
-> doLoopProcess()
-> doFinish()
```

但和 `AC/NOISE` 最大的不同是：

```text
HB 不是“先做 DCOP 再按频点扫一个线性系统”，
而是要先建立 HB 专用的频谱点、时域采样点、DFT/IFT 接口、
HBLoader / HBBuilder / HBLinearSystem，
最后再进入一个频域系数上的 nonlinear solve。
```

## HB 在哪里注册

先看：

- [N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)

这里会统一调用：

- `registerHBFactory(factory_block);`

再跳到：

- [N_ANP_HB.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.C)
  里的 `registerHBFactory(...)`

这里做了几件关键事：

1. 创建 `HBFactory`
2. `addAnalysisFactory(factory_block, factory);`
3. 注册 `.HB` parser：

```cpp
factory_block.optionsManager_.addCommandParser(".HB", extractHBData);
```

4. 注册一组 HB 专用 option 入口：
   - `HBINT`
   - `LINSOL-HB`
   - `LINSOL`
   - `TIMEINT`

所以从注册视角看，`HB` 的入口关系是：

```text
.HB
-> extractHBData
-> HBFactory
-> AnalysisManager 可选中的 analysis creator
```

## HBFactory 在创建什么

继续看：

- `HBFactory::create()`

这里的关键动作是：

- `analysisManager_.setAnalysisMode(ANP_MODE_HB);`
- `new HB(...)`

然后再把：

- `.HB` 本身的 analysis 参数
- `HBINT`
- `LINSOL-HB`
- `LINSOL`
- `TIMEINT`

这些配置块灌进 `HB` 对象。

这一步最值得先记住的是：

```text
HB 的分析对象不是单靠 .HB 这一行就能定下来的，
它还会额外吃进一套 HB 专用积分、线性求解、以及启动阶段参数。
```

这已经暗示了：

```text
HB 的生命周期比 AC/NOISE 更复杂
```

## HB::doRun() 的生命周期结构

再看：

- `HB::doRun()`

它表面上仍然是：

```cpp
return doInit() && doLoopProcess() && doFinish();
```

所以形式上和前面的进阶分析类型很像：

```text
doInit()
-> doLoopProcess()
-> doFinish()
```

但从 `HB` 开始，`doInit()` 的工作量明显增加了。

## HB::doInit() 为什么这么重

`HB::doInit()` 里最值得先抓住的几类动作是：

1. 先确定 HB 的频谱结构
   - `setFreqPoints_()`
   - 必要时 `mapFreqs_()`
2. 再确定与之对应的 fast-time 采样点
   - `setTimePoints_()`
3. 先准备初值
   - `setInitialGuess()`
   - 可能来自 transient-assisted HB 或 DCOP
4. 构造 HB 专用基础设施
   - `HBBuilder`
   - `HBLoader`
   - `DFT/IFT` 接口
5. 销毁前一阶段求解对象并重建 HB phase 的 solver stack
   - `analysisManager_.resetSolverSystem()`
   - `initializeSolverSystem(...)`
   - `nonlinearManager_.initializeAll(...)`

所以从生命周期角度，这里最该先记住的一句是：

```text
HB 的初始化不是“简单设置几个 sweep 参数”，
而是在真正开始求解之前，
先搭出一个专门服务于 harmonic balance 的求解环境。
```

## 为什么 HB 会先碰 transient / DCOP 初值

在 `doInit()` 以及相关 helper 里，你会看到：

- `runDCOP()`
- `runTransientIC()`
- `runStartupPeriods()`
- `interpolateIC(...)`

这说明从控制流视角看，`HB` 并不假设：

```text
一开始就已经有一个好的频域周期解初值
```

相反，它经常要先借助：

- `DCOP`
- 一段 transient
- 或 startup periods

来构造更合理的 HB 初值。

所以你可以先把这部分理解成：

```text
HB 初始化期会主动借别的分析类型来“喂初值”
```

而不是从空白频域向量硬起步。

## 为什么会有 HBBuilder / HBLoader / DFT 接口

这一步是 `HB` 和 `AC/NOISE` 在控制流上的最大分水岭之一。

在 `doInit()` 中你会看到：

- `HBBuilder`
- `HBLoader`
- `registerDFTInterface(...)`
- `permutedFFT(...)`
- `createFT_()`

从生命周期角度，这意味着：

```text
HB 不只是“在已有线性系统上改个矩阵”，
而是需要一套专门把时域量、频域量、谐波块结构组织起来的基础设施。
```

所以这一步你先不要急着下钻公式，先记住它的控制流角色：

```text
它们是在求解开始前，
把“普通电路系统”转换成“HB 可操作的块结构系统”的关键支架。
```

## 为什么 doLoopProcess() 里还会出现 DCSweep

这是 `HB` 生命周期里最容易让人困惑的一点。

看：

- `HB::doLoopProcess()`

这里你会看到它在 HB phase 真正开始时，居然又构造了一个：

- `DCSweep dc_sweep(...)`

然后：

- `analysisManager_.pushActiveAnalysis(&dc_sweep);`
- `returnValue = dc_sweep.run();`

这里最值得先抓住的理解不是“HB 其实是 DC”，而是：

```text
HB 在控制流上复用了 DCSweep 这一层现成的 nonlinear solve 外壳，
但它底下接的 loader / linear system / nonlinear mode
已经换成了 HB 专用版本。
```

也就是说：

- 外层看起来像借用了 `DCSweep::run()`
- 但实际求解对象已经不是普通 DC 电路系统

所以从生命周期视角看，这一步更像：

```text
HB 借用已有的 nonlinear loop 骨架，
来驱动一个已经切换成 HB 模式的系统
```

这正好说明：

```text
05 里看到的“外层 analysis 对象”
和 06 里要讲的“底下到底在解什么方程”
是两层不同的事
```

## 这一篇最想让你先吃下来的本质

从分析调度层看，`HB` 的身份可以先这样理解：

```text
它是一个先建立频谱/采样/DFT/HB loader 等专用环境，
再借已有 nonlinear loop 骨架去驱动 HB 方程求解的 analysis object。
```

所以这篇读完之后，最重要的不是先记住所有 `HBINT` 选项，而是先把下面这条控制流站稳：

```text
.HB
-> registerHBFactory
-> HBFactory::create
-> HB::doRun
-> doInit 里准备频谱、采样点、初值、HB loader/builder/solver
-> doLoopProcess 里把系统切到 HB phase 并进入 nonlinear solve
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `HB::doInit()` 会比 `AC` 或 `NOISE` 重很多？
2. 为什么 `HB::doLoopProcess()` 里出现 `DCSweep`，并不意味着 `HB` 退化成了普通 `DC`？
