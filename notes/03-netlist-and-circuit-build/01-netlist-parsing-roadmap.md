# netlist parsing roadmap

记录日期：2026-05-27

## 这次读了哪些文件

- [src/CircuitPKG/N_CIR_Xyce.C](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [src/IOInterfacePKG/N_IO_NetlistImportTool.h](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.h)
- [src/IOInterfacePKG/N_IO_NetlistImportTool.C](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C)
- [src/IOInterfacePKG/N_IO_CircuitBlock.h](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.h)
- [src/IOInterfacePKG/N_IO_CircuitBlock.C](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C)
- [src/IOInterfacePKG/N_IO_DeviceBlock.h](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_DeviceBlock.h)
- [src/IOInterfacePKG/N_IO_ParameterBlock.h](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_ParameterBlock.h)
- [src/IOInterfacePKG/N_IO_OptionBlock.h](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_OptionBlock.h)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMgr.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMgr.h)

## 这次带着什么问题去读

第三阶段的目标是理解：

- netlist parser 的入口在哪里
- 器件语句和控制语句如何区分
- 节点、器件和模型在哪一步被创建或注册
- 解析后的电路由哪些内部对象表示

## 这一阶段最该抓的主线

这一阶段不要把重点放在某个 parser 细节上，而要先看清这条主线：

```text
netlist 文本
  -> NetlistImportTool
  -> CircuitBlock::parseNetlistFilePass1
  -> CircuitBlock::handleLinePass1
  -> DeviceBlock / ParameterBlock / OptionBlock / FunctionBlock / sub-CircuitBlock
  -> DeviceMgr / Topology
```

也就是说，这一阶段最重要的是理解：

- 文本先被分类
- 再被变成中间对象
- 最后才推进到真正的电路构建

## netlist parser 的入口在哪里

顶层入口仍然是在：

- `Simulator::initializeEarly()`
- 调用 `netlist_import_tool.constructCircuitFromNetlist(...)`

真正进入 netlist 导入主线的关键函数是：

- [N_IO_NetlistImportTool.C](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.C) 里的 `NetlistImportTool::constructCircuitFromNetlist(...)`

从 [N_IO_NetlistImportTool.h](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_NetlistImportTool.h) 的注释可以直接看出，它承担三件事：

1. 读并解析 netlist
2. 把解析结果存进合适的数据结构
3. 构建 Xyce circuit

所以第三阶段的第一阅读入口不是更底层的 tokenizer，而是 `constructCircuitFromNetlist(...)`。

## 器件语句和控制语句如何区分

这一点最关键的函数是：

- [N_IO_CircuitBlock.C](../../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CircuitBlock.C) 里的 `CircuitBlock::handleLinePass1(...)`

当前可以先抓住最粗粒度的分类规则：

- 首字符是 `A-Z`：按器件语句处理
- 首字符是 `.`：按控制语句或 dot line 处理
- 首字符是 `*` 或空白：按注释/空行处理

然后在器件语句内部，还有一些特殊分支：

- `X`：subcircuit instance
- `K`：mutual inductance
- `U`
- `Y`

在 dot line 内部，则会继续分流到：

- `.MODEL`
- `.PARAM`
- `.GLOBAL_PARAM`
- `.FUNC`
- `.SUBCKT`
- `.ENDS`
- `.INCLUDE`
- `.LIB`
- `.GLOBAL`
- `.INITCOND`

当前阶段最重要的理解不是每个分支做了什么，而是：

- Xyce 在 pass1 中先基于首字符和首 token 做分类
- 再把不同类型的语句送到不同的中间表示或处理路径

## 中间表示对象是什么

这一阶段最值得建立印象的中间对象有：

- `NetlistImportTool`
  - netlist 导入总入口

- `CircuitBlock`
  - file hierarchy 对应的容器
  - 负责一段 netlist 文件或 subcircuit block 的解析组织

- `CircuitContext`
  - subcircuit hierarchy 对应的语义上下文

- `DeviceBlock`
  - 器件语句的中间表示

- `ParameterBlock`
  - `.MODEL` 等参数类语句的中间表示

- `OptionBlock`
  - `.OPTIONS`、analysis、控制类语句的中间表示

- `FunctionBlock`
  - `.FUNC` 的中间表示

这里最重要的是区分：

- `CircuitBlock = file hierarchy`
- `CircuitContext = subcircuit hierarchy`

这是理解 Xyce netlist 组织方式的关键点。

## 节点、器件和模型在哪一步被创建或注册

这一点建议分三层理解。

### 第一层：pass1 做的是识别和收集

在 `CircuitBlock::handleLinePass1(...)` 中：

- `.MODEL` 会被转成 `ParameterBlock`
- 器件语句会形成 `DeviceBlock` 或相关上下文记录
- `.OPTIONS` / `.TRAN` / `.PRINT` 等会形成 `OptionBlock`
- `.SUBCKT` 会创建新的 `CircuitBlock`

这一层重点不是最终实例化，而是：

- 识别语句类型
- 把数据暂存在合适的中间对象或上下文容器中

### 第二层：CircuitBlock / CircuitContext 组织这些结果

