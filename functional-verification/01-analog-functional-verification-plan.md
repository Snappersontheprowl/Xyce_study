# 模拟电路功能验证计划

## 1. 目标

本计划用于验证当前安装的 Xyce 7.10.0 串行最小构建对常规模拟电路仿真的可用性。

验证重点不是跑大而全的回归测试，而是构建一组小型、可读、可复现的模拟电路 netlist，让每个用例都能回答一个明确问题：

```text
当前 Xyce 对这个分析类型、器件类型或模型类型是否可用？
```

## 2. 当前已通过基线

已通过最小 resistor operating point 冒烟测试：

```spice
* Xyce smoke test: 1 V source through 1 kOhm resistor
V1 1 0 DC 1
R1 1 0 1k
.OP
.PRINT DC V(1) I(V1)
.END
```

结果：

```text
V(1)  =  1.00000000e+00
I(V1) = -1.00000000e-03
```

解释：

```text
1 V / 1 kΩ = 1 mA
```

电流负号来自电压源电流参考方向。

## 3. 验证矩阵

### FV-001：线性 DC operating point

目的：

```text
确认基础 netlist 解析、线性器件、MNA 装配、DC operating point 和输出链路可用。
```

电路：

```text
1 V source + 1 kΩ resistor
```

状态：

```text
已通过
```

### FV-002：二极管 DC IV 曲线

目的：

```text
确认 D 器件、非线性 DC 求解、DC sweep 和指数 IV 曲线输出可用。
```

建议 netlist：

```spice
* Diode IV smoke test
V1 anode 0 0
D1 anode 0 DMOD
.MODEL DMOD D(IS=1e-14 N=1)
.DC V1 0 0.8 0.01
.PRINT DC V(anode) I(V1)
.END
```

验收：

- 无 netlist error / fatal / abort；
- 输出文件存在；
- 电流随电压指数上升；
- `I(V1)` 符号按电压源电流参考方向解释。

状态：

```text
已通过，见 02-verification-results.md
```

### FV-003：RC transient 阶跃响应

目的：

```text
确认 TRAN 分析、时间积分、电容器件、PULSE 源和瞬态输出可用。
```

建议 netlist：

```spice
* RC transient step response
V1 in 0 PULSE(0 1 0 1n 1n 1u 2u)
R1 in out 1k
C1 out 0 1n
.TRAN 1n 5u
.PRINT TRAN V(in) V(out)
.END
```

验收：

- `V(out)` 呈指数充电/放电；
- 时间常数约为 `R*C = 1 us`；
- 输出无 fatal/error。

状态：

```text
已通过，见 02-verification-results.md
```

### FV-004：RC AC 小信号频响

目的：

```text
确认 AC 分析、线性化、小信号源和频域输出可用。
```

建议 netlist：

```spice
* RC low-pass AC response
V1 in 0 DC 0 AC 1
R1 in out 1k
C1 out 0 1n
.AC DEC 20 1 1MEG
.PRINT AC V(out)
.END
```

验收：

- 低频 `|V(out)|` 接近 1；
- 截止频率约为 `1/(2*pi*R*C) ≈ 159 kHz`；
- 高频幅度下降。

状态：

```text
已通过，见 02-verification-results.md
```

### FV-005：MOSFET DC 曲线

目的：

```text
确认 M 器件、MOS 模型卡、DC sweep 和基础晶体管 IV 曲线可用。
```

建议先使用简单 Level 1 模型，后续再接入 PTM/BSIM 模型：

```spice
* NMOS Id-Vgs smoke test, simple level 1 model
VDS d 0 1
VGS g 0 0
M1 d g 0 0 NM L=1u W=10u
.MODEL NM NMOS LEVEL=1 VTO=0.5 KP=100u LAMBDA=0.02
.DC VGS 0 1.8 0.01
.PRINT DC V(g) I(VDS)
.END
```

验收：

- 低于阈值时电流较小；
- 超过阈值后电流上升；
- 输出曲线可用于后续 gm/ID 或器件模型学习。

状态：

```text
已通过，见 02-verification-results.md
```

### FV-006：共源放大器 OP + AC

目的：

```text
确认 MOS 放大器偏置、OP、AC 小信号增益链路可用。
```

