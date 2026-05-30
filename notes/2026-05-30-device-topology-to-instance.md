# 2026-05-30 device topology to instance

## 这次读了哪些文件

- [src/IOInterfacePKG/N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C)
- [src/TopoManagerPKG/N_TOP_Topology.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_Topology.C)
- [src/TopoManagerPKG/N_TOP_CktNode_Dev.h](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.h)
- [src/TopoManagerPKG/N_TOP_CktNode_Dev.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.C)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h)
- [src/DeviceModelPKG/OpenModels/N_DEV_Resistor.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.h)
- [src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C)

## 这次带着什么问题去读

上一篇笔记已经走到了：

```text
R1 n1 n2 1k
-> DeviceBlock::extractBasicDeviceData(...)
-> topology_.addDevice(...)
```

这次要继续回答的是：

- 为什么解析完 `DeviceBlock` 之后，还不能立刻创建最终的 resistor 对象
- `topology_.addDevice(...)` 到底在做什么
- `topology_->instantiateDevices()` 为什么要单独放在后面
- `DeviceMgr::addDeviceInstance(...)` 之后，是怎么真正落到 `N_DEV_Resistor.*` 里的

## 当前结论先写在前面

对普通器件 `R1 n1 n2 1k` 来说：

- parser 把它拆成结构化实例数据
- topology 先把它放进电路图结构
- `CktNode_Dev` 暂存一份 `InstanceBlock`
- 到 `instantiateDevices()` 阶段，才真正调用 `DeviceMgr::addDeviceInstance(...)`
- `DeviceMgr` 根据注册表和配置，把它路由到 resistor 的 `Master`
- 最终由通用模板 `DeviceMaster<T>::addInstance(...)` 真正 `new Resistor::Instance(...)`

所以这条链路的关键词是：

```text
parse
-> topology graph
-> delayed instantiate
-> device routing
-> concrete instance
```

## 为什么 `DeviceBlock` 解析完之后还不能立刻实例化

在 parser 这一层，系统已经知道：

- instance name
- device type
- node list
- primary parameter
- 可能的 model name 和额外参数

但这还不够直接进入求解。

原因是仿真器还需要先建立：

- 电路图中的节点和器件连接关系
- 节点编号和邻接关系
- 后续矩阵结构、变量分配、并行划分所依赖的拓扑信息

所以 Xyce 的设计不是：

```text
解析一条器件行
-> 立刻 new 一个最终器件对象
```

而是：

```text
解析一条器件行
-> 先放进 topology
-> 后续统一 instantiate
```

## `CircuitBlock::addTableData(...)` 在做什么

从这里开始看：

