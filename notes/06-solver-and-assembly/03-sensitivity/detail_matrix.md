先把这条式子放回它的原始背景里看：

$$
f(x,p)=0
$$

这里：

- $x \in \mathbb{R}^n$ 是电路解向量，比如节点电压、支路电流、内部状态
- $p \in \mathbb{R}^m$ 是参数向量，比如电阻值、器件尺寸、模型参数、源幅度
- $f:\mathbb{R}^n \times \mathbb{R}^m \to \mathbb{R}^n$ 是残差方程

对参数求导后得到：

$$
\frac{\partial f}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial f}{\partial p}
=0
$$

这条式子表示：当参数 $p$ 发生微小变化时，解 $x$ 也必须随之变化，才能继续让残差保持为 0。

---

## 1. 用一般维度来写

设

$$
x=
\begin{bmatrix}
x_1\\
x_2\\
\vdots\\
x_n
\end{bmatrix},
\qquad
p=
\begin{bmatrix}
p_1\\
p_2\\
\vdots\\
p_m
\end{bmatrix},
\qquad
f(x,p)=
\begin{bmatrix}
f_1(x,p)\\
f_2(x,p)\\
\vdots\\
f_n(x,p)
\end{bmatrix}
=
\begin{bmatrix}
0\\
0\\
\vdots\\
0
\end{bmatrix}
$$

这里：

- 未知量个数是 $n$
- 参数个数是 $m$
- 方程个数也是 $n$

所以这是一个“$n$ 个方程、$n$ 个未知量、$m$ 个参数”的标准灵敏度问题。

---

## 2. 各个导数对象的矩阵形式

### 2.1 对未知量的 Jacobian

$$
\frac{\partial f}{\partial x}
=
\begin{bmatrix}
\frac{\partial f_1}{\partial x_1} & \frac{\partial f_1}{\partial x_2} & \cdots & \frac{\partial f_1}{\partial x_n}\\
\frac{\partial f_2}{\partial x_1} & \frac{\partial f_2}{\partial x_2} & \cdots & \frac{\partial f_2}{\partial x_n}\\
\vdots & \vdots & \ddots & \vdots\\
\frac{\partial f_n}{\partial x_1} & \frac{\partial f_n}{\partial x_2} & \cdots & \frac{\partial f_n}{\partial x_n}
\end{bmatrix}
\in \mathbb{R}^{n\times n}
$$

这就是系统 Jacobian，也就是当前工作点上，残差方程对解向量的线性化。

### 2.2 解对参数的敏感度矩阵

$$
\frac{\partial x}{\partial p}
=
\begin{bmatrix}
\frac{\partial x_1}{\partial p_1} & \frac{\partial x_1}{\partial p_2} & \cdots & \frac{\partial x_1}{\partial p_m}\\
\frac{\partial x_2}{\partial p_1} & \frac{\partial x_2}{\partial p_2} & \cdots & \frac{\partial x_2}{\partial p_m}\\
\vdots & \vdots & \ddots & \vdots\\
\frac{\partial x_n}{\partial p_1} & \frac{\partial x_n}{\partial p_2} & \cdots & \frac{\partial x_n}{\partial p_m}
\end{bmatrix}
\in \mathbb{R}^{n\times m}
$$

它的第 $k$ 列表示：

$$
\frac{\partial x}{\partial p_k}
=
\begin{bmatrix}
\frac{\partial x_1}{\partial p_k}\\
\frac{\partial x_2}{\partial p_k}\\
\vdots\\
\frac{\partial x_n}{\partial p_k}
\end{bmatrix}
$$

也就是“当第 $k$ 个参数变化时，整个解向量如何响应”。

### 2.3 方程对参数的显式导数

$$
\frac{\partial f}{\partial p}
=
\begin{bmatrix}
\frac{\partial f_1}{\partial p_1} & \frac{\partial f_1}{\partial p_2} & \cdots & \frac{\partial f_1}{\partial p_m}\\
\frac{\partial f_2}{\partial p_1} & \frac{\partial f_2}{\partial p_2} & \cdots & \frac{\partial f_2}{\partial p_m}\\
\vdots & \vdots & \ddots & \vdots\\
\frac{\partial f_n}{\partial p_1} & \frac{\partial f_n}{\partial p_2} & \cdots & \frac{\partial f_n}{\partial p_m}
\end{bmatrix}
\in \mathbb{R}^{n\times m}
$$

