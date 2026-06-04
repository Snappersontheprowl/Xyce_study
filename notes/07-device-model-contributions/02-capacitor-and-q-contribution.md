# capacitor and q contribution

记录日期：2026-06-04

## 这次读了哪些文件

这次不直接从 `capacitor` 的公式开始，而是按“solver 看到的接口 -> device manager 调用 -> capacitor 自己如何实现”的顺序读了这些文件：

- [src/DeviceModelPKG/Core/N_DEV_Device.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_Device.h)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMgr.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.h)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C)
- [src/DeviceModelPKG/OpenModels/N_DEV_Capacitor.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Capacitor.h)
- [src/DeviceModelPKG/OpenModels/N_DEV_Capacitor.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Capacitor.C)

## 这次带着什么问题去读

这一篇只回答一个核心问题：

```text
solver 在 transient 里反复使用的 Q 和 dQdx，
到了器件层到底是谁写出来的？
```

更具体一点，就是：

- 为什么说 capacitor 是学习 `Q/dQdx` 的最好入口？
- 它在总方程里到底贡献什么，为什么几乎不贡献普通的 `F`？
- `Model`、`Master`、`Instance` 在这个器件里怎么分工？
- `qVec` 和 `dQdx` 分别在哪一步被真正写进去？
- 为什么 `IC=` 这个选项会让 capacitor 在 DC 下看起来像“临时电压源”？

## 当前结论先写在前面

如果只压成一句话，capacitor 最值得你现在抓住的本质是：

$$
q_0 = C \, (V_+ - V_-)
$$

而 Xyce 不直接把“电容电流”写进器件代码里，而是把：

$$
q_0
$$

写进 `Q` 向量，把：

$$
\frac{\partial q_0}{\partial x}
$$

写进 `dQdx`，然后把“求时间导数”这件事留给 time integration 层去做。

也就是说，capacitor 这一层真正做的是：

```text
提供 charge 及其对未知量的导数
```

而不是：

```text
自己直接算最终的 dQ/dt 电流项
```

这和你前面在 [04-transient-time-discretization-and-solving.md](../06-solver-and-assembly/04-transient-time-discretization-and-solving.md) 里学到的：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

正好能接上。

## 第一步：先从通用 device 接口看，solver 到底向器件要什么

先看：

- [N_DEV_Device.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_Device.h)

这里最关键的不是某个具体实现，而是两个通用接口：

- `loadDAEVectors(...)`
- `loadDAEMatrices(...)`

而注释已经把约束写得很清楚：

- 先 `loadDAEVectors`
- 再 `loadDAEMatrices`

这说明在 Xyce 里，器件层和 solver 层之间的约定不是：

```text
“给我一个电流值”
```

而是：

```text
“给我 Q/F/B 这些向量贡献”
“再给我 dQdx/dFdx 这些矩阵贡献”
```

所以当我们接下来去看 capacitor 时，脑子里就要一直带着这个问题：

```text
它实现这两个接口时，到底主要在写哪一部分？
```

## 第二步：再看 DeviceMgr 是怎样把这个接口统一调起来的

接着看：

- [N_DEV_DeviceMgr.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.h)
- [N_DEV_DeviceMgr.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C)

这里要抓的不是所有细节，而是总调用骨架。

### 1. 先更新状态

`DeviceMgr::updateState(...)` 先把：

- `nextSol`
- `state`
- `store`

这些当前步相关向量挂到 `externData_` 里，然后调用每个 device 的：

- `updateState(...)`

对 capacitor 来说，这一步的真正意义是：

```text
先根据当前解向量，算出这一步的 q0、vcap，以及必要的历史状态
```

也就是说，真正写 `Q` 之前，器件已经先把“这一时刻的内部物理量”准备好了。

### 2. 再装向量

`DeviceMgr::loadDAEVectors(...)` 会把：

- `daeQ`
- `daeF`
- `daeB`

