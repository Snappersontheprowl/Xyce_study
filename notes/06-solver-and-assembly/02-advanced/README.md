# advanced solver and assembly

记录日期：2026-06-04

这个子目录放的是进阶仿真类型在“方程与求解”层面的专题。

这一组的核心问题是：

```text
除了 DC 和 transient，
Xyce 里其他分析类型在数学上到底在解什么，
又是怎样落到代码里的？
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
9. [09-sensitivity-analysis-solving.md](09-sensitivity-analysis-solving.md)

## 这一组的边界

这一组仍然只讲“方程与求解”，不讲分析对象的注册和生命周期调度。

所以如果你想先看：

- `AC`、`NOISE`、`HB`、`MPDE` 在哪里注册
- 它们怎样被 `AnalysisManager` 选中

应该先回到 [../../05-analysis-flow/02-advanced/README.md](../../05-analysis-flow/02-advanced/README.md)。
