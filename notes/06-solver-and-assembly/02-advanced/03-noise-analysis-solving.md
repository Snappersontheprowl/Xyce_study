# noise analysis solving

记录日期：2026-06-06

## 这篇的定位

这一篇只回答：

```text
NOISE analysis 在数学上到底解什么，
以及它为什么建立在 AC 的小信号频域系统之上？
```

这篇不再讲 analysis object 是怎么被调度起来的，那部分已经放到：

- [../../05-analysis-flow/02-advanced/03-noise-lifecycle.md](../../05-analysis-flow/02-advanced/03-noise-lifecycle.md)

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_NOISE.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.h)
- [src/AnalysisPKG/N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
- [src/LoaderServicesPKG/N_LOA_Loader.h](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_Loader.h)
- [src/AnalysisPKG/N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)

## 当前结论先写在前面

`NOISE` 最适合先理解成下面这条数学主线：

```text
先求一个 DC operating point
-> 在这个工作点附近形成 small-signal 频域线性系统
-> 把器件噪声表示成等效小信号源
-> 在每个频点上求这些噪声源传到输出端的响应
-> 再把谱密度积分成 total noise
```

如果把最核心的线性系统压成一行，可以先记成：

$$
\left(G + j \omega C\right) X(\omega) = B(\omega)
$$

而 `NOISE` 相比 `AC` 的额外问题是：

```text
不是只求“输入激励 -> 输出响应”，
而是要继续求“每个器件噪声源 -> 输出噪声谱密度”的映射。
```

## 第零步：原始电路方程还是那条 DAE

和 `DC`、`transient`、`AC` 一样，起点仍然是：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

`NOISE` 不是从另一条新方程突然开始的。  
它和 `AC` 一样，首先都建立在：

```text
围绕某个 DC working point 的小信号线性化
```

之上。

所以理解 `NOISE` 的第一步，不是先问“噪声怎么积分”，而是先问：

```text
为什么它必须先依赖 AC 那种 small-signal 频域系统？
```

## 第一步：为什么 NOISE 也必须先有 DCOP

先记工作点 $x^\*$ 满足：

$$
F(x^\*) - B_0 = 0
$$

这里 $B_0$ 是直流偏置。

`NOISE` 要研究的不是：

- 大信号时域轨迹
- 或某个未平衡状态

而是：

```text
在一个已经平衡的偏置点附近，
器件内部噪声如何经过小信号网络传播到输出端
```

所以和 `AC` 一样，如果没有先求出 $x^\*$，后面的小信号网络本身就不成立。  
这就是为什么 `NOISE::doInit()` 里同样先调用：

- `nonlinearManager_.solve();`

去得到 `DCOP`。

## 第二步：为什么 NOISE 先复用 AC 的 small-signal 线性化

在工作点附近，把变量写成：

$$
x(t) = x^\* + \hat{x}(t)
$$

然后对原始 DAE 做一阶 Taylor 线性化，就和 `AC` 一样得到：

$$
C\,\frac{d\hat{x}}{dt} + G\,\hat{x} = \hat{b}(t)
$$

其中：

$$
C = \left.\frac{\partial Q}{\partial x}\right|_{x^\*}, \qquad
G = \left.\frac{\partial F}{\partial x}\right|_{x^\*}
$$

接着在频域里，就得到：

$$
\left(G + j\omega C\right) X(\omega) = B(\omega)
$$

到这里为止，`NOISE` 和 `AC` 还没有本质区别。  
真正的分叉点在于：

- `AC` 关注的是外部小信号激励 $B(\omega)$ 造成的响应
- `NOISE` 关注的是器件内部噪声源造成的响应

所以从数学层面最值得先记住的一句是：

```text
NOISE 不是重新发明一个新的频域系统，
而是在 AC 的小信号频域系统上，
继续研究内部噪声源的传播。
```

## 第三步：NOISE 里“噪声源”在数学上是什么

在小信号框架里，器件噪声通常会被等效成：

- 电流噪声源
- 或电压噪声源

并且这些噪声不是看一个瞬时值，而是看它们在频域里的：

$$
S_n(\omega)
$$

也就是噪声谱密度。

所以 `NOISE` 的问题，不是：

```text
给一个确定正弦输入，求一次确定输出
```

而是：

```text
给定某个器件噪声源在频点 ω 的谱密度，
它经过当前线性小信号网络后，
在输出端会形成多大的输出噪声谱密度？
```

这时最常见的数学结构就是：

- 先有一个线性系统算传递关系
- 再用这个传递关系把器件噪声谱密度映到输出端

这也是为什么 `NOISE` 在代码里会出现：

- 普通 AC solve
- 以及额外的 adjoint solve

因为它需要的不只是“正向响应”，还要高效地计算：

```text
很多器件噪声源到某个固定输出量的增益
```

## 第四步：为什么这里会用 adjoint

如果只做最朴素的想法，似乎可以说：

- 每个 noise source 都单独当输入
- 每次都解一次正向线性系统
- 最后看输出端响应

但这在器件噪声源很多时会非常贵。

所以更高效的做法是：

1. 先固定输出观测量
2. 建一个 adjoint 问题
3. 用 adjoint 解来同时评估许多噪声源对这个输出的影响

从数学上，你可以先把它理解成：

```text
不是反复问“这个源推到输出有多大”，
而是先建立“输出对全系统的灵敏度”，
再把每个噪声源投影到这个灵敏度上。
```

这就是 `NOISE` 相比 `AC` 最值得先抓住的新增数学层。

## 第五步：输出噪声和输入参考噪声是什么

在每个频点上，`NOISE` 最终关心的至少有两类量：

### 1. 输出噪声谱密度

也就是某个输出量上的：

$$
S_{\text{out}}(\omega)
$$

它回答的是：

```text
这个频点上，所有器件噪声通过网络传播后，
在输出端留下多大的噪声谱密度？
```

### 2. 输入参考噪声谱密度

也就是把输出噪声再除以小信号增益平方，折回输入端：

$$
S_{\text{in,ref}}(\omega)
=
\frac{S_{\text{out}}(\omega)}{|H(\omega)|^2}
$$

这正好对应代码里的：

- `GainSqInv_`
- `totalOutputNoiseDens_`
- `totalInputNoiseDens_`

所以这一层的本质是：

```text
NOISE 不只给“输出端有多吵”，
还给“如果等效回输入端，相当于多大的输入噪声源”。
```

## 第六步：为什么还要做 noise integral

单个频点上得到的是谱密度，不是总噪声。

如果想得到某个频带内的总噪声，还要对频率积分：

$$
\sigma_{\text{noise}}^2
=
\int_{\omega_1}^{\omega_2} S(\omega)\, d\omega
$$

这就是代码里：

- `noiseIntegral(...)`

存在的原因。

所以 `NOISE` 在数学上至少有两层结果：

1. 每个频点上的噪声谱密度
2. 对整个扫频区间积分后的 total noise

## 第七步：这些数学对象在代码里怎么落地

现在再把这条数学主线对回代码。

### 1. 先复用 AC 的 $C$ 和 $G$

看：

- [N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
  里的 `updateACLinearSystem_C_and_G_()`

这里做的事情和 `AC` 很像：

- 清零 `daeQ / daeF / dQdx / dFdx`
- `loader_.loadDAEVectors(...)`
- `loader_.loadDAEMatrices(...)`
- 然后：
  - `C_ = dQdxMatrixPtr`
  - `G_ = dFdxMatrixPtr`

也就是说，`NOISE` 的频域系统仍然建立在：

$$
C = \frac{\partial Q}{\partial x}, \qquad G = \frac{\partial F}{\partial x}
$$

之上。

### 2. 再组装频域系统

看：

- `updateACLinearSystemFreq_()`

这里仍然是在构造 2-block real/imag 形式的：

$$
G + j\omega C
$$

所以从求解器角度看，`NOISE` 先沿用了 `AC` 的 block linear system。

### 3. 先求 AC 响应

看：

- `solveACLinearSystem_()`

这一步求的是：

```text
这个频点下，普通小信号激励对应的 AC 解
```

它帮助后面得到输出增益、输入参考噪声等量。

### 4. 再做 adjoint noise solve

看：

- `setupAdjointRHS_()`
- `resetAdjointNOISELinearSystem_()`
- `solveAdjointNOISE_()`

这里的关键动作是：

- `blockSolver_->solveTranspose();`

这说明 `NOISE` 不是再做一次普通正向 solve，而是在解一个转置系统，对应 adjoint 思路。

### 5. 再从器件拿噪声源

在 `solveAdjointNOISE_()` 里，你会看到：

- `loader_.getNoiseSources(noiseDataVec_);`

也就是说：

```text
器件层会把各自的 noise source 谱密度和连接信息填进 noiseDataVec_
```

然后 `NOISE` 再用当前频点下的 adjoint 解，去计算：

- 每个器件噪声源的 `outputNoiseDens`
- `inputNoiseDens`
- `totalOutputNoiseDens`
- `totalInputNoiseDens`

### 6. 最后做积分

在 `doLoopProcess()` 里，频点循环过程中会调用：

- `noiseIntegral(...)`

把逐点谱密度积分成 total noise。

## 这一篇最想让你先吃下来的本质

从方程与求解角度看，`NOISE` 的身份可以先这样理解：

```text
它不是一个新的 nonlinear DAE 求解框架，
而是在 AC 的 small-signal frequency-domain 线性系统上，
继续计算器件噪声源到输出端的谱密度传播与积分。
```

所以这篇读完之后，最重要的不是先背所有 `noiseDataVec_` 字段，而是先把下面这条数学链站稳：

```text
原始 DAE
-> DCOP
-> small-signal linearization
-> (G + jωC) X = B
-> 器件噪声源作为等效小信号源进入系统
-> 用 adjoint / gain 计算输出噪声与输入参考噪声
-> 对频率积分得到 total noise
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `NOISE` 必须先建立在 `AC` 那种 small-signal 频域线性系统之上，而不是直接在原始 nonlinear DAE 上做“噪声 transient”？
2. 为什么 `NOISE` 比 `AC` 多出来的关键数学层，不是新的 time stepping，而是“噪声源传播 + adjoint + 频谱积分”？
