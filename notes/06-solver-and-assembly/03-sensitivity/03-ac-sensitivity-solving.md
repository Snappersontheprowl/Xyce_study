# ac sensitivity solving

记录日期：2026-07-04

## 这篇的定位

这一篇只讲 `AC sensitivity` 的数学骨架，以及它和 `DC sensitivity` 的关键差别。

核心问题是：

```text
为什么 AC 灵敏度不是“再做一次 DC 灵敏度”，
而是“先在 DC 工作点上线性化，再在频域里对小信号系统求导”？
```

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)

## 当前结论先写在前面

`AC sensitivity` 最适合先压成下面这句话：

```text
先求 DC 工作点，
再围绕这个工作点建立 AC 小信号线性系统，
最后对这个频域线性系统对参数求导。
```

如果先写成复数形式，那么 AC 主问题是：

$$
J_{AC}(\omega)\,\hat{x} = \hat{b}
$$

其中

$$
J_{AC}(\omega)=G+j\omega C
$$

对参数 $p_k$ 求导后得到：

$$
J_{AC}(\omega)\,\frac{\partial \hat{x}}{\partial p_k}
=
\frac{\partial \hat{b}}{\partial p_k}
-
\frac{\partial J_{AC}}{\partial p_k}\,\hat{x}
$$

这就是 `AC direct sensitivity` 最核心的方程。

## 第一步：为什么 AC 不是直接从原非线性方程开始

`AC analysis` 不是直接把非线性电路拿到频域里解，而是分两步：

### 1. 先求 DC 工作点

得到：

$$
x^*
$$

### 2. 再在工作点附近做小信号线性化

于是原始非线性系统在小扰动层面只保留一阶项，形成：

$$
G\,\Delta x + C\,\frac{d(\Delta x)}{dt} = \Delta b(t)
$$

这里：

- $G$ 来自工作点处的 $\partial F/\partial x$
- $C$ 来自工作点处的 $\partial Q/\partial x$

然后假设小信号是正弦稳态：

$$
\Delta x(t)=\Re\{\hat{x}e^{j\omega t}\}
$$

就得到频域方程：

$$
(G+j\omega C)\hat{x}=\hat{b}
$$

*细节参考：*[02-ac-small-signal-solving](notes/06-solver-and-assembly/02-advanced/02-ac-small-signal-solving.md)
所以 `AC sensitivity` 的起点不是原始非线性残差，而是：

```text
已经在线性化之后的频域小信号系统
```

## 第二步：参数在 AC 里会影响哪些对象

对 `AC` 来说，参数不只会影响右端输入，也会影响系统矩阵本身：

### 1. 影响输入

$$
\hat{b}=\hat{b}(p)
$$

所以会有：

$$
\frac{\partial \hat{b}}{\partial p_k}
$$

### 2. 影响线性化矩阵

因为：

$$
J_{AC}(\omega)=G+j\omega C
$$

而 $G$ 和 $C$ 都来自工作点及器件模型，所以参数变化会导致：

$$
\frac{\partial J_{AC}}{\partial p_k}
=
\frac{\partial G}{\partial p_k}
+
j\omega\frac{\partial C}{\partial p_k}
$$

这就是 `AC sensitivity` 和 `DC sensitivity` 的一个非常重要的差别：

```text
DC 里更像是“参数推动静态残差”，
AC 里还要问“参数如何改变小信号矩阵本身”。
```

## 第三步：direct AC sensitivity 方程是怎么来的

从

$$
J_{AC}(\omega)\hat{x}=\hat{b}
$$

对参数 $p_k$ 求导：

$$
\frac{\partial J_{AC}}{\partial p_k}\hat{x}
+
J_{AC}\frac{\partial \hat{x}}{\partial p_k}
=
\frac{\partial \hat{b}}{\partial p_k}
$$

整理得到：

$$
J_{AC}(\omega)\frac{\partial \hat{x}}{\partial p_k}
=
\frac{\partial \hat{b}}{\partial p_k}
-
\frac{\partial J_{AC}}{\partial p_k}\hat{x}
$$

所以 `AC direct sensitivity` 的结构和 `DC direct sensitivity` 非常像：

- 左边还是同一个 AC 系统矩阵
- 未知还是解的参数导数
- 右边变成了“输入导数减去矩阵导数乘原解”

其中：

$$
\frac{\partial J_{AC}}{\partial p_k}\hat{x}
$$

是 `AC` 里最值得特别注意的一项，因为它编码了：

```text
参数变化不仅推动输入，还会改变整个小信号网络本身。
```

## 第四步：为什么 Xyce 的 AC sensitivity 会先做一层 DC 预计算

这一步从代码里看非常关键。

在 [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C) 的 `precomputeDCsensitivities_()` 注释里，作者直接说明：

