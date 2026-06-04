# advanced analysis flow

记录日期：2026-06-04

这个子目录放的是进阶分析类型在“分析调度层”的地图。

这一组不急着展开所有数学细节，只先回答：

- `AC / NOISE / HB / MPDE` 在哪里注册
- 它们怎样被 `AnalysisManager` 选中
- 生命周期入口大致怎么组织
- 它们和 `DCOP`、包装层分析的关系是什么

## 当前内容

1. [01-advanced-analysis-type-map.md](01-advanced-analysis-type-map.md)

## 后续建议展开

- `02-ac-and-noise-lifecycle.md`
- `03-hb-and-mpde-lifecycle.md`

## 这一组的边界

这一组仍然属于 `05-analysis-flow`，所以只讲“调度”和“生命周期地图”。

真正涉及：

- small-signal 方程
- noise 数学对象
- harmonic balance 方程形式
- MPDE 多时间尺度求解

这些内容应该放到 [../../06-solver-and-assembly/README.md](../../06-solver-and-assembly/README.md) 的进阶求解部分。
