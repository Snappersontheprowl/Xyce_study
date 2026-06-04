# mosfet b4 merge summary

记录日期：2026-06-04

## 这篇的定位

这一篇不再展开新代码，只做一件事：

```text
把 MOSFET_B4 重新压回
F / Q / dFdx / dQdx
这一张总图里
```

## 当前最核心的结论

`MOSFET_B4` 可以看成前面几类器件贡献方式的大合体：

- 像 `resistor` 一样贡献导通电流和导数
- 像 `capacitor` 一样贡献电荷和电荷导数
- 像 `diode` 一样在当前工作点做非线性局部线性化

所以它不是“一个很大的电流公式”，而是：

$$
\bigl(F,\;Q,\;\frac{\partial F}{\partial x},\;\frac{\partial Q}{\partial x}\bigr)
$$

四部分一起工作的复杂 compact model。

## 把前面三篇压成一条主线

现在可以把 `B4` 的主线重新写成：

1. [06-mosfet-b4-unknowns-and-stamp.md](06-mosfet-b4-unknowns-and-stamp.md)
   - 先建立 unknown / stamp / offset / pointer 地图
2. [07-mosfet-b4-f-and-dfdx.md](07-mosfet-b4-f-and-dfdx.md)
   - 再看工作点量如何变成 `F/dFdx`
3. [08-mosfet-b4-q-and-dqdx.md](08-mosfet-b4-q-and-dqdx.md)
   - 再看 charge 如何变成 `Q/dQdx`

合在一起就是：

```text
unknown structure
-> work-point quantities
-> F / Q blocks
-> dFdx / dQdx blocks
-> time integration + Newton
```

## 这一轮最该记住的 4 句话

1. `B4` 的复杂度，先体现在未知量结构和内部子网络上。
2. `F` 侧本质上是电流残差和局部线性化系数。
3. `Q` 侧本质上是电荷状态和电荷偏导系数。
4. 求解器最后解的不是“某一个 MOS 公式”，而是所有器件贡献合并后的总 DAE。

## 和前面简单器件的对应关系

- `resistor`
  - 帮我们建立 `F/dFdx` 直觉
- `capacitor`
  - 帮我们建立 `Q/dQdx` 直觉
- `diode`
  - 帮我们建立 nonlinear local linearization 直觉
- `MOSFET_B4`
  - 把前面三种直觉同时合在一个真实 compact model 里

## 下一步最自然该去哪里

如果继续往前，最自然的方向有两个：

1. 回到 `07` 专题里，换一个器件做横向对比  
   例如再看一个 `BJT` 或别的 MOS 变体

2. 回到 `06` 专题，把 `B4` 和求解器再反向连起来  
   也就是专门看：

```text
B4 提供的 F/Q/dFdx/dQdx
是怎样进入 transient / Newton / linear solve 的
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `B4` 不是“公式更多的 diode”，而是 `resistor + capacitor + diode` 三种贡献方式的大合体？
2. 为什么读完 `06/07/08` 之后，再回头看 solver，会比一开始直接啃 `B4` 容易很多？
