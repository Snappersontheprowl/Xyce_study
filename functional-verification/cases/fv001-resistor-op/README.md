# FV-001: resistor operating point

## 功能

本用例验证基础 netlist 解析、线性器件、MNA 装配、DC operating point 和输出链路是否可用。

## 本级文件职责

- `README.md`：说明本用例目标和验收标准。
- `resistor-op.cir`：输入 netlist。
- `resistor-op.cir.prn`：Xyce 输出结果。
- `run.log`：Xyce 运行日志。

## 验收标准

```text
V(1)    = 1 V
|I(V1)| = 1 mA
```

电压源电流符号按 Xyce 电压源电流参考方向解释。