- [N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 第 780 行附近
  `CircuitBlock::addTableData(DeviceBlock &device)`

这个函数先做几件基础工作：

- 检查器件名是否重复
- 记录 node name，便于后续诊断

真正关键的一句是：

- [N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 第 815 行附近
  `topology_.addDevice(deviceManager_, device.getDeviceData());`

这句的含义不是 “创建最终 resistor instance”，而是：

```text
把这个器件的结构化描述交给 topology
```

## `Topology::addDevice(...)` 的本质是建图

接着看：

- [N_TOP_Topology.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_Topology.C) 第 191 行附近
  `Topology::addDevice(...)`

这个函数做的事情很有代表性：

1. 遍历器件 node list
2. 对每个节点插入 `CktNode_V`
3. 把这些节点记成 `NodeID`
4. 再插入一个 `CktNode_Dev`
5. 把器件节点和这些电压节点连起来

如果用最直观的方式理解：

```text
n1 ---- R1 ---- n2
```

在 topology 里会先变成：

- 一个表示 `n1` 的电压节点
- 一个表示 `n2` 的电压节点
- 一个表示 `R1` 的器件节点
- 再把这三个节点按电路连接关系挂到图里

所以这里的本质是：

```text
先把电路的图结构建出来
```

而不是：

```text
已经开始做 resistor 方程加载
```

## `CktNode_Dev` 为什么重要

再往下看：

- [N_TOP_CktNode_Dev.h](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.h) 第 54 行附近
  `CktNode_Dev(...)`

这个构造函数做了两个很关键的动作：

- 把这个图节点标记为 `_DNODE`
- 保存一份 `InstanceBlock` 副本到 `instanceBlock_`

这里要特别记住一个判断：

- 此时 topology 中保存的还不是最终 `DeviceInstance`
- 而是一份以后用来实例化设备的 `InstanceBlock`

所以 `CktNode_Dev` 可以先理解成：

```text
图中的器件节点
+ 一份暂存的实例说明书
```

## 为什么要延迟到 `instantiateDevices()`

真正的实例化发生在：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 第 1125 行附近
  `topology_->instantiateDevices();`

再跳到：

- [N_TOP_Topology.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_Topology.C) 第 1211 行附近
  `Topology::instantiateDevices()`

这里的逻辑是：

1. `generateOrderedNodeList()`
2. 遍历 ordered node list
3. 遇到 `_DNODE`
4. 调用 `CktNode_Dev::instantiate()`

这说明 Xyce 的思路是：

```text
先把整张图建好
-> 再按统一顺序实例化所有器件
```

这样做的好处是：

- 拓扑信息已经稳定
- 统一控制实例化时机
- 后面注册 LID/GID、矩阵结构等流程更容易组织

## `CktNode_Dev::instantiate()` 才是真正把说明书交给 `DeviceMgr`

看这里：

- [N_TOP_CktNode_Dev.C](../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.C) 第 96 行附近
  `CktNode_Dev::instantiate()`

核心代码是：

```cpp
deviceInstance_ = deviceManager_->addDeviceInstance(*instanceBlock_);
```

这句话的意义非常直接：

- 之前暂存在 `CktNode_Dev` 里的 `InstanceBlock`
- 现在交给 `DeviceMgr`
- 由 `DeviceMgr` 决定该创建什么具体器件实例

而且实例化完成以后：

- `instanceBlock_` 会被删除

这进一步说明它只是过渡阶段使用的说明书，而不是长期工作的对象。

## `DeviceMgr::addDeviceInstance(...)` 这一层在做什么

继续看：

- [N_DEV_DeviceMgr.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C) 第 1419 行附近
  `DeviceMgr::addDeviceInstance(...)`

这一层的核心职责不是手写所有器件逻辑，而是：

1. 根据 `InstanceBlock` 判断 `model_type` / `model_group`
2. 找到对应的 device
3. 调那个 device 的 `addInstance(...)`

所以它更像一个：

```text
总调度器 / 路由器
```

而不是 resistor、capacitor、MOSFET 的具体实现本体。

## 为什么 `DeviceMgr` 能把 `R` 路由到 resistor

答案在 resistor 自己的注册逻辑里。

看这里：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 1488 行附近
  `registerDevice(...)`

这里做了：

- `.registerDevice("r", 1)`
- `.registerModelType("r", 1)`
- `.registerModelType("res", 1)`

这相当于告诉整个 device framework：

- 网表里的 `R` 设备，对应 resistor 这套实现
- model type `R` / `RES` 都归到 resistor level 1

所以 `DeviceMgr` 不是靠 if/else 猜，而是靠：

```text
registerDevice
-> configuration / model type mapping
-> route to correct device
```

## `Traits` 是 resistor 的静态说明书

再看：

- [N_DEV_Resistor.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.h) 第 100 行附近
  `struct Traits`

这里直接定义了 resistor 的一些关键静态特征：

- `numNodes() -> 2`
- `primaryParameter() -> "R"`
- `instanceDefaultParameter() -> "R"`
- `isLinearDevice() -> true`

可以把 `Traits` 理解成：

```text
这个器件类型的静态身份证
```

它说明了：

- 这是两端器件
- 主参数叫 `R`
- 默认实例参数也是 `R`
- 它是线性器件

这些信息既影响 parser 识别，也影响后面的 device 框架。

## `getDeviceByModelType(...)` 为什么先拿到的是 `Master`

看：

- [N_DEV_DeviceMgr.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.C) 第 1134 行附近
  `getDeviceByModelType(...)`

这里不是直接 `new Resistor::Instance`，而是：

1. 找 `Configuration`
2. 调 `configuration->createDevice(factory_block)`
3. 把得到的 `Device *` 缓存起来

对于 resistor，这一步最终会经过：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 1466 行附近
  `Traits::factory(...)`

返回的是：

```text
new Master(...)
```

也就是说，`DeviceMgr` 先拿到的是 resistor 的“设备主对象”，而不是单个 resistor instance。

## `DeviceMaster<T>::addInstance(...)` 才是真正 `new Resistor::Instance(...)` 的地方

这是整条链里最关键的一步之一。

看：

- [N_DEV_DeviceMaster.h](../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h) 第 478 行附近
  `DeviceMaster<T>::addInstance(...)`

这个模板函数做了：

1. 决定实例应该挂到哪个 model
2. 如果没有 model name，就使用 default model
3. 找到对应 model
4. 真正执行：

```cpp
new InstanceType(configuration_, instance_block, model, factory_block);
```

对 resistor 来说，`InstanceType` 就是：

- `Resistor::Instance`

所以到这里，普通器件链路终于落到了具体器件实现类上。

## `Resistor::Instance` 构造函数拿到了什么

最后看：

- [N_DEV_Resistor.C](../vendor/Xyce-7.10.0/src/DeviceModelPKG/OpenModels/N_DEV_Resistor.C) 第 282 行附近
  `Resistor::Instance::Instance(...)`

这个构造函数吃进去的四样东西非常重要：

- `configuration`
- `instance_block`
- `model`
- `factory_block`

它们分别对应：

- 设备配置和 traits
- 从 netlist 解析出来的实例信息
- 该实例所属的 model
- solver state / device options 等运行时环境

这说明 `Resistor::Instance` 并不是突然凭空创建的，而是吃进了前面整条链路准备好的上下文。

## 当前可以稳定记住的完整链路

对 `R1 n1 n2 1k`，目前可以稳定记成：

```text
R1 n1 n2 1k
-> DeviceBlock::extractBasicDeviceData(...)
-> CircuitBlock::addTableData(...)
-> topology_.addDevice(...)
-> Topology::addDevice(...)
   -> CktNode_V / CktNode_Dev 建图
   -> CktNode_Dev 暂存 InstanceBlock
-> topology_->instantiateDevices()
-> Topology::instantiateDevices()
-> CktNode_Dev::instantiate()
-> DeviceMgr::addDeviceInstance(...)
-> getDeviceByModelType(...)
-> resistor Traits::factory()
-> Resistor::Master
-> DeviceMaster<T>::addInstance(...)
-> new Resistor::Instance(...)
```

## 到这里为止，哪些东西已经清楚了

当前已经比较清楚的点：

- 普通器件不是 parser 当场直接实例化
- topology 先负责把器件纳入电路图结构
- `CktNode_Dev` 是延迟实例化的承接层
- `DeviceMgr` 负责路由，不负责手写每种器件实例逻辑
- resistor 的注册信息和 `Traits` 决定了它如何被识别和创建
- 真正 `new Resistor::Instance(...)` 的地方在通用模板 `DeviceMaster<T>::addInstance(...)`

## 下一步最自然的问题

如果继续沿着普通器件链路往下走，下一步最值得追的是：

- `Resistor::Instance` 创建完成后，什么时候开始参与矩阵加载
- `loadDAEFVector()` 和 `loadDAEdFdx()` 是在什么阶段被调用
- resistor 的 Jacobian stamp 和节点 LID 是怎么接上的

也就是从：

```text
instance created
-> solver/load path
```

继续往后走。
