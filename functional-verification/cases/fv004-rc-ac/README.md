# FV-004: RC AC small-signal response

## 功能

本用例验证 AC 分析、线性化、小信号源和频域输出是否可用。

## 本级文件职责

- `README.md`：说明本用例目标和验收标准。
- `rc-ac.cir`：输入 netlist。
- `rc-ac.cir.FD.prn`：Xyce 频域输出结果。
- `run.log`：Xyce 运行日志。

## 验收标准

- 低频 `|V(out)|` 接近 `1`。
- 高频 `|V(out)|` 下降。
- 截止频率约为：

```text
1/(2*pi*R*C) ≈ 159 kHz
```
