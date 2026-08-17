## 关于真解处的 Jacobian 要可逆

设非线性方程组为

$$
f(x)=0
$$

Newton 法在第 $k$ 次迭代时，会把 $f(x)$ 在当前位置 $x_k$ 附近进行一阶线性化：

$$
f(x_k+\Delta x)
\approx
f(x_k)+J(x_k)\Delta x
$$

为了让下一步尽量满足 $f(x_{k+1})=0$，令

$$
f(x_k)+J(x_k)\Delta x=0
$$

于是需要求解 Newton 方程：

$$
J(x_k)\Delta x=-f(x_k)
$$

然后更新：

$$
x_{k+1}=x_k+\Delta x
$$

因此，Newton 法能否稳定工作，很大程度上取决于 Jacobian 矩阵 $J(x_k)$ 是否可逆。



### 一、什么叫 Jacobian 奇异

对于一个方阵 $J$，如果它不存在逆矩阵，也就是：$J^{-1}$ 不存在，那么就称它为**奇异矩阵**。



对于方阵，下面几个条件是等价的：

$$
J \text{ 奇异}
$$

$$
\Longleftrightarrow
\det(J)=0
$$

$$
\Longleftrightarrow
\operatorname{rank}(J)<n
$$

$$
\Longleftrightarrow
\exists v\neq 0,\quad Jv=0
$$

最后一个表达最有直观意义：

$$
\exists v\neq0,\quad Jv=0
$$

它表示：变量明明沿着非零方向 $v$ 发生了变化，但经过 Jacobian 的线性映射之后，函数值却没有任何一阶变化。换句话说，Jacobian 把方向 $v$ “压扁”成了零。


### 二、Jacobian 在 Newton 法中表示什么

假设

$$
x=
\begin{bmatrix}
x_1
\\
x_2
\end{bmatrix},
\qquad
f(x)=
\begin{bmatrix}
f_1(x_1,x_2)
\\
f_2(x_1,x_2)
\end{bmatrix}
$$

那么 Jacobian 为

$$
J(x)=
\begin{bmatrix}
\dfrac{\partial f_1}{\partial x_1}
&
\dfrac{\partial f_1}{\partial x_2}
\\[6pt]
\dfrac{\partial f_2}{\partial x_1}
&
\dfrac{\partial f_2}{\partial x_2}
\end{bmatrix}
$$

它描述了变量发生小变化 $\Delta x$ 时，函数值大约会发生怎样的变化：

$$
\Delta f\approx J(x)\Delta x
$$

Newton 法要做的是反过来：

> 已知希望函数值变化多少，反推出变量应该变化多少。

即求解：

$$
J(x_k)\Delta x=-f(x_k)
$$

如果 $J(x_k)$ 可逆，就可以形式上写成：

$$
\Delta x=-J(x_k)^{-1}f(x_k)
$$

但如果 $J(x_k)$ 奇异，变量变化与函数变化之间就无法进行唯一反推。


### 三、一个简单的奇异矩阵例子

考虑矩阵

$$
J=
\begin{bmatrix}
1 & 1 
\\
2 & 2
\end{bmatrix}
$$

它的第二行是第一行的两倍，因此两行提供的是重复信息。

它的行列式为0, 所以 $J$ 是奇异矩阵。

取非零向量

$$
v=
\begin{bmatrix}
1 
\\
-1
\end{bmatrix}
$$

有

$$
Jv
=

\begin{bmatrix}
1 & 1 
\\
2 & 2
\end{bmatrix}
\begin{bmatrix}
1 
\\
-1
\end{bmatrix}
=

\begin{bmatrix}
0 
\\
0
\end{bmatrix}
$$

这意味着，沿着方向

$$
\Delta x=
\begin{bmatrix}
1 
\\
-1
\end{bmatrix}
$$

移动时，线性模型认为函数值完全不变。

因此，只观察函数值的一阶变化，无法判断变量沿这个方向移动了多少。换句话说，Jacobian 丢失了方向
$
\begin{bmatrix}
1 
\\
-1
\end{bmatrix}
$上的信息，这正是矩阵奇异的一种直观表现。


