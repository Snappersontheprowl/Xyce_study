最本质地说，**direct sensitivity 的目标就是把“参数变一点，解会怎么变”这件事，变成一个普通线性方程组来解**。

所以在这条式子里：

$$
J\frac{\partial x}{\partial p} = -\frac{\partial f}{\partial p}
$$

你真正要找的未知量其实只有一个：

$$
\frac{\partial x}{\partial p}
$$

也就是“解对参数的灵敏度”。

其余两项在进入这一步时，通常都已经是已知的：

- $J = \dfrac{\partial f}{\partial x}$：已知  
  因为它来自你已经求出来的名义解 `x*` 附近的 Jacobian
- $\dfrac{\partial f}{\partial p}$：已知  
  因为它表示“参数变化直接对方程造成的扰动”，在当前工作点也可以算出来
- $\dfrac{\partial x}{\partial p}$：未知  
  这正是要解的东西

所以它本质上就是：

```text
已知左端矩阵 J
已知右端向量 -∂f/∂p
求未知向量 ∂x/∂p
```

也就是最普通的线性系统：

$$
A s = b
$$

## 1. 为什么这条式子成立

先从原方程出发：

$$
f(x,p)=0
$$

这表示：在参数是 $p$ 时，解 $x$ 必须让残差为 0。

现在把参数改一点：

$$
p \to p + \Delta p
$$

那解也会跟着变：

$$
x \to x + \Delta x
$$

因为新的解仍然要满足方程，所以：

$$
f(x+\Delta x,\, p+\Delta p)=0
$$

对它做一阶线性化：

$$
f(x,p)
+
\frac{\partial f}{\partial x}\Delta x
+
\frac{\partial f}{\partial p}\Delta p
\approx 0
$$

而原来就有：

$$
f(x,p)=0
$$

所以剩下：

$$
\frac{\partial f}{\partial x}\Delta x
+
\frac{\partial f}{\partial p}\Delta p
\approx 0
$$

如果把 $\Delta x$ 看成由 $\Delta p$ 引起的响应，即

$$
\Delta x \approx \frac{\partial x}{\partial p}\Delta p
$$

代进去：

$$
\frac{\partial f}{\partial x}\frac{\partial x}{\partial p}\Delta p
+
\frac{\partial f}{\partial p}\Delta p
=0
$$

对任意小的 $\Delta p$ 成立，于是得到：

$$
J\frac{\partial x}{\partial p} = -\frac{\partial f}{\partial p}
$$

所以这条式子不是“突然来的公式”，而是：

> 原方程在名义解附近，对参数扰动做一阶线性化后的结果。


## 2. 到底哪些量是已知，哪些量是未知

我们先只看 **单个参数** $p_k$。

这时方程是：

$$
J\frac{\partial x}{\partial p_k} = -\frac{\partial f}{\partial p_k}
$$

这时：

### 已知量 1：名义解 $x^*$

你必须先把原问题解出来：

$$
f(x,p)=0
$$

得到当前参数下的名义解：

$$
x = x^*
$$

没有这个工作点，后面的 Jacobian 和参数导数都无从谈起。

### 已知量 2：Jacobian $J$

在工作点 $x^*$ 处计算：

$$
J = \left.\frac{\partial f}{\partial x}\right|_{x^*,p}
$$

这和 Newton 迭代里的 Jacobian 是同一个类型的对象。

### 已知量 3：右端项 $\dfrac{\partial f}{\partial p_k}$

在工作点处计算：

$$
\left.\frac{\partial f}{\partial p_k}\right|_{x^*,p}
$$

它表示：如果第 $k$ 个参数动一下，而解还没来得及动，残差会被直接推向哪个方向。

### 未知量：$\dfrac{\partial x}{\partial p_k}$

这是一个向量，表示所有解变量对参数 $p_k$ 的响应：

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

这才是要解出来的量。

## 3. 真正的求解步骤是什么

如果你把它当成算法，步骤其实很清楚。

### 第一步：先解原始电路

==其中 $f$ 表达式已知， $p$ 数值已知， $x$ 数值待求解==

$$
f(x,p)=0
$$

例如在 DC 下，就是先求 operating point。

得到：

$$
x^*
$$

### 第二步：在名义解处组装 Jacobian

计算：

$$
J = \left.\frac{\partial f}{\partial x}\right|_{x^*,p}
$$

这就是线性系统左端矩阵。
其中 ==$\frac{\partial f}{\partial x}$ 表达式已知==
### 第三步：选一个参数，构造右端项