`CircuitBlock` 和 `CircuitContext` 承担的是“把 netlist 内容整理成可进一步构建的内部结构”。

例如：

- 模型会被 `circuitContext_` 保存
- 函数会被 `circuitContext_` 保存
- subcircuit 定义会被 `circuitBlockTable_` 保存
- option 类内容会进入 `optionsTable_`

### 第三层：真正进入 DeviceMgr / Topology

真正更接近“最终电路对象”的入口，要看：

- `DeviceMgr::addDeviceModel(const ModelBlock &)`
- `DeviceMgr::addDeviceInstance(const InstanceBlock &)`

也就是说：

- parser 先把文本变成 block/context
- 然后这些 block 再推进到 device manager 和 topology

## 当前最值得重点看的函数

第三阶段如果只选几处重点，我会优先看下面这些：

### 1. `NetlistImportTool::constructCircuitFromNetlist(...)`

作用：

- 第三阶段总入口
- 负责串起 `CircuitBlock`、注册 device、注册 options、后续分布和构建流程

看法：

- 先把它当阶段组织函数
- 不要一开始就抠每个分支细节

### 2. `CircuitBlock::parseNetlistFilePass1(...)`

作用：

- 第一遍读 netlist 的主循环

看法：

- 看它如何持续读取 netlist 行
- 看它如何驱动 `handleLinePass1(...)`

### 3. `CircuitBlock::handleLinePass1(...)`

作用：

- 整个 netlist 行分类中心

看法：

- 这是“器件语句和控制语句如何区分”的关键实现
- 这一阶段必须重点看

### 4. `DeviceBlock` / `ParameterBlock` / `OptionBlock`

作用：

- 代表 netlist 不同类别语句的中间表示

看法：

- 当前先建立“谁对应哪类语句”的认识
- 不用先读完所有字段

### 5. `DeviceMgr::addDeviceModel` / `addDeviceInstance`

作用：

- 把中间表示推进为真正 device model / instance

看法：

- 当前只要知道这是“真正落地为器件对象”的关键位置
- 可以暂时不深挖内部实现

## 建议的阅读顺序

这一阶段建议按下面顺序读：

1. `N_IO_NetlistImportTool.h`
2. `N_IO_NetlistImportTool.C`
3. `N_IO_CircuitBlock.h`
4. `N_IO_CircuitBlock.C`
5. `N_IO_DeviceBlock.h`
6. `N_IO_ParameterBlock.h`
7. `N_IO_OptionBlock.h`
8. `N_DEV_DeviceMgr.h`

目标不是一次全懂，而是逐步回答：

- 入口是谁
- 语句怎么分类
- 数据先被装进什么对象
- 最后由谁接手构建

## 当前推荐的最小对象清单

第三阶段至少要记住这些名字：

- `NetlistImportTool`
- `CircuitBlock`
- `CircuitContext`
- `DeviceBlock`
- `ParameterBlock`
- `OptionBlock`
- `FunctionBlock`
- `DeviceMgr`
- `Topology`

如果这几个对象之间的关系能说清楚，第三阶段就已经建立起主干认知了。

## 一张文字版转换图

当前可以先把转换链画成这样：

```text
netlist file
  -> NetlistImportTool::constructCircuitFromNetlist
  -> CircuitBlock::parseNetlistFilePass1
  -> CircuitBlock::handleLinePass1
     -> DeviceBlock
     -> ParameterBlock
     -> OptionBlock
     -> FunctionBlock
     -> sub-CircuitBlock
  -> CircuitContext / CircuitBlock tables
  -> DeviceMgr / Topology
```

这张图已经足够作为第三阶段的第一版导航图。

## 当前不建议深挖的内容

这一阶段先不要陷进这些地方：

- 所有 `.OPTIONS` 的注册细节
- 所有 `include` / `library` 分支的边角处理
- distribution tool 的完整逻辑
- mutual inductance 的单独 pass 细节
- `DeviceMgr::addDeviceInstance(...)` 的全部内部过程

它们都属于真实流程的一部分，但不是第三阶段主线最核心的理解点。

## 当前结论

这次阅读路线可以先得出这些结论：

1. 第三阶段的总入口是 `NetlistImportTool::constructCircuitFromNetlist(...)`
2. `CircuitBlock::handleLinePass1(...)` 是语句分类中心
3. Xyce 不是直接把 netlist 文本变成最终器件对象，而是先转成 block/context 形式
4. `CircuitBlock` 和 `CircuitContext` 分别对应 file hierarchy 和 subcircuit hierarchy
5. 真正更靠近最终器件对象的构建发生在 `DeviceMgr` 和 `Topology` 层

## 下一步还要继续追踪什么

如果继续沿第三阶段深入，下一步最自然的是：

1. 单独追 `.MODEL` 的路径
2. 单独追一个普通器件，例如 resistor 的路径
3. 确认 `DeviceBlock` 最终如何变成 `InstanceBlock` / device instance
4. 确认 parser 结果何时交给 `Topology`

也就是从“总体路线图”进入一条更具体的纵向追踪：

```text
一行 netlist
  -> block
  -> device/model
  -> topology
```