有关矩阵更深入的思考，可以查看三蓝一棕的视频讲解。
这里大致认知如下：
n 维方阵A 是对n 维空间进行线性变换的一种算子，处于n 维空间中的向量 x 会跟随此变化变成x'， 
当一种变换矩阵将原空间压缩到了更低的维度中，x也将被压缩为更低维的向量x' 。 此时不存在一种逆变换将 x' 变换回 x
更直观地来说，某些维度被压缩到0意味着这些维度上的分量被置零的速度都是一样的，不管是0.001 还是 1000000 ，而这种一视同仁的置零速度导致在还原的时候根本无法将原来的不同向量加以区分。

### 四、奇异为什么会使 Newton 步不唯一

Newton 法需要解：

$$
J\Delta x=-f
$$

假设 $\Delta x_0$ 是其中一个解，并且存在非零向量 $v$ 满足

$$
Jv=0
$$

那么对于任意常数 $t$，都有

$$
J(\Delta x_0+tv)
=

J\Delta x_0+tJv
$$

由于

$$
Jv=0
$$

所以

$$
J(\Delta x_0+tv)
=
J\Delta x_0
=
-f
$$

这说明：$\Delta x_0+tv$ 全部都是 Newton 方程的解。于是 Newton 步不再唯一。

算法不知道应该选择：

$$
\Delta x_0
$$

还是

$$
\Delta x_0+100v
$$

或者

$$
\Delta x_0-1000v
$$

这些方向在线性方程看来都是一样的。

### 五、奇异时也可能根本没有 Newton 步

奇异矩阵不能覆盖整个输出空间。

仍然考虑

$$
J=
\begin{bmatrix}
1&1
\\
2&2
\end{bmatrix}
$$

对于任意

$$
\Delta x=
\begin{bmatrix}
a\
b
\end{bmatrix}
$$

都有

$$
J\Delta x
=
\begin{bmatrix}
a+b
\\
2a+2b
\end{bmatrix}
$$

因此输出的第二个分量永远是第一个分量的两倍。

如果 Newton 方程右端是

$$
-f=
\begin{bmatrix}
1\
3
\end{bmatrix}
$$

那么方程就不可能有解，因为 $3$ 不是 $1$ 的两倍。

所以当 Jacobian 奇异时，Newton 方程可能出现两种情况：

1. 没有解；
2. 有无穷多个解。

但不会有唯一解。



### 六、什么叫“接近奇异”

实际数值计算中，更常见的情况不是 Jacobian 完全奇异，而是**接近奇异**。

例如：

$$
J=
\begin{bmatrix}
1&1
\\
1&1+\varepsilon
\end{bmatrix}
$$

其中 $\varepsilon$ 是一个很小的正数。

它的行列式为

$$
\det(J)
=
1(1+\varepsilon)-1
=
\varepsilon
$$

只要$\varepsilon\neq0$, 矩阵在数学上就是可逆的。

其逆矩阵为

$$
J^{-1}
=
\frac{1}{\varepsilon}
\begin{bmatrix}
1+\varepsilon&-1
\\
-1&1
\end{bmatrix}
$$

关键在于其中出现了
$$
\frac{1}{\varepsilon}
$$

如果

$$
\varepsilon=10^{-8}
$$

那么

$$
\frac{1}{\varepsilon}=10^8
$$

这意味着逆矩阵会把某些微小误差放大约 $10^8$ 倍。

因此，虽然这个矩阵在数学上可逆，但在计算机中已经非常不稳定。

### 七、为什么接近奇异会放大误差

考虑线性方程

$$
J\Delta x=b
$$

其中

$$
J=
\begin{bmatrix}
1&1
\\
1&1+\varepsilon
\end{bmatrix}
$$

设右端为

$$
b=
\begin{bmatrix}
1
\\
1+\delta
\end{bmatrix}
$$

对应方程组为

$$
\Delta x_1+\Delta x_2=1
$$

$$
\Delta x_1+(1+\varepsilon)\Delta x_2=1+\delta
$$

第二个方程减去第一个方程，得到

$$
\varepsilon\Delta x_2=\delta
$$

因此

$$
\Delta x_2=\frac{\delta}{\varepsilon}
$$

如果右端只有很小的扰动

$$
\delta=10^{-6}
$$

但矩阵接近奇异，满足

$$
\varepsilon=10^{-8}
$$

那么

$$
\Delta x_2
=
\frac{10^{-6}}{10^{-8}}
=
100
$$

