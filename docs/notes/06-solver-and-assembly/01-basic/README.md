# 06-solver-and-assembly / 01-basic

## 功能

本目录记录最基础、最通用的电路方程与求解骨架：电路 DAE、DC operating point、transient 时间步、residual/Jacobian、Newton 和 linear solve。

本目录不讲 `AC / NOISE / HB / MPDE` 等进阶分析。

## 本级模块职责

- `README.md`：说明本组笔记职责和阅读顺序。
- `01-dae-assembly-pipeline.md`：电路 DAE 的装配路径。
- `02-dae-math-solving.md`：DAE 数学结构和求解入口。
- `03-dc-operating-point-solving.md`：DC operating point 在数学上解什么。
- `03-dcop-convergence-analysis.md`：DCOP 收敛相关问题。
- `03-detail-singular-matrix.md`：奇异矩阵细节说明。
- `03-detail-unsmooth.md`：非光滑问题细节说明。
- `04-transient-time-discretization-and-solving.md`：瞬态时间离散与时间步求解。

## 使用建议

按编号顺序阅读主线文件；`03-detail-*` 属于遇到对应问题时再读的补充材料。

## 当前约定

- 本目录只覆盖 `DC / transient` 的通用求解骨架。
- 分析对象生命周期回到 `../../05-analysis-flow/`；进阶求解进入 `../02-advanced/`。
