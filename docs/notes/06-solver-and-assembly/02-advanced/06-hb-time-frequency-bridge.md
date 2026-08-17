# hb time frequency bridge

记录日期：2026-06-06

## 这篇的定位

这一篇继续承接：

- [05-hb-solving-roadmap.md](05-hb-solving-roadmap.md)

这一篇要先回答数学上的核心问题，再去对代码：

```text
为什么 HB 会同时出现“谐波系数”“fast-time 样本”“FFT/IFT”这三套对象？
它们不是实现细节，而是 HB 数学形式本身的直接落地。
```

如果只抓一句话，请先抓这个：

```text
HB 不是在时域一步一步推进轨迹，
而是在“周期稳态”假设下，
直接把整条周期波形表示成有限个谐波系数，
然后在这些系数上解一个 nonlinear algebraic system。
```

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_HB.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.C)
- [src/LoaderServicesPKG/N_LOA_HBLoader.h](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_HBLoader.h)
- [src/LoaderServicesPKG/N_LOA_HBLoader.C](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_HBLoader.C)
- [src/LinearAlgebraServicesPKG/N_LAS_HBBuilder.h](../../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_HBBuilder.h)

## 先从原始电路方程出发

`HB` 也不是从空中冒出来的。它和 `DC`、`transient` 一样，起点仍然是同一条电路 DAE：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

这里：

- $x(t)$ 是整套电路未知量
- $Q(x)$ 是电荷/磁链类动态项
- $F(x)$ 是静态导通与 KCL/KVL 项
- $B(t)$ 是外部激励

`transient` 的思路是：

- 保留 $x(t)$ 这条轨迹
- 再用时间离散把它变成一步一步的 nonlinear equation

而 `HB` 的思路完全不同：

- 先假设最终要找的是一个 **周期稳态解**
- 不再一步步追踪整个起始到终点的时间演化
- 而是直接在“一个周期上的周期函数空间”里解方程

## 第一步：周期稳态假设

`HB` 的第一条数学假设是：

$$
x(t + T) = x(t)
$$

也就是说，我们关心的是周期为 $T$ 的稳态响应。

这一步和 `transient` 的根本差别就在这里：

- `transient` 允许波形随着时间继续向前演化
- `HB` 只关心“最终那个已经稳定下来的周期波形”

一旦这个假设成立，就意味着我们可以不再把未知对象看成“任意轨迹”，而把它看成“周期函数”。

## 第二步：有限谐波展开

对于周期函数，最自然的表示方法就是 Fourier 展开。

对单基波场景，可以先写成：

$$
x(t) \approx x_0 + \sum_{k=1}^{K}
\Big(
a_k \cos(k\omega_0 t) + b_k \sin(k\omega_0 t)
\Big)
$$

其中：

- $\omega_0 = \frac{2\pi}{T}$
- $K$ 是保留的最高谐波阶数
- $x_0, a_k, b_k$ 都是待求系数

如果把这些系数统一堆成一个大向量：

$$
\hat{x}
=
\begin{bmatrix}
x_0 & a_1 & b_1 & a_2 & b_2 & \cdots & a_K & b_K
\end{bmatrix}^T
$$

那么 `HB` 真正要求解的未知量，其实就不再是时域轨迹 $x(t)$，而是这组谐波系数 $\hat{x}$。

这一点非常重要：

```text
HB 的 Newton 未知量不是“当前时刻的电压向量”，
而是“整个周期波形的有限谐波系数”。
```

## 第三步：为什么 nonlinear 器件逼着我们回到时域样本

如果电路是线性的，那么把所有东西都写成 Fourier 系数后，频域处理会很直接。

但真实电路里，器件是非线性的。  
比如某个器件电流可能是：

$$
i(t) = f(v(t))
$$

如果 $v(t)$ 已经写成一串谐波展开，那么：

$$
f(v(t))
$$

通常不会轻松地直接变成“简单的系数代数表达式”。  
尤其对 `MOSFET_B4` 这类复杂 compact model，更不可能要求器件作者手工直接写出完整的谐波域公式。

所以 `HB` 的实际思路不是：

```text
让每个器件直接给出完整频域 nonlinear 残差
```

而是：

```text
先把谐波系数还原成一个周期上的若干时域样本，
在这些样本点上复用普通时域器件装配，
再把结果投影回谐波系数空间。
```

这就是时频桥的数学理由。

## 第四步：从谐波系数到 fast-time 样本

为了复用普通时域装配，`HB` 会在一个周期内选择若干个采样点：

$$
t_1, t_2, \dots, t_M
$$

然后用当前谐波系数 $\hat{x}$ 计算这些采样点上的波形值：

$$
x(t_i) = \Phi(t_i)\hat{x}
$$

这里 $\Phi(t_i)$ 可以理解成由：

