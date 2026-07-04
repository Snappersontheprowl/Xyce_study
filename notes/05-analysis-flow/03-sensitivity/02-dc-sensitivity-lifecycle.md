# dc sensitivity lifecycle

记录日期：2026-07-04

## 这篇的定位

这一篇只看 `DC sensitivity` 在工程代码里的挂接位置。

不展开底层方程推导，只回答：

```text
在 Xyce 里，
DC 灵敏度是在什么时候被打开的，
又是在每个 DC sweep 步的哪个阶段真正计算的？
```

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)

## 当前结论先写在前面

`DC sensitivity` 的代码生命周期非常短，基本就是两步：

```text
setup 阶段先 enableSensitivity(...)
每个成功的 DC 工作点后再 calcSensitivity(...)
```

所以从工程实现上，它最像：

```text
附着在每个 DC operating point 上的一次追加求解
```

## 第一步：先看 setup 阶段

最先该看的位置是：

- [N_ANP_DCSweep.C:249](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C#L249)

这里的 `DCSweep::finalExpressionBasedSetup()` 做了一件很关键但很克制的事：

```cpp
nonlinearManager_.enableSensitivity(...)
```

也就是说，`DC sensitivity` 在 `DCSweep` 这一层并没有自己重新创建一套 solver，而是：

1. 检查 `sensFlag_`
2. 如果本次仿真请求了灵敏度
3. 就把 sensitivity 基础设施挂到 `nonlinearManager_` 上

所以第一层理解应该是：

```text
DCSweep 自己不做灵敏度数学，
它只负责在正确的时机把 sensitivity 能力打开。
```

## 第二步：再看 DC 主循环

接着顺着同一个文件往下看：

- [N_ANP_DCSweep.C:396](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C#L396)

`DCSweep::doLoopProcess()` 是 DC sweep 的主循环。

它的逻辑顺序很清楚：

1. 更新 sweep 参数
2. 调 `takeStep_()` 求当前这个 DC 工作点
3. 判断这一步成功还是失败
4. 成功就进 `doProcessSuccessfulStep()`

所以如果你在跟灵敏度，当前最重要的不是去跳到很多别的文件，而是先抓住：

```text
DC sensitivity 不会在 takeStep_ 之前发生，
而是挂在“成功得到一个 DC 工作点之后”的处理阶段。
```

## 第三步：真正的 sensitivity solve 发生在成功步之后

继续顺着同一个文件看：

- [N_ANP_DCSweep.C:463](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C#L463)

在 `DCSweep::doProcessSuccessfulStep()` 里，你会看到：

```cpp
if (sensFlag_ && !firstDoubleDCOPStep())
{
  nonlinearManager_.calcSensitivity(...);
}
```

这句基本就把 `DC sensitivity` 的生命周期说完了：

```text
一个 DC 工作点先被主非线性求解器求出来
-> 如果成功
-> 再调用 nonlinearManager_.calcSensitivity(...)
```

所以这里不是：

```text
灵敏度和 DC 主求解完全混在一起
```

而更像：

```text
主 DC 求解成功后，
在该工作点上追加一次 sensitivity 计算
```

## 第四步：为什么它挂在成功步之后很自然

因为 `DC sensitivity` 的数学前提就是：

```text
必须先有名义工作点 x*
```

如果工作点还没求出来，后面的 Jacobian、右端项、输出映射都没有稳定依托。

所以在工程上，把它放在 `doProcessSuccessfulStep()` 里非常自然：

- 先确认这一步 `DCOP` 成功
- 再基于这个成功工作点做 sensitivity

这也解释了为什么失败步里没有 sensitivity 计算。

## 第五步：`double DCOP` 为什么要单独绕开第一步

代码里有：

```cpp
!firstDoubleDCOPStep()
```

这说明对某些 PDE / 特殊场景，Xyce 会有一个“双阶段 DCOP”的流程。

从学习角度，你现在不必先深挖 `double DCOP` 的所有细节，只要先抓住一点：

```text
并不是所有“看起来像 DCOP 的中间步”都适合作为最终灵敏度工作点；
代码在这里显式避免在第一个过渡 DCOP 上做 sensitivity。
```

这说明 sensitivity 是挂在“有效工作点”上的，而不是挂在任何中间过渡状态上。

## 第六步：这一条线先读到哪里就够了

当前阶段，我建议你在 `DC sensitivity` 这条工程线里先停在：

- `enableSensitivity(...)`
- `calcSensitivity(...)`

也就是：

```text
DCSweep 负责什么时候开启 sensitivity，
什么时候在成功步后触发 sensitivity solve
```

再往下如果继续追，就会进入 `nonlinearManager_` 和更底层的 sensitivity loader / solver 细节。

那属于下一层深入，不属于这一篇的第一目标。

## 当前这一篇学完后，应该记住什么

1. `DC sensitivity` 的工程入口只沿着一个文件就能看清：`N_ANP_DCSweep.C`。
2. 它在 `finalExpressionBasedSetup()` 里先 `enableSensitivity(...)`。
3. 它在 `doProcessSuccessfulStep()` 里对每个成功 DC 工作点调用 `calcSensitivity(...)`。
4. 所以它在生命周期上是“附着在 DC 工作点之后的追加求解”，不是独立主分析。