它的第 $k$ 列表示：

$$
\frac{\partial f}{\partial p_k}
=
\begin{bmatrix}
\frac{\partial f_1}{\partial p_k}\\
\frac{\partial f_2}{\partial p_k}\\
\vdots\\
\frac{\partial f_n}{\partial p_k}
\end{bmatrix}
$$

也就是“如果只动第 $k$ 个参数，而暂时不让解 $x$ 跟着调整，残差会被直接推向哪个方向”。

---

## 3. 把矩阵乘法完全展开

原式

$$
\frac{\partial f}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial f}{\partial p}
=0
$$

可以写成

$$
\begin{bmatrix}
\frac{\partial f_1}{\partial x_1} & \frac{\partial f_1}{\partial x_2} & \cdots & \frac{\partial f_1}{\partial x_n}\\
\frac{\partial f_2}{\partial x_1} & \frac{\partial f_2}{\partial x_2} & \cdots & \frac{\partial f_2}{\partial x_n}\\
\vdots & \vdots & \ddots & \vdots\\
\frac{\partial f_n}{\partial x_1} & \frac{\partial f_n}{\partial x_2} & \cdots & \frac{\partial f_n}{\partial x_n}
\end{bmatrix}
\begin{bmatrix}
\frac{\partial x_1}{\partial p_1} & \frac{\partial x_1}{\partial p_2} & \cdots & \frac{\partial x_1}{\partial p_m}\\
\frac{\partial x_2}{\partial p_1} & \frac{\partial x_2}{\partial p_2} & \cdots & \frac{\partial x_2}{\partial p_m}\\
\vdots & \vdots & \ddots & \vdots\\
\frac{\partial x_n}{\partial p_1} & \frac{\partial x_n}{\partial p_2} & \cdots & \frac{\partial x_n}{\partial p_m}
\end{bmatrix}
+
\begin{bmatrix}
\frac{\partial f_1}{\partial p_1} & \frac{\partial f_1}{\partial p_2} & \cdots & \frac{\partial f_1}{\partial p_m}\\
\frac{\partial f_2}{\partial p_1} & \frac{\partial f_2}{\partial p_2} & \cdots & \frac{\partial f_2}{\partial p_m}\\
\vdots & \vdots & \ddots & \vdots\\
\frac{\partial f_n}{\partial p_1} & \frac{\partial f_n}{\partial p_2} & \cdots & \frac{\partial f_n}{\partial p_m}
\end{bmatrix}
=0
$$

其中第 $(i,k)$ 个元素满足：

$$
\sum_{j=1}^{n}
\frac{\partial f_i}{\partial x_j}
\frac{\partial x_j}{\partial p_k}
+
\frac{\partial f_i}{\partial p_k}
=0
\qquad
(i=1,\dots,n;\;k=1,\dots,m)
$$

这就是最一般的逐元素形式。

你也可以把它理解成：

- 行索引 $i$ 对应第 $i$ 条方程
- 列索引 $k$ 对应第 $k$ 个参数
- 求和索引 $j$ 遍历所有未知量

所以对于每个参数 $p_k$，都要回答一个问题：

> 为了让所有方程继续成立，整个解向量 $x$ 应该如何联动变化？

---

## 4. 写成标准线性系统

把它整理一下：

$$
\frac{\partial f}{\partial x}\frac{\partial x}{\partial p}
=
-
\frac{\partial f}{\partial p}
$$

记号上通常写成：

$$
J S = -F_p
$$

其中：

- $J = \dfrac{\partial f}{\partial x} \in \mathbb{R}^{n\times n}$
- $S = \dfrac{\partial x}{\partial p} \in \mathbb{R}^{n\times m}$
- $F_p = \dfrac{\partial f}{\partial p} \in \mathbb{R}^{n\times m}$

这说明灵敏度分析的核心不是重新建立一套全新的非线性方程，而是：

1. 复用原问题在线性化后的 Jacobian $J$
2. 为每个参数方向构造右端项 $-\dfrac{\partial f}{\partial p_k}$
3. 解出对应的敏感度列向量 $\dfrac{\partial x}{\partial p_k}$

如果 $J$ 可逆，那么形式上有：

