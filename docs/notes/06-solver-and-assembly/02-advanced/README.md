# advanced solver and assembly

记录日期：2026-07-03

这个子目录放的是进阶仿真类型在 **底层数学原理与求解结构** 层面的专题。

这一组的核心问题不是“这些分析怎么注册”，而是：

```text
除了 DC 和 transient，
Xyce 里其他分析类型在数学上到底在解什么，
它们怎样从原始 DAE 变形而来，
以及这些数学对象后来怎样落到代码里的？
```

## 当前内容

1. [01-advanced-simulation-roadmap.md](01-advanced-simulation-roadmap.md)
2. [02-ac-small-signal-solving.md](02-ac-small-signal-solving.md)
3. [03-noise-analysis-solving.md](03-noise-analysis-solving.md)
4. [04-adjoint-for-noise.md](04-adjoint-for-noise.md)
5. [05-hb-solving-roadmap.md](05-hb-solving-roadmap.md)
6. [06-hb-time-frequency-bridge.md](06-hb-time-frequency-bridge.md)
7. [07-mpde-solving-roadmap.md](07-mpde-solving-roadmap.md)
8. [08-advanced-analysis-comparison.md](08-advanced-analysis-comparison.md)

## 灵敏度已单独拆出

灵敏度分析已经单独整理到同级目录：

- [../03-sensitivity/README.md](../03-sensitivity/README.md)

## 这一组的边界

这一组仍然只讲“方程与求解”，不讲工程控制流本身。

所以如果你想先看：

- `AC`、`NOISE`、`HB`、`MPDE` 在哪里注册
- 它们怎样被 `AnalysisManager` 选中
- 它们的 factory / manager / loader 是在哪个初始化阶段接进来的

应该先回到 [../../05-analysis-flow/02-advanced/README.md](../../05-analysis-flow/02-advanced/README.md)。
