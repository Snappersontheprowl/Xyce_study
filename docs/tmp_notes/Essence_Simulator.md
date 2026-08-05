# 更详细的内容请参考 Xyce 的学习笔记

## 一、最本质的三类：DC、Transient、AC

晶体管级电路仿真最核心的三类是：

| 本质仿真      | 中文      | 求解对象       |
| --------- | ------- | ---------- |
| DC / OP   | 直流工作点分析 | 非线性代数方程    |
| Transient | 瞬态分析    | 非线性微分-代数方程 |
| AC        | 小信号频域分析 | 线性化后的频域方程  |

这三类基本构成了 SPICE 类仿真器的主干。


## 1. DC / OP：最基础的静态非线性求解

DC 或 OP 分析求的是电路在静态条件下的工作点。

它本质上是在求：

$$
F(x,p)=0
$$

其中：

* $x$ 是节点电压、电感电流等未知量；
* $p$ 是器件参数、电路参数；
* $F$ 是 KCL、KVL 和器件模型组成的非线性方程组。

对晶体管级电路来说，MOS 管、BJT、二极管都是非线性器件，所以这个方程一般是非线性的，需要用 Newton-Raphson 迭代求解。

**OP 分析是很多其他仿真的前置基础。**

比如：

* AC 分析要先求 OP，然后在 OP 点附近线性化；
* Noise 分析也要先求 OP；
* TF 分析也要先求 OP；
* PZ 分析也要先求 OP；
* 很多瞬态仿真也需要先求初始 DC 工作点。

所以如果问“最底层、最基础”的仿真，DC / OP 一定是第一类。


## 2. Transient：最一般的时域动态求解

瞬态分析研究电路随时间变化的行为。

它本质上求解的是：

$$
F(x(t),\dot{x}(t),t,p)=0
$$

也就是包含电容、电感、非线性器件的微分-代数方程组。

电容、电感带来了动态项：

$$
i_C=C\frac{dv}{dt}
$$

$$
v_L=L\frac{di}{dt}
$$

仿真器通常会把时间离散化，例如用 backward Euler、trapezoidal、Gear 等数值积分方法，把微分方程在每个时间步转化成非线性代数方程：

$$
F_n(x_n,x_{n-1},t_n,p)=0
$$

然后每个时间点再用 Newton 迭代求解。

因此瞬态分析可以理解成：

> 在一系列时间点上反复求解非线性电路方程。

它是最通用的仿真类型，因为大多数电路现象都可以通过时间响应观察：

* 开关翻转；
* 延迟；
* 过冲；
* 振铃；
* 启动过程；
* 振荡建立过程；
* 数字电路动态功耗；
* SRAM 读写过程；
* PLL 锁定过程；
* 比较器翻转；
* 大信号非线性行为。

从理论上说，很多频域现象也可以通过瞬态仿真加 FFT 得到，但效率不一定高。

所以 Transient 是第二个最本质的仿真。


## 3. AC：工作点附近的小信号线性频域求解

AC 分析不是重新求一个非线性大信号问题，而是先做 DC 工作点 → 在线性化小信号模型上 → 对每个频率点直接求频域线性方程。

先有：

$$
F(x,p)=0
$$

求出工作点 $x_0$。

然后在 $x_0$ 附近做一阶线性化：

$$
G\Delta x + C\frac{d\Delta x}{dt} = B\Delta u
$$

再假设小信号是正弦稳态：

$$
\Delta x(t)=\hat{x}e^{j\omega t}
$$

代入之后得到：

$$
(G+j\omega C)\hat{x}=B\hat{u}
$$

所以 AC 分析本质上是在每个频率点求解一个线性方程组。

它和 Transient 的区别是：

| 对比      | Transient      | AC            |
| ------- | -------------- | ------------- |
| 信号类型    | 大信号、非线性、时域     | 小信号、线性化、频域    |
| 是否保留非线性 | 保留             | 只保留工作点附近的一阶线性 |
| 求解对象    | 非线性 DAE        | 线性频域方程        |
| 适合看     | 延迟、翻转、启动、非线性响应 | 增益、带宽、相位、极点趋势 |

所以 AC 也是本质仿真，但它依赖 OP。


## 二、哪些是“本质仿真的复用”？

### 1. DC Sweep：DC 的重复调用

DC Sweep 不是新的求解类型。

它只是把某个变量扫一遍，每个点都做一次 DC / OP。

例如：

$$
V_{in}=0,0.01,0.02,\dots,1.8
$$

每个输入值都解一次：

$$
F(x,V_{in})=0
$$

