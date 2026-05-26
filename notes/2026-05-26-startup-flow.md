# 2026-05-26 startup flow

## 这次读了哪些文件

- [src/Xyce.C](../vendor/Xyce-7.10.0/src/Xyce.C)
- [src/CircuitPKG/N_CIR_Xyce.h](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h)
- [src/CircuitPKG/N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [src/IOInterfacePKG/N_IO_CmdParse.h](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CmdParse.h)
- [src/IOInterfacePKG/N_IO_CmdParse.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CmdParse.C)

## 这次带着什么问题去读

目标是弄清从进程启动到真正开始仿真之前发生了什么，重点回答四个问题：

1. `main()` 在哪里
2. 命令行参数如何处理
3. 运行时对象和全局选项在哪里初始化
4. `netlist` 加载从哪一步开始

## 启动主线

当前可以先把启动主线记成：

```text
main()
  -> Xyce::Circuit::Simulator
  -> Simulator::run()
  -> initialize()
  -> initializeEarly()
  -> initializeLate()
  -> runSimulation()
```

这条主线已经足够作为第二阶段的阅读骨架。

## 关键定位

### `main()` 在哪里

- `main()` 位于 [src/Xyce.C](../vendor/Xyce-7.10.0/src/Xyce.C)
- 默认执行路径是：
  - 创建 `Xyce::Circuit::Simulator`
  - 调用 `xyce.run(argc, argv)`
- 特殊情况是命令行带 `-dakota` 时，会改走 `Xyce::Dakota::Controller`

### 顶层启动入口在哪里

- 顶层类是 [N_CIR_Xyce.h](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h) 中的 `Xyce::Circuit::Simulator`
- 关键函数在 [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)：
  - `Simulator::run()`
  - `Simulator::initialize()`
  - `Simulator::initializeEarly()`
  - `Simulator::initializeLate()`
  - `Simulator::runSimulation()`

## 初始化阶段切分

从 `Simulator::RunState` 和 `initializeEarly()` / `initializeLate()` 可以整理出下面这条阶段时序：

```text
PARALLEL_INIT
-> PARSE_COMMAND_LINE
-> CHECK_NETLIST
-> OPEN_LOGSTREAM
-> ALLOCATE_SUBSYSTEMS
-> PARSE_NETLIST
-> SETUP_TOPOLOGY
-> INSTANTIATE_DEVICES
-> SETUP_MATRIX_STRUCTURE
-> INITIALIZE_SYSTEM
-> runSimulation()
```

这说明 Xyce 启动阶段已经被明确拆成：

- 前半段：命令行、文件检查、日志、子系统分配、`netlist` 导入
- 后半段：拓扑后处理、矩阵结构建立、系统初始化

## 命令行参数如何处理

命令行解析发生在：

- `Simulator::initializeEarly()`
- 调用 `commandLine_.parseCommandLine(comm_, argc, argv)`

实际解析实现位于：

- [N_IO_CmdParse.C](../vendor/Xyce-7.10.0/src/IOInterfacePKG/N_IO_CmdParse.C)

当前理解：

- `CmdParse` 会遍历 `argv`
- 把 switch 和 string-valued option 分别存入内部 map
- 非 `-` 开头的第一个普通参数会被当作 `netlist`
- 如果发现第二个 `netlist`，一般会报错
- 某些选项如 `-h`、`-v`、`-license` 会直接返回 `DONE`
- 非法选项或缺失参数会返回 `ERROR`

第二阶段需要掌握的不是所有 option 细节，而是这条关系：

```text
argv
  -> CmdParse::parseCommandLine()
  -> commandLine_ 内部状态
  -> Simulator 通过 argExists/getArgumentValue 读取结果
```

## 运行时对象和全局选项在哪里初始化

主要发生在 `initializeEarly()` 和 `initializeLate()`。

### `initializeEarly()` 中的重要动作

- `PARALLEL_INIT`
  - 创建 `Parallel::Manager`
  - 注册 communicator：`Report::registerComm(comm_)`

- `PARSE_COMMAND_LINE`
  - 调用 `commandLine_.parseCommandLine(...)`
  - 处理 `-max-warnings`、`-plugin`、`-param`、`-doc`、`-doc_cat`

- `CHECK_NETLIST`
  - 从 `commandLine_` 里取出 `netlist`
  - 检查 `netlist` 文件和 `-o` 输出文件名是否合法

- `OPEN_LOGSTREAM`
  - 初始化日志流
  - 按需打开 `-l` 和 `-verbose` 对应的文件

- `ALLOCATE_SUBSYSTEMS`
  - 调用 `doAllocations_()`
  - 调用 `doRegistrations_()`
  - 构造 `mainXyceExpressionGroup`
  - 构造 `IO::NetlistImportTool`

### `initializeLate()` 中的重要动作

- `SETUP_MATRIX_STRUCTURE`
  - 调用 `setUpMatrixStructure_()`

- `INITIALIZE_SYSTEM`
  - 调用 `doInitializations_()`
  - 检查 print、measure、FFT 等后续仿真前参数

## `netlist` 从哪一步开始加载

真正开始把 `netlist` 导入系统的阶段是：

- `PARSE_NETLIST`

对应的关键调用是：

```cpp
netlist_import_tool.constructCircuitFromNetlist(...)
```

这一步位于：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)

这说明第二阶段的一个重要结论是：

- `netlist` 不是在 `main()` 里读
- 也不是在命令行解析器里读
- 而是在 `Simulator::initializeEarly()` 完成前置准备之后，通过 `NetlistImportTool` 开始导入

## 当前结论

这次阅读已经能稳定回答第二阶段的四个核心问题：

1. `main()` 在 [src/Xyce.C](../vendor/Xyce-7.10.0/src/Xyce.C)
2. 命令行解析入口在 `commandLine_.parseCommandLine(...)`
3. 运行时对象初始化主要在 `initializeEarly()` 和 `initializeLate()`
4. `netlist` 导入从 `PARSE_NETLIST` 阶段开始，关键调用是 `constructCircuitFromNetlist(...)`

## 当前还没有展开的点

这次没有继续深挖这些内容：

- `doAllocations_()` 里到底分配了哪些具体 subsystem
- `doRegistrations_()` 的注册细节
- `constructCircuitFromNetlist(...)` 的内部解析流程
- `setUpMatrixStructure_()` 如何把拓扑转成矩阵结构
- `runSimulation()` 之后 solver 如何真正开始跑

这些内容属于后续阶段，不必在第二阶段一次性吃完。

## 下一步还要继续追踪什么

按当前主线，下一步最自然的是：

1. 沿着 `constructCircuitFromNetlist(...)` 继续追 `netlist parser`
2. 确认 parser 结果如何进入 `SETUP_TOPOLOGY`
3. 再继续追 `INSTANTIATE_DEVICES`

也就是把主线从：

```text
main -> initialize
```

继续往下推进到：

```text
netlist -> topology -> instantiate devices
```