这些向量指针挂进去，然后循环调用每个 device 的：

- `loadDAEVectors(...)`

### 3. 最后装矩阵

`DeviceMgr::loadDAEMatrices(...)` 会把：

- `dQdx`
- `dFdx`

挂进去，然后循环调用每个 device 的：

- `loadDAEMatrices(...)`

所以从大链路上看，capacitor 并不是直接“把最终 residual 写出来”，而是按这条顺序参与：

$$
\text{updateState}
\rightarrow
\text{loadDAEVectors}
\rightarrow
\text{loadDAEMatrices}
$$

这就是它和 solver 之间最基本的接口边界。

## 第三步：再看 capacitor 自己把自己声明成什么样的器件

现在才进入：

- [N_DEV_Capacitor.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Capacitor.h)

这里最值得先看的，是 `Traits`。

### Traits 先告诉我们三件关键事

1. 这是一个两端器件

```cpp
static int numNodes() {return 2;}
```

2. 它的主参数是 `C`

```cpp
static const char *primaryParameter() {return "C";}
```

3. 在默认意义下它被看成线性器件

```cpp
static bool isLinearDevice() {return true;}
```

这三点很重要，因为它们让我们先有一个非常稳定的心理模型：

```text
一个最基本的 capacitor，
本质上就是一个两端、以 C 为主参数、通过 charge 进入方程的线性动态器件
```

## 第四步：先看它为什么是“动态器件”

在 `Instance` 的成员里，最关键的不是一大堆参数名，而是这些变量：

- `double C`
- `double Q`
- `double q0`
- `double vcap`
- `int li_QState`

这几个名字已经在暗示：

- 它关心电压差 `vcap`
- 它关心电荷 `q0`
- 它还需要状态量保存与电荷相关的历史信息

所以和 resistor 相比，capacitor 最本质的区别已经出现了：

```text
resistor 的核心是“当前电压 -> 当前导通电流”
capacitor 的核心是“当前电压 -> 存储电荷”
```

而 transient 里真正出现的电流，是：

$$
i_C = \frac{dq_0}{dt}
$$

这也解释了为什么 capacitor 的学习重点应该放在 `Q/dQdx`，而不是先盯 `F/dFdx`。

## 第五步：从构造函数开始，看它为什么要提前准备 Jacobian stamp

接着看：

- [N_DEV_Capacitor.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Capacitor.C)
  里 `Instance::Instance(...)`

这里有一大段非常值得认真看的注释，因为它几乎把 capacitor 的 DAE 含义直接讲出来了。

最关键的几句话可以压缩成下面这个逻辑。

### 最简单的 capacitor

如果电容是常数，那么：

$$
q_0 = C (V_+ - V_-)
$$

于是 Xyce 在 `Q` 向量里放的是：

$$
\begin{aligned}
Q_{pos} &+= q_0 \\
Q_{neg} &+= -q_0
\end{aligned}
$$

而不是直接放电流。

对应的 `dQdx` 就是：

$$
\frac{\partial q_0}{\partial (V_+,V_-)}
=
\begin{bmatrix}
C & -C \\
-C & C
\end{bmatrix}
$$

这就是一个最标准、最值得你现在记住的动态器件例子。

### 为什么 constructor 里就要管 Jacobian stamp

因为 capacitor 还有两个额外复杂点：

1. 可能有 `IC=...`
2. 可能有 solution-dependent 的 `C` 或直接给 `Q` 表达式

这会改变它在 Jacobian 里的非零结构，所以它不像简单 resistor 那样能一直复用一个完全固定的最小 stamp。

这一步你不用一次吃透所有分支，但一定要先记住：

```text
capacitor 的矩阵形状，不只是由“两端器件”决定，
还会被 IC 和 solution-dependent C/Q 这些功能影响
```

## 第六步：再看 updateState，q0 是在哪里真正算出来的

接着顺着 `DeviceMgr::updateState(...)` 这条线，看：