函数值中只有 $10^{-6}$ 量级的微小变化，却导致变量修正量发生 $100$ 量级的变化。

这就是接近奇异导致不稳定的核心：

$$
\boxed{
\text{很小的函数误差}
\Longrightarrow
\text{很大的变量误差}
}
$$

在 Newton 法中，计算误差、舍入误差以及函数评估误差，都可能被放大为很大的 Newton 步。



### 八、几何上为什么说“切平面塌了”

考虑二维非线性方程组：

$$
\begin{cases}
f_1(x,y)=0
\\
f_2(x,y)=0
\end{cases}
$$

两个方程分别对应两条曲线。

在解点附近，Newton 法使用两条曲线的切线来近似原曲线，然后把两条切线的交点作为下一次迭代位置。

#### 正常情况：两条曲线横向相交

如果两条曲线在解点以明显不同的方向相交，那么它们的切线也有唯一交点。

对应地，两个梯度方向不同：

$$
\nabla f_1(x^*)\not\parallel \nabla f_2(x^*)
$$

此时 Jacobian 的两行线性无关，因此 Jacobian 可逆。

Newton 法可以从两条切线的交点确定下一步的位置。

#### 奇异情况：两条曲线相切

如果两条曲线在解点相切，那么它们的切线重合。

对应地：

$$
\nabla f_1(x^*)\parallel\nabla f_2(x^*)
$$

Jacobian 的两行线性相关，因此 Jacobian 奇异。

此时两条切线不再给出唯一交点，而是重合成同一条直线。仅靠一阶信息无法确定解在切线上的哪个位置。

这就是所谓的“切平面塌了”：

> 原本应该提供多个独立方向约束的切平面，退化成了较低维度的对象。



### 九、一个曲线相切的例子

考虑

$$
f_1(x,y)=y
$$

以及

$$
f_2(x,y)=y-x^2
$$

要求解

$$
\begin{cases}
y=0\
y-x^2=0
\end{cases}
$$

真解是

$$
(x^*,y^*)=(0,0)
$$

Jacobian 为

$$
J(x,y)
=

\begin{bmatrix}
0&1
\\
-2x&1
\end{bmatrix}
$$

在真解处：

$$
J(0,0)
=

\begin{bmatrix}
0&1
\\
0&1
\end{bmatrix}
$$

两行相同，所以

$$
\det J(0,0)=0
$$

Jacobian 是奇异的。

从几何上看，两个方程对应：

$$
y=0
$$

以及

$$
y=x^2
$$

直线 $y=0$ 与抛物线 $y=x^2$ 在原点相切。

在原点附近，把抛物线做一阶线性化：

$$
y=x^2\approx0
$$

于是两个方程的一阶近似都变成

$$
y=0
$$

一阶模型完全失去了关于 $x$ 的约束。

真实方程之所以能确定 $x=0$，依靠的是二阶项 $x^2$，但标准 Newton 法主要利用一阶 Jacobian，所以在这里会遇到困难。



### 十、一维情况下，奇异就是导数为零

对于一维方程

$$
f(x)=0
$$

Newton 迭代为

