# 05-analysis-flow

## 功能

本目录从工程实现角度记录 Xyce 的分析调度流程：谁决定运行哪类分析、分析对象如何组织、生命周期如何展开。

本目录不负责推导电路方程或求解算法；这些内容放在 [../06-solver-and-assembly/](../06-solver-and-assembly/)。

## 本级模块职责

- `README.md`：说明分析流程专题的职责、分层和阅读顺序。
- `01-basic/`：基础分析 `.OP / .DC / .TRAN` 的工程实现主线。
- `02-advanced/`：进阶分析 `AC / NOISE / HB / MPDE` 的工程实现地图。
- `03-sensitivity/`：灵敏度作为 capability layer 如何挂入主分析流程。

## 使用建议

建议先读 `01-basic/`，理解 `Simulator::runSimulation()` 之后分析层如何接管；再读 `02-advanced/`；最后读 `03-sensitivity/`。

## 当前约定

- 本目录关注代码入口、对象关系、注册选择、生命周期和控制流。
- 与 `Q/F/B/dQdx/dFdx`、Newton、linear solve、direct/adjoint 数学相关的内容统一放在 `06-solver-and-assembly/`。
