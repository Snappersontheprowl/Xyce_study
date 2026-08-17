# 05-analysis-flow / 02-advanced

## 功能

本目录记录进阶分析类型在工程代码中的注册、选择和生命周期地图，覆盖 `AC / NOISE / HB / MPDE`。

本目录不展开 small-signal、noise、harmonic balance 或 MPDE 的数学推导。

## 本级模块职责

- `README.md`：说明本组笔记职责和阅读顺序。
- `01-advanced-analysis-type-map.md`：进阶分析类型总览。
- `02-ac-lifecycle.md`：`AC` 生命周期。
- `03-noise-lifecycle.md`：`NOISE` 生命周期。
- `04-noise-adjoint-lifecycle-hook.md`：noise adjoint 在生命周期中的挂接位置。
- `05-hb-lifecycle.md`：`HB` 生命周期。
- `06-hb-time-frequency-lifecycle-hook.md`：HB 时域/频域桥接位置。
- `07-mpde-lifecycle.md`：`MPDE` 生命周期。

## 使用建议

读完本目录后，如需横向比较进阶分析的数学对象，转到 [../../06-solver-and-assembly/02-advanced/08-advanced-analysis-comparison.md](../../06-solver-and-assembly/02-advanced/08-advanced-analysis-comparison.md)。

## 当前约定

- 灵敏度调度已单独放在同级 `03-sensitivity/`。
- 本目录只讲工程控制流；数学与求解结构放在 `06-solver-and-assembly/02-advanced/`。