所以：

> DC Sweep = 多次 DC / OP 分析。

典型用途：

* 反相器 VTC；
* 器件 I-V 曲线；
* 比较器翻转点；
* 输入失调电压；
* SRAM 静态噪声容限。

它是 DC 的复用。


### 2. Parametric Sweep：任意基础仿真的外层循环

参数扫描也不是一种本质仿真。

它只是改变参数，然后重复做某种基础仿真。

例如：

* 扫 $W$，每个 $W$ 做一次 AC；
* 扫 $C_L$，每个负载电容做一次 Transient；
* 扫温度，每个温度做一次 OP；
* 扫偏置电流，每个偏置做一次 Noise。

所以：

> Parametric Sweep = 对 DC / AC / Transient 等基础分析加一层参数循环。

它是外层控制逻辑，不是新的数学问题。

### 3. Temperature Sweep：参数扫描的一种

温度分析本质上也是参数扫描。

温度改变后，器件模型参数变了，比如：

* 阈值电压变；
* 迁移率变；
* 电阻值变；
* 漏电流变；
* BJT 饱和电流变。

然后仿真器在每个温度下重新做 OP、AC 或 Transient。

所以：

> Temperature Sweep = 以温度为参数的 Parametric Sweep。

它不是独立的本质仿真。

### 4. Corner Analysis：模型文件/参数组合扫描

Corner 分析也不是底层求解类型。

TT、FF、SS、SF、FS 只是不同的模型参数集合。仿真器在不同 corner 下分别跑基础仿真。

所以：

> Corner Analysis = 换一组模型参数后重复 DC / AC / Transient / Noise。

例如：

| Corner | 实际做法                          |
| ------ | ----------------------------- |
| TT     | 用 typical 模型跑仿真               |
| FF     | 用 fast NMOS + fast PMOS 模型跑仿真 |
| SS     | 用 slow NMOS + slow PMOS 模型跑仿真 |
| SF     | 用 slow NMOS + fast PMOS 模型跑仿真 |
| FS     | 用 fast NMOS + slow PMOS 模型跑仿真 |

它的本质是模型参数组合扫描。

### 5. Monte Carlo：随机参数扫描

Monte Carlo 也不是新的电路方程。

它是：

1. 按统计分布随机抽样工艺参数或失配参数；
2. 每个样本生成一套电路参数；
3. 对每个样本跑 OP、DC、AC、Transient 等；
4. 最后统计结果分布。

所以：

> Monte Carlo = 随机化的参数扫描 + 统计后处理。

例如输入失调电压的 Monte Carlo 分析，本质上可能是：

每次随机扰动 MOS 管 $V_{th}$、$\beta$、尺寸失配，然后跑一次 DC Sweep 或 OP，提取 offset。

### 6. Worst-Case Analysis：有策略的参数扫描

Worst-Case Analysis 通常也不是独立的基础求解器。

它是在参数空间里寻找性能最差的组合。

可能方法包括：

* brute-force corner；
* 灵敏度引导；
* 优化搜索；
* statistical worst-case；
* Monte Carlo 筛选。

但每次评价性能时，底层还是跑：

* DC；
* AC；
* Transient；
* Noise。

所以：

> Worst-Case Analysis = 参数搜索 + 基础仿真 + 性能提取。


## 三、哪些是 AC / OP 的派生分析？

有些分析看起来是独立类型，但本质上是 OP 后的小信号线性系统分析。

### 1. Noise：OP + 小信号噪声传播

Noise Analysis 通常要先做 OP。

因为器件噪声强度依赖工作点，例如 MOS 管沟道热噪声和 $g_m$、$g_{ds}$ 有关，闪烁噪声也和偏置有关。

然后仿真器在线性化小信号网络中计算噪声源到输出的传递。

因此：

> Noise = OP + 小信号线性化 + 噪声源传播积分。

它和 AC 非常接近。区别是 AC 给定一个确定的小信号输入，而 Noise 给每个器件引入随机噪声源，再计算输出噪声谱。

所以 Noise 可以看作 AC 小信号框架的扩展。

### 2. Transfer Function：OP + 低频小信号解

TF 分析通常给：

* 小信号增益；
* 输入电阻；
* 输出电阻。

它本质上是 OP 后的线性化求解，通常相当于频率为 0 的小信号分析。

所以：

> TF ≈ OP + DC 小信号线性化。

它不是新的底层仿真。

### 3. Pole-Zero：OP + 线性化系统特征分析

PZ 分析也是先做 OP，然后得到线性化系统：

