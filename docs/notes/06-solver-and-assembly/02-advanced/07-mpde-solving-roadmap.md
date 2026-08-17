# mpde solving roadmap

记录日期：2026-06-07

## 这篇的定位

这一篇先回答：

```text
MPDE 在数学上到底想解什么问题，
它为什么既不是普通 transient，也不是 HB 那样的纯周期稳态频域平衡？
```

所以这一篇先立多时间尺度求解的数学骨架，再对代码。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_MPDE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_MPDE.C)
- [src/MultiTimePDEPKG/N_MPDE_Manager.h](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Manager.h)
- [src/MultiTimePDEPKG/N_MPDE_Manager.C](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Manager.C)
- [src/MultiTimePDEPKG/N_MPDE_Loader.h](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Loader.h)
- [src/MultiTimePDEPKG/N_MPDE_Loader.C](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Loader.C)
- [src/MultiTimePDEPKG/N_MPDE_Discretization.h](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Discretization.h)

## 当前结论先写在前面

`MPDE` 最适合先理解成下面这条数学主线：

```text
原始电路 DAE
-> 把时间拆成 slow time + fast time
-> 把原来的 ODE/DAE 提升成多时间尺度 PDE
-> 先沿 fast time 做离散，变成 block-vector DAE
-> 再把这个 block-vector DAE 交给普通 transient 外壳沿 slow time 推进
```

如果只抓一句话，我希望你先抓住：

```text
HB 是“直接求周期稳态系数”，
MPDE 是“把慢变化包络和快周期振荡拆开，再在 slow time 上推进一个大块系统”。
```

## 先从原始电路方程出发

和 `DC`、`TR`、`AC`、`HB` 一样，起点仍然是：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

普通 `transient` 的思路是：

- 用一个单时间变量 $$t$$
- 沿这个时间轴一步一步推进

但某些电路存在明显的双时间尺度：

- 一条很快的周期振荡
- 外面再包着一条更慢的演化

这时如果只用单一时间轴做普通 transient，往往会变得很贵，因为：

```text
为了跟住快振荡，
slow envelope 也被迫跟着用很小步长推进。
```

`MPDE` 的出发点就是：

```text
把这两种时间尺度显式拆开。
```

## 第一步：引入 slow time 和 fast time

`MPDE` 的基本想法是：

不再把解写成单变量轨迹 $x(t)$，而是改写成双时间变量函数：

$$
x(t) \approx \hat{x}(t_1, t_2)
$$

其中：

- $t_1$ 表示慢时间尺度
- $t_2$ 表示快时间尺度

这里的直觉可以先记成：

```text
t1 负责“包络/慢变化”
t2 负责“一个周期内的快振荡形状”
```

于是原来的一条轨迹问题，被提升成了一个多时间尺度的问题。

## 第二步：为什么会从 ODE/DAE 变成 PDE

一旦把未知量改成：

$$
\hat{x}(t_1,t_2)
$$

那么沿真实时间的变化，就要用链式法则拆开。

最朴素地写，可以把总时间导数理解成：

$$
\frac{d}{dt}
\quad \leadsto \quad
\frac{\partial}{\partial t_1}

+ \frac{\partial}{\partial t_2}
$$

如果再考虑 warped MPDE，则还会出现一个可变频率因子：

$$
\frac{d}{dt}
\quad \leadsto \quad
\frac{\partial}{\partial t_1}
+ \omega(t_1)\frac{\partial}{\partial t_2}
$$

这也是为什么你会在代码里看到：

- `warpMPDE_`
- `omegaGID`
- `phiGID`
- `bOmegadQdt2Ptr_`

但在第一轮学习里，先抓最基本的非 warp 版本就够了。

于是，原始 DAE 就被提升成多时间尺度 PDE 形式：

$$
\frac{\partial Q(\hat{x})}{\partial t_1}
+ \frac{\partial Q(\hat{x})}{\partial t_2}
+ F(\hat{x})
- B(t_1,t_2)
=0
$$

如果是 warped 版本，则更接近：

$$
\frac{\partial Q(\hat{x})}{\partial t_1}
+ \omega(t_1)\frac{\partial Q(\hat{x})}{\partial t_2}
+ F(\hat{x})
- B(t_1,t_2)
=0
$$

这一点最值得先记住：

```text
MPDE 的“PDE”并不是空间 PDE，
而是“时间变量被拆成两个独立方向”之后产生的多时间尺度 PDE。
```

## 第三步：MPDE 和 HB 的根本区别

这一步很容易混，所以最好先压一下。

### HB
`HB` 的核心假设是：

$$
x(t+T)=x(t)
$$

也就是直接找一个周期稳态解。  
它最后要解的是：

```text
有限谐波系数上的 nonlinear algebraic system
```

### MPDE
`MPDE` 不要求系统一开始就是纯周期稳态。  
它允许：

- 快时间上是周期结构
- 慢时间上包络仍然在变化

所以它最后更像是在解：

```text
slow time 上推进的 block-vector DAE
```

这就是最本质的区别：

```text
HB：把“快周期结构”直接压成一个稳态频域平衡问题
MPDE：保留慢时间推进，只把快周期结构单独拆成第二个时间维度
```

## 第四步：为什么要先沿 fast time 离散

