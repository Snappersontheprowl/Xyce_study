不是。更准确地说，**先进制程首先是“为高密度、低功耗、高性能逻辑而优化”，但 SPICE 模型本身绝不是只考虑数字电路指标**。而且模拟电路不仅能用先进制程，某些高速模拟/RF/混合信号电路反而非常需要先进制程。

截至 2026 年，量产前沿已经进入 **GAA/nanosheet** 时代，例如 TSMC N2 已在 2025 年第四季度进入量产，Samsung SF2 采用第二代 GAA MBCFET，Intel 18A 则采用 RibbonFET GAA + PowerVia 背面供电。([台积电][1])

## 1. 先进制程的 SPICE 模型，最大的变化其实是“晶体管已经变了”

比如你过去在 180 nm、65 nm、28 nm 学到的 MOS：

[
I_D=f(V_{GS},V_{DS},V_{BS},W,L)
]

通常可以把 $W$ 看成一个近似连续的设计变量。

到了 FinFET：

[
W_{\mathrm{eff}}\approx N_{\mathrm{fin}}(2H_{\mathrm{fin}}+W_{\mathrm{fin}})
]

$W$ 开始变成**离散的 fin 数量**。

到了 2 nm 左右的 GAA nanosheet，本质上又变成若干层堆叠 nanosheet：

[
W_{\mathrm{eff}}\sim N_{\mathrm{sheet}}\times W_{\mathrm{sheet}}
]

因此对于电路设计者来说，一个很明显的变化就是：

**以前：**

```text
W = 3.72 um
```

这种尺寸很自然。

**先进 FinFET/GAA：**

```text
3 fins
4 fins
5 fins
...
```

或者若干 sheet / finger 组合。

也就是说，**sizing 从近似连续优化逐渐变成带离散约束的优化问题**。

这其实和你现在关注的模拟电路自动 sizing 非常相关。

---

## 2. compact model 也从 BSIM4 向多栅模型发展

传统平面 CMOS 常见的是 BSIM4 一类模型。

FinFET/GAA 则需要描述真正的多栅极电场，因此 Berkeley 的 BSIM 团队开发了 **BSIM-CMG（Common Multi-Gate）**。它是专门针对 multi-gate FET 的 compact model，目前最新标准版本已经到 BSIM-CMG 112.1.0。([BSIM GROUP | BSIM Group at UC Berkeley][2])

它不再只是简单修改几个 BSIM4 参数，而需要显式考虑很多多栅器件物理，例如：

* multi-gate electrostatics；
* short-channel effect；
* quantum mechanical effects；
* volume inversion；
* source/drain 端表面势；
* finite body doping。

BSIM-CMG 官方说明里明确提到 quantum mechanical effects、volume inversion 和多栅短沟道效应。([BSIM GROUP | BSIM Group at UC Berkeley][2])

所以你可以把技术演化大致理解成：

```text
Planar MOS
   ↓
BSIM3 / BSIM4
   ↓
FinFET
   ↓
BSIM-CMG
   ↓
GAA nanosheet
   ↓
更复杂的 BSIM-CMG / foundry proprietary extension
```

不过对于你在 Virtuoso/Spectre 里做电路设计来说，**这种变化通常被 PDK 隐藏掉了**。

你可能还是放一个 `nmos`，然后 Spectre 底层去调用 foundry 提供的 compact model。

---

# 3. 那么 SPICE 建模是不是只需要保证数字电路指标？

**完全不是。**

这是一个很容易产生的误解。

数字设计师最后比较关心的是：

[
t_{pd},\quad P,\quad I_{\mathrm{on}},\quad I_{\mathrm{off}}
]

例如：

* cell delay；
* leakage；
* dynamic power；
* setup/hold；
* PVT timing。

但这些并不是晶体管 SPICE model 的全部。

因为数字标准单元的 Liberty timing model，本身很多就是从 transistor-level SPICE 仿真抽取出来的。

底层 MOS compact model 仍然必须能够准确描述：

[
I_D(V_{GS},V_{DS},V_{BS})
]

以及

[
g_m=\frac{\partial I_D}{\partial V_{GS}}
]

[
g_{ds}=\frac{\partial I_D}{\partial V_{DS}}
]

[
C_{gs},C_{gd},C_{gb},C_{db}
]

以及：

[
\text{noise, mismatch, temperature, process variation}
]

