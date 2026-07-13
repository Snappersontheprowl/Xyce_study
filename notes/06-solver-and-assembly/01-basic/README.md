# basic solver and assembly

记录日期：2026-07-03

这个子目录从 **底层数学原理** 的角度，只讲最基础、最通用的求解骨架：

- 电路 DAE 是怎样装配出来的
- `DC operating point` 在数学上解什么
- `transient` 每个时间步在数学上解什么
- residual / Jacobian、Newton、linear solve 在这两类分析里怎样协作

## 推荐阅读顺序

1. [01-dae-assembly-pipeline.md](01-dae-assembly-pipeline.md)
2. [02-dae-math-solving.md](02-dae-math-solving.md)
3. [03-dc-operating-point-solving.md](03-dc-operating-point-solving.md)
4. [03-dcop-convergence-analysis.md](03-dcop-convergence-analysis.md)
5. [04-transient-time-discretization-and-solving.md](04-transient-time-discretization-and-solving.md)

## 这一组的边界

这一组只讲：

```text
DC / transient 的通用求解骨架
```

不讲：

- `AC / NOISE / HB / MPDE`
- 分析对象注册与生命周期调度
- 代码层的 factory / manager 组织关系

这些内容分别放在：

- [../../05-analysis-flow/README.md](../../05-analysis-flow/README.md)
- [../02-advanced/README.md](../02-advanced/README.md)
