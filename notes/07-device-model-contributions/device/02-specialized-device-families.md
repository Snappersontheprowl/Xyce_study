# 专用模型家族速览

记录日期：2026-06-04

## 这篇的定位

这一篇承接上一页的目录地图，专门把几类“不是常规晶体管级 compact model”的模型家族做一个够用介绍。

建议的阅读顺序仍然保持从通用到专用：

1. 先从 [OpenModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels) 里看混合信号接口
2. 再看 [IBISModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/IBISModels)
3. 再看 [NeuronModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/NeuronModels)
4. 再看 [TCADModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/TCADModels)
5. 最后看 [EXTSC](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/EXTSC)

这个顺序的逻辑是：

```text
先看还在常规电路仿真语境里的扩展
-> 再看领域更专门、耦合更重的模型家族
```

## 1. 混合信号接口

这一类其实就在 [OpenModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels) 里，不需要先跳到更远的目录。

最直接的代表文件是：

- [N_DEV_ADC.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_ADC.C)
- [N_DEV_DAC.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_DAC.C)
- [N_DEV_Digital.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Digital.C)

这一类模型的核心任务是：

- `DAC`：把数字侧信息变成模拟激励
- `ADC`：把模拟节点状态采样成数字量
- `Digital`：提供更偏数字行为的模型支持

所以它们和普通 `resistor / diode / MOS` 的区别，不只是公式不同，而是它们多了一层：

```text
模拟域 <-> 数字域
```

的桥接角色。

## 2. IBISModels

这一类在：

- [IBISModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/IBISModels)

代表文件很集中：

- [N_DEV_IBIS.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/IBISModels/N_DEV_IBIS.C)

IBIS 这类模型更关注：

- I/O buffer
- 驱动/接收行为
- 引脚和封装对外的行为特性

它的重点不是晶体管内部物理细节，而是：

```text
这个接口单元从外部看起来怎么驱动、怎么切换、怎么和负载互动
```

所以它更像“高速 I/O 行为模型”，而不是“晶体管级物理模型”。

## 3. NeuronModels

这一类在：

- [NeuronModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/NeuronModels)

典型文件包括：

- [N_DEV_Neuron.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/NeuronModels/N_DEV_Neuron.C)
- [N_DEV_Synapse.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/NeuronModels/N_DEV_Synapse.C)
- [N_DEV_MembraneHH.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/NeuronModels/N_DEV_MembraneHH.C)

这一类不是传统电子器件，而是把：

- 膜电位
- 离子通道动力学
- 突触耦合

这些神经动力学系统，作为一种可进入 Xyce DAE 框架的“动态器件”来实现。

所以它的关键不是“是不是电子器件”，而是：

```text
它是不是也能写成一组动态、非线性的方程贡献
```

## 4. TCAD / PDE 类模型

这一类在：

- [TCADModels](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/TCADModels)

代表文件包括：

- [N_DEV_2DPDE_DAE.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/TCADModels/N_DEV_2DPDE_DAE.C)
- [N_DEV_DiodePDE_DAE.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/TCADModels/N_DEV_DiodePDE_DAE.C)
- [N_DEV_PDE_2DMesh.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/TCADModels/N_DEV_PDE_2DMesh.C)
- [N_DEV_PDE_Electrode.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/TCADModels/N_DEV_PDE_Electrode.C)

这一类和 `BSIM4` 这种 compact model 的差别非常大。

`BSIM4` 更像：

- 少量外部端口
- 一套紧凑公式
- 在器件级做低维近似

而 `TCAD/PDE` 更像：

- 器件内部被离散成网格
- 形成大量内部未知量
- 直接解器件内部的 PDE 或近 PDE 型系统

所以它的建模层级已经不是“紧凑模型更复杂一点”，而是：

```text
直接进入器件内部场和输运方程的数值离散层
```

## 5. 外部耦合模型

这一类在：

- [EXTSC](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/EXTSC)

代表文件包括：

- [N_DEV_ExternDevice.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/EXTSC/N_DEV_ExternDevice.C)
- [N_DEV_ExternCodeInterface.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/EXTSC/N_DEV_ExternCodeInterface.C)
- [N_DEV_XyceInterface.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/EXTSC/N_DEV_XyceInterface.C)
- [N_DEV_CharonInterface.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/EXTSC/N_DEV_CharonInterface.C)

这一类不是在 Xyce 内部完整实现某个器件公式，而是提供：

- Xyce 和外部代码的接口
- Xyce 和外部求解器的耦合通道
- 外部专用物理程序与电路主框架之间的连接层

所以它更像：

```text
接口层 / 协同仿真层
```

而不是“再多一种内建器件”。

## 这一篇最想让你先吃下来的本质

这几类目录虽然都在 `DeviceModelPKG` 下面，但它们扩展的方向并不一样：

- 混合信号接口：扩展模拟/数字桥接
- `IBISModels`：扩展 I/O 行为建模
- `NeuronModels`：扩展神经动力学
- `TCADModels`：扩展器件内部 PDE 级建模
- `EXTSC`：扩展外部耦合能力

也就是说，它们不是在同一条“器件复杂度”坐标上排队，而是在扩展不同的应用维度。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `TCADModels` 和 `MOSFET_B4` 的差别，不只是“公式更复杂”，而是“建模层级都不一样”？
2. `IBISModels` 和 `EXTSC` 的定位差别，本质上更接近“内建特定行为模型”和“外部耦合接口层”吗？
