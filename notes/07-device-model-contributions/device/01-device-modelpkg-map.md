# DeviceModelPKG 地图

记录日期：2026-06-04

## 这篇的定位

这一篇先不进入某个具体器件公式，而是先把 `DeviceModelPKG` 的目录地图建立起来。

如果后面你再看到一个陌生文件，比如：

- `N_DEV_IBIS.C`
- `N_DEV_ExternDevice.C`
- `N_DEV_ADMSbsim6.C`

第一件事不应该是直接读公式，而应该先判断：

```text
它属于哪个模型家族？
这个家族在 Xyce 里是干什么的？
它是常规 compact model，还是某种专门扩展？
```

## 建议的代码入口顺序

这一篇建议按下面顺序看代码路径：

1. 先看 [DeviceModelPKG](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG)
2. 再看 [OpenModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/CMakeLists.txt)
3. 然后再看：
   - [ADMS](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/ADMS)
   - [IBISModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/IBISModels)
   - [NeuronModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/NeuronModels)
   - [TCADModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/TCADModels)
   - [EXTSC](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/EXTSC)

这个顺序的逻辑是：

```text
先看总目录
-> 再看最常规的器件实现家族
-> 最后再看各种扩展模型家族
```

## DeviceModelPKG 下面主要有哪些目录

从 [DeviceModelPKG](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG) 可以直接看到 7 个核心子目录：

- `Core`
- `OpenModels`
- `ADMS`
- `IBISModels`
- `NeuronModels`
- `TCADModels`
- `EXTSC`

可以先把它们粗分成两层。

### 第一层：基础设施层

- `Core`

这一层更像器件系统的公共骨架，放的是：

- `Device`
- `DeviceMgr`
- `DeviceMaster`
- 参数系统
- 注册系统
- `F/Q/dFdx/dQdx` 接口

也就是说，`Core` 更偏“器件框架”，不是具体器件家族。

### 第二层：具体模型家族

- `OpenModels`
- `ADMS`
- `IBISModels`
- `NeuronModels`
- `TCADModels`
- `EXTSC`

这些目录才是真正“各种器件和模型实现”所在的地方。

## 为什么应该先看 OpenModels

如果你要先建立对 Xyce 器件系统的直觉，最值得先看的还是 [OpenModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/CMakeLists.txt)。

原因很简单：

- 这里集中放了最常见、最典型的手工实现器件
- 你前面精读过的 `Capacitor`、`Diode`、`MOSFET_B4` 都在这里
- 代码结构通常最直接体现 Xyce 自己的 `Traits / Model / Instance / Master` 风格

这一层里能直接看到很多常见器件：

- `Resistor`
- `Capacitor`
- `Inductor`
- `Diode`
- `BJT`
- `JFET`
- `MESFET`
- `MOSFET1/2/3/6`
- `MOSFET_B3`
- `MOSFET_B4`
- `Vsrc`
- `ISRC`
- `ADC`
- `DAC`
- `Digital`

如果只压缩成一句话：

```text
OpenModels 是理解 Xyce 器件系统最自然的入口家族。
```

## 其余目录应该先怎么理解

看完 `OpenModels` 之后，再把其它目录当作“特定方向扩展”去理解会更顺。

- `ADMS`
  - 一批通过模型生成路线接入的 compact model
- `IBISModels`
  - 面向高速 I/O / buffer 行为模型
- `NeuronModels`
  - 面向神经动力学与突触系统
- `TCADModels`
  - 面向器件内部 PDE / 网格离散
- `EXTSC`
  - 面向外部代码、外部求解器耦合

也就是说，`OpenModels` 回答的是：

```text
Xyce 自己怎样直接实现一个器件
```

而后面这些目录更像在回答：

```text
Xyce 怎样支持不同领域、不同来源、不同层级的模型
```

## 这一篇最想让你先吃下来的本质

以后看到 `DeviceModelPKG` 下面一个陌生文件时，建议先问这两个问题：

1. 它属于哪个目录家族？
2. 这个目录家族是在扩展“器件类型”，还是在扩展“模型接入方式”？

只要先把这两个问题问清楚，后面读代码就不会一上来迷路。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `OpenModels` 比 `ADMS` 或 `TCADModels` 更适合作为第一次理解 Xyce 器件系统的入口？
2. `DeviceModelPKG/Core` 和 `DeviceModelPKG/OpenModels` 的角色，本质上有什么不同？
