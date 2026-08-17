# 06-solver-and-assembly / 03-sensitivity

## 功能

本目录记录灵敏度分析的数学与求解：解对参数的敏感度、输出对参数的敏感度、direct 和 adjoint 的成本结构。

本目录不讲 `.SENS` 在工程调度层如何进入系统。

## 本级模块职责

- `README.md`：说明本组笔记职责和阅读顺序。
- `01-sensitivity-analysis-solving.md`：灵敏度分析的总数学框架。
- `02-dc-sensitivity-solving.md`：DC 灵敏度求解。
- `03-ac-sensitivity-solving.md`：AC 灵敏度求解。
- `04-transient-sensitivity-solving.md`：瞬态灵敏度求解。
- `detail_less_computation.md`：为什么 adjoint 在多参数少输出时更省计算。
- `detail_matrix.md`：灵敏度相关矩阵细节。
- `detail_sens_under_freq.md`：频域灵敏度物理含义补充。
- `detail_solver_process.md`：灵敏度求解过程细节。

## 使用建议

先读 `01-sensitivity-analysis-solving.md` 建立 direct/adjoint 总图，再按 `DC -> AC -> transient` 推进；`detail_*` 文件作为补充阅读。

## 当前约定

- 本目录只讲数学对象、方程推导、Jacobian/输出映射/转置求解和成本结构。
- 灵敏度生命周期和调度入口放在 [../../05-analysis-flow/03-sensitivity/](../../05-analysis-flow/03-sensitivity/)。
