# Xyce 模拟功能验证结果汇总

本文记录 `functional-verification/cases/` 下各功能验证用例的执行结果。

## 当前 Xyce

```text
/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release/bin/Xyce
Xyce Release 7.10.0-opensource
```

## 结果表

| ID | 用例 | 状态 | 关键结论 |
|---|---|---|---|
| FV-001 | resistor OP | 通过 | `V(1)=1.0 V`，`I(V1)=-1 mA` |
| FV-002 | diode IV | 通过 | D 器件、非线性 DC、DC sweep 可用，电流随正向电压指数上升 |
| FV-003 | RC transient | 通过 | TRAN、PULSE、电容时间积分可用，`t≈1 us` 时 `V(out)≈0.632 V` |
| FV-004 | RC AC | 通过 | AC 小信号频响可用，`fc≈159 kHz` 处 `|V(out)|≈0.709` |
| FV-005 | MOS DC | 通过 | M 器件与 Level 1 MOS DC sweep 可用，超过阈值后电流上升 |
| FV-006 | common-source AC | 通过 | MOS 放大器 OP + AC 可用，低频小信号增益约 `-9.51 V/V` |
| FV-007 | noise | 通过 | `.NOISE` 语法与噪声输出可用，生成 `NOISE.prn` 与 `_noise.dat` |
| FV-008 | model-card compat | 通过 | `.include` 模型卡、模型识别、MOS DC sweep 可用 |
| FV-009 | XDM HSPICE minimal | 通过 | XDM 2.7.0 可将最小 HSPICE-like 网表转为 Xyce，当前 Xyce 可解析并运行，`V(1)=1.0 V`、`I(V1)=-1 mA` |

## 运行约定

每个 case 目录中保留：

```text
README.md
*.cir
run.log
*.prn 或其它 Xyce 输出文件
```

统一错误检查：

```bash
rg -n "Netlist error|MSG_FATAL|MSG_ERROR|Simulation aborted|Xyce Abort|failed|fatal|error" run.log
```

如果该命令无输出，表示未发现常见失败关键词；仍需结合 `.prn` 或专用输出文件做数值验收。

## 执行摘要

执行时间：

```text
2026-07-22
```

执行命令模式：

```bash
cd functional-verification/cases/<case>
/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release/bin/Xyce <case>.cir > run.log 2>&1
```

所有用例：

```text
exit_status=0
```

统一错误检查对所有 `run.log` 均无输出：

```bash
rg -n "Netlist error|MSG_FATAL|MSG_ERROR|Simulation aborted|Xyce Abort|failed|fatal|error" run.log
```

## 数值验收摘录

### FV-001 resistor OP

输出文件：

```text
functional-verification/cases/fv001-resistor-op/resistor-op.cir.prn
```

结果：

```text
V(1)  =  1.00000000e+00
I(V1) = -1.00000000e-03
```

判断：通过。电流绝对值为 1 mA，符合 `1 V / 1 kΩ`。

### FV-002 diode IV

输出文件：

```text
functional-verification/cases/fv002-diode-iv/diode-iv.cir.prn
```

代表点：

```text
I(V1) @ 0.10 V = -5.677e-13
I(V1) @ 0.80 V = -2.711e-01
```

判断：通过。二极管正向电流绝对值随电压显著上升，非线性 DC sweep 链路可用。

### FV-003 RC transient

输出文件：

```text
functional-verification/cases/fv003-rc-tran/rc-tran.cir.prn
```

代表点：

```text
t≈1.001 us: V(in)=1.000 V, V(out)=0.632 V
t≈2.000 us: V(in)=0.000 V, V(out)=0.233 V
t≈5.000 us: V(in)=1.000 V, V(out)=0.729 V
```

判断：通过。`R*C=1 us`，阶跃后约一个时间常数时 `V(out)≈0.632 V`，符合 RC 一阶响应。

### FV-004 RC AC

输出文件：

```text
functional-verification/cases/fv004-rc-ac/rc-ac.cir.FD.prn
```

代表点：

```text
f=1 Hz:       |V(out)|≈1.000
f≈158.5 kHz: |V(out)|≈0.709
f=1 MHz:     |V(out)|≈0.157
```

判断：通过。理论截止频率 `1/(2*pi*R*C)≈159 kHz`，对应幅值接近 `1/sqrt(2)`。