$$
x_{k+1}
=
x_k-\frac{f(x_k)}{f'(x_k)}
$$

此时 Jacobian 就是导数：

$$
J(x)=f'(x)
$$

如果真解处满足

$$
f'(x^*)=0
$$

那么 Jacobian 就是奇异的。

由于 Newton 公式需要除以 $f'(x_k)$，当导数非常小时：

$$
\frac{1}{f'(x_k)}
$$

会非常大，因此很小的函数误差也可能产生很大的 Newton 步。



### 十一、奇异不一定让 Newton 法完全无法收敛

例如：

$$
f(x)=x^2
$$

真解为

$$
x^*=0
$$

但

$$
f'(0)=0
$$

Newton 迭代为

$$
x_{k+1}
=
x_k-\frac{x_k^2}{2x_k}
$$

因此

$$
x_{k+1}=\frac{x_k}{2}
$$

它仍然收敛到零，但误差满足

$$
|e_{k+1}|
=
\frac{1}{2}|e_k|
$$

这只是线性收敛。

而对于 Jacobian 非奇异的普通简单根，Newton 法通常具有二次收敛：

$$
|e_{k+1}|
\approx
C|e_k|^2
$$

二次收敛远快于线性收敛。

因此，真解处 Jacobian 奇异，可能不会让 Newton 法完全失败，但通常会破坏 Newton 法原本的快速收敛性质。



### 十二、用奇异值理解最准确

矩阵可以进行奇异值分解：

$$
J=U\Sigma V^{\mathsf T}
$$

其中

$$
\Sigma
=
\operatorname{diag}
\left(
\sigma_1,\sigma_2,\ldots,\sigma_n
\right)
$$

并且

$$
\sigma_1\geq\sigma_2\geq\cdots\geq\sigma_n\geq0
$$

这些 $\sigma_i$ 称为奇异值。

如果最小奇异值满足

$$
\sigma_{\min}=0
$$

那么 $J$ 是奇异矩阵。

如果

$$
\sigma_{\min}\approx0
$$

那么 $J$ 接近奇异。

假设 $v_{\min}$ 是最小奇异值对应的方向，则

$$
|Jv_{\min}|
=
\sigma_{\min}|v_{\min}|
$$

当 $\sigma_{\min}$ 很小时，即使变量沿 $v_{\min}$ 方向变化很大，函数值也只发生很小的变化。

也就是说，函数对这个变量方向非常不敏感。

但 Newton 法要进行反向求解，因此这个方向上的修正量大约需要除以 $\sigma_{\min}$：

$$
\Delta x_{\min}
\sim
\frac{1}{\sigma_{\min}}
$$

当 $\sigma_{\min}$ 很小时，Newton 步就可能非常大。



### 十三、条件数衡量接近奇异的程度

判断矩阵是否接近奇异，通常使用条件数：

$$
\kappa(J)
=
|J||J^{-1}|
$$

在二范数下：

$$
\kappa_2(J)
=
\frac{\sigma_{\max}}{\sigma_{\min}}
$$

如果

$$
\kappa(J)\approx1
$$

说明矩阵条件较好，对误差不敏感。

如果

$$
\kappa(J)\gg1
$$

说明矩阵接近奇异，对误差十分敏感。

如果

$$
\kappa(J)=\infty
$$

说明矩阵完全奇异。

例如：

$$
\kappa(J)=10^8
$$

意味着输入中的相对误差，在最坏情况下可能被放大约 $10^8$ 倍。

因此，实际数值计算中，不能只检查

$$
\det(J)=0
$$

因为行列式不等于零，只能说明矩阵在精确数学意义上可逆，不能说明它在浮点计算中稳定。

通常更应关注：

$$
\sigma_{\min}(J)
$$

以及

$$
\kappa(J)
$$



### 十四、与电路仿真的关系

在电路仿真中，Newton 法通常求解：

$$
F(x)=0
$$

其中 $x$ 可能包含：

* 节点电压；
* 支路电流；
* 器件内部状态变量。

Jacobian 描述这些变量变化对 KCL、KVL 和器件方程残差的影响。

如果 Jacobian 奇异，通常意味着系统中存在某种约束缺失或约束重复。例如：

* 节点缺少直流参考路径；
* 理想电压源形成闭环；
* 理想电流源形成割集；
* 某些器件在当前工作区间导数接近零；
* 多个方程实际上描述了相同约束；
* 不同变量之间存在严重尺度差异。

这时 Newton 法无法稳定地从残差反推出电压和电流应该如何修正。



### 十五、最核心的理解

Jacobian 奇异的本质不是简单地“行列式等于零”，而是：

$$
\boxed{
\text{局部的一阶模型丢失了某些变量方向的信息}
}
$$

某个非零方向 $v$ 满足

$$
Jv=0
$$

意味着变量沿这个方向变化时，函数在线性近似下不发生变化。

因此，在 Newton 方程

$$
J\Delta x=-f
$$

中会出现三类问题：

1. Newton 步可能不存在；
2. Newton 步可能不唯一；
3. 接近奇异时，微小误差可能被放大成巨大的 Newton 步。

所以，“切平面塌了”可以更准确地理解为：

> Jacobian 把某些变量方向压缩到了零，或者几乎压缩到了零。正向映射时，这些方向的变化几乎看不出来；反向求解时，则必须被无限放大或大幅放大，因此 Newton 法变得不稳定。
