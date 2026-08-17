# diode and nonlinear f

记录日期：2026-06-04

## 这次读了哪些文件

这次继续沿着和 capacitor 相同的总调用链往下走，但把重点从 `Q/dQdx` 换成 nonlinear `F/dFdx`。按“器件接口 -> diode 自己的状态变量 -> F / dFdx 装配”的顺序读了这些文件：

- [src/DeviceModelPKG/Core/N_DEV_Device.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_Device.h)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C)
- [src/DeviceModelPKG/OpenModels/N_DEV_Diode.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Diode.h)
- [src/DeviceModelPKG/OpenModels/N_DEV_Diode.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Diode.C)

## 这次带着什么问题去读

这一篇只追一个核心问题：

```text
solver 在 Newton 里每次都要重建的 nonlinear F 和 dFdx，
到了器件层，diode 是怎么把它们写出来的？
```

更具体一点，就是：

- 为什么 diode 是理解 nonlinear `F/dFdx` 的最好入口？
- 它的主要未知量关系到底是什么？
- `Id`、`Gd`、`Qd`、`Cd` 分别代表什么？
- 为什么这篇重点放在 `F/dFdx`，但 diode 又并不是“完全没有 Q”？
- 它的 nonlinear 性是在哪一步真正进入 Newton 的？

## 当前结论先写在前面

如果只压成一句话，diode 最值得你现在抓住的本质是：

```text
它把当前工作点下的电流 Id 和小信号导数 Gd 供给 F/dFdx，
这正是 Newton 每次迭代都要重新线性化的那一部分
```

数学上，你可以先把最简化的 diode 想成：

$$
I_d = I_s \left(e^{V_d/(nV_T)} - 1\right)
$$

于是它最核心的 Jacobian 信息就是：

$$
G_d = \frac{\partial I_d}{\partial V_d}
$$

而 Xyce 做的事情，并不是只把这个公式“翻译成 C++”，而是把：

- 当前工作点下的 `Id`
- 当前工作点下的 `Gd`

写进总方程需要的：

- `F`
- `dFdx`

所以这篇和上一篇 capacitor 的对应关系可以先记成：

- capacitor：重点是 `Q/dQdx`
- diode：重点是 nonlinear `F/dFdx`

## 第一步：先从 Traits 看，这个器件和 capacitor 有什么最本质的不同

先看：

- [N_DEV_Diode.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Diode.h)

最值得先抓的一句是：

```cpp
static bool isLinearDevice() {return false;}
```

这句话的意义比看一大串参数更重要，因为它直接告诉你：

```text
diode 不是“矩阵系数固定”的器件，
而是一个工作点相关的 nonlinear device
```

也就是说，你不能像看 resistor 那样只记一个固定系数，也不能像看最简单 capacitor 那样只记一个固定 `C`。  
每次 Newton 到达新的 `x_k`，diode 的：

- 电流
- 导数

都可能变化。

## 第二步：再看 diode 的内部物理量，为什么要盯 `Id/Gd/Qd/Cd`

继续看 `Instance` 的成员和实现，你会发现这几个量反复出现：

- `Id`
- `Gd`
- `Qd`
- `Cd`
- `Gspr`

对当前阶段，最重要的理解是：

### 1. `Id`

当前工作点下，这个 diode 的导通电流贡献。

### 2. `Gd`

当前工作点下，diode 电流对电压的导数，也就是：

$$
G_d = \frac{\partial I_d}{\partial V_d}
$$

这正是 Newton 线性化时最想要的量。

### 3. `Qd`

结电荷或与 diode 动态行为相关的 charge 量。

### 4. `Cd`

`Qd` 对电压的导数，也就是等效小信号电容：

$$
C_d = \frac{\partial Q_d}{\partial V_d}
$$

### 5. `Gspr`

串联电阻等效带来的导通项，用来构成 `Pos` 到 `Pri` 的那部分导数关系。

这一步最重要的认识是：

```text
diode 虽然这篇重点是 F/dFdx，
但它其实不是“只有电流，没有电荷”的器件。
它同时也能对 Q/dQdx 供货。
```

这点很关键，因为它说明真实器件往往不是“只属于 F 或只属于 Q”，而是两边都可能有，只是某一边更适合作为当前学习重点。

