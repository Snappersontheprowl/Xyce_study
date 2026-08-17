# FV-003: RC transient step response

## 功能

本用例验证 TRAN 分析、时间积分、电容器件、PULSE 源和瞬态输出是否可用。

## 本级文件职责

- `README.md`：说明本用例目标和验收标准。
- `rc-tran.cir`：输入 netlist。
- `rc-tran.cir.prn`：Xyce 输出结果。
- `run.log`：Xyce 运行日志。

## 验收标准

`V(out)` 应表现为 RC 指数充放电响应。

```text
R*C = 1 kΩ * 1 nF = 1 μs
```
