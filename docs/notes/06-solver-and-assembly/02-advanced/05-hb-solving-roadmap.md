# hb solving roadmap

记录日期：2026-06-06

## 这篇的定位

这一篇先不追 `HB` 的全部实现细节，而是先回答：

```text
HB 在数学上到底想解什么问题，
它为什么既不是 AC 的小信号频域分析，
也不是 transient 的时间步进？
```

所以这篇更像 `HB` 的求解路线图，而不是完整推导。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_HB.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.h)
- [src/AnalysisPKG/N_ANP_HB.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.C)
- [src/LoaderServicesPKG/N_LOA_HBLoader.h](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_HBLoader.h)
- [src/LinearAlgebraServicesPKG/N_LAS_HBBuilder.h](../../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_HBBuilder.h)

## 当前结论先写在前面

`HB` 最适合先理解成下面这条数学主线：

```text
不是去求完整长时间 transient 轨迹，
而是直接求“周期稳态解”
-> 把周期解展开到有限个 Fourier / harmonic 系数上
-> 把原始 nonlinear DAE 变成这些系数上的 nonlinear algebraic system
-> 再对这个代数系统做 nonlinear solve
```

也就是说：

```text
AC 研究的是：工作点附近的小信号线性响应
HB 研究的是：周期稳态下的大信号非线性平衡
```

## 第零步：原始电路方程仍然还是那条 DAE

和前面的 `DC`、`transient`、`AC`、`NOISE` 一样，起点还是：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

真正的分叉点不在“起点换了”，而在：

```text
HB 对解的目标施加了“周期稳态”这个结构性假设
```

也就是它不是要整条任意轨迹，而是要找：

$$
x(t+T)=x(t)
$$

的解。

## 第一步：为什么 HB 不是 transient

`transient` 的思路是：

```text
给定初值
-> 时间离散
-> 一步一步往前推进
-> 让系统自己慢慢收敛到可能的周期稳态
```

而 `HB` 的思路是：

```text
我直接假设目标解是周期的，
不再一小步一小步把长时间轨迹都走出来，
而是直接在“周期解空间”里找它。
```

所以 `HB` 和 `transient` 的本质差别，不是“都和时间有关，所以差不多”，而是：

- `transient`：轨迹推进问题
- `HB`：周期边值/周期平衡问题

这就是为什么 `HB` 需要：

- `freqPoints_`
- `fastTimes_`
- `DFT/IFT`

这些结构，而不是只需要普通时间步长。

## 第二步：为什么 HB 也不是 AC

`AC` 的核心前提是：

```text
先有 DC working point
-> 在工作点附近做一阶线性化
-> 得到小信号 LTI 系统
```

也就是说，`AC` 本质上依赖：

$$
x(t)=x^*+\hat{x}(t), \qquad \hat{x}(t)\ \text{很小}
$$

于是才有：

$$
\left(G+j\omega C\right)X(\omega)=B(\omega)
$$

但 `HB` 不是小信号框架。  
它要处理的通常是：

- 周期激励下的大信号响应
- 非线性器件产生的多次谐波
- 不同谐波分量之间的耦合

所以 `HB` 最值得先抓住的一句是：

```text
HB 不是“多几个频点的 AC”，
而是“在频域里直接解一个非线性的周期稳态系统”。
```

## 第三步：HB 在数学上到底求什么

如果系统存在周期稳态解，就可以把未知量写成有限谐波展开，例如：

$$
x(t) \approx x_0 + \sum_{k=1}^{K}\left(a_k\cos(k\omega_0 t) + b_k\sin(k\omega_0 t)\right)
$$

这里：

- $x_0$ 是 DC 分量
- $a_k, b_k$ 是第 $k$ 个谐波的系数
- $\omega_0$ 是基波频率

这时 `HB` 真正想解的，就不再是“时刻 $t_n$ 上的状态”，而是：

```text
这些 Fourier / harmonic 系数到底取什么值
```

