# mosfet b4 roadmap

记录日期：2026-06-04

## 这篇的定位

这一篇不直接进入 `BSIM4` 的具体公式，而是先回答：

```text
面对 N_DEV_MOSFET_B4 这种超大 compact model 文件，
第一轮到底该怎么读，先看什么，后看什么？
```

前面我们已经用：

- resistor
- capacitor
- diode

分别把：

- `F/dFdx`
- `Q/dQdx`
- nonlinear 局部线性化

这些基本部件拆开看过了。

所以现在进入 `MOSFET_B4`，真正的目标不是“重新学一个器件”，而是：

```text
看一个复杂 compact model
如何把前面这些贡献几乎全部同时装进总方程
```

## 这次读了哪些文件

这次只做路线图，不进深公式，按“注册入口 -> 结构层次 -> 节点与 stamp -> 状态更新 -> 向量/矩阵装配”这条顺序看了这些位置：

- [src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.h](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.h)
- [src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

重点扫过的函数位置包括：

- `registerDevice(...)`
- `Traits::factory(...)`
- `Instance::Instance(...)`
- `registerLIDs(...)`
- `jacobianStamp()`
- `registerJacLIDs(...)`
- `updatePrimaryState()`
- `Master::loadDAEVectors(...)`
- `Master::loadDAEMatrices(...)`

## 当前结论先写在前面

如果只压成一句话，`MOSFET_B4` 最应该先这样看：

```text
先把它当成“前面几种器件贡献的大合体”，
而不是先把它当成“一堆 BSIM4 公式”
```

也就是说，第一轮阅读最重要的不是：

- 每个参数的物理意义
- 每条模型公式的推导

而是先建立这张地图：

$$
\text{nodes / internal variables}
\rightarrow
\text{intermediate quantities}
\rightarrow
(F,Q)
\rightarrow
(dFdx,dQdx)
\rightarrow
\text{solver}
$$

## 第一步：先确认它在 netlist 里的身份

先看：

- [N_DEV_MOSFET_B4.h](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.h)
- [N_DEV_MOSFET_B4.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

最先要抓的是 `Traits` 和 `registerDevice(...)`。

这里已经直接告诉我们：

- 它是 `M` 器件
- level 是 `14` / `54`
- `modelRequired() == true`
- `isLinearDevice() == false`
- 外部节点数 `numNodes() == 4`

所以第一层稳定结论是：

```text
这是一个四端、必须带 model card、明确非线性的 MOS compact model
```

也就是说，它从入口定义上就和 resistor / capacitor / diode 拉开了层级差距。

## 第二步：先把代码角色分层，不要一头扎进公式

这一类大文件最容易让人失控的原因，是它把很多层的东西都放在一个 `.C/.h` 里：

- model 参数系统
- instance 参数系统
- 尺寸相关参数
- 节点与 stamp
- 中间物理量
- `F/Q` 装配
- `dFdx/dQdx` 装配
- 噪声
- 数值保护

所以第一轮最重要的不是“顺读”，而是先分层。

建议你先把 `B4` 分成下面 5 块：

1. **入口层**
   - `Traits`
   - `factory`
   - `registerDevice`

2. **结构层**
   - `Model`
   - `Instance`
   - `Master`
   - `SizeDependParam`

3. **拓扑/未知量层**
   - `registerLIDs`
   - `jacobianStamp`
   - `registerJacLIDs`

4. **物理量更新层**
   - `updateIntermediateVars`
   - `updatePrimaryState`

5. **装配层**
   - `loadDAEVectors`
   - `loadDAEMatrices`

只要先把这 5 层分清，后面再深入某一层时就不容易迷路。

## 第三步：为什么第一轮必须先看“节点和 stamp”

和前面简单器件最大的不同，是 `B4` 不是只有：

- drain
- gate
- source
- body

这四个外部节点。

在：

- [N_DEV_MOSFET_B4.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)
  里的 `registerLIDs(...)`

你会看到它根据选项和模型结构，可能还会出现：

- `DrainPrime`
- `SourcePrime`
- `GatePrime`
- `GateMid`
- `BodyPrime`
- `SourceBody`
- `DrainBody`
- `Charge`
- 以及一些只在初值约束时出现的 branch 变量

所以第一轮一定要先吃下这件事：

```text
B4 不是“四端器件就只有四个未知量”，
它往往会扩展成一大块内部节点和附加变量网络
```

这也是为什么它的 Jacobian stamp 会远大于前面那些简单器件。

## 第四步：为什么 `updateIntermediateVars` 是第二个必须先建立的锚点

在头文件和实现里，你会看到：

- `updateIntermediateVarsPtr_`
- `updateIntermediateVars4p61_()`
- `updateIntermediateVars4p70_()`
- `updateIntermediateVars4p82_()`

再配合：

- `updatePrimaryState()`

这说明 `B4` 的一个很重要的结构特点是：

```text
先根据 BSIM4 版本选择一套 updateIntermediateVars 实现，
再由统一的 updatePrimaryState 调用它
```

这非常值得先记住，因为它直接告诉你：

- 真正的大量模型计算，不在 `loadDAEVectors` 里临时做
- 而是先集中算出当前工作点下的大量中间物理量
- 然后装配层再使用这些量写 `F/Q/dFdx/dQdx`

这和 diode 的节奏是一致的，只是规模大得多。

## 第五步：为什么 `Master::loadDAEVectors` 和 `Master::loadDAEMatrices` 必须分开读

从现在看到的代码结构已经很清楚：

- `Master::loadDAEVectors(...)` 非常长
- `Master::loadDAEMatrices(...)` 也非常长

如果第一轮就把它们混在一起读，会很容易失去重点。

更合理的拆法是：

### 先把 `loadDAEVectors` 当成“当前工作点下的向量贡献汇总”

这里你会同时看到：

- 大量 `F` 侧电流平衡项
- 大量 `Q` 侧电荷项
- 各种 `leadF / leadQ`
- limiter 修正向量

### 再把 `loadDAEMatrices` 当成“对应导数信息汇总”

这里你会看到：

- `dFdx`
- `dQdx`

是怎样围绕同一批中间物理量展开的。

所以这一步的阅读策略不是：

```text
从头一直看下去
```

而是：

```text
先看 vector 层在写什么类别的量，
再看 matrix 层在给这些量补什么导数
```

## 我建议的实际学习顺序

基于现在这个子专题的结构，最适合按下面顺序往下读：

### 1. `02-unknowns-and-stamp.md`

只看：

- 外部节点
- 内部节点
- branch 变量
- Jacobian stamp

目标：

```text
先搞清这个器件在总方程里占了多大一块位置
```

### 2. `03-f-and-dfdx.md`

只看：

- `Master::loadDAEVectors(...)` 里 `F` 一侧
- `Master::loadDAEMatrices(...)` 里 `dFdx` 一侧

目标：

```text
先把导通电流和局部线性化这一半读通
```

### 3. `04-q-and-dqdx.md`

只看：

- `Q` 一侧
- `dQdx` 一侧
- `Charge` 内部变量、NQS 相关量

目标：

```text
再把电荷和动态项这一半读通
```

### 4. `09-mosfet-b4-numerical-guards.md`

这一步先不要再开新分支，直接读：

- `05-merge-summary.md`

目标：

```text
先把 unknown structure、F/Q、dFdx/dQdx
重新压回同一张总图里
```

### 5. 如果后面还要继续扩展

等这五篇真正读顺以后，再单独补一篇“数值保护”是更合适的。

那时可以专门再开一篇，比如：

- `06-numerical-guards.md`

只看：

- limiter
- clipping
- 初值处理
- 各种工程化数值保护

目标：

```text
把“物理模型”和“为了 Newton 收敛而加的工程逻辑”彻底拆开
```

## 第一轮阅读最不该做的事

这里我想特别提醒 3 个坑。

### 1. 不要先啃所有参数表

`B4` 的参数非常多。第一轮如果先盯参数，很容易掉进：

```text
变量名很多
但不知道它们最后服务哪一层
```

### 2. 不要先追所有公式推导

BSIM4 的公式本身就很重。  
如果还没建立代码结构地图，就直接追推导，最后通常会变成：

```text
既没读懂代码，也没读懂系统位置
```

### 3. 不要先混着看 F 和 Q

`B4` 最复杂的地方之一，就是它同时强烈贡献：

- `F/dFdx`
- `Q/dQdx`

所以一定要分层读，不然你很容易把：

- 电流侧导数
- 电荷侧导数
- time integration 之后的动态 Jacobian

全部混在一起。

## 这一篇最想让你先记住的 4 句话

1. `MOSFET_B4` 是前面 `resistor / capacitor / diode` 三条线的真正“大合体”。
2. 第一轮先建立代码结构地图，不要先扎进公式。
3. 第一优先级是先看“未知量和 stamp 有多大”，第二优先级才是看具体 `F/Q` 装配。
4. 后面阅读时一定把：
   - `F/dFdx`
   - `Q/dQdx`
   - 数值保护  
   三块分开。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么进入 `B4` 的第一轮，不该先去啃所有 BSIM4 公式？
2. 为什么说对 `MOSFET_B4` 来说，“节点/内部变量地图”比“公式细节”更应该先建立？
