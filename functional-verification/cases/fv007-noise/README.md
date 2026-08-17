# FV-007: basic noise analysis

## 功能

本用例验证当前 Xyce binary 是否支持常见 `.NOISE` 分析路径，以及噪声输出格式是否可用。

## 本级文件职责

- `README.md`：说明本用例目标和验收标准。
- `noise.cir`：输入 netlist。
- `noise.cir.NOISE.prn`：Xyce 噪声输出结果。
- `noise.cir_noise.dat`：Xyce 噪声数据输出。
- `run.log`：Xyce 运行日志。

## 验收标准

- 当前构建接受 `.NOISE` 语法。
- 生成噪声相关输出文件。
- 若语法或功能失败，应记录首个错误作为当前能力边界。