然后把这组周期函数形式代回原始 DAE，再通过频域平衡或时频变换关系，得到：

```text
一组关于谐波系数的 nonlinear algebraic equations
```

这就是为什么 `HB` 最后仍然要进：

- `nonlinearManager`
- Newton 类流程

因为它不是线性的。

## 第四步：为什么会出现 DFT / IFT / fastTimes

这一步是 `HB` 和其他分析类型最不一样的地方之一。

你在代码里会看到：

- `setFreqPoints_()`
- `setTimePoints_()`
- `createFT_()`
- `registerDFTInterface(...)`
- `permutedFFT(...)`

从数学视角，这说明 `HB` 并不是只活在“纯频域符号”里。  
它需要在：

- 时域采样点
- 频域谐波系数

之间来回切换。

这是因为很多电路器件的 nonlinear evaluation，更自然还是在“时域样本”上完成；  
而 `HB` 整体想求的未知量，又是频域谐波系数。

所以这一层最值得先记成：

```text
HB 不是把所有东西都手工写成封闭频域公式，
而是要靠 DFT/IFT 在时域样本和频域系数之间搭桥。
```

这也解释了为什么会专门有：

- `HBLoader`
- `HBBuilder`
- `DFTInterface`

这些基础设施。

## 第五步：为什么 HB 还需要初值，而且常常来自 transient

因为 `HB` 最终还是在解一个：

```text
频域谐波系数上的 nonlinear algebraic system
```

它不是小信号线性问题，所以也会有：

- 初值敏感
- 收敛难度
- 多解或坏初值导致难收敛

因此代码里你会看到：

- `runTransientIC()`
- `runStartupPeriods()`
- `interpolateIC(...)`
- `runDCOP()`

这说明 `HB` 常常不是凭空从零开始，而是：

```text
先借 transient 或 DCOP 给它一个更靠谱的周期解初值
```

这一步从求解策略角度非常关键。

## 第六步：代码主线先怎么抓

如果先不进深细节，`HB` 的求解主线可以先压成：

```text
setFreqPoints_ / setTimePoints_
-> setInitialGuess()
-> HBBuilder / HBLoader / DFT interface
-> initializeSolverSystem(..., hbLoader, hbLinearSystem, ...)
-> nonlinearManager 进入 HB mode
-> doLoopProcess() 里驱动 HB 的 nonlinear solve
```

这里最值得先记住的不是每个 helper 的细节，而是：

```text
HB 先把“普通电路系统”重新组织成一个针对周期稳态的块结构系统，
然后再把这个块结构系统交给现有的 nonlinear solve 骨架。
```

## 第七步：为什么这篇暂时只做 roadmap

因为 `HB` 比 `AC`、`NOISE` 的跨度明显更大。

如果一上来就硬推完整公式，很容易同时掉进这些内容：

- 多音频率集合怎么生成
- 时频变换矩阵怎么构造
- 非线性器件在时域样本上怎样评估再映回频域
- 矩阵自由算子和 HB 预条件器

这会一下子把学习负担拉得太高。

所以这一步最稳的做法是先建立 3 个本质判断：

1. `HB` 目标是周期稳态，不是整条 transient 轨迹
2. `HB` 是非线性的，不是 `AC` 那种小信号线性频域问题
3. `HB` 需要在时域样本和频域谐波系数之间来回切换

只要这三点站住，后面再深入代码就不会乱。

## 这一篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
HB 的本质不是“频域版 transient”或“强一点的 AC”，
而是“直接在有限个谐波系数上求一个周期稳态的 nonlinear 平衡解”。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `HB` 相比 `AC` 的关键变化，不是“频率点更多了”，而是“问题从小信号线性响应变成了大信号周期稳态的 nonlinear 平衡”？
2. 为什么 `HB` 相比 `transient` 的关键变化，不是“也和时间有关”，而是“它不再一步步推进轨迹，而是直接求周期解的谐波系数”？
