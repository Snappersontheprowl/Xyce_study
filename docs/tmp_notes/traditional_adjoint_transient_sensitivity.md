这一步的核心是：**用伴随变量 $\lambda$ 把原来必须显式计算的 $\frac{\partial x}{\partial p}$ 消掉。**

也就是说，传统直接法本来要算：

$\frac{dO}{dp}=\frac{dO}{dx_N}\frac{\partial x_N}{\partial p}$

但 $\frac{\partial x_N}{\partial p}$ 是一个很大的矩阵，所以伴随法想办法把它改写成：

$\frac{dO}{dp}=-\sum_{n=0}^{N}\lambda_n\left(\frac{\partial g}{\partial p}\right)_n$

这样就不用直接保存和计算 $\frac{\partial x}{\partial p}$ 这个大矩阵了。论文中这一组公式对应第 II-B 节的直接法与伴随法推导。

---

# 1. 从瞬态电路方程开始

电路瞬态方程写成：

$$f(x,t,p)=\frac{d}{dt}[Q(x,p)]+F(x,p)+B(t,p)=0$$

其中：

* $x$：电路状态变量，比如节点电压、电感电流；
* $p$：电路参数，比如电阻、MOS 管宽度、阈值电压；
* $Q(x,p)$：动态项，比如电容电荷；
* $F(x,p)$：静态电流项；
* $B(t,p)$：外部输入源。

瞬态仿真把连续时间离散成：

$t_0,t_1,\cdots,t_N$

于是每个时间点都要求解一个离散后的非线性方程。

---

# 2. 对参数求导，得到灵敏度方程

我们关心的是：$\frac{dO}{dp}$ 而 $O=f(x_N)$，所以如果直接用链式法则：

$$\frac{dO}{dp}=\frac{dO}{dx_N}\frac{\partial x_N}{\partial p}$$

问题就变成：如何求 $\frac{\partial x_N}{\partial p}$？

论文从电路方程对参数 $p$ 求导，经过后向欧拉离散后得到一个递推关系。为了简化记号，可以写成：

$$\left(\frac{\partial f}{\partial x}\right)*{n+1}
\left(\frac{\partial x}{\partial p}\right)*{n+1}
\frac{1}{\Delta t}
\left(\frac{\partial Q}{\partial x}\right)_n
\left(\frac{\partial x}{\partial p}\right)_n
\left(\frac{\partial g}{\partial p}\right)_{n+1}$$

这里：

$$\left(\frac{\partial f}{\partial x}\right)_{n+1}
\frac{1}{\Delta t}
\left(\frac{\partial Q}{\partial x}\right)*{n+1}
+
\left(\frac{\partial F}{\partial x}\right)*{n+1}$$
而 $\left(\frac{\partial g}{\partial p}\right)_{n+1}$ 表示那些**直接由参数变化引起的项**，例如：

$\frac{\partial Q}{\partial p},\frac{\partial F}{\partial p},\frac{\partial B}{\partial p}$

---

# 3. 直接法是怎么来的？

把上面的式子整理一下，可以得到：

$$\left(\frac{\partial x}{\partial p}\right)_{n+1}
\left(\frac{\partial f}{\partial x}\right)_{n+1}^{-1}
\left[
\frac{1}{\Delta t}
\left(\frac{\partial Q}{\partial x}\right)_n
\left(\frac{\partial x}{\partial p}\right)_n
\left(\frac{\partial g}{\partial p}\right)_{n+1}
\right]$$

这就是**直接法**。

它的意思是：

> 已知第 $n$ 个时间点的灵敏度 $\left(\frac{\partial x}{\partial p}\right)_n$，就可以往前推出第 $n+1$ 个时间点的灵敏度。

所以直接法是沿着时间方向**正向传播**：

$x_0 \rightarrow x_1 \rightarrow x_2 \rightarrow \cdots \rightarrow x_N$

同时也传播：

$\frac{\partial x_0}{\partial p}
\rightarrow
\frac{\partial x_1}{\partial p}
\rightarrow
\cdots
\rightarrow
\frac{\partial x_N}{\partial p}$

