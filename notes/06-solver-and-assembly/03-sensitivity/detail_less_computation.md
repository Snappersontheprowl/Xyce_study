**adjoint 通常不去显式求整块 $\partial x / \partial p$，而是只求“当前关心输出所需要的那一部分投影”**。这就是它省计算的根本原因。

最核心的结论先放前面：

```text
direct:
先求每个参数引起的整个状态向量变化 ∂x/∂p

adjoint:
不先求整个 ∂x/∂p
而是先求一个和“输出 y”相关的伴随向量 λ
再直接得到 dy/dp
```

所以如果你关心的是：

- 参数很多
- 输出很少，往往只有 1 个或几个

那么 adjoint 会明显更省。


## 1. 先把 direct 方法回顾清楚

原方程：

$$
f(x,p)=0
$$

对参数求导：

$$
J \frac{\partial x}{\partial p} = -\frac{\partial f}{\partial p}
$$

其中：

$$
J=\frac{\partial f}{\partial x}
$$

如果观测量是：

$$
y=g(x,p)
$$

那么：

$$
\frac{dy}{dp}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial g}{\partial p}
$$

### direct 在做什么

假设：

- 状态变量 `x` 有 `n` 个
- 参数 `p` 有 `m` 个
- 输出 `y` 有 `q` 个

那么 direct 要先求：

$$
\frac{\partial x}{\partial p} \in \mathbb{R}^{n\times m}
$$

也就是一整块敏感度矩阵。

按列看，就是要对每个参数 `p_k` 解一次：

$$
J \frac{\partial x}{\partial p_k}
=
-\frac{\partial f}{\partial p_k}
$$

一共要解 `m` 次线性系统。

所以 direct 的成本大致是：

- 1 个 Jacobian
- `m` 个右端项
- 解 `m` 次线性系统

---

## 2. 你关心的其实往往不是整个 `∂x/∂p`

这是理解 adjoint 的关键。

很多时候你最终想要的不是：

$$
\frac{\partial x}{\partial p}
$$

而是某个输出对参数的敏感度：

$$
\frac{dy}{dp}
$$

比如：

- 输出节点电压对某些器件参数的敏感度
- 增益对某些模型参数的敏感度
- 延时对尺寸参数的敏感度
- 某个噪声指标对参数的敏感度

也就是说，你最后要的是一个 **标量或少量输出**，而不是整块状态敏感度矩阵。

这时如果还先把整块 $\partial x / \partial p$ 都算出来，其实有点“算多了”。


## 3. adjoint 怎么把问题改写掉

先看单个标量输出：

$$
y=g(x,p)
$$

那么：

$$
\frac{dy}{dp}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial g}{\partial p}
$$

这里麻烦的地方就在：

$$
\frac{\partial x}{\partial p}
$$

因为 direct 需要先把它求出来。

现在利用灵敏度方程：

$$
J \frac{\partial x}{\partial p}
=
-\frac{\partial f}{\partial p}
$$

我们不直接解 `∂x/∂p`，而是引入一个伴随向量 `\lambda`，满足：

$$
J^T \lambda
=
\left(\frac{\partial g}{\partial x}\right)^T
$$

这就是 adjoint 方程。

然后有：

$$
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
=
\lambda^T J \frac{\partial x}{\partial p}
$$

再代入

$$
J \frac{\partial x}{\partial p}
=
-\frac{\partial f}{\partial p}
$$

得到：

$$
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
=
-\lambda^T \frac{\partial f}{\partial p}
$$

所以最终：

$$
\frac{dy}{dp}
=
-\lambda^T \frac{\partial f}{\partial p}
+
\frac{\partial g}{\partial p}
$$

注意看，这里已经 **没有显式求 $\partial x / \partial p$ 了**。


## 4. 所以它到底省在哪里

省在这里：

### direct 的路径

如果有 `m` 个参数，要算一个输出 `y` 对所有参数的敏感度：

1. 对每个参数 `p_k` 解一次
   $$
   J \frac{\partial x}{\partial p_k} = -\frac{\partial f}{\partial p_k}
   $$
2. 一共解 `m` 次

3. 再把每列代入

   $$
   \frac{dy}{dp_k}
   =
   \frac{\partial g}{\partial x}\frac{\partial x}{\partial p_k}
   +
   \frac{\partial g}{\partial p_k}
   $$