$$
S
=
\frac{\partial x}{\partial p}
=
-
\left(\frac{\partial f}{\partial x}\right)^{-1}
\frac{\partial f}{\partial p}
$$

不过在实际数值求解里，通常不是显式求逆，而是解线性系统。

---

## 5. 按列看会更直观

由于

$$
S=
\begin{bmatrix}
\frac{\partial x}{\partial p_1} &
\frac{\partial x}{\partial p_2} &
\cdots &
\frac{\partial x}{\partial p_m}
\end{bmatrix},
\qquad
F_p=
\begin{bmatrix}
\frac{\partial f}{\partial p_1} &
\frac{\partial f}{\partial p_2} &
\cdots &
\frac{\partial f}{\partial p_m}
\end{bmatrix}
$$

所以

$$
J S = -F_p
$$

等价于并排放在一起的 $m$ 个线性系统：

$$
J\frac{\partial x}{\partial p_1}
=
-\frac{\partial f}{\partial p_1}
$$

$$
J\frac{\partial x}{\partial p_2}
=
-\frac{\partial f}{\partial p_2}
$$

$$
\vdots
$$

$$
J\frac{\partial x}{\partial p_m}
=
-\frac{\partial f}{\partial p_m}
$$

这很重要，因为它直接说明：

- 参数有多少个，就有多少列敏感度要解
- 左边的 Jacobian $J$ 是同一个
- 右边只是在换不同参数对应的显式扰动列

这正是 direct sensitivity 的基本计算结构。

---

## 6. 放回电路语境里怎么理解

在电路里，

$$
f(x,p)=0
$$

表示“在当前分析类型下，电路方程被满足”。

例如在 `DC` 下，常可以抽象成：

$$
f(x,p)=F(x,p)-B(p)=0
$$

在 `transient` 下，更一般是：

$$
f(x,p)=\frac{dQ(x,p)}{dt}+F(x,p)-B(t,p)=0
$$

这时：

- $\dfrac{\partial f}{\partial x}$ 表示电路方程对解向量的线性化
- $\dfrac{\partial f}{\partial p}$ 表示参数变化对残差的直接注入
- $\dfrac{\partial x}{\partial p}$ 表示为了把残差重新拉回 0，解变量必须如何响应

所以灵敏度方程可以直觉地理解为：

> 参数先把残差推偏了一下，系统再通过解变量的联动变化，把残差补回到 0。

---

## 7. 再连到观测量

如果观测量写成

$$
y=g(x,p)
$$

更一般地，如果有多个观测量，也可以写成

$$
y \in \mathbb{R}^q,
\qquad
y=g(x,p)
$$

那么：

$$
\frac{\partial y}{\partial p}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial g}{\partial p}
$$

这里各个对象的维度是：

- $\dfrac{\partial g}{\partial x} \in \mathbb{R}^{q\times n}$
- $\dfrac{\partial x}{\partial p} \in \mathbb{R}^{n\times m}$
- $\dfrac{\partial g}{\partial p} \in \mathbb{R}^{q\times m}$
- $\dfrac{\partial y}{\partial p} \in \mathbb{R}^{q\times m}$

把它按元素展开，第 $(\ell,k)$ 个元素满足：

$$
\frac{\partial y_\ell}{\partial p_k}
=
\sum_{j=1}^{n}
\frac{\partial g_\ell}{\partial x_j}
\frac{\partial x_j}{\partial p_k}
+
\frac{\partial g_\ell}{\partial p_k}
\qquad
(\ell=1,\dots,q;\;k=1,\dots,m)
$$

这说明：

- 如果你关心的是“解对参数的敏感度”，核心对象是 $S=\dfrac{\partial x}{\partial p}$
- 如果你关心的是“观测量对参数的敏感度”，还要再经过一次输出映射 $\dfrac{\partial g}{\partial x}$

---

## 8. 一句话收束

你写的公式在一般矩阵层面，本质就是：

$$
J S = -F_p
$$

其中：

- $J = \dfrac{\partial f}{\partial x}$：系统 Jacobian
- $S = \dfrac{\partial x}{\partial p}$：解对参数的敏感度矩阵
- $F_p = \dfrac{\partial f}{\partial p}$：参数对残差的直接扰动矩阵

它把“参数变化带来的残差偏移”，转换成“解变量必须怎样联动变化，才能继续满足电路方程”。
