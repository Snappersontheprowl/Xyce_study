# Xyce 功能验证工作区

本目录用于记录当前已安装 Xyce 的功能验证工作，而不是记录编译过程本身。编译与安装全过程仍以：

```text
docs/notes/build-and-install/
```

为主。

## 当前验证对象

当前验证对象是项目内已完成安装的 Xyce：

```text
/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release/bin/Xyce
```

已知版本：

```text
Xyce Release 7.10.0-opensource
```

当前安装定位：

```text
serial + Release + static + no-plugin + no-FFT + no-test
```

运行时 BLAS/LAPACK provider：

```text
Mentor OpenBLAS
```

已完成最小冒烟测试：

```text
1 V source + 1 kΩ resistor
V(1)  =  1.00000000e+00
I(V1) = -1.00000000e-03
```

## 本目录文件

```text
functional-verification/
├── README.md
├── 00-current-install-scope.md
├── 01-analog-functional-verification-plan.md
├── 02-verification-results.md
├── 03-gui-and-frontend-notes.md
├── 04-netlist-syntax-and-conversion-notes.md
├── 05-xdm-binary-install-and-verification-plan.md
├── 06-interactive-mode-source-implementation-assessment.md
└── cases/
```

其中：

- `00-current-install-scope.md`：记录当前 Xyce binary、已知能力、关闭项、适用边界；
- `01-analog-functional-verification-plan.md`：定义后续模拟电路功能验证矩阵、用例优先级和验收标准。
- `02-verification-results.md`：记录已执行用例的结果和数值验收结论；
- `cases/`：保存每个可复现 netlist 用例、运行日志和输出结果。

## 验证目标

本阶段不追求“替代 Spectre/HSPICE 做商业 PDK sign-off”，而是验证：

1. 当前 Xyce 是否能稳定运行常见开源/教学模拟电路；
2. DC、OP、TRAN、AC、NOISE 等基础分析链路是否可用；
3. 常见器件模型与 netlist 语法在当前构建中是否可用；
4. 哪些功能边界来自当前最小构建配置，而不是 Xyce 本身能力不足；
5. 为后续阅读 Xyce 源码建立一组可复现的小型功能回归用例。

## 当前总体判断

当前 Xyce 对“学习 Xyce 内核、运行基础/中等复杂度开源模拟电路、理解 SPICE 求解流程”已经足够可用；但对“商业 PDK 下的日常生产级模拟 IC 设计仿真”，还不能直接替代 Spectre/HSPICE，也不应视为完整 sign-off 仿真器。

后续功能验证将通过分层 netlist 回归逐步收敛这个边界。
