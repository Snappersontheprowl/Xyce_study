# mosfet b4 unknowns and stamp

记录日期：2026-06-04

## 这篇的定位

这一篇只回答一个问题：

```text
MOSFET_B4 这个器件，在总方程里到底占了多大一块位置？
```

也就是说，这一篇先不追电流公式，也不追电荷公式，而是先把：

- 外部节点
- 内部节点
- branch 变量
- state/store 变量
- Jacobian stamp

这些结构看清楚。

这是进入 `B4` 的第一道门槛，因为如果连“它有哪些未知量、矩阵里占几行几列”都没建立起来，后面再看 `F/Q/dFdx/dQdx` 很容易失去坐标感。

## 这次读了哪些文件

这次主要读了：

- [src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.h)
- [src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)

重点看了这些位置：

- `Instance::Instance(...)`
- `registerLIDs(...)`
- `registerStateLIDs(...)`
- `registerStoreLIDs(...)`
- `jacobianStamp()`
- `registerJacLIDs(...)`
- `setupPointers()`

## 当前结论先写在前面

如果只压成一句话，`MOSFET_B4` 最重要的结构特征是：

```text
它虽然从 netlist 看起来只是一个四端 M 器件，
但在方程系统里通常会扩展成“外部四端 + 多个内部节点 + 若干可选附加变量”的大块结构
```

所以它和前面那些简单器件最本质的差别，不只是公式更复杂，而是：

```text
它在未知量层面就已经复杂很多
```

## 第一步：先确认外部节点并不是全部未知量

从 `Traits` 开始，`B4` 明确告诉我们：

```cpp
static int numNodes() {return 4;}
```

也就是说，netlist 语义层面它是一个四端器件：

- drain
- gate
- source
- body

这和我们电路课里的 MOS 直觉是一致的。

但是这只是“外部接口”，不是它在求解器里实际占用的全部未知量。

## 第二步：真正的关键在 `registerLIDs(...)`

继续看：

- [N_DEV_MOSFET_B4.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_MOSFET_B4.C)
  里的 `registerLIDs(...)`

这里最值得先抓住的事情是：

### 固定外部节点

一开始总有这四个：

- `li_Drain`
- `li_GateExt`
- `li_Source`
- `li_Body`

### 可选内部节点

然后根据模型和选项，还可能出现：

- `li_DrainPrime`
- `li_SourcePrime`
- `li_GatePrime`
- `li_GateMid`
- `li_BodyPrime`
- `li_SourceBody`
- `li_DrainBody`
- `li_Charge`

### 可选 branch 变量

如果指定初始条件，还可能额外出现：

- `li_Ibs`
- `li_Ids`
- `li_Igs`

这一步最重要的认识是：

```text
B4 的“未知量个数”不是固定常数，
而是会随着 rgateMod、rbodyMod、trnqsMod、初始条件选项一起膨胀
```

这就是它为什么不能只按“一个四端器件”去想。

## 第三步：这些开关为什么这么关键

在头文件和构造函数里，有三个特别值得记住的模式开关：

- `rgateMod`
- `rbodyMod`
- `trnqsMod`

它们几乎就是 `B4` 结构复杂度的三个总开关。

### 1. `rgateMod`

决定 gate 电阻网络怎么建。

它会影响：

- 是否需要 `GatePrime`
- 是否需要 `GateMid`

所以一旦 `rgateMod` 打开，gate 就不再只是一个单节点。

### 2. `rbodyMod`

决定 body 电阻网络是否显式展开。

它会影响：

- `BodyPrime`
- `SourceBody`
- `DrainBody`

这会让 bulk/body 一侧从一个简单端口，扩展成一个更复杂的内部子网络。

### 3. `trnqsMod`

决定是否启用 NQS（non-quasi-static）相关附加未知量。

它会影响：

- `Charge`

这非常重要，因为它直接说明：

```text
在复杂 compact model 里，“charge” 本身都可能被提升成显式内部未知量
```

这一步已经开始把前面 `Q/dQdx` 的概念推向更复杂形式了。

## 第四步：构造函数里其实已经在搭“方程规模”

再看 `Instance::Instance(...)` 附近，会看到一批非常关键的初始化：

- `numIntVars`
- `numExtVars`
- `numStateVars`
- `setNumBranchDataVars(...)`

其中一组特别值得记住：

- `numExtVars = 4`
- `numIntVars = 3`
- `numStateVars = 17`

这个默认值本身就已经在说明：

```text
即使在最基础配置下，
B4 也远不是“只有外部四个电压变量”的小器件
```

而且这些数值后面还会因为选项继续加大。

所以第一轮最重要的直觉是：

```text
复杂 compact model 的负担，
从“变量个数”这一层就已经开始了
```

## 第五步：Jacobian stamp 为什么是理解 B4 的第一锚点

继续看构造函数里 `jacStamp` 的建立逻辑。

这里最值得先抓住的不是每个位置具体含义，而是：

- 它先搭了一个比较大的“完整图”
- 然后再根据选项把一些可选节点 remap / 折叠掉

这是一种很典型的工程写法：

```text
先按最全结构建 stamp，
再按实例配置裁剪
```

所以这里的阅读重点不是背所有 `jacStamp[i][j]`，而是先建立这两个结论：

