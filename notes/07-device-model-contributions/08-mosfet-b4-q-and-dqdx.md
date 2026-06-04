# mosfet b4 q and dqdx

记录日期：2026-06-04

## 这篇的定位

这一篇只回答一个问题：

```text
MOSFET_B4 的电荷侧贡献，
是怎样从内部 charge 量一路变成 Q 和 dQdx 的？
```

和上一篇 `07-mosfet-b4-f-and-dfdx.md` 对应，这一篇只盯：

$$
Q(x), \qquad \frac{\partial Q}{\partial x}
$$

暂时不把 `F/dFdx` 再混进来。

## 这次读了哪些文件

这次继续读：

- [src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

重点看了这些函数：

- `updatePrimaryState()`
- `auxChargeCalculations()`
- `setupCapacitors_newDAE()`
- `Master::loadDAEVectors(...)` 里 `Q` 相关部分
- `Master::loadDAEMatrices(...)` 里 `dQdx` 相关部分

## 当前结论先写在前面

如果只压成一句话，`B4` 的电荷侧主线是：

```text
updateIntermediateVars / setupCapacitors_newDAE
-> 得到 qgate/qbulk/qdrn/qbs/qbd/qgmid/qcheq 以及 CAPc* 系数
-> updatePrimaryState() 把这些量写进 state
-> auxChargeCalculations() 生成 Q 侧 limiter 修正项
-> Master::loadDAEVectors() 写 Q
-> Master::loadDAEMatrices() 写 dQdx
```

所以 `B4` 的 `Q` 侧并不是“临时几项电容电流”，而是先组织成一整套电荷变量和电荷导数，再交给 time integration 去形成：

$$
\frac{dQ(x)}{dt}
$$

## 第一步：先认清 `B4` 保存的不是“电流型电容”，而是 charge

从构造和状态量命名就能看出来，`B4` 持有的是：

- `qgate`
- `qbulk`
- `qdrn`
- `qbs`
- `qbd`
- `qgmid`
- `qdef`
- `qcheq`

这说明在器件层，它首先关心的是：

```text
每一部分电荷本身是多少
```

而不是直接关心“最终瞬态电流是多少”。

这一点和我们前面在 capacitor 里建立的认识是完全一致的：

```text
器件先提供 Q，
time integration 再把它变成 dQ/dt
```

## 第二步：`updatePrimaryState()` 把 charge 组织成状态量

继续顺着代码看：

- [updatePrimaryState()](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

这里会把内部 charge 写进 state vector，例如：

- `qg = qgate`
- `qd = qdrn - qbd`
- `qb = qbulk` 或 `qbulk + qbd + qbs`

如果：

- `rbodyMod` 打开，还会把 `qbs/qbd` 单独存下来
- `rgateMod == 3`，还会存 `qgmid`
- `trnqsMod` 打开，还会存 `qcheq` 和 `qdef`

这一层的本质是：

```text
把复杂器件内部的各类电荷，
整理成求解器和时间积分层可追踪的状态量
```

所以和上一节 `F` 侧对照来看：

- `F` 侧先组织的是“等效电流块”
- `Q` 侧先组织的是“状态电荷块”

## 第三步：`setupCapacitors_newDAE()` 是电荷侧最关键的中间翻译层

接下来最关键的函数是：

- [setupCapacitors_newDAE()](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

这一步的角色，和上一节的 `setupFVectorVars()` 很像。  
它做的事情不是直接装配，而是把更原始的电荷/电容信息整理成一组适合写 `dQdx` 的系数：

- `CAPcggb`
- `CAPcgdb`
- `CAPcgsb`
- `CAPcdgb`
- `CAPcddb`
- `CAPcdsb`
- `CAPcbgb`
- `CAPcbdb`
- `CAPcbsb`
- 以及 NQS 相关的 `CAPcq*`

你可以先把这些量粗略理解成：

```text
各个 charge 分量对各个局部电压变量的偏导系数
```

也就是：

$$
\frac{\partial Q_i}{\partial x_j}
$$

的器件层表达。

## 第四步：为什么 `setupCapacitors_newDAE()` 要按 `mode/rgateMod/rbodyMod/trnqsMod` 分支

这一步很值得停一下，因为它体现了复杂 compact model 的真实样子。

在这个函数里，电荷系数不是一套固定表，而是会随着这些条件变化：

- `mode > 0` / `mode < 0`
- `rgateMod`
- `rbodyMod`
- `trnqsMod`

这说明：

```text
Q/dQdx 的结构不是固定的“几个电容”，
而是会随着导通方向和内部子网络结构一起变化
```

也就是说，`B4` 的电荷模型已经不是“一个栅电容 + 一个结电容”的级别了，而是一整张分布电荷网络。

## 第五步：`auxChargeCalculations()` 负责把 charge 变成可用于装配的修正项

然后再看：

- [auxChargeCalculations()](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

这一层最重要的不是再去算新的物理 charge，而是把已有电荷量整理成：

- `Qeqqg_Jdxp`
- `Qeqqd_Jdxp`
- `Qeqqb_Jdxp`
- `Qeqqgmid_Jdxp`
- `Qeqqjs_Jdxp`
- `Qeqqjd_Jdxp`
- `Qqcheq_Jdxp`

这些量和上一节看到的 `*_Jdxp` 一样，主要是为了：

- limiter
- 原始电压与 `orig` 电压之间的差分修正

所以要把两层分开：

- `CAPc*`
  - 更像电荷侧的基本偏导系数
- `Qeqq*_Jdxp`
  - 更像基于当前工作点差分打包出来的修正项

## 第六步：`Master::loadDAEVectors()` 才真正把 charge 写进 `Q`

等前面的 charge 量和修正量准备好以后，才轮到：

- [Master::loadDAEVectors(...)](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

这里最值得抓的是，它先把内部 charge 统一命名成：

- `Qeqqg`
- `Qeqqb`
- `Qeqqd`
- `Qeqqgmid`
- `Qeqqjs`
- `Qeqqjd`
- `Qqdef`
- `Qqcheq`

然后按器件结构把这些量分配到：

- `GatePrime`
- `DrainPrime`
- `BodyPrime`
- `SourcePrime`
- 可选的 `GateMid`
- 可选的 `DrainBody/SourceBody`
- 可选的 `Charge`

这里最重要的认识是：

```text
Q-vector 的写法，本质上是在做电荷守恒分配
```

例如 source 侧经常是“其余电荷的总和负号”，这不是凑出来的，而是在保证：

```text
总电荷分配一致
```

## 第七步：`trnqsMod` 说明 charge 甚至可以变成显式未知量

如果打开 `trnqsMod`，你会看到：

- `li_Charge`
- `Qqcheq`
- `Qqdef`
- `CAPcqgb/CAPcqdb/CAPcqsb/CAPcqbb`

以及在 `F` 侧还会出现和 `qdef/gtau` 相关的项。

这一点特别值得记住，因为它说明：

```text
在复杂 compact model 里，
charge 不只是一个“附带电容效果”，
它甚至可以提升成显式内部未知量和方程块
```

这也是为什么前面 `06-mosfet-b4-unknowns-and-stamp.md` 里要先把 `li_Charge` 单独记下来。

## 第八步：`Master::loadDAEMatrices()` 才是真正写 `dQdx`

最后再看：

- [Master::loadDAEMatrices(...)](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

在 `Q` 侧，这里最重要的事就是：

```text
把前面已经整理好的 CAPc* / CAPcq* 系数，
按 offset 写进 dQdx
```

你会看到大量像这样的条目：

- `q_GPgpPtr += CAPcggb`
- `q_DPdpPtr += CAPcddb`
- `q_BPbpPtr += CAPcbbb`
- `q_QgpPtr += -CAPcqgb`

或者非指针版本里的：

- `dQdx[...] += ...`

这一步从数学上看，就是在构造：

$$
\frac{\partial Q}{\partial x}
$$

从电路角度看，就是：

```text
每个 charge 分量对每个相关未知量的电荷偏导
```

这正是 transient Jacobian 后面会用到的重要来源之一。

## 第九步：为什么 `Q` 侧比 `F` 侧更容易看乱

`Q` 侧最容易混的，是下面三层：

1. 原始 charge 量
   - `qgate/qbulk/qdrn/...`
2. 电荷偏导系数
   - `CAPc*`
3. 最终 `Q/dQdx`
   - `Qeqq*`、`qVec[...]`、`dQdx[...]`

如果把这三层混在一起，就很容易误以为：

- `CAPcggb` 就是电荷本身
- `qgate` 就是 `Q-vector` 条目
- `Qeqq*_Jdxp` 就是最终 `dQdx`

实际上都不是。

所以这一步最重要的边界是：

- `q*`
  - charge state
- `CAPc*`
  - charge derivative coefficients
- `Qeqq* / qVec`
  - 装配后的 `Q`
- `dQdx`
  - 最终 Jacobian 中的 charge 部分

## 把这一轮主线压缩成一句顺序

现在可以把 `B4` 电荷侧主线记成：

1. `updateIntermediateVars()` / `setupCapacitors_newDAE()`
   - 先得到 charge 和 charge 导数系数
2. `updatePrimaryState()`
   - 把这些 charge 写入 state
3. `auxChargeCalculations()`
   - 生成 limiter 相关修正项
4. `Master::loadDAEVectors(...)`
   - 把电荷分配写进 `Q`
5. `Master::loadDAEMatrices(...)`
   - 把 `CAPc* / CAPcq*` 写进 `dQdx`

这就是：

```text
charge state
-> charge derivative coefficients
-> Q
-> dQdx
```

## 这一篇最想让你记住的 4 句话

1. `B4` 的 `Q` 侧首先是电荷模型，不是“电流型电容模型”。
2. `setupCapacitors_newDAE()` 是电荷侧最关键的中间翻译层。
3. `CAPc*` 更像 $\partial Q / \partial x$ 的器件层系数，不等于 charge 本身。
4. `Q` 侧的最终目标不是自己算 `dQ/dt`，而是把 `Q/dQdx` 提供给后面的 time integration。

## 下一步最自然该去哪里

现在 `MOSFET_B4` 的两半已经分别站稳：

- `07-mosfet-b4-f-and-dfdx.md`
- `08-mosfet-b4-q-and-dqdx.md`

下一步最自然的是再做一篇很短的合流总结，例如：

```text
把 B4 看成 F/Q/dFdx/dQdx 的大合体
```

这样前面 `resistor / capacitor / diode` 和现在的 `B4` 就能真正汇总到一起。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `setupCapacitors_newDAE()` 比 `Master::loadDAEMatrices()` 更像 `B4` 电荷侧的“翻译中枢”？
2. 为什么 `Q` 侧最重要的边界，不是“有没有电容”，而是“charge state / CAP 系数 / Q / dQdx` 这几层不要混掉”？ 
