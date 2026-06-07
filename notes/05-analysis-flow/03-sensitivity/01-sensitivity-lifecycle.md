# sensitivity lifecycle

记录日期：2026-06-07

## 这篇的定位

这一篇只回答：

```text
灵敏度分析在 Xyce 里是怎么挂到现有分析上的？
它为什么不像 HB / MPDE 那样是一个完全独立的 analysis object？
```

这一篇故意不展开 direct / adjoint 的完整数学推导，只看：

- `.SENS` / `SENSITIVITY` 在调度层如何进入系统
- 它和 `DC / AC / Transient` 的关系
- 为什么它更像“附着在主分析上的能力层”
- `AC` 和 `Transient` 在生命周期上分别怎样接入灵敏度求解

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/AnalysisPKG/N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
- [src/AnalysisPKG/N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
- [src/AnalysisPKG/N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

## 当前结论先写在前面

从分析调度视角看，灵敏度分析最适合先理解成：

```text
.SENS 不是单独创建一个全新的主分析对象，
而是打开一个 sensitivity flag，
再把 direct / adjoint 求解挂到 DC / AC / Transient 这些主分析的生命周期里。
```

换句话说：

```text
灵敏度分析更像“analysis capability layer”，
不是一个像 HB / MPDE 那样自成体系的大 analysis class。
```

## 第一步：全局 `.SENS` 先把 sensFlag_ 打开

先看：

- [N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)

在 `registerPkgOptionsMgr(...)` 里，`AnalysisManager` 会注册：

```cpp
options_manager.addCommandProcessor("SENS",
  IO::createRegistrationOptions(analysis_manager, &AnalysisManager::setSensOptions));
```

再看：

- `AnalysisManager::setSensOptions(...)`

它做的事情非常朴素：

```cpp
sensFlag_ = true;
```

这一步非常关键，因为它说明：

```text
.SENS` 这一层首先不是“创建一个 sensitivity analysis object”，
而是先把“本次仿真带灵敏度需求”这个全局开关打开。
```

所以从生命周期视角，灵敏度分析的第一层入口更像：

```text
一个全局模式开关
```

而不是：

```text
新的主分析类型
```

## 第二步：为什么 AC / Transient 还会单独注册 `SENSITIVITY`

虽然 `.SENS` 先把 `sensFlag_` 打开，但还不够。

再看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
- [N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

这两个 factory 都会继续注册：

- `SENS`
- `SENSITIVITY`

也就是说：

- `.SENS` 本身负责：
  - 目标函数
  - 参数列表
  - 基本灵敏度请求
- `.options sensitivity` 这一层负责：
  - `DIRECT`
  - `ADJOINT`
  - `FORCEFD`
  - `FORCEANALYTIC`
  - 以及 transient adjoint 的额外时间范围设置

这说明从调度层来看，灵敏度分析的配置分两层：

```text
全局请求层：我要做 sensitivity
分析专用策略层：在 AC / Transient 里具体怎么做
```

## 第三步：DC 里灵敏度是怎样挂进去的

最简单的挂法先看 `DCSweep`。

在：

- [N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)

里，`DCSweep::finalExpressionBasedSetup()` 会在 `sensFlag_` 为真时调用：

```cpp
nonlinearManager_.enableSensitivity(...)
```

也就是说：

```text
先在 DC 分析初始化阶段把敏感度基础设施打开
```

然后在每个成功步之后，又会调用：

```cpp
nonlinearManager_.calcSensitivity(...)
```

这说明对 `DC` 来说，灵敏度分析在生命周期上非常自然：

```text
每求完一个 operating point
-> 就在这个工作点上追加 sensitivity 计算
```

所以 `DC` 这里的灵敏度，更像是：

```text
附着在 operating point / sweep 步上的后处理求解动作
```

## 第四步：AC 里灵敏度是怎样挂进去的

再看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)

这里的控制流更清楚一点。

### 1. 参数和目标先在前期读进来

- `AC::setSensAnalysisParams(...)`
- `AC::setSensitivityOptions(...)`

这两步分别处理：

- 想对哪些参数求灵敏度
- 想观察哪些目标函数
- 走 `DIRECT` 还是 `ADJOINT`

### 2. analysis object 创建时把这些配置灌进去

在 `ACFactory::create()` 里，会做：

- `ac->setSensAnalysisParams(...)`
- `ac->setSensitivityOptions(...)`

所以在 `AC` 里，灵敏度不是后面临时插进去的，而是在 analysis object 创建时就已经一起挂好了。

### 3. 真正的 sensitivity solve 挂在 AC 主循环后段

在 `AC` 正常求完某个频点的主系统之后，会调用：

- `solveSensitivity_()`

然后再根据配置继续分成：

- `solveDirectSensitivity_()`
- `solveAdjointSensitivity_()`

所以从生命周期角度最值得先记住的一句是：

```text
AC sensitivity 不是另起一个 analysis，
而是在“每个频点的小信号主系统求解完成之后”
追加 direct / adjoint 灵敏度求解。
```

## 第五步：Transient 里灵敏度为什么更复杂

再看：

- [N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

`Transient` 里最值得先抓住的是：  
它同时支持：

- direct sensitivity
- transient adjoint sensitivity

而且后者明显更重。

### 1. 前期配置更复杂

在：

- `Transient::setSensitivityOptions(...)`

你会看到比 `AC` 更多的选项：

- `ADJOINTBEGINTIME`
- `ADJOINTFINALTIME`
- `ADJOINTTIMEPOINTS`
- `FULLADJOINTTIMERANGE`
- `SPARSESTORAGE`

这已经说明：

```text
transient adjoint sensitivity 不是“某一步顺手解一下”，
而是一个带时间区间、历史存储、反向时间积分的完整附加流程。
```

### 2. 先在 forward transient 里积累信息

在：

- `Transient::finalExpressionBasedSetup()`

会先 `enableSensitivity(...)`。

后续在正常 transient 跑的过程中，会调用：

- `saveTransientAdjointSensitivityInfo()`
- `saveTransientAdjointSensitivityInfoDCOP()`

也就是说，forward solve 阶段就已经开始存后面 adjoint 需要的历史信息。

### 3. 真正的 adjoint 阶段发生在 forward transient 之后

再看：

- `Transient::doTransientAdjointSensitivity()`

这里会：

- 选定感兴趣的时间点
- 对每个输出时刻做一轮 backward integration
- 调 `initializeAdjoint(...)`
- `updateAdjointCoeffs()`
- `calcTransientAdjoint(...)`

所以从生命周期角度最值得先记住的一句是：

```text
Transient adjoint sensitivity 不是在每个 forward step 顺手完成的，
而是“先做完整正向 transient，再做一轮或多轮反向时间积分”的附加分析阶段。
```

## 当前这篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
灵敏度分析在 Xyce 里更像“挂在主分析上的能力层”：
DC 在每个工作点后追加 sensitivity，
AC 在每个频点主系统后追加 direct / adjoint，
Transient 则在正向时间推进后再追加更重的反向 adjoint 阶段。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `.SENS` 在调度层首先更像“打开 sensFlag_ 的全局请求”，而不是立刻创建一个全新的主 analysis object？
2. 为什么 `Transient` 的 adjoint sensitivity 生命周期会比 `AC` 的 sensitivity 明显更重？
