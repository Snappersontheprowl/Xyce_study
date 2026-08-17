# 05-analysis-flow / 03-sensitivity

## 功能

本目录记录灵敏度分析在工程代码层如何附着到 `DC / AC / Transient` 等主分析流程上。

本目录不推导 direct/adjoint sensitivity 的数学公式。

## 本级模块职责

- `README.md`：说明本组笔记职责和阅读顺序。
- `01-sensitivity-lifecycle.md`：灵敏度能力层的整体生命周期。
- `02-dc-sensitivity-lifecycle.md`：DC 灵敏度的工程挂接路径。
- `03-ac-sensitivity-lifecycle.md`：AC 灵敏度的工程挂接路径。
- `04-transient-sensitivity-lifecycle.md`：瞬态灵敏度的工程挂接路径。

## 使用建议

先读本组理解 `.SENS` 如何进入调度层；再到 [../../06-solver-and-assembly/03-sensitivity/](../../06-solver-and-assembly/03-sensitivity/) 学习 direct/adjoint 的数学与求解。

## 当前约定

- 本目录把灵敏度视为主分析上的 capability layer，而不是独立主分析类型。
- 数学推导、成本结构和转置求解统一放在 `06-solver-and-assembly/03-sensitivity/`。
