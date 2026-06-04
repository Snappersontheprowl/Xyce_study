# device model contributions

这个专题承接 [06-solver-and-assembly](../06-solver-and-assembly/README.md)。

`06` 已经回答了：

- 求解器到底在解什么方程
- `DC` 和 `transient` 在数学上分别做什么
- Newton 和 linear solve 在代码里怎样展开

接下来的关键问题就是反过来问：

```text
这些方程里的 Q / F / B / dQdx / dFdx
到底是谁写出来的？
器件模型怎样把自己的物理关系翻译成求解器需要的量？
```

所以这个专题的主线不是再讲 solver，而是讲：

```text
device model
-> instance / master
-> Q/F/B/dQdx/dFdx
-> residual / Jacobian
-> solver
```

## 推荐阅读顺序

1. 先读 [01-device-model-roadmap.md](01-device-model-roadmap.md)
2. 再读 [02-capacitor-and-q-contribution.md](02-capacitor-and-q-contribution.md)
3. 再读 [03-diode-and-nonlinear-f.md](03-diode-and-nonlinear-f.md)
4. 再读 [04-from-device-equations-to-stamp.md](04-from-device-equations-to-stamp.md)
5. 再读 [05-mosfet-b4-roadmap.md](05-mosfet-b4-roadmap.md)
6. 再读 [06-mosfet-b4-unknowns-and-stamp.md](06-mosfet-b4-unknowns-and-stamp.md)
7. 再读 [07-mosfet-b4-f-and-dfdx.md](07-mosfet-b4-f-and-dfdx.md)
8. 再读 [08-mosfet-b4-q-and-dqdx.md](08-mosfet-b4-q-and-dqdx.md)
9. 后面再继续：
   - 再回头总结复杂 compact model 如何同时贡献 `F/Q/dFdx/dQdx`

## 这一专题最想回答的 4 个问题

1. 一个器件到底给总方程增加了什么？
2. 这些贡献是在 `Model`、`Master` 还是 `Instance` 里实现的？
3. 器件的公式是如何变成 `Q/F/B/dQdx/dFdx` 的？
4. 数值求解的需求，为什么会反过来影响器件代码的写法？
