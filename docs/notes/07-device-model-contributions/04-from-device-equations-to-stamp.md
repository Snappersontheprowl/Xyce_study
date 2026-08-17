# from device equations to stamp

记录日期：2026-06-04

## 这篇的定位

前面三篇已经分别回答了：

- [01-device-model-roadmap.md](01-device-model-roadmap.md)：这一专题为什么要从 solver 反过来追到 device
- [02-capacitor-and-q-contribution.md](02-capacitor-and-q-contribution.md)：动态器件怎样贡献 `Q/dQdx`
- [03-diode-and-nonlinear-f.md](03-diode-and-nonlinear-f.md)：非线性器件怎样贡献 `F/dFdx`

这一篇不再展开新的代码细节，只做一次合流总结：

```text
器件公式
-> Q / F
-> dQdx / dFdx
-> solver 最终看到的 residual / Jacobian
```

## 当前结论先写在前面

如果只压成一句话，这一阶段最重要的统一认识是：

```text
器件并不是“直接把最终 residual 写给 solver”，
而是先把自己的物理关系拆成 Q/F 及其导数，
再由 time integration 和 Newton 组合成最终要求解的方程
```

## 三类典型器件的最小对照

### 1. resistor

最简单的线性静态器件。

核心关系可以想成：

$$
i = G (V_+ - V_-)
$$

它最典型的贡献是：

- `F`：有
- `dFdx`：有
- `Q`：没有
- `dQdx`：没有

所以 resistor 最适合帮你建立：

```text
静态线性导通项如何进入总方程
```

### 2. capacitor

最简单的动态器件。

核心关系是：

$$
q = C (V_+ - V_-)
$$

它最典型的贡献是：

- `Q`：有
- `dQdx`：有
- `F`：通常没有主贡献
- `dFdx`：通常没有主贡献

所以 capacitor 最适合帮你建立：

```text
动态储能项如何进入总方程
```

以及：

$$
\frac{dQ}{dt}
$$

为什么不是器件层直接算，而是后面 time integration 再处理。

### 3. diode

最简单的非线性导通器件，同时还带结电荷。

从当前阶段最值得先抓的角度看，核心关系是：

$$
I_d = I_d(V_d), \qquad G_d = \frac{\partial I_d}{\partial V_d}
$$

它最典型的贡献是：

- `F`：有，而且是 nonlinear 的
- `dFdx`：有，而且随工作点变化
- `Q`：也有
- `dQdx`：也有

所以 diode 最适合帮你建立：

```text
非线性器件如何把当前工作点下的 residual 和局部斜率交给 Newton
```

## 把三类器件放到同一张表里

| 器件 | 当前阶段主重点 | 主要贡献 | 求解器意义 |
| --- | --- | --- | --- |
| resistor | 线性静态导通 | `F`, `dFdx` | 固定线性导通项 |
| capacitor | 动态储能 | `Q`, `dQdx` | 经过时间离散后形成动态 Jacobian 项 |
| diode | 非线性导通 | `F`, `dFdx`，同时也有 `Q`, `dQdx` | 每次 Newton 都要重建局部线性化 |

## 从器件到 solver 的统一路径

现在可以把我们这一专题前半段真正压缩成一条统一路径：

$$
\text{device equation}
\rightarrow
(Q,F)
\rightarrow
\left(\frac{\partial Q}{\partial x}, \frac{\partial F}{\partial x}\right)
\rightarrow
\text{time integration}
\rightarrow
\text{residual / Jacobian}
\rightarrow
\text{Newton solve}
$$

其中最容易混淆、但一定要分清的边界是：

### 器件层负责

- 写 `Q`
- 写 `F`
- 写 `dQdx`
- 写 `dFdx`

### time integration 层负责

把：

$$
Q
$$

变成：

$$
\frac{dQ}{dt}
$$

相关的离散化项。

### nonlinear solver 层负责

把这些量组合成：

$$
f(x) = 0
$$

和

$$
J(x)\Delta x = -f(x)
$$

并做 Newton。

## 这一篇最想让你记住的 3 句话

1. `resistor` 让你看懂 `F/dFdx` 的最简单线性形式。
2. `capacitor` 让你看懂 `Q/dQdx` 为什么是 transient 的核心来源。
3. `diode` 让你看懂 nonlinear `F/dFdx` 为什么必须随着工作点不断重建。

## 下一步最自然该去哪里

如果继续往下走，最自然的下一步就是：

```text
进入更复杂的 compact model，
看一个器件如何同时强烈地贡献 F/Q/dFdx/dQdx
```

也就是说，后面可以开始进入：

- MOS
- BJT

这类“把前面几种贡献几乎全都合在一起”的器件。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `capacitor` 和 `diode` 放在一起看之后，更容易理解“真实器件往往同时有动态项和非线性导通项”？
2. 为什么说器件层、time integration 层、nonlinear solver 层这三者的边界必须分清，否则会很容易把 `Q`、`dQdx`、`dQ/dt` 混为一谈？