- 常数基
- $$\cos(k\omega_0 t_i)$$
- $$\sin(k\omega_0 t_i)$$

组成的一行基函数矩阵。

把所有采样点堆起来，就得到：

$$
x_t = T_{\mathrm{IFT}} \hat{x}
$$

这就是“从频域系数到时域样本”的线性变换。  
在代码里，它对应的正是 `IFT`。

所以，`HB` 里的 `IFT` 不是附属技巧，而是这条数学关系的直接实现：

$$
\text{谐波系数} \longrightarrow \text{周期样本值}
$$

## 第五步：在样本点上写残差

一旦得到了这些样本值 $x(t_i)$，我们就可以在每个样本点上评估原始 DAE：

$$
r(t_i;\hat{x}) =
\frac{dQ(x(t_i))}{dt} + F(x(t_i)) - B(t_i)
$$

这里要注意：

- 器件仍然只是在“某个时刻的状态”下算 $Q$、$F$、$dQdx$、$dFdx$
- 它并不知道自己正在为 `HB` 服务
- `HB` 只是在外层帮它把“当前谐波系数对应的波形样本”喂进去

这就是为什么 `HB` 能大量复用普通器件装配代码。

## 第六步：为什么还要把样本残差再变回频域

`HB` 真正的未知量是谐波系数 $\hat{x}$，所以最终 residual 也必须表达在同一个空间里。

也就是说，我们不能只在样本点上得到一堆：

$$
r(t_1), r(t_2), \dots, r(t_M)
$$

还必须把这些样本残差重新投影回有限谐波子空间：

$$
\hat{r} = T_{\mathrm{FFT}} r_t
$$

这样才能得到 `HB` 的 nonlinear solve 真正要看到的频域 residual：

$$
\hat{r}(\hat{x}) = 0
$$

因此，`FFT` 这一步也不是辅助动作，而是这条数学关系的直接实现：

$$
\text{时域样本残差} \longrightarrow \text{谐波系数残差}
$$

## 第七步：时间导数为什么会变成 $j\omega$

这是 `HB` 数学里最核心的一步之一。

对单个复指数基函数：

$$
e^{jk\omega_0 t}
$$

有：

$$
\frac{d}{dt} e^{jk\omega_0 t}
=
jk\omega_0 e^{jk\omega_0 t}
$$

所以在 Fourier 系数空间里，时间导数算子不再表现成“时间步长差分”，而直接变成“乘以谐波频率”：

$$
\frac{d}{dt}
\quad \Longleftrightarrow \quad
jk\omega_0
$$

这就是为什么：

- `transient` 里导数项靠 $\Delta t$ 离散
- `HB` 里导数项靠 $j\omega$ 作用

对实数形式的 `cos/sin` 基底来说，$j\omega$ 不会直接以复数标量出现，而是变成实数块之间的耦合。  
这正是你在代码里看到的：

```text
±ω 的交叉项
```

所以本质上：

```text
HB 里的时间导数没有消失，
只是从“时间差分”变成了“谐波域中的频率乘子”。
```

## 第八步：Jacobain 为什么也要走同样的时频桥

`HB` 最终要做 Newton，所以还需要：

$$
\frac{\partial \hat{r}}{\partial \hat{x}}
$$

这个 Jacobian 不适合被理解成“器件直接给出一张巨大频域矩阵”。  
更自然的理解是：

1. 当前谐波系数 $\hat{x}$ 先通过 `IFT` 变成样本值
2. 每个样本点上，普通器件照常给出：
   - $\frac{\partial Q}{\partial x}$
   - $\frac{\partial F}{\partial x}$
3. 再通过 `FFT/IFT` 和导数算子的组合，把它们拼成谐波系数空间里的 Jacobian 作用

所以在 `HB` 里：

```text
Jacobian 的难点不是“它是个大矩阵”，
而是“它是时域局部导数，经由时频变换，投影成谐波系数空间中的大块结构”。
```

## 到这里先收一句最本质的话

如果只抓一句数学本质，我希望你先抓住：

```text
HB = 周期稳态假设
   + 有限谐波展开
   + 在 fast-time 样本点上评估 nonlinear 器件
   + 再把样本残差/导数投影回谐波系数空间
```

这就是 `HB` 里同时出现：

- 谐波系数
- fast-time 样本
- FFT / IFT

的根本原因。

## 下面再把这条数学主线对上代码

到这一步，再去看代码，逻辑就会顺很多。

### 1. 先定 fast-time 采样点和变换矩阵

在：

- [N_ANP_HB.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.C)

里，先看：

- `HB::setTimePoints_()`
- `HB::createFT_()`

这里的作用分别可以先理解成：

- `setTimePoints_()`：决定一个周期内选哪些采样点
- `createFT_()`：构造时频变换矩阵，也就是这里说的 $T_{\mathrm{IFT}}$ 和 $T_{\mathrm{FFT}}$ 的实现基础