- `Instance::updatePrimaryState()`
- `Master::updateState(...)`

### 简单常数电容的核心公式

对于最基础、最值得当前阶段先抓住的情况，代码最终做的就是：

$$
v_{cap} = V_+ - V_-
$$

然后：

$$
q_0 = C \, v_{cap}
$$

也就是说，这一步不是在写矩阵，而是在得到：

```text
“当前这个 capacitor 在当前解点下，存了多少电荷”
```

这是后面 `loadDAEVectors` 和 `loadDAEMatrices` 的前提。

### 为什么这一步要先于 load

因为 `load` 只负责把已经算好的物理量写到总向量和总矩阵里。  
如果不先更新状态，就不会有当前步的：

- `vcap`
- `q0`
- 以及 solution-dependent 情况下的导数信息

所以现在这条链你可以先记成：

$$
\text{current solution } x_n
\rightarrow
v_{cap}
\rightarrow
q_0
\rightarrow
\text{write into } Q \text{ and } dQdx
$$

## 第七步：再看 loadDAEVectors，capacitor 到底往哪个向量里写东西

现在进入最关键的一步：

- `Master::loadDAEVectors(...)`

这里一定要先抓住一个很重要的事实：

```text
对 capacitor 来说，正常情况下最重要的贡献是 Q，不是 F
```

代码里最核心的两句就是：

$$
Q_{pos} += q_0
$$

$$
Q_{neg} += -q_0
$$

它对应的代码就是把：

- `qVec[li_Pos] += q0`
- `qVec[li_Neg] += -q0`

写进去。

### 这一步的数学含义

这不是在说 capacitor “没有电流”，而是在说：

```text
电流来自后面的 dQ/dt，
不是器件层直接在这里手写一个最终的瞬态电流值
```

所以如果把它和第六阶段的 transient 笔记对上，这一步其实是在给：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

里的第一项供货。

## 第八步：为什么说 capacitor “几乎不写 F”

如果只看最普通的 transient 或 DC 稳态而没有额外选项，capacitor 的主要贡献不在 `F`。

这里有个很重要的例外：

- 如果实例线上写了 `IC=...`

那么在 DC operating point 阶段，Xyce 会把这个 capacitor 临时当作“带 branch equation 的约束器件”来处理。

### 数学直觉

因为纯电容在 DC 下本来不会导 steady-state current，但如果用户又要求：

```text
初始电压必须等于 IC
```

那系统就必须在 operating point 阶段额外加一个约束，把：

$$
V_+ - V_- = IC
$$

强行建立起来。

这就是为什么 capacitor 在 `IC` 场景下会出现：

- 额外 branch variable
- 额外 `F`
- 额外 `dFdx`

换句话说：

```text
普通 capacitor 的主战场是 Q/dQdx
但带 IC 的 capacitor 在 DCOP 下会暂时多出一个 F/dFdx 约束分支
```

这一步很有代表性，因为它说明：

**器件的方程贡献，不只是由物理器件类型决定，也会被仿真语义选项改变。**

## 第九步：再看 loadDAEMatrices，dQdx 到底是怎样写进去的

然后看：

- `Master::loadDAEMatrices(...)`

对于最简单常数电容，最本质的矩阵贡献就是：

$$
dQdx \; += \;
\begin{bmatrix}
C & -C \\
-C & C
\end{bmatrix}
$$

这一步非常关键，因为它直接说明了：

```text
transient Jacobian 里那部分“像电容一样”的项，
并不是 time integrator 凭空造出来的，
而是器件先把 dQdx 提供出来，
再由 time integration 把它乘上时间离散系数
```

也就是说，你前面在 `06` 里看到的：

$$
J_n \approx \frac{\alpha_0}{\Delta t}\frac{\partial Q}{\partial x}(x_n) + \frac{\partial F}{\partial x}(x_n)
$$

这里的：

$$
\frac{\partial Q}{\partial x}(x_n)
$$

