# FV-008: model-card include compatibility

## 功能

本用例验证 `.include` 模型卡路径、模型识别和简单 MOS DC sweep 是否可用。

## 本级文件职责

- `README.md`：说明本用例目标和验收标准。
- `model-card-compat.cir`：输入 netlist。
- `simple-nmos-model.lib`：本用例使用的简单 Level 1 NMOS 模型卡。
- `model-card-compat.cir.prn`：Xyce 输出结果。
- `run.log`：Xyce 运行日志。

## 验收标准

- `.include` 模型卡路径可解析。
- MOS 模型可识别。
- 简单 DC sweep 可运行并输出合理 IV 趋势。

本用例先用简单 Level 1 模型卡验证 include 机制；更真实的 PTM/BSIM/PDK 模型卡兼容性应作为后续独立 case。
