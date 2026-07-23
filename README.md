# Xyce 源码学习与验证工作区

本仓库是一个围绕 Xyce 7.10.0 的个人学习、构建、验证和源码探索工作区。

当前重点不是维护一个 Xyce 上游分叉，而是把以下内容放在一个结构清晰、可持续追踪的项目里：

1. Xyce 源码阅读笔记；
2. Xyce 及关键依赖的本地编译安装记录；
3. 当前安装的功能验证用例；
4. 网表转换、GUI/前端、interactive mode 等工程能力评估；
5. 后续可能进行的小型源码实验。

更细的学习计划、笔记组织方式和长期阅读节奏，请参考：

```text
notes/README.md
```

## 当前状态

截至 2026-07-23，本项目已经完成：

1. Xyce 7.10.0 最小串行构建与安装；
2. SuiteSparse 7.8.3 最小 AMD 依赖构建；
3. Trilinos 14.4 串行依赖构建；
4. Mentor OpenBLAS 替代 Cadence BLAS/LAPACK；
5. Xyce 基础模拟功能验证 FV001-FV008；
6. XDM 2.7.0 binary 安装与最小 HSPICE-like 网表转换验证 FV009；
7. Xyce GUI/frontend 能力说明；
8. Xyce 是否具备 Spectre-like interactive mode 的源码级评估。

当前已安装 Xyce：

```text
out/xyce-7.10-serial-release/bin/Xyce
```

版本：

```text
Xyce Release 7.10.0-opensource
```

当前构建定位：

```text
serial + Release + static + no-plugin + no-FFT + no-test
```

运行时 BLAS/LAPACK provider：

```text
Mentor OpenBLAS
/opt/mentor/Calibre2023/aok_cal_2023.2_16.9/pkgs/icv.aok/julia/1.5/lib/libopenblas.so
```

## 仓库结构

```text
.
├── AGENTS.md
├── artifacts/
├── build/
├── docs/
├── functional-verification/
├── notes/
├── out/
├── README.md
├── scripts/
└── vendor/
```

主要目录说明：

- `vendor/`：本地源码快照，例如 `vendor/Xyce-7.10.0/`；
- `artifacts/source/`：下载的源码包、依赖源码包等本地归档；
- `artifacts/tools/`：下载的二进制工具包，例如 XDM zip，本地保留但不纳入 Git；
- `build/`：编译过程生成物、本地日志和临时构建目录；
- `out/`：本地安装前缀，例如已安装的 Xyce、Trilinos、SuiteSparse、XDM 解压目录；
- `notes/`：源码学习笔记、构建计划、构建执行日志；
- `functional-verification/`：当前 Xyce 安装的功能验证计划、结果和测试用例；
- `docs/`：横向专题文档，例如 C++ 阅读补充；
- `scripts/`：可复用辅助脚本。

## 构建与安装记录

构建安装主线文档位于：

```text
notes/build-and-install/
```

关键文档：

- `notes/build-and-install/01-build-and-install-architecture.md`
- `notes/build-and-install/02-layered-minimal-build-plan.md`
- `notes/build-and-install/03-gcc-toolchain-check.md`
- `notes/build-and-install/04-layered-minimal-build-execution-log.md`

本项目采用分层构建思路：

```text
toolchain
  -> SuiteSparse minimal AMD
    -> Trilinos 14.4 serial
      -> Xyce 7.10.0 serial minimal
        -> functional verification
```

已知关键构建选择：

```text
GCC: /opt/rh/gcc-toolset-15/root/usr/bin/gcc
G++: /opt/rh/gcc-toolset-15/root/usr/bin/g++
CMake: 3.26.5
flex: /home/eda/.local/xyce-tools/bin/flex
bison: /home/eda/.local/xyce-tools/bin/bison
MPI: OFF
Fortran: OFF
Xyce plugin support: OFF
Xyce FFT: OFF
Xyce tests: OFF
```

Trilinos 14.4 使用 GCC 15 时曾需要少量源码补丁，补丁记录见：

```text
notes/build-and-install/patches/
```

## 功能验证状态

功能验证工作区：

```text
functional-verification/
```

当前验证结果汇总：

```text
functional-verification/02-verification-results.md
```

已完成用例：

| ID | 用例 | 状态 | 说明 |
|---|---|---|---|
| FV001 | resistor OP | 通过 | 1 V / 1 kΩ 基础 DC operating point |
| FV002 | diode IV | 通过 | 二极管非线性 DC sweep |
| FV003 | RC transient | 通过 | RC 一阶瞬态响应 |
| FV004 | RC AC | 通过 | RC 低通小信号频响 |
| FV005 | MOS DC | 通过 | Level 1 MOS DC sweep |
| FV006 | common-source AC | 通过 | MOS 共源放大器 OP + AC |
| FV007 | noise | 通过 | `.NOISE` 分析与噪声输出 |
| FV008 | model-card compat | 通过 | `.include` 简单 Level 1 模型卡 |
| FV009 | XDM HSPICE minimal | 通过 | XDM 2.7.0 binary 将最小 HSPICE-like 网表转换为 Xyce 并成功运行 |

FV009 当前验证链路：

```text
HSPICE-like input netlist
  -> XDM 2.7.0 binary
    -> Xyce-compatible netlist
      -> Xyce -syntax
        -> Xyce run
          -> .csd result
```

结果代表值：

```text
V(1)  =  1.00000000e+00
I(V1) = -1.00000000e-03
```

