# FV-005: MOSFET DC curve

## 功能

本用例验证 M 器件、简单 MOS 模型卡、DC sweep 和基础晶体管 IV 曲线是否可用。

## 本级文件职责

- `README.md`：说明本用例目标和验收标准。
- `mos-dc.cir`：输入 netlist。
- `mos-dc.cir.prn`：Xyce 输出结果。
- `run.log`：Xyce 运行日志。

## 验收标准

- `V(g)` 低于阈值时，`I(VDS)` 绝对值较小。
- `V(g)` 超过阈值后，`I(VDS)` 绝对值明显上升。

本用例使用简单 Level 1 MOS 模型，只验证仿真链路，不用于生产级模型精度判断。
