# 当前 Xyce 安装对象与能力边界

## 1. 验证对象

当前验证对象：

```bash
/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release/bin/Xyce
```

版本：

```text
Xyce Release 7.10.0-opensource
```

构建安装来源：

```text
notes/build-and-install/04-layered-minimal-build-execution-log.md
```

最终构建结论：

```text
Xyce installed:                    yes
Installed Xyce version:            7.10.0-opensource
Serial minimal configuration:      yes
Runtime BLAS/LAPACK provider:      Mentor OpenBLAS
Cadence BLAS/LAPACK removed:       yes
Minimal resistor smoke simulation: yes
```

## 2. 当前安装方式与启动范围

当前安装是 `eda` 用户家目录下的项目内安装，不是系统级公共安装。

```text
eda 用户：可在任意工作目录用绝对路径启动；加入 PATH 后也可直接运行 Xyce
其它用户：当前不可直接使用
```

原因：

```text
/home/eda  drwx------ eda eda
```

其它用户无法穿越 `/home/eda`，也就无法访问当前 Xyce binary 及其家目录下依赖：

```text
/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib64/libamd.so.3
```

当前 binary 的关键 RUNPATH：

```text
$ORIGIN/../lib
/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib64
/opt/mentor/Calibre2023/aok_cal_2023.2_16.9/pkgs/icv.aok/julia/1.5/lib
```

## 3. 当前 runtime 依赖

当前 installed Xyce 已确认运行时绑定到 Mentor OpenBLAS：

```text
libopenblas.so.0 => /opt/mentor/Calibre2023/aok_cal_2023.2_16.9/pkgs/icv.aok/julia/1.5/lib/libopenblas.so.0
libgcc_s.so.1    => /lib64/libgcc_s.so.1
libgfortran.so.5 => /lib64/libgfortran.so.5
libquadmath.so.0 => /lib64/libquadmath.so.0
```

注意：Mentor OpenBLAS 是本机务实 fallback，不是最理想的公共发布依赖。若将来做多用户公共安装，优先考虑系统 OpenBLAS/LAPACK 或公共前缀内项目专用 OpenBLAS。

## 4. 当前 binary 能力摘要

`Xyce -capabilities` 显示当前构建包含：

```text
Serial
Reaction parser
ROL enabled
Build compiler is C++17 compliant
Stokhos enabled
Amesos2 (Basker and KLU2) enabled
```

含义：

- 当前是串行版本，不是 MPI 并行版本；
- 保留了 Trilinos 求解器栈中的关键组件；
- Amesos2/KLU2/Basker 可用于当前开源串行求解路径；
- 已经完成最小 resistor `.OP` / DC operating point 冒烟测试。

## 5. 已观察到的常见器件支持

`Xyce -param` 设备参数列表中可见常见模拟器件类型，包括：

```text
R: Resistor
C: Capacitor
L: Inductor
V/I: independent voltage/current sources
E/F/G/H: controlled sources
B: expression based voltage/current source
D: Diode
Q: BJT
J: JFET
M: MOSFET, multiple model levels
MESFET
ADC/DAC and simple behavioral digital interface devices
```

这说明当前 binary 具备常见 SPICE 类基础器件与若干行为/混合信号接口器件。

## 6. 当前构建明确关闭的能力

CMake cache 中当前关闭项：

```text
Xyce_PARALLEL_MPI=OFF
Xyce_USE_FFT=OFF
Xyce_PLUGIN_SUPPORT=OFF
Xyce_ADMS_MODELS=OFF
Xyce_NEURON_MODELS=OFF
Xyce_NONFREE_MODELS=OFF
Xyce_RAD_MODELS=OFF
Xyce_TEST_BINARIES=OFF
BUILD_TESTING=OFF
```

因此当前 binary 不是“功能最大化构建”，而是“开源、串行、最小可用、适合学习和基础仿真”的构建。

## 7. 当前适用性判断

当前安装适合：

- 学习 Xyce 内核、器件模型、netlist 解析、非线性求解与时间积分；
- 基础 R/C/L、源、受控源、二极管、BJT、JFET、MOSFET 电路；
- 小到中等规模串行 DC operating point、DC sweep、瞬态仿真、基础小信号分析；
- 使用公开 SPICE 模型做教学、验证、算法学习、器件/电路原理实验；
- 建立源码阅读时的可复现小型 netlist 回归集。

当前安装不应直接视为：

- 商业 PDK 下的生产级 Spectre/HSPICE 替代；
- tape-out / sign-off 仿真器；
- 大规模并行模拟仿真环境；
- 完整插件、ADMS/Verilog-A、非自由模型、辐照模型或 FFT 相关流程。

## 8. 当前结论

当前 Xyce 对“学习 Xyce 内核、运行基础/中等复杂度开源模拟电路、理解 SPICE 求解流程”已经足够完善。

但对“商业 PDK 下的日常生产级模拟 IC 设计仿真”，还不能直接替代 Spectre/HSPICE，也不应视为完整 sign-off 仿真器。

后续功能验证应使用分层 netlist 回归来逐项确认边界。