比如你关心某个电阻值 $R$、某个 MOS 宽度 $W$、某个模型参数 $V_{th0}$，就计算：

$$
\frac{\partial f}{\partial p_k}
$$
其中 ==$\frac{\partial f}{\partial p}$ 表达式已知==
于是右端项就是：

$$
b_k = -\frac{\partial f}{\partial p_k}
$$

### 第四步：解线性系统

求解：

$$
J s_k = b_k
$$

其中

$$
s_k = \frac{\partial x}{\partial p_k}
$$

这一步做完后，你就得到了：

- 每个节点电压对参数 $p_k$ 的灵敏度
- 每个支路电流对参数 $p_k$ 的灵敏度
- 每个内部状态对参数 $p_k$ 的灵敏度

### 第五步：如果有多个参数，就重复右端项

如果参数有很多个：

$$
p_1, p_2, \dots, p_m
$$

那么就分别解：

$$
J\frac{\partial x}{\partial p_1} = -\frac{\partial f}{\partial p_1}
$$

$$
J\frac{\partial x}{\partial p_2} = -\frac{\partial f}{\partial p_2}
$$

$$
\vdots
$$

$$
J\frac{\partial x}{\partial p_m} = -\frac{\partial f}{\partial p_m}
$$

这里非常关键的一点是：

- 左边的 $J$ 是同一个
- 右边换成不同参数对应的扰动
- 所以通常可以 **复用同一个矩阵分解**

这也是 direct sensitivity 在工程上可行的原因之一。


## 4. 一个很直接的直觉

你可以把它想成：

- $\dfrac{\partial f}{\partial p_k}$：参数动一下，残差先“歪”了多少
- $J$：系统允许用哪些解变量联动来把残差纠回来
- $\dfrac{\partial x}{\partial p_k}$：最终为了把残差补回 0，解必须怎么改

所以 direct sensitivity 其实是在回答：

> 参数动了一点后，系统为了继续满足方程，需要把解往哪个方向挪、挪多少？

## 5. 为什么这叫 direct sensitivity

因为它是 **先求解的灵敏度**：

$$
\frac{\partial x}{\partial p}
$$

然后如果你还关心某个输出

$$
y=g(x,p)
$$

再通过链式法则得到：

$$
\frac{\partial y}{\partial p}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial g}{\partial p}
$$

所以它的顺序是：

1. 先求所有状态对参数的灵敏度
2. 再从状态映射到输出

这就是 “direct” 的含义。


# 非要手动差分法
这其实就是最直观的 **finite difference sensitivity** 思路。本质上你不去解

$$
J\frac{\partial x}{\partial p}=-\frac{\partial f}{\partial p}
$$

而是直接把参数改一点，重新跑仿真，然后用差分近似导数。

比如你关心某个输出 $y$ 对参数 $p$ 的灵敏度，就可以写成：

$$
\frac{dy}{dp}\approx \frac{y(p+\Delta p)-y(p)}{\Delta p}
$$

或者更常用、更稳一点的中心差分：

$$
\frac{dy}{dp}\approx \frac{y(p+\Delta p)-y(p-\Delta p)}{2\Delta p}
$$

如果你关心的是整个解向量 $x$，也是一样：

$$
\frac{\partial x}{\partial p}\approx \frac{x(p+\Delta p)-x(p)}{\Delta p}
$$

或者

$$
\frac{\partial x}{\partial p}\approx \frac{x(p+\Delta p)-x(p-\Delta p)}{2\Delta p}
$$

## 这件事本质上会发生什么

你相当于在做：

1. 先跑一次名义仿真，得到 $x(p)$ 或输出 $y(p)$
2. 把参数改成 $p+\Delta p$，再跑一次
3. 如果用中心差分，再跑一次 $p-\Delta p$
4. 用两个或三个仿真结果做差，近似导数

所以它不是“解灵敏度方程”，而是：

```text
拿多个完整仿真结果做数值近似
```

这非常容易理解，也很适合做概念验证。

---

## 它的优点

### 1. 最直观

你不用先搞懂 Jacobian、`∂f/∂p`、direct sensitivity、adjoint 这些对象。

只要会跑仿真，就能做。

### 2. 对黑盒系统也能用

如果你拿到的是一个不透明模型，内部没有提供解析导数，只能：

- 改参数
- 重跑
- 看输出变化

那差分法几乎是默认办法。

### 3. 很适合做结果校验

即使系统里已经实现了 direct sensitivity，工程上也经常会拿差分法做 sanity check。

比如：

