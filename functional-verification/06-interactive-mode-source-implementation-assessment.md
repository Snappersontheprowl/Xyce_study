# Xyce interactive mode 源码实现难度评估

## 1. 结论

在 Xyce 源码上实现“某种交互式控制”是可行的；实现“类似 Spectre interactive mode 的完整交互环境”难度较高。

推荐把目标分成四档：

| 档位 | 目标 | 是否推荐 | 难度 |
|---|---|---:|---:|
| A | 外部 Python/shell/Jupyter wrapper，反复生成 netlist 并调用 Xyce | 推荐先做 | 低 |
| B | 基于 Xyce C/Python interface 做外部交互会话 | 推荐作为第一阶段源码相关实验 | 中 |
| C | 在 Xyce 源码中新增 `XyceInteractive` executable 或 `Xyce -interactive` | 可做原型 | 中高 |
| D | 做到 Spectre interactive 级别：会话内 alter、run、save、query、重跑、复杂状态管理 | 不建议作为近期目标 | 高到很高 |

最稳妥路线：

```text
先验证 Xyce library/C interface
  -> 做外部 Python REPL 原型
    -> 再决定是否把 REPL 移入 C++ 源码
      -> 最后才考虑 Spectre-like 功能扩展
```

## 2. 源码中已有的有利条件

Xyce 不是完全没有交互控制基础。源码中已经存在 `Simulator` 顶层类，其生命周期不是只藏在 `main()` 中。

关键文件：

```text
vendor/Xyce-7.10.0/src/Xyce.C
vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h
vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C
vendor/Xyce-7.10.0/utils/XyceCInterface/N_CIR_XyceCInterface.h
vendor/Xyce-7.10.0/utils/XyceCInterface/xyce_interface.py.cmake
vendor/Xyce-7.10.0/utils/XyceCInterface/XyceRest.py
```

`src/Xyce.C` 的 standalone 入口目前是：

```text
创建 Xyce::Circuit::Simulator
调用 xyce.run(argc, argv)
成功后进程退出
```

`Simulator::run()` 内部流程是：

```text
initialize()
runSimulation()
finalize()
```

但 `Simulator` 也公开了更细的接口：

```text
initialize()
initializeEarly()
initializeLate()
runSimulation()
simulateUntil()
finalize()
simulationComplete()
setCircuitParameter()
getCircuitValue()
obtainResponse()
getTime()
getFinalTime()
```

这些接口说明：Xyce 已经可以被外部程序以 library-like 方式驱动，不是纯粹不可拆分的一次性 CLI。

## 3. 源码中已有的外部接口

Xyce 7.10 源码中有 C interface：

```text
utils/XyceCInterface/N_CIR_XyceCInterface.h
```

它暴露了：

```text
xyce_open()
xyce_close()
xyce_initialize()
xyce_runSimulation()
xyce_simulateUntil()
xyce_simulationComplete()
xyce_getTime()
xyce_getFinalTime()
xyce_getCircuitValue()
xyce_setCircuitParameter()
xyce_obtainResponse()
```

源码里还有 Python ctypes wrapper：

```text
utils/XyceCInterface/xyce_interface.py.cmake
```

以及一个 REST 示例：

```text
utils/XyceCInterface/XyceRest.py
```

REST 示例中已经有类似会话接口：

```text
/xyce_open
/xyce_initialize
/xyce_simulateuntil
/xyce_run
/xyce_getsimtime
/xyce_getfinaltime
/xyce_getcircuitvalue
/xyce_setcircuitparameter
/xyce_close
```

这说明，若目标是“做一个交互式控制层”，最自然入口不是直接改解析器和求解器，而是先复用 C/Python interface。

## 4. 当前最小构建的限制

当前项目的 Xyce 是最小串行静态构建：

```text
BUILD_SHARED_LIBS=OFF
Xyce_PLUGIN_SUPPORT=OFF
```

本地安装中可以看到：

```text
out/xyce-7.10-serial-release/include/N_CIR_XyceCInterface.h
out/xyce-7.10-serial-release/share/xyce_interface.py
out/xyce-7.10-serial-release/share/XyceRest.py
```

但当前安装没有发现：

```text
libxycecinterface.so
```

原因是 `utils/XyceCInterface/CMakeLists.txt` 中的 `xycecinterface` target 是：

```text
add_library(xycecinterface EXCLUDE_FROM_ALL)
```

并且当前构建 `BUILD_SHARED_LIBS=OFF`。所以如果要验证 Python/C interface，可能需要一个新的 shared build 或显式构建/安装 `xycecinterface` target。

这不影响“可实现性”，但影响近期实验路线：不能假设当前已安装 binary 可以立刻被 Python `ctypes` 当动态库加载。

## 5. 分档难度评估

### 5.1 A 档：外部 wrapper，不改 Xyce 源码

做法：

```text
Python/Jupyter/shell 生成 netlist
调用 Xyce executable
解析 .prn/.csd/.raw/.dat
提供类似 run/plot/measure/sweep 的交互体验
```

难度：低。

预计工作量：

```text
1-3 天可做出可用原型
1-2 周可做成项目内稳定工具
```

优点：

- 不需要重新编译 Xyce；
- 不触碰 Xyce 内部状态机；
- 错误隔离好；
- 适合 functional verification；
- 最符合当前学习阶段。

缺点：

- 每次运行一般是新进程；
- 不能在同一个仿真器进程内保留求解状态；
- 不是真正的 Spectre interactive。

### 5.2 B 档：基于 Xyce C/Python interface 的外部交互层

