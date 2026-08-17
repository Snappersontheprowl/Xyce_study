# dc sensitivity solving

记录日期：2026-07-04

## 这篇的定位

这一篇只讲 `DC sensitivity` 的数学骨架。

也就是：

```text
当电路先求出了一个 DC operating point 之后，
参数变化会怎样推动残差，
系统又怎样通过 Jacobian 把这种参数扰动变成解扰动？
```

这一篇故意不展开 `AC` 和 `Transient`，因为它们都建立在这条最基础的 `DC` 灵敏度骨架之上。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)

## 当前结论先写在前面

`DC sensitivity` 最适合先压成下面这句话：

```text
先求 DC 工作点 x*，
再在这个工作点上线性化残差方程，
最后把“参数对残差的直接扰动”转换成“解对参数的响应”。
```

写成式子就是：

$$
f(x,p)=0
$$

在 `DC` 下最自然的写法是：

$$
F(x,p)-B(p)=0
$$

对参数 $p_k$ 求导后得到：

$$
\frac{\partial F}{\partial x}\frac{\partial x}{\partial p_k}
+
\frac{\partial F}{\partial p_k}
-
\frac{\partial B}{\partial p_k}
=0
$$

记

$$
J_{DC}=\frac{\partial F}{\partial x}
$$

则有：

$$
J_{DC}\frac{\partial x}{\partial p_k}
=
-
\left(
\frac{\partial F}{\partial p_k}
-
\frac{\partial B}{\partial p_k}
\right)
$$

这就是 `DC direct sensitivity` 最核心的方程。

## 第一步：先把 DC 原问题单独看清

在 `DC operating point` 下，没有时间导数项，所以原始电路 DAE

$$
\frac{dQ(x,p)}{dt}+F(x,p)-B(t,p)=0
$$

会退化成：

$$
F(x,p)-B(p)=0
$$

这里：

- $x$ 是 DC 工作点未知量
- $F(x,p)$ 是器件和拓扑形成的静态残差
- $B(p)$ 是独立源等外部注入

在这一步里，真正的第一层未知量是：

$$
x^*
$$

也就是工作点本身。

只有先把它求出来，后面的灵敏度问题才有意义。

## 第二步：参数扰动在 DC 里怎样进入方程

在工作点 $x^*$ 处，参数 $p_k$ 变化会带来两部分影响：

### 1. 直接影响残差

也就是：

$$
\frac{\partial F}{\partial p_k}
-
\frac{\partial B}{\partial p_k}
$$

它表示：

```text
如果把工作点 x* 暂时冻结住，
只让参数 p_k 自己动一下，
残差会立刻偏向哪里。
```

这就是右端项来源。

### 2. 间接引起解变化

也就是：

$$
\frac{\partial x}{\partial p_k}
$$

它表示：

```text
为了把偏掉的残差重新拉回 0，
整套 DC 解变量必须怎样联动变化。
```

这是真正要求的量。

## 第三步：为什么会得到同一个 Jacobian

从

$$
F(x,p)-B(p)=0
$$

对参数求导，有：

$$
\frac{\partial F}{\partial x}\frac{\partial x}{\partial p_k}
+
\frac{\partial F}{\partial p_k}
-
\frac{\partial B}{\partial p_k}
=0
$$

把未知量留在左边：

$$
\frac{\partial F}{\partial x}\frac{\partial x}{\partial p_k}
=
-
\left(
\frac{\partial F}{\partial p_k}
-
\frac{\partial B}{\partial p_k}
\right)
$$

于是左边矩阵正好就是[原始 *DC Newton* 问题](/home/eda/my_lab/projects/study/xyce_study/docs/notes/06-solver-and-assembly/01-basic/03-dc-operating-point-solving.md)用过的 Jacobian：

$$
J_{DC}=\frac{\partial F}{\partial x}
$$

这就是为什么 `DC direct sensitivity` 不是重新发明一套方程，而是复用：

```text
原来的 Jacobian + 新的参数扰动右端项
```

## 第四步：从解灵敏度到输出灵敏度

如果你关心某个观测量：

$$
y=g(x,p)
$$

那么：

$$
\frac{dy}{dp_k}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p_k}
+
\frac{\partial g}{\partial p_k}
$$

所以 `DC sensitivity` 里实际上分两层：

### 第一层：求解灵敏度

$$
\frac{\partial x}{\partial p_k}
$$

### 第二层：把解灵敏度映射到输出

$$
\frac{dy}{dp_k}
$$

如果输出本身就是某个节点电压或支路电流，那么这个映射往往很直接。

## 第五步：direct 和 adjoint 在 DC 里的区别

### direct

对于每个参数 $p_k$，都解：

$$
J_{DC}\frac{\partial x}{\partial p_k}
=
-
\left(
\frac{\partial F}{\partial p_k}
-
\frac{\partial B}{\partial p_k}
\right)
$$

如果参数有很多个，就要重复很多次。

### adjoint

如果只关心少数输出，就不一定先求整块

$$
\frac{\partial x}{\partial p}
$$

而是引入伴随向量 $\lambda$：

$$
J_{DC}^{T}\lambda
=
\left(\frac{\partial g}{\partial x}\right)^T
$$

再直接计算：

$$
\frac{dy}{dp_k}
=
\frac{\partial g}{\partial p_k}
-
\lambda^T
\left(
\frac{\partial F}{\partial p_k}
-
\frac{\partial B}{\partial p_k}
\right)
$$

所以 `DC adjoint` 的节省点仍然是：

```text
按输出求解
而不是按参数求解
```

## 第六步：为什么 DC 是三种灵敏度里最基础的一种

因为 `DC sensitivity` 没有：

- 时间离散
- 历史项
- 频域复数块矩阵
- 反向时间积分

它只有：

```text
工作点
+ Jacobian
+ 参数右端项
+ 输出映射
```

所以你如果要建立真正稳定的灵敏度直觉，应该先把 `DC` 吃透，再往 `AC` 和 `Transient` 迁移。

## 第七步：和代码怎么对照

在工程实现层，`DC sensitivity` 的接入点非常短：

1. 在 [N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C) 的 `finalExpressionBasedSetup()` 里先 `enableSensitivity(...)`
2. 在同一文件的 `doProcessSuccessfulStep()` 里，每个成功的 DC 工作点后调用 `nonlinearManager_.calcSensitivity(...)`

对应文件位置可直接跳：

- [N_ANP_DCSweep.C:249](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C#L249)
- [N_ANP_DCSweep.C:463](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C#L463)

从学习顺序上，这里最重要的是先理解：

```text
DC sensitivity 在数学上是“工作点上的线性响应问题”，
在代码上是“每个成功 DC 工作点后追加的一次 sensitivity solve”。
```

## 当前这一篇学完后，应该记住什么

1. `DC sensitivity` 的母方程是

   $$
   J_{DC}\frac{\partial x}{\partial p_k}
   =
   -
   \left(
   \frac{\partial F}{\partial p_k}
   -
   \frac{\partial B}{\partial p_k}
   \right)
   $$
2. 左边的 $J_{DC}$ 是原 DC 问题的 Jacobian，不是新造出来的矩阵。
3. 右边是“参数对残差的直接扰动”，未知的是“解的响应”。
4. 输出灵敏度不是第一层对象，而是解灵敏度经过输出映射后的结果。
5. `AC sensitivity` 和 `Transient sensitivity` 都是在这条骨架上继续变形。