这些恰恰都是**模拟电路最关心的东西**。

所以实际上：

> **数字电路和模拟电路用的是同一个底层 transistor compact model，只是两边观察它的方式不同。**

数字：

```text
MOS model
   ↓
standard cell SPICE
   ↓
Liberty characterization
   ↓
delay / power / timing
```

模拟：

```text
MOS model
   ↓
gm / gds / Cgg / noise / mismatch
   ↓
gain / bandwidth / phase margin / noise / offset
```

---

# 4. 模拟电路当然可以使用 2 nm / 3 nm

而且已经有非常明显的使用场景。

Intel 甚至专门介绍过 **18A 上的 mixed-signal / high-speed analog**：RibbonFET 能用于高 $f_T/f_{\max}$、低噪声、高速模拟电路，并支持 precision analog 和 DSP 集成。([英特尔社区][3])

典型的先进制程模拟模块会包括：

```text
CPU / GPU / AI accelerator
        │
        ├── PLL
        ├── DLL
        ├── Clock generator
        ├── SerDes
        ├── CDR
        ├── ADC / DAC
        ├── PHY
        ├── LDO
        ├── temperature sensor
        └── high-speed I/O
```

这些全都是模拟或者 mixed-signal 电路。

所以一颗 2 nm CPU/GPU 并不是：

```text
100% digital
```

实际一定会包含不少：

[
\text{analog + RF + mixed-signal}
]

---

# 5. 但是为什么很多模拟芯片反而不用最先进工艺？

这才是这个问题最重要的地方。

你可能会想：

> 既然 2 nm MOS 更快，那为什么运放、Bandgap、PMIC 不全去 2 nm？

因为：

[
\boxed{\text{工艺越先进}\neq\text{模拟电路越好}}
]

例如你现在做一个二级 OTA。

假设你希望：

[
A_v\approx g_m r_o
]

先进制程带来非常高的速度和晶体管密度，这当然很好。

但模拟设计还关心另外很多东西：

[
V_{DD},\quad V_{\mathrm{headroom}},\quad r_o,
\quad \sigma_{V_T},
\quad 1/f\ noise
]

以及：

[
\text{resistor / capacitor / inductor quality}
]

这些不会随着“节点变小”统一变好。

尤其一个非常现实的问题是：

### 电源电压越来越低

例如传统 180 nm 电路可能：

[
V_{DD}=1.8\sim3.3V
]

而先进逻辑节点核心器件可能只有大约：

[
V_{DD}\sim 0.7\sim1V
]

于是一个传统级联结构：

```text
VDD
 │
PMOS
 │
PMOS
 │
NMOS
 │
NMOS
 │
GND
```

会发现：

> **没有 headroom 了。**

这对模拟电路是很大的挑战。

---

# 6. 先进制程还有一个对模拟设计非常有意思的问题：尺寸离散化

这点与你研究 **sizing / KAN / $g_m/I_D$** 特别相关。

传统模拟 sizing：

[
\mathbf{x}=[W_1,L_1,W_2,L_2,\ldots]
]

优化：

[
\min f(\mathbf{x})
]

本质上可以当作连续优化。

但是 FinFET/GAA 后：

[
\mathbf{x}=
[N_{\mathrm{fin},1},N_{\mathrm{fin},2},\ldots]
]

很多变量变成：

[
N_{\mathrm{fin}}\in\mathbb Z^+
]

因此问题变成：

[
\boxed{\text{Mixed discrete-continuous optimization}}
]

例如优化算法算出来：

[
N_{\mathrm{fin}}=3.67
]

没有意义。

你只能：

[
N_{\mathrm{fin}}=3
]

或者

[
N_{\mathrm{fin}}=4
]

这对自动模拟电路设计实际上是一个非常有研究价值的问题。

---

# 7. 甚至 $g_m/I_D$ 方法在先进工艺下也更有意思

例如你平时可能做：

[
\frac{g_m}{I_D}
]

然后建立：

[
\frac{g_m}{I_D}
\leftrightarrow
\frac{I_D}{W}
]

查找表。

在 FinFET/GAA 中，则很可能需要变成类似：

[
\frac{g_m}{I_D}
\leftrightarrow
\frac{I_D}{N_{\mathrm{fin}}}
]

或者：

[
\frac{I_D}{N_{\mathrm{sheet}}}
]