最后代入：

$\frac{dO}{dp}=\frac{dO}{dx_N}\frac{\partial x_N}{\partial p}$

但是问题是：

$\frac{\partial x_n}{\partial p}$

是一个 $D\times M$ 的矩阵。

其中：

* $D$ 是电路状态变量个数；
* $M$ 是参数个数。

真实电路里 $D$ 和 $M$ 都可能很大，所以这个矩阵会非常大。

---

# 4. 伴随法的目标：不要显式算 $\frac{\partial x}{\partial p}$

伴随法的想法是：

> 既然最终只需要 $\frac{dO}{dp}$，不一定非要把每个时间点完整的 $\frac{\partial x_n}{\partial p}$ 都算出来。

我们只需要最终这个乘积：

$\frac{dO}{dx_N}\frac{\partial x_N}{\partial p}$

而不一定需要单独知道完整的 $\frac{\partial x_N}{\partial p}$。

这就像矩阵乘法里，你要算：

$a^T X$

不一定要完整构造 $X$，可以通过反向递推直接算这个乘积。

---

# 5. 用简化符号推导伴随法

为了看清楚推导，把直接法写成更抽象的形式。

令：

$G_n=\left(\frac{\partial x}{\partial p}\right)_n$

$A_n=\left(\frac{\partial f}{\partial x}\right)_n^{-1}$

$B_n=\frac{1}{\Delta t}\left(\frac{\partial Q}{\partial x}\right)_n$

$C_n=-\left(\frac{\partial g}{\partial p}\right)_n$

那么直接法递推可以写成：

$G_{n+1}=A_{n+1}(B_nG_n+C_{n+1})$

这里：

* $G_n$ 是状态对参数的灵敏度；
* $A_n$ 是每个时间点要求解的雅可比矩阵逆；
* $B_n$ 表示前一个时间点灵敏度如何传到下一个时间点；
* $C_n$ 是参数对当前方程的直接影响。

---

# 6. 先看最后一个时间点的目标函数

现在目标函数只依赖最后一个时间点：

$O=f(x_N)$

所以：

$\frac{dO}{dp}=\frac{dO}{dx_N}G_N$

令：

$D_N=\frac{dO}{dx_N}$

则：

$\frac{dO}{dp}=D_NG_N$

接下来关键是把 $G_N$ 展开。

---

# 7. 展开 $G_N$，观察结构

根据递推：

$G_N=A_N(B_{N-1}G_{N-1}+C_N)$

代入：

$\frac{dO}{dp}=D_NA_N(B_{N-1}G_{N-1}+C_N)$

展开：

$\frac{dO}{dp}=D_NA_NB_{N-1}G_{N-1}+D_NA_NC_N$

现在定义：

$\lambda_N=D_NA_N$

也就是：

$\lambda_N=
\frac{dO}{dx_N}
\left(\frac{\partial f}{\partial x}\right)_N^{-1}$

这就是你看到的第一条公式。

于是：

$\frac{dO}{dp}=\lambda_NB_{N-1}G_{N-1}+\lambda_NC_N$

继续看第一项：

$\lambda_NB_{N-1}G_{N-1}$

因为：

$G_{N-1}=A_{N-1}(B_{N-2}G_{N-2}+C_{N-1})$

代入：

$\lambda_NB_{N-1}G_{N-1}
\lambda_NB_{N-1}A_{N-1}(B_{N-2}G_{N-2}+C_{N-1})$

展开：

$\lambda_NB_{N-1}A_{N-1}B_{N-2}G_{N-2}
+
\lambda_NB_{N-1}A_{N-1}C_{N-1}$

这时定义：

$\lambda_{N-1}=\lambda_NB_{N-1}A_{N-1}$

于是就得到：

$$\lambda_{N-1}
\lambda_N
\frac{1}{\Delta t}
\left(\frac{\partial Q}{\partial x}\right)*{N-1}
\left(\frac{\partial f}{\partial x}\right)*{N-1}^{-1}$$

