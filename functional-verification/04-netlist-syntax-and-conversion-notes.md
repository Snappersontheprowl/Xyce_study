# 主流网表语法与公开转换工具笔记

## 1. 核心结论

“网表”不是一种统一语法，而是一类描述电路连接、器件、模型、参数和分析控制的文本/结构化格式。

主流网表大致可分为：

1. SPICE 家族模拟网表；
2. Spectre native 网表；
3. CDL / LVS 用连接网表；
4. Verilog / SystemVerilog 结构网表；
5. EDIF / BLIF / JSON 等数字综合中间网表；
6. DSPF / SPEF / PEX 等寄生提取网表；
7. Verilog-A / Verilog-AMS 等模型/混合信号描述。

公开转换工具是存在的，但不存在一个“任意语法之间完全保真互转”的通用工具。

最可靠的转换通常发生在同一语义层内部，例如：

```text
HSPICE / PSpice / Spectre 子集 -> Xyce
Verilog RTL / gate-level -> BLIF / EDIF / JSON
layout extracted netlist -> SPICE-like LVS netlist
schematic -> SPICE / Spectre / Verilog netlist
```

跨语义层转换，例如：

```text
SPICE transistor-level analog netlist -> synthesizable Verilog RTL
Spectre PDK netlist -> arbitrary SPICE simulator
DSPF/PEX netlist -> clean schematic netlist
```

通常不可能自动、完全、无损完成。

## 2. 主流网表语法类别

### 2.1 SPICE 家族

常见成员：

```text
Berkeley SPICE
ngspice
HSPICE
PSpice
LTspice
Xyce
Eldo / SmartSpice 等 SPICE-like 方言
```

典型特点：

- 行式文本；
- 元件前缀有语义，例如 `R` 电阻、`C` 电容、`L` 电感、`V` 电压源、`I` 电流源、`D` 二极管、`Q` BJT、`M` MOS、`X` 子电路实例；
- 常见控制语句包括 `.MODEL`、`.SUBCKT`、`.PARAM`、`.OP`、`.DC`、`.TRAN`、`.AC`、`.NOISE`、`.PRINT`；
- 方言差异主要在模型参数、函数表达式、控制语句、库/角落语法、行为源语法、单位和 continuation 规则。

对 Xyce 而言，SPICE 家族是最接近的输入生态，但不同 SPICE 方言仍可能需要转换或手工修正。

### 2.2 Spectre native

Spectre 是 Cadence 的模拟仿真器，其 native netlist 与 SPICE 相近但不是同一种语法。

典型差异包括：

- 实例语法；
- 参数语法；
- `simulator lang=spectre` / `simulator lang=spice` 混合语法；
- PDK 模型库、section/corner、include/lib 组织方式；
- Verilog-A / bsource / ahdl 等特性。

Spectre 与 SPICE 之间可以做子集转换，但 PDK 级别网表经常依赖 simulator-specific 功能，不能默认无损转换。

### 2.3 CDL / LVS netlist

CDL 常见于版图验证、LVS、寄生前后流程。

特点：

- 通常是 SPICE-like；
- 更强调 connectivity；
- 分析语句和仿真控制信息可能缺失；
- 器件参数可能被简化；
- 主要用于 “layout vs schematic” 连接一致性检查，而不是直接作为完整仿真 deck。

### 2.4 Verilog / SystemVerilog 结构网表

常见于数字设计：

```text
module / instance / wire / assign / cell instance
```

它描述的是数字逻辑连接，不是 SPICE 方程级器件模型。

可用于：

- RTL；
- gate-level netlist；
- mixed-signal co-simulation 中的数字部分；
- standard-cell level connectivity。

它和 SPICE transistor-level netlist 之间不是简单语法互换关系。

### 2.5 EDIF / BLIF / JSON 等数字网表

这些多用于综合、形式验证、FPGA/ASIC 数字流程。

例如 Yosys 可以将设计写出为：

```text
Verilog
BLIF
EDIF
JSON
AIGER
```

这类转换服务于数字综合/实现，不解决模拟 SPICE/Spectre 网表互转问题。

### 2.6 DSPF / SPEF / PEX 寄生网表

这些格式用于后仿和寄生信息交换：

- SPEF 常见于数字时序/寄生；
- DSPF / extracted SPICE 常见于晶体管级后仿；
- PEX SPICE 网表可能包含大量寄生 R/C、子电路层次和 layout-extracted instance 名称。

它们可以导入某些仿真器，但通常不适合“还原”为干净 schematic netlist。

