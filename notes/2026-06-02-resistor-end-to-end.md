# 2026-06-02 resistor end-to-end trace

## 这次读了哪些文件

这次按普通电阻 `R1 n1 n2 1k` 的完整链路顺序回看了这些文件：

- [src/CircuitPKG/N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [src/IOInterfacePKG/N_IO_NetlistImportTool.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C)
- [src/IOInterfacePKG/N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C)
- [src/IOInterfacePKG/N_IO_DistToolBase.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DistToolBase.C)
- [src/IOInterfacePKG/N_IO_DeviceBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DeviceBlock.C)
- [src/TopoManagerPKG/N_TOP_Topology.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_Topology.C)
- [src/TopoManagerPKG/N_TOP_CktNode_Dev.h](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.h)
- [src/TopoManagerPKG/N_TOP_CktNode_Dev.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.C)
- [src/TopoManagerPKG/N_TOP_CktGraphBasic.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktGraphBasic.C)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h)
- [src/DeviceModelPKG/Core/N_DEV_Device.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_Device.h)
- [src/DeviceModelPKG/OpenModels/N_DEV_Resistor.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.h)
- [src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C)
- [src/LoaderServicesPKG/N_LOA_CktLoader.C](../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_CktLoader.C)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C](../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)

## 这次带着什么问题去读

第四阶段的大纲要求是把一个简单器件从解析一直追到矩阵贡献。

这次重点想把下面几个问题彻底收尾：

- 电阻实例由哪段代码解析？
- 器件对象在哪里真正创建？
- 参数值最后保存在哪里？
- 哪个函数真正负责它的 `load` 或 `stamp` 行为？
- 它最后是怎样影响 `F` 向量和 `dFdx` 矩阵的？

## 当前结论先写在前面

对普通电阻 `R1 n1 n2 1k` 来说，完整主线可以先压成：

```text
netlist line
-> pass1 分类
-> second pass 详细解析
-> DeviceBlock / InstanceBlock
-> topology graph
-> delayed instantiate
-> Resistor::Instance
-> register LIDs / Jacobian offsets
-> loader
-> Resistor::Master::loadDAEVectors()
-> Resistor::Master::loadDAEMatrices()
```

如果只抓最重要的几个点：

- 解析器真正把 `R1 n1 n2 1k` 拆开的地方是 `DeviceBlock::extractBasicDeviceData(...)`
- 真正 `new Resistor::Instance(...)` 的地方在通用模板 `DeviceMaster<T>::addInstance(...)`
- 电阻值最终保存在 `Resistor::Instance::R`
- 电阻对 `F` 向量和 Jacobian 的真正贡献，实际走的是 `Resistor::Master::loadDAEVectors()` 和 `Resistor::Master::loadDAEMatrices()`
- `Instance::loadDAEFVector()` 和 `Instance::loadDAEdFdx()` 虽然也存在，但对 resistor 来说，正常流程下主要是 `Master` 版本在工作

## 从顶层入口重新串起这条链

这条链的顶层入口还是：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
  中的 `netlist_import_tool.constructCircuitFromNetlist(...)`

从这里进入 netlist 系统之后，普通器件链就可以先记成：

```text
Simulator::initializeEarly()
-> NetlistImportTool::constructCircuitFromNetlist(...)
-> parseNetlistFilePass1(...)
-> distributeDevices()
-> DeviceBlock::extractBasicDeviceData(...)
-> topology_.addDevice(...)
-> instantiateDevices()
-> setUpMatrixStructure_()
-> doInitializations_()
-> analysis / loader path
```

前面几步在前两篇笔记已经详细展开过，这里只保留第四阶段真正需要的主干。

## 第一段：电阻实例是如何被解析出来的

普通电阻不会在 `handleLinePass1(...)` 里立刻变成最终器件对象。

第一遍 `pass1` 主要做：

- 识别器件类型
- 统计 device count
- 准备 `.MODEL`、`.PARAM`、`.FUNC`、`.SUBCKT` 这些上下文

