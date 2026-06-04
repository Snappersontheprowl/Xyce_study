# mosfet b4

这个子专题承接上一级的：

- [04-from-device-equations-to-stamp.md](../04-from-device-equations-to-stamp.md)

它只做一件事：

```text
把 MOSFET_B4 当成一个独立的复杂 compact model，
顺着 unknown structure -> F -> Q -> merge summary
这条线单独读透
```

## 推荐阅读顺序

1. 先读 [01-roadmap.md](01-roadmap.md)
2. 再读 [02-unknowns-and-stamp.md](02-unknowns-and-stamp.md)
3. 再读 [03-f-and-dfdx.md](03-f-and-dfdx.md)
4. 再读 [04-q-and-dqdx.md](04-q-and-dqdx.md)
5. 最后读 [05-merge-summary.md](05-merge-summary.md)

## 这个子专题最想回答的 3 个问题

1. `B4` 的 unknown / stamp 结构为什么会比简单器件复杂很多？
2. 它如何分别贡献 `F/dFdx` 和 `Q/dQdx`？
3. 为什么说 `B4` 是前面 `resistor / capacitor / diode` 三类贡献方式的大合体？
