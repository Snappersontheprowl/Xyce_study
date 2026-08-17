# 06-solver-and-assembly

## 功能

本目录从方程与求解角度记录 Xyce 底层在解什么、方程如何装配、矩阵和求解器如何协作。

本目录不解释分析对象如何注册和调度；工程控制流放在 [../05-analysis-flow/](../05-analysis-flow/)。

## 本级模块职责

- `README.md`：说明求解与装配专题的职责、分层和阅读顺序。
- `00-notation-conventions.md`：本专题统一符号约定。
- `01-basic/`：`DC / transient` 的基础 DAE、residual、Jacobian、Newton 和时间离散骨架。
- `02-advanced/`：`AC / NOISE / HB / MPDE` 的进阶方程和求解结构。
- `03-sensitivity/`：解敏感度、输出敏感度、direct/adjoint 的数学与求解。

## 使用建议

建议先读 `00-notation-conventions.md`，再进入 `01-basic/`。基础方程稳定后，再读 `02-advanced/` 和 `03-sensitivity/`。

## 当前约定

- 本目录关注 `Q/F/B/dQdx/dFdx`、residual、Jacobian、time discretization、Newton、adjoint 和频域/周期稳态求解。
- 分析类型注册、manager/factory 对象关系和生命周期调度不在本目录展开。