## 第三步：先看 updatePrimaryState，当前工作点下的 nonlinear 量是在哪里算出来的

接着看：

- [N_DEV_Diode.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Diode.C)
  里的 `Instance::updatePrimaryState()`

这一步本身不展开大段公式，而是调用：

- `updateIntermediateVars()`

然后把计算结果存下来：

- `Vd`
- `Qd`
- `Cd`

以及前面已经定义好的：

- `Id`
- `Gd`

从学习角度看，这一步最重要的不是马上吃透所有半导体公式，而是先建立一个非常重要的节奏感：

$$
x_k
\rightarrow
\text{updateIntermediateVars}
\rightarrow
(Id, Gd, Qd, Cd, \ldots)
\rightarrow
\text{load into } F,Q,dFdx,dQdx
$$

也就是说，器件层和 solver 的配合模式是：

1. 先基于当前解向量计算中间物理量
2. 再把这些量写进全局方程对象

这和 capacitor 的 `q0` 是同一种结构，只是 diode 的中间量更多，而且 nonlinear 得多。

## 第四步：为什么说 diode 的主战场是 nonlinear `F/dFdx`

现在进入最关键的部分。

在：

- `Master::loadDAEVectors(...)`

里，diode 的 `F` 侧装配是最值得先看的。

### 核心量是 `Id`

代码里最醒目的几句是：

- 正节点方程里写入和串联导通有关的 `Ir`
- 负节点方程里写入 `Id`
- `Pri` 节点方程里写入 `-Id + Ir`

如果不纠结所有符号细节，先抓住最本质的一句话：

```text
diode 把当前工作点下的非线性导通电流 Id，
分配到对应的 KCL 方程里
```

也就是说，`F` 向量这一侧真正承载的是：

$$
\text{current balance}
$$

而 diode 最典型的非线性，就体现在这里。

### 为什么这正好对应 Newton 要解的东西

前面在 solver 专题里你已经看到，Newton 每一步都在解：

$$
J(x_k)\,\Delta x_k = -f(x_k)
$$

其中 $f(x_k)$ 的一大块来源，就是 $F(x_k)$。

所以 diode 对 `F` 的贡献，实际上就是：

```text
把当前工作点下的 nonlinear current residual
交给总方程
```

## 第五步：再看 dFdx，为什么它就是 nonlinear 器件送给 Newton 的“线性化信息”

然后看：

- `Master::loadDAEMatrices(...)`
- `Instance::loadDAEdFdx()`

这里最值得抓的是 `Gd` 的角色。

对最简化的二极管直觉来说：

$$
G_d = \frac{\partial I_d}{\partial V_d}
$$

这就是在当前工作点把非线性电流近似成局部线性关系时的斜率。

而代码里正是在把这个斜率装进 `dFdx`：

- `Neg` 行里有 `+Gd`
- `Pri` 行里有 `-Gd` 或相关平衡组合

所以从数学上看，`dFdx` 这一步做的事情就是：

```text
把当前工作点附近的“局部斜率信息”写进 Jacobian
```

这正是 Newton 为什么每次迭代都必须重新装配 diode Jacobian 的原因。

因为如果 `x_k` 变了，那么：

- `Vd` 会变
- `Id` 会变
- `Gd` 也会变

所以和 resistor 不一样，diode 的 Jacobian 不是“一次建好一直用”的固定矩阵块。

## 第六步：为什么这篇重点是 F/dFdx，但你不能误以为 diode 没有 Q

这是非常值得专门强调的一点。

在同一个 `Master::loadDAEVectors(...)` 和 `Master::loadDAEMatrices(...)` 里，你还能看到：

- `qVec` 里写入 `Qd`
- `dQdx` 里写入 `Cd`

也就是：

$$
Q_d
$$

和

$$
C_d = \frac{\partial Q_d}{\partial V_d}
$$

这说明真实 diode 不是一个“纯静态电流器件”，它还带结电容和 transit time 相关动态项。

但为什么这篇仍然把重点放在 `F/dFdx`？

因为从学习顺序上，现在最重要的是先建立：

```text
非线性电流 residual 是如何进入 Newton 的
```

这一层理解。

而 diode 同时带 `Q/Cd`，反而是个好提醒：