## XDM 与网表转换

XDM binary 安装与验证计划：

```text
functional-verification/05-xdm-binary-install-and-verification-plan.md
```

网表语法与公开转换工具调研：

```text
functional-verification/04-netlist-syntax-and-conversion-notes.md
```

当前判断：

- XDM 是本项目中最值得优先验证的 Xyce 网表转换工具；
- 已验证最小 HSPICE-like 电阻网表可经 XDM 转成 Xyce 并运行；
- 这不等价于复杂 HSPICE/Spectre/真实 PDK deck 已完整兼容；
- 后续应继续按分层方式验证 `.MODEL`、`.SUBCKT`、`.lib/corner`、真实 PDK preflight。

## GUI / frontend / interactive mode

GUI 与前端集成说明：

```text
functional-verification/03-gui-and-frontend-notes.md
```

当前结论：

```text
Xyce 自带 GUI: no
Spectre-like interactive shell: no
自带轻量绘图脚本: yes
可被外部 GUI 调用: yes
建议当前学习阶段使用 GUI: not yet
```

interactive mode 源码实现难度评估：

```text
functional-verification/06-interactive-mode-source-implementation-assessment.md
```

源码中已经存在可被外部程序驱动的 `Simulator` / C interface 基础，例如：

```text
Simulator::initialize()
Simulator::runSimulation()
Simulator::simulateUntil()
Simulator::getCircuitValue()
Simulator::setCircuitParameter()
Simulator::finalize()
```

但当前最小静态安装没有现成 `libxycecinterface.so`。如果要做真正的 Python/C interface 交互原型，建议新建 shared/interface 构建层，而不是直接污染当前最小安装。

## 源码学习主线

源码学习笔记按主题组织在：

```text
notes/
```

当前主线包括：

- `notes/01-overview/`：整体结构地图；
- `notes/02-startup/`：程序启动流程与顶层 `Simulator`；
- `notes/03-netlist-and-circuit-build/`：netlist 解析与电路构建；
- `notes/04-device-trace/`：器件实例化与拓扑连接；
- `notes/05-analysis-flow/`：分析流程调度；
- `notes/06-solver-and-assembly/`：方程、矩阵、求解；
- `notes/07-device-model-contributions/`：器件模型如何贡献 `Q/F/B/dQdx/dFdx`；
- `notes/parallel/`：并行相关理解。

横向 C++ 补充放在：

```text
docs/cpp/
```

## 常用命令

确认当前 Xyce：

```bash
cd /home/eda/my_lab/projects/study/xyce_study

out/xyce-7.10-serial-release/bin/Xyce -v
out/xyce-7.10-serial-release/bin/Xyce -h | head -n 40
```

运行一个已存在验证用例：

```bash
cd /home/eda/my_lab/projects/study/xyce_study/functional-verification/cases/fv001-resistor-op

/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release/bin/Xyce resistor-op.cir \
  > run.log 2>&1
```

检查常见错误：

```bash
rg -n "Netlist error|MSG_FATAL|MSG_ERROR|Simulation aborted|Xyce Abort|failed|fatal|error" \
  functional-verification/cases/*/run.log
```

确认 XDM：

```bash
cd /home/eda/my_lab/projects/study/xyce_study

xyce_xdm_bin="$(find "$PWD/out/tools" -maxdepth 4 -type f -path '*/bin/xdm_bdl' | sort | head -n 1)"
test -x "$xyce_xdm_bin" && "$xyce_xdm_bin" -h | head -n 40
```

## 版本控制策略

本仓库跟踪学习资料、验证用例、小型文本结果和必要补丁，不跟踪大型源码树、构建产物和下载归档。

主要忽略内容：

```text
vendor/*
artifacts/source/*
artifacts/tools/*
build/
out/
tmp/
logs/
```

例外：

- `vendor/README.md` 可作为源码目录说明；
- `artifacts/source/README.md`、`artifacts/tools/README.md` 可作为本地归档说明；
- 小型 functional verification 输入/输出文本可纳入 Git，便于复现。

每次对项目文档、验证用例或源码补丁做实质修改后，应及时本地提交。

## 官方来源

- Xyce 官方主页：https://xyce.sandia.gov/
- Xyce 官方源码下载页：https://xyce.sandia.gov/downloads/source-code/
- Xyce 官方 GitHub 仓库：https://github.com/Xyce/Xyce
- XDM GitHub 仓库：https://github.com/Xyce/XDM

当前本地源码目录：

```text
vendor/Xyce-7.10.0/
```

该目录是发布版源码快照，不是完整上游 Git checkout。如果以后需要查看上游提交历史，可单独克隆：

```bash
git clone https://github.com/Xyce/Xyce.git
```

## 下一步建议

短期建议继续沿三条线推进：

1. 真实 PDK preflight：
   - 只读扫描模型文件结构；
   - 判断 HSPICE/Spectre 格式、corner 入口、是否加密；
   - 决定直接 Xyce 还是先 XDM。

2. XDM 转换能力扩展：
   - FV010：HSPICE MOS + `.MODEL`；
   - FV011：HSPICE `.SUBCKT`；
   - FV012：Spectre simple netlist；
   - FV013：`.lib/corner` 最小验证。

3. interactive mode 原型路线：
   - 先做外部 Python wrapper；
   - 再验证 Xyce C interface shared build；
   - 最后再考虑 C++ `XyceInteractive` 原型。
