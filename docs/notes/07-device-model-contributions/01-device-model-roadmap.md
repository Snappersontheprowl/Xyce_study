# device model roadmap

记录日期：2026-06-04

## 这篇的定位

这一篇不直接进入某个具体器件实现，而是先把“为什么现在要从 solver 转向 device model”讲清楚。

前面的 [06-solver-and-assembly](../06-solver-and-assembly/README.md) 已经回答了：

- solver 在解什么方程
- `DC` 和 `transient` 的数学本质是什么
- residual、Jacobian、Newton、linear solve 在代码里落在哪

但那一组笔记还留了一个很关键的问题没有继续下钻：

```text
求解器看到的 Q / F / B / dQdx / dFdx
到底是谁提供的？
器件模型和求解器之间，到底是怎么接上的？
```

所以这个专题的任务，是沿着下面这条链往回追：

$$
\text{solver}
\rightarrow
\text{residual / Jacobian}
\rightarrow
Q,F,B,dQdx,dFdx
\rightarrow
\text{device instance}
\rightarrow
\text{device model equations}
$$

## 当前结论先写在前面

如果只压缩成一句话，这个专题要学的是：

```text
器件如何把自己的电流、电荷、状态关系
翻译成总方程里的 Q / F / B / dQdx / dFdx
```

也就是说，接下来不再只问“solver 怎么解”，而是开始问：

- 一个器件到底给系统加了什么？
- 它是写 `F`，还是写 `Q`，还是两者都写？
- 它对哪些未知量求导？
- 它为什么要按那种方式写，Newton 才能收敛？

## 为什么这个专题应该放在 solver 后面

因为现在去学器件模型，已经有了一个非常重要的上下文：

- 你已经知道总方程长什么样
- 你已经知道 transient 为什么需要 `Q/dQdx`
- 你已经知道 Newton 为什么依赖 Jacobian
- 你已经知道 linear solver 只是解某一步线性化方程

所以这时再回头看器件代码，就不会把它误读成“只是一些零散公式”，而会自然带着下面这个问题去读：

```text
这个器件到底在给哪一个方程项供货？
```

这正是这一专题最重要的视角转换。

## 这一专题建议按什么顺序学

### 第一步：先建立“器件对 DAE 的贡献分类”

先不要急着上 MOS。更合理的顺序是先按器件类型建立感觉：

- **静态线性器件**
  - 典型：resistor
  - 重点：`F`、`dFdx`
- **动态器件**
  - 典型：capacitor
  - 重点：`Q`、`dQdx`
- **静态非线性器件**
  - 典型：diode
  - 重点：nonlinear `F`、随工作点变化的 `dFdx`
- **更复杂 compact model**
  - 典型：MOS / BJT
  - 重点：多端口、电流、电荷、limiting、内部状态

这一层的目标不是背公式，而是先知道：

```text
不同器件，会给总方程的不同部分供货
```

### 第二步：再建立“器件代码阅读模板”

后面每看一个器件，建议固定带着下面这些问题：

1. 这个器件有哪些外部节点？
2. 它有没有内部未知量或 branch variable？
3. 它主要贡献 `F`、`Q`，还是两者都有？
4. 它的主方程是什么？
5. 它对哪些变量求偏导？
6. Jacobian 的非零位置是怎么决定的？
7. 它有没有状态量 / history 量？
8. 它有没有 limiting、clipping、初值处理这类数值稳定措施？

这个模板很重要，因为它能把“看代码”变成“看器件怎样接入总方程系统”。

## 为什么我建议先看 capacitor 和 diode

### 1. capacitor 最适合把 `Q/dQdx` 讲透

你在 transient 那组笔记里已经反复看到：

$$
\frac{dQ(x)}{dt}+F(x)-B(t)=0
$$

但如果没有看一个真正写 `Q` 的器件，这个式子还是容易停留在抽象层。

capacitor 正好能回答：

- `Q` 在器件层到底是什么样的量
- `dQdx` 为什么会进入 Jacobian
- 为什么 time discretization 一定会特别关心这类器件

### 2. diode 最适合把 nonlinear `F/dFdx` 讲透

resistor 虽然也会贡献 `F` 和 `dFdx`，但它太线性，不足以让你真正体会：

- residual 为什么会依赖当前工作点
- Jacobian 为什么必须每次迭代重建
- 为什么器件代码里常常要做 limiting

而 diode 足够简单，又足够非线性，非常适合作为进入真正 compact model 之前的桥梁。

## 我建议这条专题的展开顺序

如果后面继续细分笔记，我建议按下面顺序展开：

1. `01-device-model-roadmap.md`
   - 先把这条学习主线和分类方式讲清楚
2. `02-capacitor-and-q-contribution.md`
   - 专门看动态器件怎样写 `Q/dQdx`
3. `03-diode-and-nonlinear-f.md`
   - 专门看非线性器件怎样写 `F/dFdx`
4. `04-from-device-equations-to-stamp.md`
   - 总结器件公式如何落到向量和矩阵位置
5. 后面再看 MOS / BJT 这类更复杂模型

这个顺序的核心逻辑是：

```text
先把 solver 需要的两类关键贡献拆开学：
Q/dQdx
和
F/dFdx
```

然后再回到复杂器件，把这两类贡献重新合起来看。

## 这一篇最想让你先吃下来的本质

器件模型不是“公式翻译成 C++”这么简单，它实际上是在做两件事：

1. 把器件的物理 / 经验关系翻译成电路 DAE 的组成部分
2. 再把这些组成部分写成适合 Newton 和 time integration 使用的数值对象

所以后面读器件代码时，最重要的问题不是：

```text
这个器件公式长什么样
```

而是：

```text
它如何贡献 Q / F / dQdx / dFdx，并且为什么必须这样写，solver 才能工作
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么在 solver 之后继续学器件模型时，最关键的视角是“器件如何贡献方程”，而不是先背一堆器件公式？
2. 为什么 `capacitor` 和 `diode` 比直接上 MOS 更适合作为这个专题的起点？