真正的详细解析发生在第二遍：

- [N_IO_DistToolBase.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DistToolBase.C) 第 715 行附近
  `DistToolBase::handleDeviceLine(...)`

这里会调用：

- [N_IO_DistToolBase.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DistToolBase.C) 第 730 行附近
  `device_.extractData(...)`

对普通电阻，最终进入：

- [N_IO_DeviceBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DeviceBlock.C) 第 490 行附近
  `extractBasicDeviceData(...)`

这里会把：

```text
R1 n1 n2 1k
```

拆成大致这样的结构化信息：

- instance name = `R1`
- device type = `R`
- node list = `n1`, `n2`
- primary parameter = `R=1k`

所以第四阶段第一个问题的答案是：

```text
电阻实例的文本解析位置 = DeviceBlock::extractBasicDeviceData(...)
```

## 第二段：解析结果为什么先进入 topology

解析完之后，不会立刻 `new Resistor::Instance`。

而是先经过：

- [N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 第 780 行附近
  `CircuitBlock::addTableData(DeviceBlock &device)`

再进入：

- [N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 第 815 行附近
  `topology_.addDevice(deviceManager_, device.getDeviceData());`

接着看：

- [N_TOP_Topology.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_Topology.C) 第 191 行附近
  `Topology::addDevice(...)`

这里的本质是建图：

- 为 `n1`、`n2` 创建电压节点 `CktNode_V`
- 为 `R1` 创建器件节点 `CktNode_Dev`
- 把这些节点按电路连接关系挂到图里

也就是说，这一步做的事情更接近：

```text
把器件纳入电路图结构
```

而不是：

```text
开始执行电阻的方程加载
```

## 第三段：器件对象在哪里真正创建

这一步是第四阶段里最重要的“实例化拐点”。

`Topology::addDevice(...)` 里插入的 `CktNode_Dev`，会在构造时保存一份 `InstanceBlock` 副本：

- [N_TOP_CktNode_Dev.h](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.h) 第 54 行附近
  `CktNode_Dev(...)`

这说明，图里此时保存的还不是最终 `DeviceInstance`，而是：

```text
一个器件节点 + 一份实例说明书
```

真正实例化发生在：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 第 1125 行附近
  `topology_->instantiateDevices();`

再继续到：

- [N_TOP_Topology.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_Topology.C) 第 1211 行附近
  `Topology::instantiateDevices()`

这里会遍历 `_DNODE`，然后调用：

- [N_TOP_CktNode_Dev.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.C) 第 96 行附近
  `CktNode_Dev::instantiate()`

核心代码是：

```cpp
deviceInstance_ = deviceManager_->addDeviceInstance(*instanceBlock_);
```

所以：

- `CktNode_Dev` 把暂存的 `InstanceBlock` 交给 `DeviceMgr`
- `DeviceMgr` 再决定该实例该归到哪一种具体 device

## 第四段：为什么最后会落到 resistor

`DeviceMgr::addDeviceInstance(...)` 并不自己手写每种器件的构造逻辑。

它主要负责：

- 根据 `InstanceBlock` 判断 `model_type` / `model_group`
- 找到对应的 device
- 调它的 `addInstance(...)`

可以看：

- [N_DEV_DeviceMgr.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C) 第 1419 行附近
  `DeviceMgr::addDeviceInstance(...)`

它之所以能把 `R` 路由到 resistor，是因为 resistor 预先注册过：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 1488 行附近
  `registerDevice(...)`

这里声明了：

- `.registerDevice("r", 1)`
- `.registerModelType("r", 1)`
- `.registerModelType("res", 1)`

所以这条路由不是硬编码猜出来的，而是由注册机制决定的。

## 第五段：真正 `new Resistor::Instance(...)` 的位置

这是第四阶段第二个核心答案。

`DeviceMgr` 找到对应 device 之后，不会直接写：

```cpp
new Resistor::Instance(...)
```

它先通过 `Configuration` 和 `Traits::factory(...)` 拿到 resistor 的 `Master` 对象：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 1466 行附近
  `Traits::factory(...)`

这个 factory 返回的是：

```text
new Master(...)
```

真正创建 instance 的位置在通用模板里：

- [N_DEV_DeviceMaster.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h) 第 478 行附近
  `DeviceMaster<T>::addInstance(...)`

这里有一句最关键的话：

```cpp
InstanceType *instance = new InstanceType(configuration_, instance_block, model, factory_block);
```

对 resistor 来说，`InstanceType` 就是：

- `Resistor::Instance`

所以第四阶段第二个问题可以正式记成：

```text
真正创建器件对象的位置 = DeviceMaster<T>::addInstance(...)
具体构造函数 = Resistor::Instance::Instance(...)
```

## 第六段：参数值最后保存在哪里

接下来回答“参数值保存在哪里”。

先看：

- [N_DEV_Resistor.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.h) 第 100 行附近
  `Traits`

这里定义了 resistor 的静态特征：

- `numNodes() -> 2`
- `primaryParameter() -> "R"`
- `instanceDefaultParameter() -> "R"`

再看：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 111 行附近
  `Traits::loadInstanceParameters(...)`

这里把实例参数元数据注册进去，其中最关键的是：

- `R`
- `M`
- `L`
- `W`
- `TEMP`
- `TC1`
- `TC2`
- `TCE`
- `DTEMP`

最后看：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 282 行附近
  `Resistor::Instance::Instance(...)`

以及：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 469 行附近
  `Instance::processParams()`

这里可以得到一个稳定认识：

- 主电阻值最终保存在 `Resistor::Instance::R`
- 乘法因子保存在 `multiplicityFactor`
- 几何参数保存在 `length`、`width`
- 运行时真正用于加载的电导保存在 `G`
- 电流临时值保存在 `i0`

所以第四阶段第三个问题的答案是：

```text
参数解析后的主要保存位置 = Resistor::Instance 的成员变量
其中最关键的是 R 和 G
```

## 第七段：实例创建之后，什么时候拿到 LID 和 Jacobian 位置

到这里器件已经被创建出来了，但还不能立刻往矩阵里写。

原因是它还不知道：

- 自己在解向量里的局部索引是多少
- 自己的 Jacobian 项在稀疏矩阵行里对应哪个 offset

这一步发生在 `initializeLate()` 之后的矩阵结构建立阶段。

先看：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 第 1261 行附近
  `runState_ = SETUP_MATRIX_STRUCTURE;`

然后调用：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 第 640 行附近
  `setUpMatrixStructure_()`

这个函数里关键一步是：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 第 649 行附近
  `topology_->registerLIDswithDevs();`

接着：

- [N_TOP_Topology.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_Topology.C) 第 240 行附近
  `Topology::registerLIDswithDevs()`

再继续到：

- [N_TOP_CktGraphBasic.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktGraphBasic.C) 第 374 行附近
  `CktGraphBasic::registerLIDswithDevs(...)`

这里会遍历 `_DNODE`，然后经由：

- [N_TOP_CktNode_Dev.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.C) 第 223 行附近
  `registerLIDswithDev(...)`

把局部索引最终交给：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 543 行附近
  `Instance::registerLIDs(...)`

在这里，电阻会把：

- `extLIDVec[0] -> li_Pos`
- `extLIDVec[1] -> li_Neg`

保存下来。

同样，Jacobian offset 会通过：

- [N_TOP_CktNode_Dev.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.C) 第 434 行附近
  `registerJacLIDswithDev(...)`

再进入：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 668 行附近
  `Instance::registerJacLIDs(...)`

最后保存成：

- `APosEquPosNodeOffset`
- `APosEquNegNodeOffset`
- `ANegEquPosNodeOffset`
- `ANegEquNegNodeOffset`

所以这一步的本质是：

```text
实例创建
-> topology / indexor 分配局部索引
-> resistor 保存自己的向量位置和矩阵位置
```

## 第八段：什么时候真正开始 load

当 setup 完成以后，分析流程会进入 loader 路径。

从比较高的一层看：

- [N_LOA_NonlinearEquationLoader.C](../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C) 第 418 行附近
  `loader_.loadDAEVectors(...)`

以及：

- [N_LOA_NonlinearEquationLoader.C](../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C) 第 533 行附近
  `loader_.loadDAEMatrices(...)`

这里的 `loader_` 对应的是：

- [N_LOA_CktLoader.C](../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_CktLoader.C)
  里的 `CktLoader`

它继续把调用转发给：

- [N_LOA_CktLoader.C](../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_CktLoader.C) 第 648 行附近
  `deviceManager_.loadDAEVectors(...)`

和：

- [N_LOA_CktLoader.C](../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_CktLoader.C) 第 476 行附近
  `deviceManager_.loadDAEMatrices(...)`

然后：

- [N_DEV_DeviceMgr.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C) 第 4156 行附近
  `DeviceMgr::loadDAEVectors(...)`

和：

- [N_DEV_DeviceMgr.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C) 第 3980 行附近
  `DeviceMgr::loadDAEMatrices(...)`

再把调用下发到每个 `Device` 对象。

## 第九段：对 resistor 来说，真正执行的是 `Master` 版本

这里有一个第四阶段里非常值得记住的细节：

resistor 虽然定义了：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 798 行附近
  `Instance::loadDAEFVector()`

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 872 行附近
  `Instance::loadDAEdFdx()`

但是注释里已经明确说了：

- 对 resistor 来说，正常流程下主要不是调用这两个 `Instance` 版本
- 而是调用它自己重写过的 `Master` 版本

也就是：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 1211 行附近
  `Master::loadDAEVectors(...)`

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 1306 行附近
  `Master::loadDAEMatrices(...)`

这么做的原因很实际：

- `Master` 可以一次性循环所有 resistor instances
- 比让每个 instance 分别调用更高效

所以第四阶段第四个问题的答案要写准确一点：

```text
resistor 的 load / stamp 逻辑，语义上对应 Instance::loadDAEFVector 和 Instance::loadDAEdFdx
但正常执行路径里，真正工作的主要是 Master::loadDAEVectors 和 Master::loadDAEMatrices
```

## 第十段：电阻到底怎么影响 `F` 向量

先看：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 1211 行附近
  `Master::loadDAEVectors(...)`

核心逻辑是：

```text
i0 = (Vpos - Vneg) * G
```

然后把它写入 `F` 向量：

- 正节点 KCL 加 `+i0`
- 负节点 KCL 加 `-i0`

如果开启了 lead current 记录，还会把：

- `leadF[li_branch_data] = i0`
- `junctionV[li_branch_data] = Vpos - Vneg`

也记录下来。

所以对 `F` 向量的本质影响是：

```text
fVec[li_Pos] += (Vpos - Vneg) * G
fVec[li_Neg] += -(Vpos - Vneg) * G
```

这就是电阻在 MNA/DAE 框架里最核心的残差贡献。

## 第十一段：电阻到底怎么影响 Jacobian

再看：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 1306 行附近
  `Master::loadDAEMatrices(...)`

对于普通线性 resistor，核心 stamp 就是：

```text
[  G  -G ]
[ -G   G ]
```

落实到代码里，就是对四个矩阵位置分别加：

- `+G`
- `-G`
- `-G`
- `+G`

如果启用了 pointer-based matrix load，代码会走预先缓存好的矩阵元素指针；
否则就使用前面 `registerJacLIDs(...)` 保存下来的 row offset：

- `APosEquPosNodeOffset`
- `APosEquNegNodeOffset`
- `ANegEquPosNodeOffset`
- `ANegEquNegNodeOffset`

所以第四阶段最后一个问题的答案可以写成：

```text
电阻对矩阵的影响 = 在两个节点对应的 KCL 方程上，写入标准 2x2 电导 stamp
```

## 这条链里最容易误解的两个点

### 1. 不是解析完就立刻实例化

真实顺序是：

```text
parse
-> topology
-> instantiate
-> register LIDs / Jacobian offsets
-> load
```

而不是：

```text
parse
-> 立刻 new Resistor::Instance
-> 立刻往矩阵写
```

### 2. 不是 `Instance::loadDAEFVector()` 一定会被直接调用

对很多器件来说，`Instance` 版 load 函数是主要路径。  
但对 resistor，正常执行路径下更常用的是 `Master` 的批量 load 实现。

这对以后读别的器件很有帮助，因为你不能默认：

```text
找到 Instance::loadDAEFVector() = 找到真实执行路径
```

有些器件会重写 `Master` 层。

## 当前可以稳定记住的完整链路

对 `R1 n1 n2 1k`，第四阶段结束时，最值得记住的一条线是：

```text
R1 n1 n2 1k
-> DeviceBlock::extractBasicDeviceData(...)
-> topology_.addDevice(...)
-> Topology::addDevice(...)
-> CktNode_Dev(instanceBlock copy)
-> topology_->instantiateDevices()
-> CktNode_Dev::instantiate()
-> DeviceMgr::addDeviceInstance(...)
-> DeviceMaster<T>::addInstance(...)
-> Resistor::Instance::Instance(...)
-> topology_->registerLIDswithDevs()
-> Resistor::Instance::registerLIDs(...)
-> Resistor::Instance::registerJacLIDs(...)
-> NonlinearEquationLoader::loadRHS/loadJacobian path
-> CktLoader::loadDAEVectors/loadDAEMatrices
-> DeviceMgr::loadDAEVectors/loadDAEMatrices
-> Resistor::Master::loadDAEVectors(...)
-> Resistor::Master::loadDAEMatrices(...)
```

## 第四阶段的问题，现在可以怎么回答

### 电阻实例由哪段代码解析？

- `DeviceBlock::extractBasicDeviceData(...)`

### 器件对象在哪里创建？

- 通用模板 `DeviceMaster<T>::addInstance(...)`
- 对 resistor 来说，最终进入 `Resistor::Instance::Instance(...)`

### 参数值保存在哪里？

- 主要保存在 `Resistor::Instance` 的成员变量里
- 最关键的是 `R`、`G`、`li_Pos`、`li_Neg`

### 哪个函数负责它的 load 或 stamp 行为？

- 正常执行路径中，主要是
  - `Resistor::Master::loadDAEVectors(...)`
  - `Resistor::Master::loadDAEMatrices(...)`

### 它如何影响矩阵项或右端项？

- 对 `F` 向量：注入 `+(Vpos-Vneg)G` 和 `-(Vpos-Vneg)G`
- 对 `dFdx`：写入标准 `[[G,-G],[-G,G]]` 电导 stamp

## 当前结论

到这里，第四阶段的大目标已经基本完成：

1. 已经打通了电阻从 `netlist` 文本到结构化器件数据的链路
2. 已经打通了电阻从 `topology` 到 `Resistor::Instance` 的实例化链路
3. 已经打通了电阻从 `registerLIDs/registerJacLIDs` 到 `loadDAEVectors/loadDAEMatrices` 的 setup 和 load 链路
4. 已经明确区分了：
   - parser 层
   - topology 层
   - device manager / device master 层
   - concrete resistor model 层

## 下一步最自然的方向

第四阶段结束之后，最自然的下一步有两个：

1. 进入第五阶段，去看 `.OP`、`.DC`、`.TRAN` 的分析流程调度
2. 进入第六阶段，继续沿着刚才的 load 路径往下，看这些 `F`、`Q`、`dFdx`、`dQdx` 最后是怎么交给 nonlinear solver 和 linear solver 的

如果只考虑和当前 resistor 链衔接最紧的一步，那么下一步更自然的是：

```text
device load
-> nonlinear equation assembly
-> solver call
```