对于简单 capacitor，正是由这一步给出来的。

这就是为什么我一直说：

```text
capacitor 是把 transient 里 Q/dQdx 真正落地的最好器件
```

## 第十步：为什么要特别注意“Master 重载了 load，而不是靠 Instance 默认逐个调用”

这一点是读 Xyce 器件代码时非常容易被忽略的。

在 capacitor 这个器件里，注释反复提醒：

- `Master::loadDAEVectors(...)` 被重写了
- `Master::loadDAEMatrices(...)` 被重写了

所以虽然 `Instance::loadDAEQVector()`、`Instance::loadDAEdQdx()` 这些函数也存在，

**但常见主路径上，真正被调用的是 `Master` 里的循环版本。**

这件事很重要，因为如果你后面自己追代码时只盯 `Instance::load...`，很容易误以为那就是实际运行路径。

对 capacitor，这里的正确理解应该是：

```text
Instance 负责定义单个器件该怎么算
Master 负责在真实执行路径上批量循环所有 instances，把贡献写进总向量和总矩阵
```

这也是 Xyce 里性能和结构之间的一种平衡方式。

## 把这条 capacitor 主线压缩成一条连续路径

你现在可以把这条主线记成：

1. [N_DEV_Device.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_Device.h)
   定义所有器件都要实现的 `loadDAEVectors / loadDAEMatrices`
2. [N_DEV_DeviceMgr.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C)
   在 `updateState -> loadDAEVectors -> loadDAEMatrices` 这个顺序里统一调度所有 devices
3. [N_DEV_Capacitor.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Capacitor.h)
   `Traits`、`Instance`、`Master` 说明这是一个以 `C` 为主参数的两端动态器件
4. [N_DEV_Capacitor.C](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Capacitor.C)
   `updatePrimaryState()` 先根据当前解算出：

   $$
   q_0 = C (V_+ - V_-)
   $$

5. 同一个文件里的 `Master::loadDAEVectors(...)`
   把：

   $$
   +q_0,\; -q_0
   $$

   写进 `Q`
6. 同一个文件里的 `Master::loadDAEMatrices(...)`
   把：

   $$
   \frac{\partial Q}{\partial x}
   =
   \begin{bmatrix}
   C & -C \\
   -C & C
   \end{bmatrix}
   $$

   写进 `dQdx`
7. 再往上才由 time integration 把它变成每一步的：

   $$
   \frac{dQ}{dt}
   $$

   相关 residual / Jacobian 项

## 这一篇最想让你真正吃下来的本质

对于 capacitor，器件层和 solver 层之间最关键的分工是：

- 器件层负责：

  $$
  Q(x), \quad \frac{\partial Q}{\partial x}
  $$

- time integration / solver 层负责：

  $$
  \frac{dQ(x)}{dt}
  $$

  以及把它和 `F-B` 组合成最终 residual / Jacobian

所以以后你只要看到“一个动态器件”，第一反应就应该是：

```text
它到底怎样提供 Q 和 dQdx？
```

而不是先问：

```text
它的电流公式怎么直接写进 residual？
```

## 下一步为什么应该看 diode

现在 `capacitor` 已经帮你把 `Q/dQdx` 这半边打通了。  
下一步最自然的是去看 `diode`，原因很简单：

- `capacitor` 让你看懂“动态项从哪里来”
- `diode` 会让你看懂“真正非线性的 `F/dFdx` 从哪里来”

这样两边一合起来，你对“器件如何供货给 solver”就会完整很多。

## 现在可以做的自检

你可以先试着回答这三个问题：

1. 为什么说 capacitor 这一层主要是在提供 `Q/dQdx`，而不是直接提供最终的瞬态电流？
2. 为什么 `dQdx` 对 transient Jacobian 很重要，但它本身还不是 time-discretized Jacobian？
3. `IC=` 为什么会让 capacitor 在 DCOP 场景下额外出现 `F/dFdx` 一侧的贡献？