所以传统的：

```text
gm/Id → W/L
```

可能逐渐演变成：

```text
gm/Id
 ↓
operating region
 ↓
fin/sheet configuration
 ↓
finger number
 ↓
layout
```

这也是为什么先进工艺模拟自动化与传统 180 nm OTA sizing 会出现明显不同。

---

# 8. 那哪些模拟电路适合先进节点？

可以记一个非常简单的规律。

**越需要“速度 + 大量数字逻辑”，越适合先进工艺：**

```text
SerDes
ADC / DAC
PLL
CDR
RF transceiver
high-speed I/O
wireline PHY
mixed-signal accelerator
```

例如：

[
\text{ADC + 大量 DSP}
]

这种东西特别适合先进工艺。

因为即使模拟部分没有缩小很多：

[
ADC_{\text{analog}}
]

后面的：

[
DSP
]

能缩小几十倍。

整个系统仍然非常划算。

Intel 18A 官方也正是在强调这种 **high-speed analog + dense DSP** 的组合。([英特尔社区][3])

---

而下面这些：

```text
precision op amp
bandgap
PMIC
high-voltage driver
sensor analog front-end
industrial analog
```

往往没有那么强的动力追求 2 nm。

TSMC 自己对成熟 0.18 µm 工艺的描述就明确强调了多电压、高压、RF、analog/mixed-signal、低成本和成熟度等优势。([台积电][1])

所以现实中的工艺选择往往是：

```text
AI / CPU / GPU
        ↓
2 nm / 3 nm

SerDes / high-speed mixed signal
        ↓
3 / 5 / 7 nm 等先进节点

RF / ADC / mixed signal
        ↓
视性能需求使用先进或中间节点

PMIC / BGR / precision analog
        ↓
28 / 40 / 65 / 130 / 180 nm 等
```

并不是“越先进越好”。

---

# 9. 如果你从 EDA/建模角度看，这件事其实特别有意思

从你现在研究模拟电路 sizing 的视角，我会把工艺演化概括成：

[
\boxed{
\text{MOS physics}
\rightarrow
\text{compact model}
\rightarrow
\text{PDK}
\rightarrow
\text{circuit sizing}
}
]

Planar 时代大概是：

[
(W,L,V_{GS},V_{DS})
\rightarrow
(I_D,g_m,g_{ds})
]

FinFET/GAA 时代则越来越像：

[
(N_{\mathrm{fin/sheet}},L,
V_{GS},V_{DS},
\text{layout})
]

[
\downarrow
]

[
(I_D,g_m,g_{ds},
C,
noise,
self\ heating,
variation)
]

也就是说，**先进节点反而让 transistor-level analog modeling 和自动 sizing 更复杂，而不是更简单。**

---

最后给你一个非常重要的认知：

> **先进工艺的核心目标虽然越来越偏向数字 PPA（Power / Performance / Area），但 SPICE compact model 描述的是“晶体管物理行为”，不是“数字行为”。**

所以：

[
\boxed{
\text{同一套 MOS model}
\rightarrow
\begin{cases}
\text{Digital characterization}\
\text{Analog simulation}\
\text{RF simulation}
\end{cases}
}
]

只是**先进节点在经济性和器件特性上，使“纯精密模拟”通常不值得迁移，而高速模拟 + 大规模数字混合系统非常值得迁移。**

对你现在做的 **“模拟电路 sizing + $g_m/I_D$ + KAN/代理模型”** 来说，我反而觉得 **FinFET/GAA 下的离散 sizing** 是一个很值得留意的研究方向：它比传统“用 ML 拟合 180 nm OTA 参数”更有鲜明的先进工艺特点。([BSIM GROUP | BSIM Group at UC Berkeley][2])

[1]: https://www.tsmc.com/english/dedicatedFoundry/technology/logic/l_2nm "2nm Technology - Taiwan Semiconductor Manufacturing Company Limited"
[2]: https://bsim.berkeley.edu/models/bsimcmg/ "BSIM-CMG | BSIM GROUP"
[3]: https://community.intel.com/t5/Blogs/Intel-Foundry/Systems-Foundry-for-the-AI-Era/Intel-Foundry-Modernizes-Next-Gen-Microelectronics-for-Aerospace/post/1742723 "Intel Foundry Modernizes Next-Gen Microelectronics for Aerospace, Defense, and Government Systems"