### 2.7 Verilog-A / Verilog-AMS

严格说，Verilog-A/AMS 更像模型/行为描述语言，不只是 netlist。

它常用于：

- compact model；
- 行为模拟模块；
- mixed-signal interface；
- PDK 模型扩展。

是否能转换为 Xyce 可用模型，取决于 Xyce/ADMS 支持范围、模型语法和构建时是否启用相关模型。

当前本项目 Xyce 构建中：

```text
Xyce_ADMS_MODELS=OFF
Xyce_PLUGIN_SUPPORT=OFF
```

因此不应默认支持自定义 Verilog-A/ADMS 模型流。

## 3. 公开转换/生成工具

### 3.1 XDM：HSPICE / PSpice / Spectre -> Xyce

XDM 是 Sandia / Xyce 项目的网表转换器。

公开资料说明：

```text
XDM can translate PSpice, HSpice, and Spectre netlist files into Xyce-compatible netlist files.
```

定位：

```text
commercial/SPICE-like netlist -> Xyce-compatible netlist
```

它不是任意格式互转工具，而是面向 Xyce 的转换器。对本项目而言，XDM 是最值得后续研究的网表转换工具。

### 3.2 Xschem：schematic -> SPICE / Spectre / Verilog / VHDL

Xschem 是 schematic capture 工具，不是“已有网表之间互转”的通用转换器。

但它可以从 schematic 生成多种 netlist。Xschem 文档说明其预定义 netlisting modes 包括：

```text
SPICE
Verilog
Spectre
VHDL
```

定位：

```text
schematic source of truth -> 多种后端 netlist
```

这比“把一个已生成的 SPICE 网表翻译成 Verilog”更可靠，因为 schematic 中保留了符号、属性、端口顺序和层次信息。

### 3.3 gEDA / gnetlist：schematic -> 多种 netlist backend

gEDA 的 `gnetlist` 可通过 backend 输出不同格式，包含 SPICE-compatible netlist。

定位：

```text
schematic -> SPICE / PCB / BOM / 其它 backend
```

它适合从 gEDA schematic 生成仿真或 PCB 工具需要的网表，不适合作为复杂 PDK 网表的保真转换器。

### 3.4 Netgen：netlist conversion + LVS comparison

Netgen 是开源 LVS / netlist management 工具。其文档说明它有两个方向：

```text
convert netlists between different formats
compare two netlists for equivalence
```

但在现代开源 IC 流程中，Netgen 主要被当作 LVS 比较工具使用。

定位：

```text
SPICE-like / layout-extracted / schematic netlist connectivity comparison
```

它不是模拟仿真 deck 的语义级翻译器。

### 3.5 KLayout：layout-to-netlist / SPICE-like netlist import/export

KLayout 的 LVS / layout-to-netlist 功能可导入/导出某种 SPICE netlist flavor，并支持一定的读写定制。

定位：

```text
layout extraction / LVS netlist / SPICE-like connectivity exchange
```

它适合版图验证和提取流程，不是 HSPICE/Spectre/Xyce 仿真 deck 的通用互转器。

### 3.6 Yosys：数字网表转换

Yosys 是 Verilog RTL synthesis framework，支持写出 JSON、BLIF、AIGER 等格式，也可写出综合后的 Verilog/EDIF 等数字网表格式。

定位：

```text
digital RTL / gate-level netlist -> digital implementation/interchange formats
```

它非常适合数字网表转换，但不解决模拟 SPICE/Spectre netlist 转换问题。

### 3.7 Qucs-S / KiCad / 其它 GUI 前端

这类工具通常是：

```text
schematic editor -> generate netlist -> call simulator backend
```

例如 Qucs-S 可以用 Xyce 作为仿真后端，但它本身不是“任意网表互转工具”。

## 4. 转换为什么困难

网表转换难点不只是语法。

真正困难的是语义：

1. 器件模型不等价；
2. PDK 中含有 simulator-specific 参数、函数、include/lib section；
3. 行为源表达式语法不同；
4. 数值选项、收敛策略、初始条件语义不同；
5. 温度、corner、Monte Carlo、统计参数语法不同；
6. Verilog-A/AMS、AHDL、plugin model 不是简单文本替换；
7. 寄生网表可能携带巨量 RC 和层次命名，转换后可读性很差；
8. 数字网表与模拟网表描述的物理层次不同。

因此公开工具常见定位是：

```text
尽量转换可转换子集 + 报告未支持语法 + 需要人工修正/验证
```

而不是：