一般化就是：

$$\lambda_n=
\frac{1}{\Delta t}
\lambda_{n+1}
\left(\frac{\partial Q}{\partial x}\right)_n
\left(\frac{\partial f}{\partial x}\right)_n^{-1}$$

这就是伴随变量的反向递推公式。

---

# 8. 为什么最后是一个求和？

继续展开就会发现：

$\frac{dO}{dp}$ 由每个时间点的 $C_n$ 贡献组成：

$\frac{dO}{dp}
\lambda_NC_N+
\lambda_{N-1}C_{N-1}
+
\cdots
+
\lambda_0C_0$

所以：

$\frac{dO}{dp}=\sum_{n=0}^{N}\lambda_nC_n$

而前面定义过：

$C_n=-\left(\frac{\partial g}{\partial p}\right)_n$

所以：

$\frac{dO}{dp}
-\sum_{n=0}^{N}
\lambda_n
\left(\frac{\partial g}{\partial p}\right)_n$

这就是最后一条公式：

$\frac{dO}{dp}=-\sum_{n=0}^{N}\lambda_n\left(\frac{\partial g}{\partial p}\right)_n$

---

# 9. 这三个公式分别是什么意思？

## 第一条：终点初始化

$\lambda_N=\frac{dO}{dx_N}\left(\frac{\partial f}{\partial x}\right)_N^{-1}$

意思是：

> 目标函数 $O$ 只依赖最后一个时间点 $x_N$，所以反向传播从 $x_N$ 开始。

$\frac{dO}{dx_N}$ 表示目标函数对最终状态的敏感程度。

再乘上 $\left(\frac{\partial f}{\partial x}\right)_N^{-1}$，表示通过最后一个时间点的电路方程，把目标函数的梯度转换成伴随变量。

---

## 第二条：反向递推

$\lambda_n=\frac{1}{\Delta t}\lambda_{n+1}\left(\frac{\partial Q}{\partial x}\right)_n\left(\frac{\partial f}{\partial x}\right)_n^{-1}$

意思是：

> 第 $n+1$ 个时间点的目标函数影响，会通过动态元件的时间耦合关系，向前传递到第 $n$ 个时间点。

这里的：

$\frac{\partial Q}{\partial x}$

来自电容、电感等动态元件。
如果电路没有动态元件，就不会形成这种跨时间耦合。

---

## 第三条：参数灵敏度累加

$\frac{dO}{dp}=-\sum_{n=0}^{N}\lambda_n\left(\frac{\partial g}{\partial p}\right)_n$

意思是：

> 每个时间点的电路方程都会受到参数 $p$ 的直接影响，把这些影响乘上对应的伴随变量 $\lambda_n$，再沿时间求和，就得到最终目标函数对参数的灵敏度。

---

# 10. 为什么伴随法适合参数很多？

直接法要算：

$G_n=\frac{\partial x_n}{\partial p}$

如果有 $D$ 个状态变量、$M$ 个参数，那么 $G_n$ 是：

$D\times M$

也就是一个大矩阵。

而伴随法算的是：

$\lambda_n$

它的维度只和状态变量数 $D$ 有关，通常是一个向量。

所以伴随法不需要为每个参数单独保存一大列状态灵敏度。

最后参数的影响通过：

$\left(\frac{\partial g}{\partial p}\right)_n$

一次性进入求和公式。

因此，当参数很多、目标函数较少时，伴随法特别合适。

---

# 11. 最直观的一句话

直接法是：

> 正着算：每个参数变化会怎样影响每个时间点的状态。

伴随法是：

> 倒着算：最终目标函数对每个时间点的“责任权重”是多少，然后再看每个参数在每个时间点对方程的影响。

所以伴随法把：

$\frac{dO}{dx_N}\frac{\partial x_N}{\partial p}$

改写成：

$-\sum_{n=0}^{N}\lambda_n\left(\frac{\partial g}{\partial p}\right)_n$

本质上就是用 $\lambda_n$ 把大矩阵 $\frac{\partial x}{\partial p}$ 消掉。
