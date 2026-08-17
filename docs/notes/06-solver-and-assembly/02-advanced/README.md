# 06-solver-and-assembly / 02-advanced

## 功能

本目录记录进阶仿真类型的数学对象和求解结构，覆盖 `AC / NOISE / HB / MPDE`。

本目录不讲这些分析类型在代码里如何注册、选择和调度。

## 本级模块职责

- `README.md`：说明本组笔记职责和阅读顺序。
- `01-advanced-simulation-roadmap.md`：进阶仿真数学路线图。
- `02-ac-small-signal-solving.md`：AC 小信号方程与求解。
- `03-noise-analysis-solving.md`：噪声分析数学对象。
- `04-adjoint-for-noise.md`：noise adjoint 的求解结构。
- `05-hb-solving-roadmap.md`：harmonic balance 求解路线。
- `06-hb-time-frequency-bridge.md`：HB 时域/频域桥接。
- `07-mpde-solving-roadmap.md`：MPDE 多时间尺度求解路线。
- `08-advanced-analysis-comparison.md`：进阶分析横向比较。

## 使用建议

如需先理解工程控制流，回到 [../../05-analysis-flow/02-advanced/](../../05-analysis-flow/02-advanced/)；如需横向收束，最后读 `08-advanced-analysis-comparison.md`。

## 当前约定

- 灵敏度数学已单独放在同级 `03-sensitivity/`。
- 本目录重点是“从原始 DAE 如何变形为不同分析问题”。
