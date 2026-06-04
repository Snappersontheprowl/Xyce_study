# mosfet b4 f and dfdx

记录日期：2026-06-04

## 这篇的定位

这一篇只做一件事：

```text
把 MOSFET_B4 的电流侧贡献看清楚，
也就是它如何把工作点量翻译成 F 和 dFdx
```

这里先不展开 `Q/dQdx`。  
这样可以把问题压缩成：

$$
F(x)
$$

以及 Newton 线性化里最需要的：

$$
\frac{\partial F}{\partial x}
$$

## 这次读了哪些文件

这次主要继续读：

- [src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

重点看了这些函数：

- `updatePrimaryState()`
- `Master::updateState(...)`
- `setupFVectorVars()`
- `Master::loadDAEVectors(...)`
- `Master::loadDAEMatrices(...)`

## 当前结论先写在前面

如果只压成一句话，`B4` 的电流侧主线是：

```text
当前解向量
-> updateIntermediateVars 算出 gm / gds / cdrain / 各类 gate-body-source-drain 电流和导数
-> setupFVectorVars() 把它们整理成 ceq* / I*eq / g* 这组“可装配形式”
-> loadDAEVectors() 写 F
-> loadDAEMatrices() 写 dFdx
```

也就是说，`B4` 不是在 `loadDAEMatrices()` 里临时现算公式，而是：

```text
先算工作点量，
再整理成残差和导数块，
最后统一装配
```

## 第一步：先认清 `F` 侧不是从 `loadDAEMatrices()` 才开始

如果只看 `Master::loadDAEMatrices(...)`，很容易误以为：

```text
MOS 的导数信息是在矩阵装配那一刻才第一次出现
```

但顺着代码看，真正更早的起点是：

- `updatePrimaryState()`
- `Master::updateState(...)`

这里先调用：

- `updateIntermediateVars()`

然后把一批当前工作点量保存下来，比如：

- `gm`
- `gds`
- `Vgs`
- `Vds`
- `Vbs`

所以这一层的本质是：

```text
先围绕当前 x_k 建立 MOS 的局部工作点描述
```

后面的 `F/dFdx` 装配，全都建立在这些中间量之上。

## 第二步：`setupFVectorVars()` 是真正的“电流侧翻译器”

接下来最关键的函数是：

- [setupFVectorVars()](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

这一步非常重要，因为它不是直接往矩阵写，而是在做一层中间翻译。

它把更原始的工作点量，例如：

- `gm`
- `gds`
- `gmbs`
- `cdrain`
- `Igs / Igd / Igb`
- `Igidl / Igisl`

翻译成后面更适合装配的量：

- `ceqdrn`
- `ceqbd`
- `ceqbs`
- `ceqgcrg`
- `ceqgdtot`
- `ceqgstot`
- `Idtoteq`
- `Istoteq`
- `Ibtoteq`
- `Igtoteq`

你可以先把这些名字粗略理解成两类：

### 1. `ceq*`

更像“已经整理好的支路等效电流项”。

### 2. `*toteq`

更像“总 gate/source/drain/body 相关电流项的等效组合”。

所以这一层的本质是：

```text
把复杂 MOS 工作点数据，
整理成后面残差装配时可以直接使用的块
```

## 第三步：为什么 `setupFVectorVars()` 里要分 forward / reverse mode

在这个函数里，最显眼的结构就是：

- `if (mode >= 0)`
- `else`

这一步很值得理解，因为它说明：

```text
MOS 的电流和导数装配，
不是永远用一套固定方向表达式
```

而是会根据当前工作区方向，分别组织：

- `Gm`
- `Gmbs`
- `FwdSum`
- `RevSum`

例如在 forward mode 里：

- `Gm = gm`
- `Gmbs = gmbs`

而在 reverse mode 里：

- `Gm = -gm`
- `Gmbs = -gmbs`

这一步的本质是：

```text
同一个 MOS 实例，
在不同导通方向下，
F 和 dFdx 的符号组织方式会变化
```

所以 `B4` 的复杂性，不只是公式多，还体现在：

```text
同一套物理量要按不同工作区重新整理
```

## 第四步：`setupFVectorVars()` 怎样把工作点量变成残差块

这一层最值得先抓住三组代表量。

### 1. 通道电流主项

最核心的是：

$$
\text{ceqdrn}
$$

它来自：

- `cdrain`
- 以及与 `gds / Gm / Gmbs` 对应的 limiter 修正项

也就是说，`ceqdrn` 不是单纯“当前电流值”，而是更接近：

```text
当前工作点下，供残差使用的等效通道电流项
```

### 2. 体相关和寄生泄漏项

例如：

- `ceqbd`
- `ceqbs`

它们把：

- `csub`
- `Igidl`
- `Igisl`

这类体相关、寄生相关电流一起纳入电流侧残差。

这正好说明 `B4` 不是“一个单纯的 Ids 公式”，而是很多支路项叠加后的结果。

### 3. gate 电流总项

例如：

- `Istoteq`
- `Idtoteq`
- `Ibtoteq`
- `Igtoteq`

这里会根据：

- `igcMod`
- `igbMod`

决定是否把：

- `Igs / Igd / Igb`
- 以及相关导数

合并进 gate 相关残差。

所以这一层最重要的认识是：

```text
B4 的 F 不是“一个 Ids”，
而是通道、结、gate leakage、寄生项共同组成的总残差
```

## 第五步：为什么这里同时出现 `*_Jdxp`

在 `setupFVectorVars()` 里，你还会看到另一组对应变量：

- `ceqdrn_Jdxp`
- `ceqbd_Jdxp`
- `ceqbs_Jdxp`
- `Idtoteq_Jdxp`
- `Igtoteq_Jdxp`

这些不是最终 Jacobian 条目本身。  
它们更接近：

```text
voltage limiter / predictor 修正需要的“工作点差分项”
```

也就是说，它们是：

- 以 `(v - v_orig)` 这种差值为中心
- 对残差修正进行一层打包

所以这一层要和后面的真正 `dFdx` 区分开：

- `*_Jdxp`：更偏 limiter 修正辅助量
- `dFdx[...] += ...`：才是真正写进 Jacobian 的条目

## 第六步：`Master::loadDAEVectors(...)` 才把这些块装进 `F`

等 `setupFVectorVars()` 把中间块准备好之后，才轮到：

- [Master::loadDAEVectors(...)](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

这里最值得看的不是每一行公式，而是它的组织方式。

### 1. 先写核心节点

最先写的是：

- `DrainPrime`
- `GatePrime`

例如：

```text
DrainPrime <- ceqjd, ceqbd, ceqdrn, Idtoteq
GatePrime  <- ceqgcrg, Igtoteq
```

这说明电流侧残差的主干，是先围绕器件内部主节点来组织的。

### 2. 再按 `rgateMod` 展开 gate 网络

接着分：

- `rgateMod == 1`
- `rgateMod == 2`
- `rgateMod == 3`

这说明 gate 一侧的残差结构，不是固定的，而是取决于前面 `06` 里已经建立好的内部节点结构。

也就是说：

```text
unknown 结构怎么展开，
F 的装配结构就跟着怎么展开
```

### 3. 再按 `rbodyMod` 展开 body 网络

如果没有 `rbodyMod`：

- body 相关残差更集中

如果打开 `rbodyMod`：

- `DrainBody`
- `Body`
- `SourceBody`
- `BodyPrime`

都会单独承接电流项

这说明：

```text
复杂 compact model 的 F 装配，
本质上是对内部子网络做 KCL
```

而不是只对四个外部端口做几项加减。

### 4. 可选的 `rdsMod`、端口电阻、初始条件分支

后面还会继续按：

- `rdsMod`
- `drainMOSFET_B4Exists`
- `sourceMOSFET_B4Exists`
- `icVBSGiven / icVDSGiven / icVGSGiven`

分别往 `F` 里加项。

这一层特别能说明：

```text
B4 的 F 装配不是“一个主公式”，
而是很多可选子结构叠加后的结果
```

## 第七步：`Master::loadDAEMatrices(...)` 才是真正写 `dFdx`

再往下看：

- [Master::loadDAEMatrices(...)](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

这里做的事就更明确了：

```text
把前面已经准备好的局部导数，
按行列 offset 写进 dFdx
```

这一层最该先抓住三个特点。

### 1. 它按结构分块写

先按：

- `rgateMod`
- `rdsMod`
- `rbodyMod`
- `trnqsMod`
- 初始条件分支

分块写矩阵。

这说明真正的 Jacobian 不是“一个统一公式”，而是：

```text
内部网络结构 + 物理导数块
```

共同拼出来的。

### 2. 它大量使用前面 `06` 里建立的指针

例如：

- `*mi.f_DPdpPtr += ...`
- `*mi.f_SPgpPtr += ...`
- `*mi.f_GPbpPtr += ...`

这正是前一篇 `06-mosfet-b4-unknowns-and-stamp.md` 的意义所在。  
如果前面没有先建立：

- `registerLIDs`
- `registerJacLIDs`
- `setupPointers`

这里就会像“凭空往矩阵里乱写”。

### 3. Jacobian 条目本质上是局部线性化后的 KCL 系数

例如你会反复看到：

- `gds`
- `Gm`
- `Gmbs`
- `gIgtotg`
- `gdtotg`
- `gbd`
- `gbs`

这些量最后都进入某个节点方程对某个未知量的偏导条目。

所以这一层从数学上看，本质上是在构造：

$$
\frac{\partial F}{\partial x}
$$

而从电路角度看，本质上是在做：

```text
每个内部节点 KCL 对各个相关未知量的局部线性化系数
```

## 第八步：这一篇最该记住的边界

读到这里，最容易混淆的是下面三层：

1. `updateIntermediateVars()`
   - 算工作点物理量
2. `setupFVectorVars()`
   - 把工作点量翻译成残差块和修正块
3. `loadDAEVectors()` / `loadDAEMatrices()`
   - 真正装配 `F` 和 `dFdx`

这三层一定要分开看。

如果把它们混成一层，就会很容易误以为：

- `gm` 就是矩阵条目
- `cdrain` 就是残差
- `*_Jdxp` 就是最终 Jacobian

实际上都不是。

## 把这一轮主线压缩成一句顺序

现在可以把 `B4` 电流侧主线记成：

1. `updateIntermediateVars()`
   - 围绕当前解算出 `gm/gds/gmbs/cdrain/...`
2. `setupFVectorVars()`
   - 整理出 `ceqdrn/ceqbd/ceqbs/I*toteq/...`
3. `Master::loadDAEVectors(...)`
   - 把这些等效电流块装进 `F`
4. `Master::loadDAEMatrices(...)`
   - 把对应局部导数装进 `dFdx`

这就是：

```text
工作点
-> 电流侧等效块
-> residual
-> Jacobian
```

## 这一篇最想让你记住的 4 句话

1. `B4` 的 `F` 不是单个 `Ids`，而是很多支路项合成后的总残差。
2. `setupFVectorVars()` 是 `B4` 电流侧最关键的中间翻译层。
3. `*_Jdxp` 更偏 limiter / 工作点差分修正，不等于最终 Jacobian 条目。
4. `loadDAEMatrices()` 之所以能读懂，前提是上一篇已经把 unknown / offset / pointer 地图建立好了。

## 下一步最自然该去哪里

现在电流侧已经单独看过了，下一步最自然就是：

- `08-mosfet-b4-q-and-dqdx.md`

也就是继续看：

```text
这个大器件如何把电荷侧贡献装进 Q 和 dQdx
```

这样 `B4` 的 `F/Q` 两半就都能各自站稳。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `setupFVectorVars()` 比 `loadDAEMatrices()` 更像 `B4` 电流侧的“翻译中枢”？
2. 为什么说 `loadDAEMatrices()` 里那些 `f_*Ptr += ...`，本质上是在写“局部线性化后的 KCL 系数”？
