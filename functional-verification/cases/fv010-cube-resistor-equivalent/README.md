# FV-010: cube resistor equivalent resistance

## 功能

本用例验证 Xyce 对稍复杂线性电阻网络的 DC operating point / MNA 求解是否正确。

电路为 8 个顶点、12 条边的立方体电阻网络，每条边为 `1 kΩ`，在一对空间对角顶点之间加 `1 V` 测试源。

## 本级文件职责

- `README.md`：说明本用例目标、理论值和验收标准。
- `cube-resistor-equivalent.cir`：输入 netlist。
- `cube-resistor-equivalent.cir.prn`：Xyce 输出结果。
- `run.log`：Xyce 运行日志。

## 理论值

对于所有边电阻均为 `R` 的立方体电阻网络，空间对角顶点之间的等效电阻为：

```text
Req = 5R / 6
```

本用例取 `R = 1 kΩ`，因此：

```text
Req = 833.333333 Ω
I   = 1 V / Req = 1.2 mA
```

## 验收标准

```text
V(a)        ≈ 1.0 V
V(b,d,e)    ≈ 0.6 V
V(c,f,h)    ≈ 0.4 V
|I(VTEST)|  ≈ 1.2 mA
Req         ≈ 833.333333 Ω
```

电压源电流符号按 Xyce 电压源电流参考方向解释。