```text
一键无损互转所有网表
```

## 5. 对当前 Xyce 项目的建议

本项目下一步若要研究网表兼容，建议优先顺序：

1. 继续使用手写 Xyce/SPICE netlist 做功能验证；
2. 引入 XDM，测试 HSPICE/PSpice/Spectre 子集到 Xyce 的转换；
3. 选择一个简单 HSPICE-like MOS netlist，验证 XDM 输出能否被当前 Xyce 运行；
4. 再测试 Spectre native 子集；
5. 最后才尝试实际 PDK model card。

建议新增验证矩阵：

```text
FV-009: XDM HSPICE -> Xyce simple R/C/MOS netlist
FV-010: XDM Spectre -> Xyce simple R/C/MOS netlist
FV-011: Xschem generated SPICE netlist -> Xyce
FV-012: KLayout/Netgen LVS-style SPICE netlist -> Xyce syntax check
FV-013: PTM/BSIM model card through XDM or direct Xyce include
```

## 6. XDM 安装复杂度判断

### 6.1 结论

XDM 的安装复杂度应按两条路线区分：

1. 使用官方发布的二进制包；
2. 从源码自行编译。

如果能取得并使用与当前 Linux 环境兼容的官方二进制包，安装复杂度预计较低，主要是解压、设置 `PATH`、运行 `xdm_bdl` 或 `xdm_bdl.py` 做验证。

如果从源码编译，复杂度预计中等偏高。它不需要 Trilinos 级别的大型依赖链，但对以下三者的匹配比较敏感：

- Boost / Boost.Python；
- Python 3；
- C++ 编译器。

官方 XDM README 明确说明：

```text
Building XDM can be tricky since there are many versions of Boost, Python 3, and C++ compilers available not all of which are compatible with each other.
```

### 6.2 当前本机环境风险点

当前机器上已经观察到：

```text
Python 3.10.19
CMake 3.26.5
GCC 15.2.1
system Boost 1.66.0
```

其中 Boost 1.66.0 低于官方 README 中提到的 Boost 1.70.0+ 开发/推荐线；Python 3.10 也高于官方说明的 Python 3.8 / 3.9 开发线；GCC 15 明显新于官方说明的 GCC 8.x 开发线。

这不代表一定不能构建，但意味着不能把 XDM 当成“直接 cmake 一次就稳过”的小工具。

### 6.3 推荐策略

本项目建议采用分层策略：

1. 优先尝试官方 release/binary 形式的 XDM；
2. 若 binary 不适配，再考虑源码构建；
3. 源码构建时，不建议混用系统 Boost 1.66 与默认 Python 3.10；
4. 更干净的方式是单独准备一套 XDM 专用依赖前缀，例如：

```text
out/tools/xdm-2.7/
out/tools/xdm-deps/
```

5. 若需要源码构建，优先考虑：

```text
Boost 1.70+ / 1.74 / 1.78
Python 3.8 或 3.9
C++11-compatible compiler
```

6. 先只验证 `xdm_bdl --help`、最小 HSPICE/PSpice/Spectre 输入转换，不要一开始就拿 PDK 级网表做压力测试。

### 6.4 是否值得安装

值得，但不应插入当前 Xyce 最小构建主线。

XDM 更适合作为 functional verification 的下一阶段工具链：

```text
Xyce binary 已验证可用
  -> 安装/验证 XDM
  -> 转换简单网表
  -> Xyce -syntax 检查
  -> Xyce 实跑
  -> 与手工 Xyce deck 对比结果
  -> 再进入真实 PDK / commercial SPICE 方言迁移
```

这样即使 XDM 构建遇到 Boost.Python 问题，也不会污染已经完成的 Xyce 主安装。

## 7. 参考资料

- Xyce Documentation & Tutorials: https://xyce.sandia.gov/documentation-tutorials/
- Xyce/XDM GitHub: https://github.com/Xyce/XDM
- XDM User Guide: https://xyce.sandia.gov/files/xyce/XDM_User_Guide_2.6.pdf
- Xschem netlisting manual: https://repo.hu/projects/xschem/xschem_man/netlisting.html
- gEDA gnetlist manual: https://linux.die.net/man/1/gnetlist
- Netgen tutorial: https://opencircuitdesign.com/netgen/tutorial/tutorial.html
- KLayout LVS input/output documentation: https://klayout.org/downloads/master/doc-qt4/manual/lvs_io.html
- Yosys output backend documentation: https://yosyshq.readthedocs.io/projects/yosys/en/latest/cmd/index_backends.html