```text
现实器件常常同时有静态非线性和动态储能两面，
只是我们可以分阶段去抓主矛盾
```

## 第七步：再看 updateIntermediateVars，为什么说器件模型代码不是“只抄公式”

往下看 `N_DEV_Diode.C` 里大量出现的：

- `applyLimiters`
- `updateTemperature`
- `updateIntermediateVars`

以及里面对：

- breakdown
- gmin
- series resistance
- depletion capacitance
- transit time

这些因素的处理，就会发现一个很重要的事实：

器件代码不是简单把：

$$
I = I_s(e^{V/V_T}-1)
$$

敲成 C++ 就结束了。

它还必须同时满足：

1. 物理/经验模型上讲得通
2. 数值上在 Newton 里能收敛
3. 在极端偏置下不至于炸掉
4. 在 DC 和 transient 下都能给出一致的 `F/Q/Jacobian` 贡献

这也是为什么 diode 特别适合作为“从公式走向仿真器实现”的第一站。

它足够简单，能看懂主线；  
但又足够真实，已经能看到：

- limiting
- 小信号导数
- 动态 charge
- 温度修正

这些仿真器实现里非常关键的工程因素。

## 第八步：把这条 diode 主线压缩成一条连续路径

你现在可以把这条主线记成：

1. [N_DEV_Device.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_Device.h)
   定义所有器件都要交出的 `Q/F/B/dQdx/dFdx` 接口
2. [N_DEV_DeviceMgr.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C)
   用统一顺序调用：

   $$
   \text{updateState}
   \rightarrow
   \text{loadDAEVectors}
   \rightarrow
   \text{loadDAEMatrices}
   $$

3. [N_DEV_Diode.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Diode.h)
   `Traits` 明确告诉你这不是线性器件
4. [N_DEV_Diode.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Diode.C)
   `updateIntermediateVars()` / `updatePrimaryState()` 先根据当前工作点得到：

   $$
   Id,\; Gd,\; Qd,\; Cd
   $$

5. 同一个文件里的 `Master::loadDAEVectors(...)`
   把 `Id` 主要写进 `F`，把 `Qd` 写进 `Q`
6. 同一个文件里的 `Master::loadDAEMatrices(...)`
   把 `Gd` 主要写进 `dFdx`，把 `Cd` 写进 `dQdx`
7. 再往上，Newton 每一步就用这些当前工作点下的量来形成新的 residual 和 Jacobian

## 这一篇最想让你真正吃下来的本质

对 diode 来说，最重要的不是“背指数公式”，而是先理解这件事：

```text
nonlinear device 的关键任务，
是把当前工作点下的残差值和局部斜率值，
提供给 Newton
```

也就是说：

- `Id` 更像当前点上的 nonlinear residual 构件
- `Gd` 更像当前点上的局部线性化信息

这正是为什么 diode 比 resistor 更适合拿来理解 Newton。

## 为什么这篇和 capacitor 那篇是互补关系

你现在可以把这两篇合在一起看：

- [02-capacitor-and-q-contribution.md](02-capacitor-and-q-contribution.md)
  - 重点：动态项从哪里来
  - 核心对象：`Q/dQdx`
- [03-diode-and-nonlinear-f.md](03-diode-and-nonlinear-f.md)
  - 重点：非线性电流和局部导数从哪里来
  - 核心对象：`F/dFdx`

这样再往后看 MOS 时，你就不会被它“同时很非线性、又同时有大量电荷项”一下压住。

## 下一步最自然该学什么

现在最自然的下一步不是立刻去啃完整 MOS，而是先做一份“总结合流”的笔记：

- 把 resistor / capacitor / diode 放在一起对照
- 总结不同器件如何分别贡献：
  - `F`
  - `Q`
  - `dFdx`
  - `dQdx`

也就是把：

```text
器件公式
-> 向量项
-> 矩阵项
-> solver 所见方程
```

再做一次抽象总结。

## 现在可以做的自检

你可以先试着回答这三个问题：

1. 为什么 diode 很适合作为理解 nonlinear `F/dFdx` 的入口？
2. 为什么说 `Gd` 对 diode 的意义，和 `Cd` 对动态部分的意义，有点像“电流侧斜率”和“电荷侧斜率”的对应关系？
3. 为什么真实 diode 代码比课本上的指数公式复杂得多？