做法：

```text
构建 libxycecinterface.so
Python REPL/REST/Jupyter 通过 ctypes 驱动 Xyce::Circuit::Simulator
使用 initialize/runSimulation/simulateUntil/get/set 接口
```

难度：中。

预计工作量：

```text
2-5 天：构建 interface + 跑通官方示例
1-3 周：做出能用的项目内 REPL/REST 原型
```

优点：

- 使用 Xyce 已经提供的接口；
- 可做到一个 session 内 `simulateUntil()`；
- 可查询时间、最终时间、部分变量/参数/measure；
- 比改核心求解器安全。

限制：

- 当前最小构建没有现成 `libxycecinterface.so`；
- 多数能力偏 transient/mixed-signal co-simulation；
- `simulateUntil()` 主要服务时间推进，不是通用 DC/AC/noise interactive；
- `setCircuitParameter()` 只能改已存在的 circuit/device parameter，不等价于任意 alter netlist；
- 动态新增/删除器件、改变拓扑、重建矩阵等不属于轻量接口能力。

### 5.3 C 档：源码中新增 `XyceInteractive` 或 `Xyce -interactive`

做法：

在 C++ 源码中新增一个 REPL：

```text
Xyce -interactive

xyce> load circuit.cir
xyce> syntax
xyce> run
xyce> time
xyce> until 1e-6
xyce> get V(out)
xyce> set R1:R 2k
xyce> measure gain
xyce> close
xyce> quit
```

可复用：

```text
Xyce::Circuit::Simulator
Simulator::initialize()
Simulator::runSimulation()
Simulator::simulateUntil()
Simulator::getCircuitValue()
Simulator::setCircuitParameter()
Simulator::finalize()
```

难度：中高。

预计工作量：

```text
1-2 周：非常小的 C++ REPL 原型
3-6 周：可用的基本 interactive executable
2-3 月：相对稳健、可文档化、可测试的功能
```

主要改动点：

1. 命令行解析：增加 `-interactive` 或新 executable；
2. REPL parser：解析 `load/run/until/get/set/status/quit` 等命令；
3. 生命周期管理：保证 `initialize/finalize` 可重复或明确每个 session 只 load 一次；
4. 错误恢复：避免某些错误直接 `exit` 或 abort 整个进程；
5. 输出控制：避免每个命令都输出完整 batch banner/timing；
6. 测试：新增 REPL 命令脚本化测试。

近期可做，但建议先限制功能范围。

### 5.4 D 档：Spectre-like 完整 interactive mode

如果目标接近 Spectre：

```text
会话内 alter 参数
会话内切换 analysis
多次 run/re-run
动态 save/print
动态查询 waveform
动态修改模型/实例
支持复杂 PDK deck
支持 DC/AC/tran/noise 等多分析
支持脚本化 command file
支持并行 MPI
错误不中断会话
```

难度：高到很高。

预计工作量：

```text
数月级
若要求产品级可靠性，可能接近一个小型子项目
```

主要原因：

- Xyce 主程序仍是 batch-first 架构；
- 很多错误路径可能假设仿真即将退出；
- netlist 解析、topology、device manager、linear system、analysis manager 的状态强耦合；
- 动态拓扑修改会牵涉矩阵结构重建；
- 不同分析类型的状态恢复规则不同；
- 输出系统主要面向文件；
- 并行 MPI 下 REPL 输入/状态同步更复杂；
- 要做到 Spectre 那种交互体验，还需要命令语言、帮助系统、脚本执行和 regression tests。

## 6. 最小源码原型建议

如果真的想“在源码上实现”，建议不要一上来改 `Xyce` 主程序，而是新增一个实验性 executable：

```text
src/XyceInteractive.C
```

第一版只支持：

```text
load <netlist>
run
until <time>
time
finaltime
get <expr-or-var>
set <param> <value>
status
quit
```

明确不支持：

```text
动态新增/删除器件
动态修改拓扑
动态重读模型库并增量更新
同一 session 多次 load 不同 netlist
完整 DC/AC/noise alter-run
MPI parallel interactive
GUI/waveform 内嵌
```

第一版目标不是复刻 Spectre，而是证明：

```text
Xyce::Circuit::Simulator 能被 REPL 生命周期稳定驱动
```

## 7. 推荐验证里程碑

建议新增验证矩阵：

```text
FV-010: 检查/构建 Xyce C interface 动态库
FV-011: Python ctypes 初始化 Xyce 并运行 resistor netlist
FV-012: Python 调用 simulateUntil 跑 RC transient 分段推进
FV-013: Python getCircuitValue 查询 V(out)
FV-014: Python setCircuitParameter 修改简单器件参数
FV-015: C++ XyceInteractive 原型 load/run/get/time
FV-016: C++ XyceInteractive 原型 until/time/get
```

这条路线比直接开挖 `-interactive` 更安全，因为它先确认已有 API 的真实边界。

## 8. 判断

综合源码结构、已有接口和当前构建状态：

```text
外部交互体验：容易
基于 Xyce C/Python interface：中等
源码中做有限 REPL：中高
实现 Spectre-like 完整 interactive：困难
```

当前最值得做的不是马上改核心，而是先做：

```text
Xyce shared/C interface build
  -> Python REPL 原型
    -> 分段 transient / get / set 验证
      -> 再决定是否写 C++ interactive executable
```

如果这个阶段证明 `simulateUntil()`、`getCircuitValue()`、`setCircuitParameter()` 能满足主要需求，再把它内化到 Xyce 源码中才有意义。