$$
G\Delta x+C\frac{d\Delta x}{dt}=B\Delta u
$$

再从这个系统中求极点和零点。

所以：

> PZ = OP + 线性化模型 + 特征值/传递函数分析。

它和 AC 属于同一类线性小信号分析。

### 4. Stability / STB：OP + 小信号环路增益分析

稳定性分析，尤其是 Spectre 的 STB，本质上也是小信号分析。

它先求工作点，然后在反馈环路中插入测试源，计算 loop gain：

$$
T(j\omega)
$$

然后得到：

* 相位裕度；
* 增益裕度；
* 交越频率。

所以：

> STB = OP + 特殊设置下的 AC 小信号环路分析。

它不是和 AC 平级的本质仿真，而是 AC 的工程化封装。

## 四、哪些是 Transient 的派生分析？

有些分析主要是瞬态仿真的变形、重复或后处理。

### 1. Startup Analysis：瞬态仿真的特殊应用

启动分析本质上就是 transient。

只是它关注的是电路从初始条件到正常工作状态的过程。

例如：

* bandgap 是否启动；
* 振荡器是否起振；
* LDO 上电是否稳定；
* PLL 是否锁定；
* SRAM 上电落在哪个状态。

所以：

> Startup Analysis = 带特定初始条件和电源激励的 Transient。

它不是新仿真类型。

### 2. Delay / Rise Time / Settling Time：瞬态结果的后处理

这些指标不是仿真类型，而是从 transient 波形里提取出来的性能指标。

例如：

* propagation delay；
* rise time；
* fall time；
* overshoot；
* settling time；
* slew rate；
* dynamic power。

本质是：

> Transient 仿真 + waveform measurement。

例如 SPICE 里的 `.measure tran` 就是后处理命令，不是新仿真。

### 3. FFT / THD：瞬态波形后处理

失真分析有时可以通过瞬态仿真得到。

做法是：

1. 对正弦输入做 transient；
2. 等电路进入稳态；
3. 对输出波形做 FFT；
4. 提取谐波分量；
5. 计算 THD、HD2、HD3。

所以在这种情况下：

> THD / FFT = Transient + 频谱后处理。

不过在 RF 仿真器中，也可能用 Harmonic Balance 或 PSS/PAC 来算失真，那就是另一类周期稳态算法。

## 五、RF/周期稳态类：可以算另一组本质仿真

如果只讨论传统 SPICE，最核心是 DC、Transient、AC。

但如果把 SpectreRF、ADS、GoldenGate 这类 RF 仿真也算进来，还应该加入一类：

> 周期稳态仿真。

### 1. PSS：周期稳态是比较本质的 RF 仿真

PSS，Periodic Steady-State，求的是满足周期条件的解：

$$
x(t+T)=x(t)
$$

这和普通 transient 不完全一样。

Transient 是从初值开始一路积分，等它自然进入稳态；而 PSS 是直接求满足周期边界条件的稳态轨道。

所以 PSS 的数学问题可以看作：

> 非线性动态方程 + 周期边界条件。

它不是简单的 transient 后处理，而是一个独立的周期边值问题。

因此在 RF/开关电容/振荡器仿真中，PSS 可以算本质仿真。


### 2. PAC / PNoise / PXF：PSS 的派生

这些通常是在 PSS 周期稳态解的基础上做线性化。

例如：

* PAC：周期工作点附近的小信号频率响应；
* PNoise：周期工作点附近的噪声传播；
* PXF：周期系统的传递函数；
* PSP：周期 S 参数。

所以：

> PAC / PNoise / PXF = PSS + 周期小信号分析。

它们相对于 PSS 是派生分析。


### 3. Harmonic Balance：频域非线性稳态仿真

Harmonic Balance 可以算另一种本质仿真。

它不是在时域一步步积分，而是假设周期稳态响应由有限个频率分量组成：

$$
x(t)=\sum_k X_k e^{jk\omega t}
$$

然后在频域中求解非线性代数方程。

所以它是：

> 非线性频域稳态求解。

在 RF 电路中，Harmonic Balance 与 Transient、PSS 属于不同的底层求解路线。

## 六、灵敏度分析比较特殊

Sensitivity Analysis 介于“本质仿真”和“派生分析”之间。

如果只是通过有限差分做：

$$
\frac{y(p+\Delta p)-y(p)}{\Delta p}
$$

那它本质上就是：

> 多次基础仿真 + 差分后处理。

例如每个参数扰动一次，重新跑 transient 或 AC。

但是更高级的灵敏度分析会直接对电路方程求导。

例如 DC 灵敏度：