你会在 `createFT_()` 里直接看到：

- `cos(...)`
- `sin(...)`
- 以及 DFT/IDFT 矩阵的建立

所以这一层不是实现细节，而是前面“有限谐波展开 + 样本投影”的数学定义在代码里的落地。

### 2. 再由 HBBuilder 决定两套 block 结构

然后看：

- [N_LAS_HBBuilder.h](../../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_HBBuilder.h)

这里最值得先记的是两类向量构造：

- `createTimeDomainBlockVector()`
- `createExpandedRealFormTransposeBlockVector()`

它们分别对应：

- 时域采样块
- 频域谐波系数块

也就是说，`HBBuilder` 做的是“线性代数对象形状”的准备工作，让后面的：

- `IFT`
- 时域装配
- `FFT`

都能落在正确的 block 结构上。

### 3. HBLoader::permutedIFT(...) 对应“系数 -> 样本”

再看：

- [N_LOA_HBLoader.C](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_HBLoader.C)
  里的 `HBLoader::loadDAEVectors(...)`

一开始最关键的动作之一就是：

```cpp
permutedIFT(bXf, &*bXtPtr_);
```

现在它就不再显得突兀了。  
它对应的正是前面的数学关系：

$$
x_t = T_{\mathrm{IFT}} \hat{x}
$$

也就是：

```text
当前 Newton 未知量是谐波系数
-> 先把它还原成一个周期上的时域样本块
```

### 4. 样本循环里复用普通时域器件装配

接着在同一个 `loadDAEVectors(...)` 里，会看到对 `BlockCount` 的循环。

在每个样本点上，核心动作是：

1. `deviceManager_.setFastTime(...)`
2. `appLoaderPtr_->updateSources()`
3. `appLoaderPtr_->updateState(..., Device::NONLINEAR_FREQ)`
4. `appLoaderPtr_->loadDAEVectors(...)`
5. `appLoaderPtr_->loadDAEMatrices(...)`

这正对应前面的数学步骤：

$$
r(t_i;\hat{x})
=
\frac{dQ(x(t_i))}{dt} + F(x(t_i)) - B(t_i)
$$

也就是说：

```text
HB 并没有要求普通器件直接进入“谐波域思维”，
而是让它们继续在“当前样本点”的时域世界里工作。
```

### 5. permutedFFT2(...) 对应“样本残差 -> 系数残差”

在 `loadDAEVectors(...)` 后半段，你会看到：

```cpp
permutedFFT2(*bBt, bB);
permutedFFT2(*bQt, bQ);
permutedFFT2(*bFt, bF);
```

这对应的正是：

$$
\hat{r} = T_{\mathrm{FFT}} r_t
$$

它的含义是：

```text
前面在时域样本点上得到的 Q/F/B，
要重新回到谐波系数空间，
这样 HB 的 residual 才能跟当前未知量 Xf 属于同一个空间。
```

### 6. applyDAEMatrices(...) 对应 Jacobian 的时频桥

最后看：

- `HBLoader::applyDAEMatrices(...)`

这一层最适合理解成：

```text
把“谐波系数空间中的一个扰动向量”
送过 HB Jacobian
得到“谐波系数空间中的 Jacobian-vector 结果”
```

它的大体逻辑是：

1. 对输入扰动向量做 `IFT`
2. 在样本点上用存好的时域 Jacobian 做局部作用
3. 再做 `FFT`
4. 最后把导数项对应的 $j\omega$ 结构补进去

这就是为什么你在这里会看到：

- 时域 matvec
- `permutedFFT / permutedIFT`
- 以及 `±ω` 交叉项

现在这几步的数学含义都能对上了。

## 当前结论

`HB` 的时频桥，最本质地可以压成下面这条链：

$$
\hat{x}
\xrightarrow{\mathrm{IFT}}
x(t_i)
\xrightarrow{\text{device/load}}
r(t_i)
\xrightarrow{\mathrm{FFT}}
\hat{r}
$$

而 Jacobian 则是这条链在线性化后的对应版本：

$$
\delta \hat{x}
\xrightarrow{\mathrm{IFT}}
\delta x(t_i)
\xrightarrow{\text{sample Jacobian}}
\delta r(t_i)
\xrightarrow{\mathrm{FFT}}
\delta \hat{r}
$$

再叠加时间导数在谐波域里的：

$$
\frac{d}{dt} \leftrightarrow j\omega
$$

这就形成了 `HB` 最终送进 Newton 的 nonlinear algebraic system。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `HB` 里必须同时保留“谐波系数空间”和“fast-time 样本空间”，而不能只在其中一个空间把所有事情做完？
2. 为什么 `HB` 中的 `IFT/FFT` 不只是实现技巧，而是“有限谐波展开 + 样本点评估 + 投影回谐波空间”这条数学链本身的直接实现？
