# 2026-05-30 ordinary device two-pass flow

## 这次读了哪些文件

- [src/CircuitPKG/N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [src/IOInterfacePKG/N_IO_NetlistImportTool.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C)
- [src/IOInterfacePKG/N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C)
- [src/IOInterfacePKG/N_IO_DistToolBase.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DistToolBase.C)
- [src/IOInterfacePKG/N_IO_DeviceBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DeviceBlock.C)

## 这次带着什么问题去读

这次的核心问题是：

- 为什么普通器件，比如 `R1 n1 n2 1k`，不会在 `handleLinePass1(...)` 里立刻变成最终器件对象
- 为什么链路会从 `CircuitBlock` 跳到 `DistToolBase`
- 普通器件第一次真正进入 `DeviceBlock::extractData(...)` 的位置在哪里

## 当前结论先写在前面

普通器件在 Xyce 里走的是“两遍处理”思路：

```text
第一遍：识别和收集上下文
第二遍：详细解析 device line
```

所以：

- `handleLinePass1(...)` 主要做分类、计数、上下文收集
- `DistToolBase::handleDeviceLine(...)` 才是普通器件真正进入 `DeviceBlock::extractData(...)` 的地方

## 从顶层入口开始的链路

普通器件链路从这里进入 netlist 导入系统：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 中调用
  `netlist_import_tool.constructCircuitFromNetlist(...)`

然后进入：

- [N_IO_NetlistImportTool.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C) 的
  `NetlistImportTool::constructCircuitFromNetlist(...)`

这条主线可以先记成：

```text
Simulator::initializeEarly()
  -> NetlistImportTool::constructCircuitFromNetlist(...)
  -> parseNetlistFilePass1(...)
  -> create distributionTool
  -> distributeDevices()
```

## 第一遍为什么不直接构造普通器件

在 [N_IO_NetlistImportTool.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C) 中，首先发生的是：

- [N_IO_NetlistImportTool.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C) 第 400 行附近
  `mainCircuitBlock_->parseNetlistFilePass1(options_manager);`

这说明一开始做的是 “pass1”。

### pass1 的职责

第一遍不是为了彻底构造普通器件对象，而是为了先准备网表上下文，包括：

- `.PARAM`
- `.GLOBAL_PARAM`
- `.FUNC`
- `.MODEL`
- `.SUBCKT`
- `.INCLUDE`
- 各类 `.OPTIONS`
- device count
- subcircuit hierarchy

这一步更像：

```text
先把整份网表的语义环境搭起来
```

而不是：

```text
立刻把每条器件行都变成最终对象
```

## `handleLinePass1(...)` 在普通器件链路里的作用

在 [N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 第 286 行附近的
`parseNetlistFilePass1(...)` 主循环里，会不断调用：

- [N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 第 997 行附近的
  `handleLinePass1(...)`

对于普通器件，比如 `R1 n1 n2 1k`，这里会发生的事情主要是：

- 根据首字符 `R` 识别它是器件语句
- 记录 device count
- 查 `Device::Configuration`
- 判断是否 linear device

最关键的认识是：

- 对普通器件，`handleLinePass1(...)` 里**没有立刻显式构造 `DeviceBlock`**
- 这里主要是在做第一遍分类和上下文准备

可以把这一步理解为：

```text
认出来这是 R 类型器件
并把它计入当前 circuit context
```

而不是：

```text
已经构造出最终 resistor instance
```

## 为什么会进入 `DistToolBase`

这一步如果只看函数名，会很容易觉得突兀。

实际上在 [N_IO_NetlistImportTool.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C) 中，pass1 之后会继续做两件事：

1. 创建 distribution tool
   - [N_IO_NetlistImportTool.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C) 第 442 行附近
     `distributionTool_ = DistToolFactory::create(...)`

2. 调用第二遍器件处理
   - [N_IO_NetlistImportTool.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C) 第 479 行附近
     `distributionTool_->distributeDevices();`

这说明 `DistToolBase` 不是随机插入的新层，而是：

- 第一遍上下文准备完成之后
- 第二遍专门处理 device line 的那一层

名字里虽然有 `Dist`，但它不只是做并行分发，它也承担：

- 接收或处理器件行
- 详细解析器件行
- 把解析结果交给 topology

## 普通器件第一次真正进入 `DeviceBlock::extractData(...)` 的位置

关键位置在：

- [N_IO_DistToolBase.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DistToolBase.C) 第 715 行附近的
  `DistToolBase::handleDeviceLine(...)`

在这个函数里，会调用：

- [N_IO_DistToolBase.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DistToolBase.C) 第 730 行附近的
  `device_.extractData(netlistFilename_, deviceLine, resolveParams, modelBinning, scale);`

这就是普通器件第一次真正被送入 `DeviceBlock` 做详细解析的地方。

也就是说：

- pass1 只认出 “这是一个 R”
- 到了 `handleDeviceLine(...)`，系统才开始真正拆：
  - instance name
  - node list
  - model name
  - parameter list

## 为什么要等到第二遍才详细解析

原因不是实现随意，而是因为普通器件的详细解析经常依赖已经准备好的上下文，例如：

- model 是否已经出现
- 当前是否在 subcircuit 中
- 参数和函数是否已经定义
- 全局 options 是否已经注册
- 并行环境下 context 是否已经广播完成

所以第二遍的作用可以理解为：

```text
在上下文足够完整后，再安全地把 device line 拆成结构化数据
```

## 进入 `DeviceBlock` 之后发生什么

在 [N_IO_DeviceBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DeviceBlock.C) 第 246 行附近的
`DeviceBlock::extractData(...)` 里，普通器件最终会走到：

- [N_IO_DeviceBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DeviceBlock.C) 第 490 行附近的
  `extractBasicDeviceData(...)`

这一步才是真正把一行类似：

```text
R1 n1 n2 1k
```

拆成内部字段的地方。

## 详细解析之后怎么进入 topology

器件行被 `DeviceBlock` 解析后，会通过：

- [N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 第 780 行附近的
  `CircuitBlock::addTableData(DeviceBlock &device)`

再继续进入：

- [N_IO_CircuitBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 第 815 行附近的
  `topology_.addDevice(deviceManager_, device.getDeviceData());`

这说明普通器件不是解析完就直接变成最终 device instance，而是先：

```text
device line
-> DeviceBlock
-> topology
```

## 当前可以稳定记住的完整链路

对于普通器件，比如 `R1 n1 n2 1k`，当前最值得记住的链路是：

```text
constructCircuitFromNetlist(...)
  -> parseNetlistFilePass1()
  -> handleLinePass1()
     -> 识别为普通器件，记录 context / count
  -> create distributionTool
  -> distributeDevices()
  -> DistToolBase::handleDeviceLine(...)
  -> DeviceBlock::extractData(...)
  -> DeviceBlock::extractBasicDeviceData(...)
  -> CircuitBlock::addTableData(...)
  -> topology_.addDevice(...)
```

## 当前结论

这次可以先得出这些稳定结论：

1. 普通器件链路确实是两遍处理，不是一遍到底
2. `handleLinePass1(...)` 对普通器件主要负责分类和上下文收集
3. `DistToolBase` 出现在链路里，是因为它负责第二遍的 device line 处理
4. 普通器件第一次真正进入 `DeviceBlock::extractData(...)` 的位置是 `DistToolBase::handleDeviceLine(...)`
5. `DeviceBlock` 解析完之后，不是立刻变成最终器件对象，而是先进入 topology

## 下一步还要继续追踪什么

接下来最自然的一步是：

- 专门盯住 [N_IO_DeviceBlock.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DeviceBlock.C) 第 490 行附近的
  `extractBasicDeviceData(...)`

目标是把：

```text
R1 n1 n2 1k
```

具体拆成哪些内部字段看清楚。