### adjoint 的路径

1. 先解一次伴随方程

   $$
   J^T \lambda
   =
   \left(\frac{\partial g}{\partial x}\right)^T
   $$

2. 然后对每个参数只做一次内积

   $$
   \frac{dy}{dp_k}
   =
   -\lambda^T \frac{\partial f}{\partial p_k}
   +
   \frac{\partial g}{\partial p_k}
   $$

所以：

- direct：解 `m` 次线性系统
- adjoint：只解 `1` 次线性系统，再做 `m` 次便宜很多的向量运算

这就是为什么当 **参数很多、输出很少** 时，adjoint 成本更低。



## 6. 你说“不是还是涉及 x 灵敏度吗”是对的，但方式不同

你这个疑问很关键，因为它抓住了本质：

> 输出敏感度明明还是通过状态变化传过去的，为什么就省了？

答案是：

- **物理上**，当然还是通过 `x` 的变化传递
- **数学上**，adjoint 把“先求完整 `\partial x / \partial p` 再投影到输出”改写成了“先求输出对应的伴随向量，再直接投影到参数扰动”

也就是说，adjoint 不是否认 `x` 的作用，而是 **避免显式构造整个 `\partial x / \partial p`**。

你可以把它理解成：

- direct：先算出“每个参数让所有状态怎么变”
- adjoint：先算出“哪些状态变化会真正影响当前输出”
- 然后只沿着这个输出关心的方向去回收敏感度信息

所以 adjoint 其实是一种“只算必要投影，不算整块中间量”的方法。

---

## 7. 一个线性代数角度的类比

假设你真正想要的是：

$$
c^T s
$$

其中：

- `s` 是某个很大的未知向量
- `s` 满足
  $$
  J s = b
  $$

### 直接做法

1. 先解出 `s = J^{-1} b`
2. 再算 `c^T s`

### adjoint 做法

1. 先解
   $$
   J^T \lambda = c
   $$
2. 再算
   $$
   c^T s = \lambda^T b
   $$

这两个结果是一样的，但第二种避免了反复求很多个 `s`。

灵敏度里的事情本质上就是这个套路。

---

## 8. 什么时候 adjoint 不省，甚至不合适

这也很重要。

如果你关心的是：

- 整个解向量 `x` 对参数的敏感度
- 或者输出很多，接近状态维度那么多

那 adjoint 的优势就会减弱。

因为 adjoint 是 **按输出数 `q` 计成本** 的：

- 每个输出通常要解一次伴随方程

所以：

- direct 更适合：参数少、输出多，或者你确实要整块 `∂x/∂p`
- adjoint 更适合：参数多、输出少

这两个方法不是谁绝对更强，而是适用方向不同。

---

## 9. 一句话把 direct 和 adjoint 对比死

设：

- 参数数 = `m`
- 输出数 = `q`

那么大致成本结构是：

- direct：解 `m` 次线性系统
- adjoint：解 `q` 次线性系统

所以：

- 如果 `m << q`，direct 往往更合适
- 如果 `q << m`，adjoint 往往更合适

而在很多电路优化/灵敏度场景里，典型情况正是：

- 参数很多
- 输出只有 1 个性能指标或少数几个指标

因此 adjoint 很常见。

---

## 10. 最后把你的问题直接回答成一句话

你说“adjoint 中不还是涉及到了对 `x` 灵敏度的求解吗”，对，**间接上是的**；但它不再显式求整个

$$
\frac{\partial x}{\partial p}
$$

而是通过解

$$
J^T \lambda = \left(\frac{\partial g}{\partial x}\right)^T
$$

把“状态灵敏度对输出的贡献”提前压缩成一个伴随向量 `\lambda`，然后直接得到

$$
\frac{dy}{dp}
=
-\lambda^T \frac{\partial f}{\partial p}
+
\frac{\partial g}{\partial p}
$$

所以计算量变小，不是因为 `x` 不重要了，而是因为 **不再把整块状态灵敏度都算出来，只算当前输出真正需要的那一部分**。

如果你愿意，我下一步可以继续做两种展开中的一种：

1. 用一个很小的 `2x2` 线性电路例子，把 direct 和 adjoint 都手算一遍  
2. 直接把这个思路整理成一篇笔记，放到 `notes/06-solver-and-assembly/03-sensitivity/` 里，专门讲 “为什么 adjoint 更省”