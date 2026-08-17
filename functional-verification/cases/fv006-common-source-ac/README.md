# FV-006: common-source amplifier OP + AC

## 功能

本用例验证 MOS 放大器偏置、OP 和 AC 小信号增益链路是否可用。

## 本级文件职责

- `README.md`：说明本用例目标和验收标准。
- `common-source-ac.cir`：输入 netlist。
- `common-source-ac.cir.TD.prn`：OP/时域输出结果。
- `common-source-ac.cir.FD.prn`：AC 频域输出结果。
- `run.log`：Xyce 运行日志。

## 验收标准

- operating point 合理。
- 低频 AC 响应呈现反相共源放大器的小信号增益。

本用例使用简单 Level 1 NMOS，目标是验证仿真链路，不用于生产级模型精度判断。
