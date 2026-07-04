# transient sensitivity lifecycle

记录日期：2026-07-04

## 这篇的定位

这一篇只看 `Transient sensitivity` 在工程代码里的挂接顺序。

核心问题是：

```text
Transient 里的 direct sensitivity 和 adjoint sensitivity
分别挂在 forward transient 的什么位置，
为什么 adjoint 明显比 DC / AC 更像一条独立附加流程？
```

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

## 当前结论先写在前面

`Transient sensitivity` 的工程主线可以压成：

```text
先在 options 里读出 direct / adjoint 及其时间范围配置
-> forward transient 开始前 enableSensitivity(...)
-> DCOP 和每个成功时间步后都可以做 direct sensitivity
-> 如果开了 adjoint，就在 forward 过程中顺手存历史
-> forward 全部结束后，再启动一条反向时间的 adjoint 流程
```

所以它和 `DC`、`AC` 最大的工程差别是：

```text
Transient adjoint 不是“某一步顺手解一下”，
而是“forward + history + reverse” 的完整附加子流程。
```

## 第一步：先看 transient 的 sensitivity 选项比 AC 多得多

顺着文件先看：

- [N_ANP_Transient.C:505](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L505)

在 `Transient::setSensitivityOptions(...)` 里，除了 `DIRECT / ADJOINT` 之外，还会读：

- `ADJOINTBEGINTIME`
- `ADJOINTFINALTIME`
- `ADJOINTTIMEPOINTS`
- `FULLADJOINTTIMERANGE`
- `SPARSESTORAGE`
- `DIFFERENCE`

这已经说明：

```text
transient sensitivity 尤其是 adjoint，
在工程上不是一个简单开关，
而是一整套带时间范围和存储策略的流程配置。
```

## 第二步：再看 `.SENS` 自己读了什么

继续顺着同一个文件往下读：

- [N_ANP_Transient.C:635](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L635)

这里除了普通 `PARAM...` 之外，还支持：

- `SENSDEVICENAME`

后面在：

- [N_ANP_Transient.C:686](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L686)

的 `obtainDeviceSensParams()` 里，会根据器件名再展开出对应的敏感参数。

这说明 `Transient sensitivity` 在工程上已经不仅是“参数列表”，还支持：

```text
围绕某个具体器件去批量抓取 sensitivity 参数
```

## 第三步：forward transient 开始前先 enableSensitivity(...)

接着再看：

- [N_ANP_Transient.C:714](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L714)

在 `finalExpressionBasedSetup()` 里，它先：

1. `obtainDeviceSensParams()`
2. `nonlinearManager_.enableSensitivity(...)`

所以顺序是很清楚的：

```text
先把 sensitivity 参数列表整理完整
再把 sensitivity 基础设施挂到 nonlinearManager_
```

这一步仍然和 `DC`、`AC` 一致，属于“准备阶段”。

## 第四步：DCOP 成功后，direct 和 adjoint 的挂法已经开始分叉

继续顺着文件往下看：

- [N_ANP_Transient.C:1681](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L1681)

在 transient 的 `DCOP` 成功处理阶段里，会看到：

### direct 分支

```cpp
nonlinearManager_.calcSensitivity(...)
```

### adjoint 分支

```cpp
saveTransientAdjointSensitivityInfoDCOP()
```

这说明从工程上，二者已经开始走不同路径：

```text
direct：
工作点一成功就直接算 sensitivity

adjoint：
工作点一成功先存历史，
因为后面反向时间流程还要回来看
```

## 第五步：每个成功 transient 步后，仍然是 direct 先算、adjoint 先存

再顺着看：

- [N_ANP_Transient.C:1777](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L1777)

在 `doProcessSuccessfulStep()` 里，同样是两条线：

### direct

```cpp
nonlinearManager_.calcSensitivity(...)
```

### adjoint

```cpp
saveTransientAdjointSensitivityInfo()
```

所以可以把 transient forward 阶段里的 sensitivity 行为总结成：

```text
每个成功时间步：
direct 立即产出当前步 sensitivity
adjoint 先把未来反向所需的东西存起来
```

## 第六步：为什么 `saveTransientAdjointSensitivityInfo()` 很关键

继续顺着同一个文件往下读：

- [N_ANP_Transient.C:2192](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L2192)
- [N_ANP_Transient.C:2274](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L2274)

这两处会保存：

- 时间历史
- 时间步长历史
- 阶数历史
- 解向量历史
- 状态向量历史
- store 历史
- 以及 sensitivity 相关的函数导数历史

所以从工程视角，你应该把这一步理解成：

```text
transient adjoint 的 forward run
并不是“算完就丢”，
而是在不停构造一个后续 reverse solve 所需的历史数据库
```

这就是它为什么明显比 `DC`、`AC` 重。

## 第七步：真正的 transient adjoint 是 forward 完成之后才开始

再继续顺着同一个文件往下读：

- [N_ANP_Transient.C:2357](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L2357)

`doTransientAdjointSensitivity()` 已经不是“某一步中的小动作”了，而是一条完整流程：

1. 选定感兴趣时间点
2. 初始化 adjoint
3. 反向遍历时间索引
4. 每一步更新 adjoint 系数
5. 调 `nonlinearManager_.calcTransientAdjoint(...)`
6. 最后输出 transient adjoint sensitivity

所以在工程上，transient adjoint 最应该先抓住的是：

```text
它不是 forward transient 主循环里的一个小分支，
而是 forward 结束后，
又额外启动的一条 reverse-time analysis 流程。
```

## 第八步：这条线现在先读到哪里最合适

当前阶段，我建议你先把 transient 工程主线读到这几个节点：

1. `setSensitivityOptions(...)`
2. `setSensAnalysisParams(...)`
3. `finalExpressionBasedSetup()`
4. `doProcessSuccessfulDCOP()`
5. `doProcessSuccessfulStep()`
6. `saveTransientAdjointSensitivityInfo*()`
7. `doTransientAdjointSensitivity()`

这条链路已经足够回答：

```text
transient sensitivity 在代码里到底怎么挂，
direct 和 adjoint 又是从哪里开始分家的
```

## 当前这一篇学完后，应该记住什么

1. `Transient sensitivity` 的工程复杂度明显高于 `DC` 和 `AC`。
2. direct 和 adjoint 在 `forward` 成功步之后就开始分叉：一个直接算，一个先存历史。
3. `saveTransientAdjointSensitivityInfo*()` 是 transient adjoint 的关键桥梁。
4. `doTransientAdjointSensitivity()` 是一条独立的 reverse-time 流程，不只是主循环里的一个小调用。
