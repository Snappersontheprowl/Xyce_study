# FV-002: diode DC IV

## 功能

本用例验证 D 器件、非线性 DC 求解、DC sweep 和指数 IV 曲线输出是否可用。

## 本级文件职责

- `README.md`：说明本用例目标和验收标准。
- `diode-iv.cir`：输入 netlist。
- `diode-iv.cir.prn`：Xyce 输出结果。
- `run.log`：Xyce 运行日志。

## 验收标准

- `V(anode)` 从 `0 V` 扫到 `0.8 V`。
- 二极管电流绝对值随正向电压快速增大。
- `I(V1)` 的符号按 Xyce 电压源电流参考方向解释。