建议在 FV-005 通过后再执行。

验收：

- operating point 合理；
- 小信号增益符号与量级符合预期；
- 可从 `.PRINT AC` 输出频响。

状态：

```text
已通过，见 02-verification-results.md
```

### FV-007：NOISE 基础验证

目的：

```text
确认当前 binary 是否支持常见噪声分析路径，以及输出格式是否可用。
```

建议先从电阻热噪声或简单 RC 网络开始。

验收：

- netlist 语法被接受；
- 输出中出现噪声相关结果；
- 结果数量级与热噪声直觉一致。

状态：

```text
已通过，见 02-verification-results.md
```

### FV-008：实际模型卡兼容性检查

目的：

```text
确认 Xyce 对目标模型卡语法的兼容程度。
```

候选：

- PTM 180 nm / 45 nm / 22 nm；
- 开源 BSIM3/BSIM4 模型；
- 后续若有真实 PDK 模型卡，只做语法和小电路兼容性验证，不直接假定 sign-off 可替代。

验收：

- `.include` / `.lib` 语法可用；
- model level 可识别；
- 简单 Id-Vg / Id-Vd 曲线能跑通；
- 若失败，记录首个错误和是否属于语法、模型参数、器件级别或 Xyce 构建缺项。

状态：

```text
已通过，见 02-verification-results.md
```

### FV-009：XDM HSPICE-like 最小转换验证

目的：

```text
确认 XDM binary 安装、HSPICE-like 最小网表到 Xyce 网表的转换链路、以及转换后网表的 Xyce 解析和运行链路可用。
```

验收：

- XDM 转换无 critical issue / error；
- 转换后网表可被 Xyce `-syntax` 接受；
- 转换后网表可实际运行；
- 最小电阻电路结果符合 `1 V / 1 kΩ = 1 mA`。

状态：

```text
已通过，见 02-verification-results.md
```

### FV-010：立方体电阻网络等效电阻

目的：

```text
确认 Xyce 对稍复杂线性电阻网络的 DC operating point / MNA 求解是否正确。
```

电路：

```text
8 个顶点、12 条边的立方体电阻网络，每条边为 1 kΩ。
在一对空间对角顶点之间加 1 V 测试源。
```

验收：

- 运行无 netlist error / fatal / abort；
- 对称节点电压满足 `V(b,d,e)≈0.6 V`、`V(c,f,h)≈0.4 V`；
- `|I(VTEST)|≈1.2 mA`；
- 等效电阻 `Req≈833.333333 Ω = 5R/6`。

状态：

```text
已通过，见 02-verification-results.md
```

## 4. 输出目录建议

后续建议按用例创建：

```text
functional-verification/
├── cases/
│   ├── fv001-resistor-op/
│   ├── fv002-diode-iv/
│   ├── fv003-rc-tran/
│   ├── fv004-rc-ac/
│   ├── fv005-mos-dc/
│   ├── fv006-common-source-ac/
│   ├── fv007-noise/
│   ├── fv008-model-card-compat/
│   ├── fv009-xdm-hspice-minimal/
│   └── fv010-cube-resistor-equivalent/
├── logs/
└── results/
```

每个 case 至少包含：

```text
README.md
*.cir
run.log
*.prn 或等价输出
```

## 5. 每个用例的统一检查命令

运行后先检查错误：

```bash
rg -n "Netlist error|MSG_FATAL|MSG_ERROR|Simulation aborted|Xyce Abort|failed|fatal|error" run.log
```

若无输出，再检查结果文件：

```bash
find . -maxdepth 1 -type f | sort
sed -n '1,40p' *.prn
```

## 6. 当前优先级

已完成：

```text
FV-001 resistor OP
FV-002 diode IV
FV-003 RC transient
FV-004 RC AC
FV-005 MOSFET DC
FV-006 common-source AC
FV-007 noise
FV-008 model-card compat
FV-009 XDM HSPICE minimal
FV-010 cube resistor equivalent
```

后续可继续扩展：

- 更复杂的线性网络；
- 受控源与小信号等效电路；
- 子电路 `.subckt` 层次验证；
- 更接近真实 PDK 的模型卡兼容性验证；
- Python/C interface 驱动仿真验证。
