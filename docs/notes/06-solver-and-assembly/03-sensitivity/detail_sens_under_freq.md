## 如何直观理解频域下的灵敏度物理含义

可以把

$$
\frac{\partial \hat{x}}{\partial p_k}
$$

先非常直接地理解成一句话：

```text
在固定频率 ω、固定 DC 工作点附近，
参数 p_k 轻微变化时，
频域小信号响应相量 x̂ 会往哪个复数方向变化、变化多快。
```

这里最难直观的地方在于：`x̂` 是 **复数相量**，不是普通实数。  
所以它不是只表示“大小变了多少”，而是同时编码：

- 幅值怎么变
- 相位怎么变

## 1. 先从你最熟悉的时域波形看

先看一个单节点的小信号响应：

$$
\Delta x(t)=\Re\{\hat{x}e^{j\omega t}\}
$$

如果把相量写成极坐标：

$$
\hat{x}=A e^{j\phi}
$$

那么时域波形就是：

$$
\Delta x(t)=A\cos(\omega t+\phi)
$$

这里：

- $A$ 是这个节点小信号响应的幅值
- $\phi$ 是这个节点相对激励的相位
- $\omega$ 是频率，通常在 AC 分析里是固定的

## 2. 参数变一点，到底发生什么

现在把参数 $p_k$ 改一点：

$$
p_k \to p_k + \delta p_k
$$

那么响应相量也会变：

$$
\hat{x} \to \hat{x} + \delta \hat{x}
$$

而且一阶近似下：

$$
\delta \hat{x}\approx
\frac{\partial \hat{x}}{\partial p_k}\,\delta p_k
$$

这就是它最直接的含义：

```text
∂x̂/∂p_k 就是“参数每变化 1 个单位，
这个频域响应相量会变化多少”。
```

注意，这里的“变化多少”是 **复数变化**。

## 3. 为什么说它同时包含幅值变化和相位变化

因为相量本身可以写成：

$$
\hat{x}(p_k)=A(p_k)e^{j\phi(p_k)}
$$

对参数求导：

$$
\frac{\partial \hat{x}}{\partial p_k}
=
\frac{\partial A}{\partial p_k}e^{j\phi}
+
A\frac{\partial}{\partial p_k}(e^{j\phi})
$$

而

$$
\frac{\partial}{\partial p_k}(e^{j\phi})
=
j e^{j\phi}\frac{\partial \phi}{\partial p_k}
$$

所以：

$$
\frac{\partial \hat{x}}{\partial p_k}
=
e^{j\phi}
\left(
\frac{\partial A}{\partial p_k}
+
jA\frac{\partial \phi}{\partial p_k}
\right)
$$

这条式子特别重要，因为它告诉你：

- 实部方向更像“幅值变化分量”
- 乘上 `j` 的那部分更像“相位旋转分量”

也就是说：

$$
\frac{\partial \hat{x}}{\partial p_k}
$$

本质上就是把下面两件事打包在一起：

1. 参数变化引起的 **幅值变化**
2. 参数变化引起的 **相位变化**

## 4. 转回时域，会更直观

时域波形是：

$$
\Delta x(t)=A\cos(\omega t+\phi)
$$

对参数求导：

$$
\frac{\partial \Delta x(t)}{\partial p_k}
=
\frac{\partial A}{\partial p_k}\cos(\omega t+\phi)
-
A\frac{\partial \phi}{\partial p_k}\sin(\omega t+\phi)
$$

这条式子非常有物理感：

### 第一项
$$
\frac{\partial A}{\partial p_k}\cos(\omega t+\phi)
$$

表示：

```text
参数变化让波形“变高或变低”
```

也就是幅值变化。

### 第二项
$$
-A\frac{\partial \phi}{\partial p_k}\sin(\omega t+\phi)
$$

表示：

```text
参数变化让波形“左右挪了一点”
```

也就是相位变化。

所以：

$$
\frac{\partial \hat{x}}{\partial p_k}
$$

如果你非要给它一个特别直观的物理图像，它其实就是：

```text
“这个参数变化，会怎样同时改变该频点响应的振幅和相位”
```

## 5. 它不是“频率变了”，而是“在固定频率下响应变了”

这一点很关键。

在 AC sensitivity 里，我们通常是在 **固定频率 $\omega$** 下讨论：

$$
J_{AC}(\omega)\hat{x}=\hat{b}
$$

所以

$$
\frac{\partial \hat{x}}{\partial p_k}
$$

不是在说：

- 频率漂了多少
- 波形周期变了多少

而是在说：

```text
当测试频率 ω 不变时，
这个参数变化会怎样改变该频率处的复响应。
```

也就是：

- 增益会不会变
- 相位会不会偏
- 某个节点的 AC 电压会不会更大
- 某个支路电流会不会滞后更多


## 6. 如果把它看成网络函数，就更像“Bode 曲线对参数的斜率”

比如某个输出是：

$$
\hat{v}_{out}(\omega,p)
$$

那么

$$
\frac{\partial \hat{v}_{out}}{\partial p_k}
$$

可以理解成：

```text
在频率 ω 这一点上，
Bode 响应对参数 p_k 的局部变化率
```

只是它不是只看幅频曲线，也不是只看相频曲线，而是一次性保留了复响应的完整信息。

如果再拆开，你就能得到：

- 幅值灵敏度
  $$
  \frac{\partial |\hat{v}_{out}|}{\partial p_k}
  $$
- 相位灵敏度
  $$
  \frac{\partial \angle \hat{v}_{out}}{\partial p_k}
  $$

所以复相量灵敏度其实比“只看增益灵敏度”更原始、更完整。


## 7. 对向量 `x̂` 来说是什么意思

上面我讲的是单个分量。  
但在电路里，`x̂` 往往是整个小信号解向量：

$$
\hat{x}=
\begin{bmatrix}
\hat{x}_1\\
\hat{x}_2\\
\vdots\\
\hat{x}_n
\end{bmatrix}
$$

那么

$$
\frac{\partial \hat{x}}{\partial p_k}
=
\begin{bmatrix}
\frac{\partial \hat{x}_1}{\partial p_k}\\
\frac{\partial \hat{x}_2}{\partial p_k}\\
\vdots\\
\frac{\partial \hat{x}_n}{\partial p_k}
\end{bmatrix}
$$

就表示：

```text
参数 p_k 变化时，
整个 AC 小信号解向量中每个节点、每个支路、每个内部变量的复响应分别怎么变。
```

也就是说，它不是一个“单个输出灵敏度”，而是整套 AC 状态的灵敏度。

这也是为什么 direct AC sensitivity 更贵：  
它算的是整块状态响应，而不只是某一个输出。


## 8. 和 DC sensitivity 的直觉差别

这个对比也很有帮助。

### DC 里
$$
\frac{\partial x}{\partial p_k}
$$

表示：

```text
参数变化时，工作点电压/电流怎么变
```

它是静态的、实数的。

### AC 里
$$
\frac{\partial \hat{x}}{\partial p_k}
$$

表示：

```text
参数变化时，该频点的小信号复响应怎么变
```

它是频域的、复数的。

所以 AC 里多出来的那层“不直观”，其实主要就来自：

- 它不是静态点值
- 它是复相量
- 它同时带着幅值和相位信息