1. `B4` 的 Jacobian stamp 从一开始就是多行多列的大块结构  
2. 这个大块结构会随可选节点裁剪变化

这和 resistor / capacitor / diode 那种“小而稳定的 stamp”非常不一样。

## 第六步：为什么 `jacMap / jacMap2` 也很重要

在 `B4` 这里，仅仅有 `jacStamp` 还不够，还额外有：

- `jacMap`
- `jacMap2`

这说明作者不仅在记录“有哪些非零位置”，还在记录：

```text
当前实例配置下，
原始完整 stamp 如何映射到实际保留下来的 stamp
```

也就是说，`B4` 的矩阵位置管理不是一个固定表，而是：

- 先有原始完整模板
- 再根据选项映射到实际实例结构

这一步你可以先把它理解成：

```text
为可裁剪的大型 stamp 准备的索引翻译层
```

这也是 `registerJacLIDs(...)` 看起来特别长的根本原因之一。

## 第七步：为什么 `registerJacLIDs(...)` 会长得像“矩阵目录表”

继续看：

- `registerJacLIDs(...)`

你会发现这里几乎像在做一件机械但很关键的事：

- 把 `jacLIDVec` 里返回的每个 offset
- 绑定到大量名字上

例如：

- `Dd`
- `Ddp`
- `GEge`
- `SPsp`
- `BPbp`
- `Qq`
- `IDSd`
- `IGSg`

这一层的本质不是“数值计算”，而是：

```text
把抽象的 Jacobian 位置，
翻译成后面装配代码能直接使用的命名偏移
```

所以这一步的意义非常像前面简单器件里的：

- `APosEquPosNodeOffset`
- `ANegEquNegNodeOffset`

只是到了 `B4`，这个映射表规模暴涨了。

## 第八步：state 和 store 向量也不能忽略

除了 solution vector 和 Jacobian，`B4` 还有大量：

- `state`
- `store`
- `branch data`

在：

- `registerStateLIDs(...)`
- `registerStoreLIDs(...)`
- `registerBranchDataLIDs(...)`

里能看到它们。

这一步最重要的认识是：

### `state`

更偏动态相关状态量，比如：

- `qb`
- `qg`
- `qd`
- `qbs`
- `qbd`
- `qcheq`

### `store`

更偏调试、输出、辅助保存的工作点/小信号信息，比如：

- `Vds`
- `Vgs`
- `Vbs`
- `gm`
- `Gds`
- `Cgs`
- `Cgd`

### `branch data`

更偏 lead current / branch 输出相关量。

也就是说，`B4` 不只是“方程块大”，它还会在周边数据结构里留下大量辅助轨迹。

## 第九步：为什么 `setupPointers()` 也值得先看

如果你读到 `setupPointers()`，会发现它在做一件很直白的事：

- 把大量 `f_*Ptr`
- `q_*Ptr`

直接指向 `dFdx` / `dQdx` 里的具体位置

这一步的意义是：

```text
一旦 unknowns 和 jacobian offsets 建好，
后面的装配层就可以直接按这些指针往矩阵里写
```

所以你现在不需要把所有指针名背下来，但要先记住：

```text
registerLIDs / registerJacLIDs / setupPointers
这三步是在为后面真正的 F/Q/Jacobian 装配铺路
```

## 把 B4 的“结构地图”压缩成一句顺序

现在可以把这一轮最重要的结构主线记成：

1. `Traits`
   - 说明这是四端、非线性、必须有 model 的 `M` 器件
2. `Instance::Instance(...)`
   - 先确定默认规模和完整 stamp 模板
3. `registerLIDs(...)`
   - 决定当前实例实际有哪些外部/内部/branch 未知量
4. `registerStateLIDs(...)` / `registerStoreLIDs(...)`
   - 绑定动态状态和辅助存储
5. `registerJacLIDs(...)`
   - 把 Jacobian 的抽象位置翻译成大量命名 offset
6. `setupPointers()`
   - 把这些 offset 进一步变成可直接写矩阵的指针

只要这条主线吃下来了，后面看 `F/Q/dFdx/dQdx` 时就不会觉得那些装配代码是“凭空往矩阵某处乱写”。

## 这一篇最想让你记住的 4 句话

1. `B4` 的复杂度，从未知量层面就已经远高于前面简单器件。
2. 它不是“4 个端口 = 4 个未知量”，而是“4 个外部端口 + 一批可选内部结构”。
3. `jacobianStamp + jacMap + jacMap2` 是理解它矩阵结构的核心。
4. 后面的 `F/Q` 装配，都是建立在这一整套 unknown / offset / pointer 地图之上的。

## 下一步最自然该去哪里

现在这层结构地图已经有了，下一步最自然的是：

- `07-mosfet-b4-f-and-dfdx.md`

也就是先只看：

```text
这个大器件如何把电流侧贡献装进 F 和 dFdx
```

把 `Q/dQdx` 先留到再下一篇。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `B4` 的困难，不只是公式多，而是它连未知量结构本身都比简单器件复杂很多？
2. 为什么在进入 `F/Q` 装配之前，先建立 `registerLIDs -> registerJacLIDs -> setupPointers` 这条地图特别重要？