- 解析灵敏度算出来是 `3.2e-4`
- 差分法估出来也是同量级

那你就更有信心了。


## 它的缺点

### 1. 计算量可能很大

如果你有 $m$ 个参数：

- 前向差分大约要 `1 + m` 次仿真
- 中心差分大约要 `1 + 2m` 次仿真

如果参数很多，代价会非常高。

而 direct sensitivity 通常是：

- 先有同一个 Jacobian
- 再换右端项解多个线性系统

在很多场景下会比“完整重跑仿真”便宜。

### 2. 步长 $\Delta p$ 很难选

这是差分法最烦的地方。

如果 $\Delta p$ 太大：

- 你测到的不再是局部导数
- 而是一个偏粗的非线性变化量

如果 $\Delta p$ 太小：

- 两次仿真结果太接近
- 数值舍入误差、收敛误差、噪声会被放大

所以你会遇到经典矛盾：

```text
步长大了，截断误差大
步长小了，数值误差大
```

### 3. 对不光滑点很敏感

如果模型里有：

- piecewise 切换
- limit/clamp
- 区域切换
- 收敛保护逻辑
- 条件分支

那参数微小变化可能导致系统切到不同分支。

这时你算出来的“差分导数”可能非常跳，甚至没有明确导数意义。

### 4. 对 transient / 周期问题更麻烦

如果输出是波形、周期稳态结果、噪声指标、HB 结果，差分法仍然能用，但要注意：

- 两次仿真必须可比
- 时间对齐可能有问题
- 周期可能轻微漂移
- 非线性系统的收敛路径可能不同

所以它不像 DC 标量输出那么干净。

---

## 和 direct sensitivity 的区别

### 差分法

你做的是：

$$
\frac{dy}{dp}\approx \frac{y(p+\Delta p)-y(p)}{\Delta p}
$$

特点是：

- 不需要解析导数
- 需要多次完整仿真
- 精度依赖步长选择

### direct sensitivity

你做的是：

$$
J\frac{\partial x}{\partial p}=-\frac{\partial f}{\partial p}
$$

然后再算

$$
\frac{dy}{dp}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial g}{\partial p}
$$

特点是：

- 需要系统能提供导数对象
- 只在线性化点附近求局部灵敏度
- 通常更高效、更“解析化”

所以可以把两者理解成：

- 差分法：用“多跑几次仿真”换取简单性
- direct sensitivity：用“更深的数学和代码实现”换取效率与结构化结果

---

## 如果你手动做人为仿真，会得到什么

分两种情况看。

### 1. 你关心单个输出

比如输出电压 `vout` 对电阻 `R` 的灵敏度：

$$
\frac{dv_{out}}{dR}\approx \frac{v_{out}(R+\Delta R)-v_{out}(R)}{\Delta R}
$$

这会直接给你一个数，单位比如是：

- `V/Ohm`
- `A/V`
- `V/m`

非常直观。

### 2. 你关心整个解向量

比如所有节点电压、支路电流都想看，那你实际上是在近似：

$$
\frac{\partial x}{\partial p}
\approx
\frac{x(p+\Delta p)-x(p)}{\Delta p}
$$

这样每个状态变量都会得到一个灵敏度值。

这和 direct sensitivity 求出来的对象本质上是同一种东西，只是来源不同：

- 一个来自解析线性化方程
- 一个来自数值差分近似

---

## 在模拟电路里什么时候适合先用差分法

很适合以下场景：

- 你刚开始学灵敏度，还没完全吃透数学形式
- 你只关心少数几个参数
- 你只关心少数几个输出
- 你想验证 direct / adjoint 的结果对不对
- 模型是黑盒，拿不到内部导数

如果是：

- 参数很多
- 输出很多
- 仿真本身很重
- 需要系统化灵敏度结果

那就更应该上 direct sensitivity 或 adjoint。

## 一个很实用的经验

如果你真要手动做，优先用 **中心差分**：

$$
\frac{dy}{dp}\approx \frac{y(p+\Delta p)-y(p-\Delta p)}{2\Delta p}
$$

因为它通常比前向差分

$$
\frac{y(p+\Delta p)-y(p)}{\Delta p}
$$

精度更好，偏差更小。

但代价是多跑一次仿真。

另外，步长通常不要直接随便拍脑袋。更稳妥的是用相对扰动，比如：

$$
\Delta p = \epsilon \cdot \max(|p|,1)
$$

其中 $\epsilon$ 取一个比较小但不过分小的量。这样比固定绝对步长更稳一些。