### FV-005 MOS DC

输出文件：

```text
functional-verification/cases/fv005-mos-dc/mos-dc.cir.prn
```

代表点：

```text
Vg=0.40 V: I(VDS)=-1.387e-12
Vg=0.60 V: I(VDS)=-5.100e-06
Vg=1.80 V: I(VDS)=-8.160e-04
```

判断：通过。Level 1 NMOS 在超过阈值后电流明显上升。

### FV-006 common-source AC

输出文件：

```text
functional-verification/cases/fv006-common-source-ac/common-source-ac.cir.TD.prn
functional-verification/cases/fv006-common-source-ac/common-source-ac.cir.FD.prn
```

OP 点：

```text
Vin  = 1.200 V
Vout = 1.064 V
```

低频 AC 增益：

```text
Re(V(out)) @ 1 Hz = -9.511
Im(V(out)) @ 1 Hz =  0.000
|gain| ≈ 9.511 V/V
```

判断：通过。共源放大器 OP 与 AC 链路可用，低频增益为负，符合反相放大器预期。

### FV-007 noise

输出文件：

```text
functional-verification/cases/fv007-noise/noise.cir.NOISE.prn
functional-verification/cases/fv007-noise/noise.cir_noise.dat
```

代表点：

```text
ONOISE @ 1 Hz = 8.288e-18
INOISE @ 1 Hz = 3.315e-17
```

判断：通过。当前 Xyce binary 接受 `.NOISE` 语法，并生成噪声谱输出。

### FV-008 model-card include compatibility

输出文件：

```text
functional-verification/cases/fv008-model-card-compat/model-card-compat.cir.prn
```

模型卡：

```text
functional-verification/cases/fv008-model-card-compat/simple-nmos-model.lib
```

代表点：

```text
Vg=0.00 V: I(VDS)=-1.387e-12
Vg=1.80 V: I(VDS)=-9.888e-04
```

判断：通过。`.include` 模型卡机制、模型识别和 MOS DC sweep 均可用。

### FV-009 XDM HSPICE-like minimal conversion

输入网表：

```text
functional-verification/cases/fv-009-xdm-hspice-minimal/input/resistor-hspice.sp
```

XDM 转换后网表：

```text
functional-verification/cases/fv-009-xdm-hspice-minimal/out/resistor-hspice.sp
```

Xyce 输出文件：

```text
functional-verification/cases/fv-009-xdm-hspice-minimal/out/resistor-hspice.sp.csd
```

转换摘要：

```text
xdm_bdl 2.7.0
input format=hspice
output format=xyce
Total critical issues reported = 0
Total errors reported          = 0
Total warnings reported        = 1
```

唯一 warning 是 `.option post` 被 HSPICE parser 保留为注释：

```text
* .option post; HSpice Parser Retained (as a comment). Continuing.
```

Xyce 语法检查：

```text
Netlist syntax OK
Device counts: R=1, V=1
```

代表点：

```text
V(1)  =  1.00000000e+00
I(V1) = -1.00000000e-03
```

判断：通过。XDM binary 安装、HSPICE-like 最小网表转换、Xyce `-syntax` 检查和 Xyce 实跑链路均可用。

## 总体结论

本轮功能验证矩阵 FV-001 至 FV-009 全部通过。

当前 Xyce 7.10.0 串行最小构建已经验证可用于：

- 线性 DC operating point；
- 非线性二极管 DC sweep；
- RC transient 时间积分；
- RC AC 小信号频响；
- Level 1 MOS DC sweep；
- 简单 MOS 共源放大器 OP + AC；
- 基础 NOISE 分析；
- 简单 `.include` 模型卡兼容性；
- XDM 2.7.0 binary 的最小 HSPICE-like 网表到 Xyce 转换链路。

这进一步支持当前判断：该安装足够用于学习 Xyce 内核、基础/中等复杂度开源模拟电路验证和 SPICE 求解流程研究。

仍需注意：本轮 FV-008 使用的是简单 Level 1 模型卡，不等价于 foundry PDK 或复杂 BSIM/PSP/FinFET 模型兼容性验证；FV-009 只验证了最小 HSPICE-like 网表转换，不代表 XDM 对复杂 HSPICE/Spectre/PDK deck 已经完成覆盖。