原方程是：

$$
F(x,p)=0
$$

对参数 $p$ 求导：

$$
\frac{\partial F}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial F}{\partial p}
=0
$$

于是：

$$
\frac{\partial x}{\partial p}
=

-\left(\frac{\partial F}{\partial x}\right)^{-1}
\frac{\partial F}{\partial p}
$$

瞬态灵敏度则会对动态方程：

$$
F(x(t),\dot{x}(t),p,t)=0
$$

求参数导数，得到灵敏度方程。

因此灵敏度有两种理解：

| 方法       | 本质                 |
| -------- | ------------------ |
| 有限差分灵敏度  | 基础仿真的重复调用          |
| 直接/伴随灵敏度 | 在原电路方程基础上构造新的灵敏度方程 |

所以如果从算法研究角度看，灵敏度分析可以算一种重要的派生求解问题；但从普通 SPICE 用户角度看，它通常依附于 DC、AC、Transient。


## 七、最终分类：哪些最本质，哪些是复用？

可以这样分。

### A 类：最本质仿真

这些是底层求解问题，不能简单理解为对其他仿真的后处理。

| 类型               | 地位     | 原因            |
| ---------------- | ------ | ------------- |
| OP / DC          | 本质     | 求非线性静态电路方程    |
| Transient        | 本质     | 求非线性动态电路方程    |
| AC               | 本质/半本质 | 求工作点线性化后的频域响应 |
| PSS              | RF 中本质 | 求非线性周期稳态解     |
| Harmonic Balance | RF 中本质 | 求非线性频域稳态解     |

其中，如果只讨论传统 SPICE，最核心就是：

> **DC / OP、Transient、AC**

如果讨论 RF 仿真器，再加：

> **PSS、Harmonic Balance**

### B 类：基础仿真的循环调用

这些不是新的底层仿真。

| 类型                | 本质上是什么                 |
| ----------------- | ---------------------- |
| DC Sweep          | 多次 DC                  |
| Parametric Sweep  | 多次 DC / AC / Transient |
| Temperature Sweep | 温度参数扫描                 |
| Corner Analysis   | 工艺/电压/温度组合扫描           |
| Monte Carlo       | 随机参数扫描 + 统计            |
| Worst-Case        | 参数空间搜索 + 基础仿真          |


### C 类：OP/AC 的派生小信号分析

这些通常依赖 OP 和线性化模型。

| 类型                 | 本质上是什么          |
| ------------------ | --------------- |
| Noise              | OP + 小信号噪声传播    |
| TF                 | OP + 低频小信号解     |
| PZ                 | OP + 线性系统极点零点   |
| STB                | OP + 环路增益 AC 分析 |
| S-Parameter        | OP + 高频小信号端口分析  |
| PAC / PNoise / PXF | PSS + 周期小信号分析   |

### D 类：Transient 的派生或后处理

| 类型             | 本质上是什么             |
| -------------- | ------------------ |
| Startup        | 特定初始条件下的 transient |
| Delay analysis | transient 波形测量     |
| Rise/Fall time | transient 波形测量     |
| Settling time  | transient 波形测量     |
| Dynamic power  | transient 电压电流积分   |
| FFT/部分 THD     | transient 波形后处理    |


### E 类：特殊派生求解

| 类型             | 说明                                      |
| -------------- | --------------------------------------- |
| Sensitivity    | 可以是多次仿真差分，也可以是直接/伴随灵敏度方程                |
| Optimization   | 反复调用基础仿真 + 优化算法                         |
| Yield Analysis | Monte Carlo / Corner / Worst-case 的统计封装 |


## 九、结合 Xyce / SPICE 的角度

对于传统 SPICE / Xyce 这类仿真器，最核心的仿真类型一般可以看成：

1. **DC operating point**
   求静态非线性代数方程。

2. **Transient analysis**
   求非线性微分-代数方程的时域演化。

3. **AC analysis**
   在 DC 工作点附近线性化，求频域小信号响应。

4. **Sensitivity analysis**
   在 DC、AC、Transient 的基础上，对参数求导；它不是完全独立于前三者的仿真，但在算法上很重要。

其他很多功能，如 sweep、Monte Carlo、corner、measure，更像是：

> 对这些核心仿真的批量调用、参数扰动、统计分析和指标提取。


一句话总结：

> **最本质的晶体管级仿真是 DC、Transient、AC；RF 场景下再加 PSS 和 Harmonic Balance。其余多数所谓仿真类型，本质上是这些核心仿真的循环调用、小信号派生、统计封装或结果后处理。**
