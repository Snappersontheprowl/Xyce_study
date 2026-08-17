# hb time frequency lifecycle hook

记录日期：2026-06-06

## 这篇的定位

这一篇不是去重复讲 `HB` 的时频数学桥。  
那部分已经放在：

- [../../06-solver-and-assembly/02-advanced/06-hb-time-frequency-bridge.md](../../06-solver-and-assembly/02-advanced/06-hb-time-frequency-bridge.md)

这一篇只回答：

```text
从分析调度和生命周期视角看，
HB 的时频桥是在 doInit() 的哪几个阶段被挂进去的？
```

也就是说，我们只看：

- 为什么先定频谱和采样点
- 为什么先喂初值
- 为什么随后才创建 `HBBuilder / HBLoader / DFT`
- 为什么最后还要 `resetSolverSystem()`

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_HB.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.C)
- [05-hb-lifecycle.md](05-hb-lifecycle.md)

## 当前结论先写在前面

从生命周期视角看，`HB` 里的时频桥主线可以先压成：

```text
HB::doInit()
-> setFreqPoints_()
-> setTimePoints_()
-> setInitialGuess()
-> 创建 HBBuilder
-> 创建 HBLoader
-> registerDFTInterface(...)
-> 先把初值块做一次 permutedFFT(...)
-> resetSolverSystem()
-> initializeSolverSystem(..., hbLoader, hbLinearSystem, ...)
```

最值得先记住的一点是：

```text
HB 的时频桥不是求解过程中“临时插进去”的，
而是在 HB phase 真正开始前，
就先作为一整套专用执行环境被搭起来。
```

## 第一步：为什么先定频谱，再定 fast-time 采样点

看：

- `setFreqPoints_()`
- `setTimePoints_()`

它们都发生在 `doInit()` 的前半段。

这个顺序很重要，因为从生命周期角度看：

```text
HB 先要知道“我要保留哪些谐波分量”，
才能反过来决定“一个周期里要在哪些 fast-time 点上采样”。
```

也就是说，这里并不是：

- 先随便给一组时域点
- 后面再想办法往频域凑

而是：

```text
先确定频域问题的规模和结构，
再为它配套时域采样点。
```

所以这一步最值得先记成：

```text
频谱结构是时频桥的上游输入
```

## 第二步：为什么先喂初值，再创建 HB phase 求解环境

接下来在 `doInit()` 里会看到：

- `setInitialGuess()`
- 里面可能走：
  - `runStartupPeriods()`
  - `runTransientIC()`
  - `runDCOP()`

这一步的位置非常关键。

它说明从生命周期角度看：

```text
HB 先要把“初始周期解猜测”准备好，
然后才值得把整套 HB phase 求解环境正式搭起来。
```

原因很实际：

- `HBBuilder / HBLoader / HBLinearSystem` 这套环境更重
- 如果初值都还没准备好，后面那套环境还没有真正的工作对象

所以这一步最值得先抓住的是：

```text
初值准备仍然属于“进入 HB phase 之前”的准备动作
```

而不是求解过程中顺手补上的小步骤。

## 第三步：为什么 HBBuilder / HBLoader / DFT 要在这里一起出现

在 `doInit()` 中，紧接着你会看到：

- `hbBuilderPtr_ = rcp(new Linear::HBBuilder(...))`
- `hbLoaderPtr_ = new Loader::HBLoader(...)`
- `hbLoaderPtr_->registerHBBuilder(...)`
- `hbLoaderPtr_->registerDFTInterface(...)`

这一组动作从生命周期角度最值得先理解成：

```text
现在系统开始从“普通电路求解环境”
切换成“HB 专用求解环境”
```

这里之所以要打包一起出现，是因为它们彼此依赖：

- `HBBuilder`
  - 定义 HB 用的 block map / block vector 结构
- `HBLoader`
  - 定义怎样在时域样本和频域块之间搬运与装配
- `DFT/IFT`
  - 定义两者之间的变换规则

所以这一步不能拆得太散。  
从控制流上更自然的理解就是：

```text
这三者共同组成了 HB phase 的“执行骨架”
```

## 第四步：为什么初值块要先做一次 permutedFFT

在 `doInit()` 里，你会看到：

- `hbLoaderPtr_->permutedFFT(*HBICVectorPtr_, &*HBICVectorFreqPtr_);`

这一步的位置也很有意思。

因为它说明：

```text
即使初值最初是按时域样本块准备出来的，
在真正进入 HB phase 之前，
也要先把它翻译成频域谐波系数形式。
```

从生命周期角度看，这一步相当于：

```text
把“初值准备阶段的时域对象”
交接成“HB 求解阶段真正使用的频域对象”
```

所以它非常适合作为 `05` 里的一个单独 hook 来记。

## 第五步：为什么后面还要 resetSolverSystem()

再往后看，你会看到：

- `analysisManager_.resetSolverSystem();`

然后接着：

- `initializeSolverSystem(..., *hbLoaderPtr_, *hbLinearSystem_, ...)`

这一步非常关键，因为它说明：

```text
HB 不是在原来的普通电路 solver system 上“加点参数继续跑”，
而是明确地切断前一阶段求解环境，
再换上一套 HB phase 专用 loader / linear system / solver stack。
```

也就是说：

- 前面那套环境更偏 DCOP / transient-assisted initialization
- 这里开始才是真正的 HB phase

从生命周期角度，这是一个很清晰的阶段边界：

```text
初值准备阶段
-> reset
-> HB 求解阶段
```

## 第六步：initializeSolverSystem(..., hbLoader, hbLinearSystem, ...) 为什么是关键钩子

看：

- `initializeSolverSystem(TimeIntg::TIAParams(), *hbLoaderPtr_, *hbLinearSystem_, nonlinearManager_, deviceManager_);`

这一步是 `05` 里最值得和 `06` 对上的位置之一。

因为从控制流角度，它意味着：

```text
从这里开始，
AnalysisManager / NonlinearManager 真正接管的对象，
已经不是普通 loader 和普通 linear system，
而是 HB 专用版本。
```

所以你可以先把这一步理解成：

```text
HB 时频桥从“准备就绪”
变成“正式接入求解器主循环”
```

这和 `06` 里讲的：

- `HBLoader::permutedIFT(...)`
- `HBLoader::loadDAEVectors(...)`
- `HBLoader::permutedFFT(...)`

正好是一对：

- `05` 讲它什么时候被接进来
- `06` 讲它接进来之后到底做什么

## 第七步：为什么这篇应该放在 05，而不是继续塞进 06

因为这篇的主问题不是：

- 频域残差数学上怎么来
- `permutedIFT` 算子怎么定义
- `dQ/dt` 为什么会变成 `jω`

而是：

```text
这些对象和桥梁，为什么要在 doInit() 里按现在这个顺序搭起来？
```

这显然更偏：

- 阶段切换
- 生命周期
- 执行环境构建

所以它更属于 `05-analysis-flow` 的边界，而不是 `06-solver-and-assembly`。

## 这一篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
从生命周期视角看，
HB 的时频桥不是求解时临时插入的一段技巧，
而是在 doInit() 中被成体系地搭好，
然后通过 resetSolverSystem + initializeSolverSystem
整体切进 HB phase 的。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `HB` 里要先有 `setFreqPoints_ / setTimePoints_ / setInitialGuess()`，然后才值得创建 `HBBuilder / HBLoader / DFT`？
2. 为什么 `analysisManager_.resetSolverSystem()` 在 `HB` 里意味着“从初值准备阶段正式切换到 HB 求解阶段”？