要让这个多时间尺度 PDE 真正进入数值求解，最自然的办法就是：

- 先把 fast time $t_2$ 离散掉
- slow time $t_1$ 暂时保留

也就是说，在一个快周期上选若干个采样点：

$$
t_{2,1}, t_{2,2}, \dots, t_{2,N}
$$

然后把：

$$
\hat{x}(t_1,t_2)
$$

在这些 fast-time 点上的值堆成一个大块向量：

$$
X(t_1)=
\begin{bmatrix}
\hat{x}(t_1,t_{2,1}) \\
\hat{x}(t_1,t_{2,2}) \\
\vdots \\
\hat{x}(t_1,t_{2,N})
\end{bmatrix}
$$

这时，对每个固定的 $t_1$，你就不再面对一个“连续 fast-time 方向”，而是得到一个大 block-vector。

这一步是 `MPDE` 求解骨架里最重要的转折：

```text
先把 fast time 离散成块，
于是多时间尺度 PDE 被降成了 slow time 上的 block-vector DAE。
```

## 第五步：fast-time 导数怎么进系统

一旦 fast time 被离散，$\partial/\partial t_2$ 就会变成离散差分算子。

在代码里，这一层由：

- [N_MPDE_Discretization.h](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Discretization.h)

负责提供：

- `Type { Backward, Centered, Forward }`
- `Order()`
- `Coeffs()`

也就是说，Xyce 这里对 fast-time 导数的处理思路可以先记成：

$$
\frac{\partial Q}{\partial t_2}
\quad \Longrightarrow \quad
\text{沿 fast-time block 的有限差分组合}
$$

在：

- [N_MPDE_Loader.C](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Loader.C)

的 `loadDAEVectors(...)` 里，这一步对应的是：

- 先取 `fastTimeDiscretizer_.Coeffs()`
- 再在每个 block 上用相邻 fast-time 样本的 `Q` 组合出 `dQdt2`
- 最后把它加回 `F`

也就是说，代码里这段：

```text
dQdt2
-> bF.block(i).update(...)
```

在数学上对应的正是：

$$
\frac{\partial Q}{\partial t_2}
$$

这一项被离散后并入系统残差。

## 第六步：为什么普通器件装配还能复用

这一步和 `HB` 很像，也是 `MPDE` 最聪明的地方之一。

在 `N_MPDE_Loader::loadDAEVectors(...)` 里，你会看到对每个 fast-time block 做：

1. `state_.fastTime = times_[i];`
2. `deviceManager_.setFastTime(times_[i]);`
3. `loader_.updateSources();`
4. `loader_.updateState(...);`
5. `loader_.loadDAEVectors(...);`
6. `loader_.loadDAEMatrices(...);`

所以从数学到实现的对应关系可以先记成：

```text
每个 fast-time 样本点上，
普通器件仍然只做“那个时刻下”的 Q/F/dQdx/dFdx 装配；
MPDE 只是在外层把这些样本块拼成一个大系统。
```

这也是为什么 `MPDE` 能在不重写全部器件模型的前提下成立。

## 第七步：为什么它最后又回到了 Transient

这是 `MPDE` 最值得先吃透的一句。

fast-time 离散之后，我们得到的是一个关于 slow time 的大块系统：

$$
\frac{d}{dt_1}Q\big(X(t_1)\big)
+ D_{t_2}Q\big(X(t_1)\big)
+ F\big(X(t_1)\big)
- B(t_1)
=0
$$

这里：

- $X(t_1)$ 是 block-vector 未知量
- $D_{t_2}$ 是 fast-time 差分算子

你会发现，这个系统从结构上仍然是：

```text
一个关于 slow time 的 DAE
```

只是未知量已经从原来的单向量，变成了 block-vector。

所以从数值求解角度，最自然的事情就是：

```text
沿 slow time 继续用普通 transient 外壳推进
```

这正是：

- `N_MPDE_Manager::runMPDEProblem_()`

里真正做的事情：

```cpp
Transient transient(..., *mpdeLoaderPtr_, ..., this);
returnValue = transient.run();
```

所以这里最值得先记住的一句是：

```text
MPDE 不是抛弃 transient，
而是把“单时间变量 transient”
升级成“slow time 上推进的 block-vector transient”。
```

## 第八步：代码主线先怎么抓

如果先不进太深实现细节，`MPDE` 的求解主线可以先压成：

```text
原始 DAE
-> 引入 t1 / t2
-> fast-time 离散
-> N_MPDE_Discretization 给出差分系数
-> N_MPDE_Loader 在每个 fast-time block 上复用普通器件装配
-> dQdt2 项并入 block residual
-> 得到 slow-time 上的 block-vector DAE
-> 用 Transient 外壳推进这个大系统
```

## 当前这篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
MPDE 的本质不是“另一种频域分析”，
而是“把快振荡单独拆成第二个时间维度，
先沿 fast time 离散，
再把剩下的 slow-time block 系统交给 transient 去推进”。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `MPDE` 会从原始单时间 DAE 变成一个“多时间尺度 PDE”，而不是像 `HB` 那样直接变成谐波系数上的代数系统？
2. 为什么 `runMPDEProblem_()` 最后重新借用了 `Transient`，这并不是“设计不纯”，反而正说明 `MPDE` 的 slow-time 求解骨架本质上仍然是 transient？