1. 先在 `DCOP` 上求每个参数的 `dx/dp`
2. 用这些 `dx/dp` 去构造扰动后的工作点
3. 重新加载 `dFdx` 和 `dQdx`
4. 再通过差分得到 `dGdp` 和 `dCdp`
5. 最后组装 `dJdp`

这件事的数学意义是：

```text
AC 矩阵 G+jωC 并不是一个“凭空给定”的常量矩阵，
它依赖于 DC 工作点和器件状态。
所以要对它求参数导数，
必须先知道参数如何改变工作点。
```


## 第五步：Xyce 为什么把复数系统改写成实数块矩阵

代码里不是直接保存一个复数矩阵，而是改成 2x2 实数块系统：

$$
\begin{bmatrix}
G & -\omega C\\
\omega C & G
\end{bmatrix}
\begin{bmatrix}
\Re(\hat{x})\\
\Im(\hat{x})
\end{bmatrix}
=
\begin{bmatrix}
\Re(\hat{b})\\
\Im(\hat{b})
\end{bmatrix}
$$

这和 [N_ANP_AC.C:1229](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1229) 的 `updateLinearSystemFreq_()` 是一致的。

这样做的好处是：

- 可以复用实数线性代数后端
- direct / adjoint 都能在同一块矩阵框架下实现

于是 `AC sensitivity` 在代码中对应的未知量实际上是：

$$
\frac{\partial \Re(\hat{x})}{\partial p_k},
\qquad
\frac{\partial \Im(\hat{x})}{\partial p_k}
$$

再进一步推到：

- 实部灵敏度
- 虚部灵敏度
- 幅值灵敏度
- 相位灵敏度

## 第六步：adjoint 在 AC 里是怎样工作的

如果目标函数是：

$$
y=g(\hat{x},p)
$$

那么 direct 思路是：

1. 对每个参数解

   $$
   J_{AC}\frac{\partial \hat{x}}{\partial p_k}
   =
   \frac{\partial \hat{b}}{\partial p_k}
   -
   \frac{\partial J_{AC}}{\partial p_k}\hat{x}
   $$
2. 再映射到输出

adjoint 思路则是：

1. 先解

   $$
   J_{AC}^{T}\lambda
   =
   \left(\frac{\partial g}{\partial \hat{x}}\right)^T
   $$
2. 再对每个参数做内积

所以在 `AC` 里，adjoint 的节省点和通用情况一致：

```text
输出少时，
按输出解伴随方程
会比按参数逐个解 direct 系统更便宜。
```

## 第七步：为什么 AC 输出会比 DC 输出多一层映射

`DC` 里输出往往直接是某个实数状态。

但 `AC` 里一个输出通常天然带有四种可观察量：

- 实部
- 虚部
- 幅值
- 相位

所以 Xyce 在 `solve_mag_phase_Sensitivities_()` 里继续把

$$
\frac{\partial \Re(\hat{x})}{\partial p_k},
\qquad
\frac{\partial \Im(\hat{x})}{\partial p_k}
$$

映射到：

$$
\frac{\partial |\hat{x}|}{\partial p_k},
\qquad
\frac{\partial \angle \hat{x}}{\partial p_k}
$$

这说明 `AC sensitivity` 的“输出层”比 `DC` 更丰富。

## 第八步：和代码怎么对照

顺着代码看，最自然的顺序是：

1. 先读 `.SENS` 解析：
   - [N_ANP_AC.C:259](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L259)
2. 再读 `.options sensitivity`：
   - [N_ANP_AC.C:331](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L331)
3. 再看 AC 主循环里什么时候触发 sensitivity：
   - [N_ANP_AC.C:1004](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1004)
4. 然后看 AC 矩阵如何由 `G` 和 `C` 组装：
   - [N_ANP_AC.C:1151](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1151)
   - [N_ANP_AC.C:1229](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1229)
5. 再看为什么要预计算 `dJdp`：
   - [N_ANP_AC.C:1394](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1394)
6. 最后看 direct / adjoint 两种求解：
   - [N_ANP_AC.C:1643](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1643)
   - [N_ANP_AC.C:1915](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1915)
   - [N_ANP_AC.C:1990](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1990)

## 当前这一篇学完后，应该记住什么

1. `AC sensitivity` 不是直接对原非线性电路做频域灵敏度，而是先建立 DC 工作点，再对小信号系统求导。
2. 它的核心方程是

   $$
   J_{AC}\frac{\partial \hat{x}}{\partial p_k}
   =
   \frac{\partial \hat{b}}{\partial p_k}
   -
   \frac{\partial J_{AC}}{\partial p_k}\hat{x}
   $$
3. `AC` 比 `DC` 多出来的难点是：参数会改变 $G$、$C$，也就会改变频域矩阵本身。
4. Xyce 用实数 2x2 块矩阵来表示复数 AC 系统，所以灵敏度最终也要落到实部/虚部/幅值/相位上。
5. `AC adjoint` 的省计算逻辑没有变，但输出映射比 `DC` 更丰富。
