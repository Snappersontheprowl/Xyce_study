# ac small signal solving

记录日期：2026-06-05

## 这篇的定位

这一篇只回答：

```text
AC analysis 在数学上到底解什么，
以及它怎样从 DCOP 走到频域线性系统求解？
```

这篇不再讲 analysis object 是怎么被调度起来的，那部分已经放到：

- [../../05-analysis-flow/02-advanced/02-ac-lifecycle.md](../../05-analysis-flow/02-advanced/02-ac-lifecycle.md)

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_AC.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.h)
- [src/AnalysisPKG/N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
- [src/NonlinearSolverPKG/N_NLS_Manager.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.C)
- [src/LoaderServicesPKG/N_LOA_Loader.h](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_Loader.h)

## 当前结论先写在前面

`AC` 最适合先理解成下面这条数学主线：

```text
先求一个 DC operating point
-> 在这个工作点附近形成小信号线性化
-> 从 dFdx 和 dQdx 得到 G 和 C
-> 在每个频点上解一个频域线性系统
```

如果把最核心的频域系统压成一行，可以先记成：

$$
\left(G + j \omega C\right) x(\omega) = b(\omega)
$$

这和 `DC`、`transient` 的区别非常大：

- `DC`：解 nonlinear algebraic equation
- `transient`：解 time-discretized nonlinear equation
- `AC`：解围绕 `DCOP` 线性化后的 frequency-domain linear system

## 第零步：原始电路方程是什么

在你已经学过的主线里，电路原始上满足的还是那条 DAE：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

这里：

- $$x(t)$$ 是电路未知量
- $$Q(x)$$ 对应动态电荷/状态项
- $$F(x)$$ 对应静态导通项
- $$B(t)$$ 对应外部激励

如果直接看这条式子，`AC`、`transient`、`DC` 好像都从这里出发。  
真正的分叉点在于：

- `DC`：求一个稳态工作点
- `transient`：保留完整非线性和时间变化，直接做时域推进
- `AC`：先找到一个稳态工作点，再只研究这个工作点附近的**微小扰动**

所以 `AC` 的第一步不是“改写成频域”，而是先决定：

```text
我要研究的不是完整大信号轨迹，
而是 DC 工作点附近的小信号响应
```

## 第一步：为什么 AC 必须先有 DC operating point

先把稳态工作点记成 $$x^\*$$。  
在这个工作点上，直流方程满足：

$$
F(x^\*) - B_0 = 0
$$

这里 $$B_0$$ 是直流偏置源形成的常值激励。

这一点非常关键，因为 `AC` 研究的不是“任意状态附近的响应”，而是：

```text
在一个已经平衡的偏置点附近，
加一个很小的交流扰动之后，
系统怎么响应
```

如果没有先求出 $$x^\*$$，你后面做线性化时会一直残留一个“常值失配项”，也就是：

$$
F(x^\*) - B_0 \neq 0
$$

那后面的方程就不是纯粹的小信号响应方程，而会混进“工作点本身还没平衡”的误差。  
这就是为什么 `AC::doInit()` 里先显式调用：

- `nonlinearManager_.solve();`

先把 `DCOP` 解出来。

所以从数学上最该先记住的一句是：

```text
AC 不是从零开始求一个新解，
而是先找到平衡点，再研究平衡点附近的微小扰动。
```

## 第二步：小信号线性化到底是怎么做的

现在把真实变量拆成：

$$
x(t) = x^\* + \hat{x}(t)
$$

其中：

- $$x^\*$$ 是 DC 工作点
- $$\hat{x}(t)$$ 是围绕工作点的微小扰动

同样，把激励也拆成：

$$
B(t) = B_0 + \hat{b}(t)
$$

其中：

- $$B_0$$ 是直流偏置部分
- $$\hat{b}(t)$$ 是很小的交流激励

然后把它们代回原始 DAE：

$$
\frac{dQ(x^\*+\hat{x})}{dt} + F(x^\*+\hat{x}) - \left(B_0+\hat{b}(t)\right)=0
$$

这时才做真正的小信号线性化。  
对 $$Q$$ 和 $$F$$ 在 $$x^\*$$ 附近做一阶 Taylor 展开：

$$
Q(x^\*+\hat{x}) \approx Q(x^\*) + \left.\frac{\partial Q}{\partial x}\right|_{x^\*}\hat{x}
$$

$$
F(x^\*+\hat{x}) \approx F(x^\*) + \left.\frac{\partial F}{\partial x}\right|_{x^\*}\hat{x}
$$

把它们代回去：

$$
\frac{d}{dt}\left[
Q(x^\*) + \left.\frac{\partial Q}{\partial x}\right|_{x^\*}\hat{x}
\right]
+
F(x^\*)
+
\left.\frac{\partial F}{\partial x}\right|_{x^\*}\hat{x}
-
B_0
-
\hat{b}(t)
=0
$$

现在用到工作点条件：

$$
F(x^\*) - B_0 = 0
$$

并且因为 $$x^\*$$ 是常值工作点，所以：

$$
\frac{dQ(x^\*)}{dt}=0
$$

于是整条式子就退化成：

$$
\left.\frac{\partial Q}{\partial x}\right|_{x^\*}\frac{d\hat{x}}{dt}
+
\left.\frac{\partial F}{\partial x}\right|_{x^\*}\hat{x}
=
\hat{b}(t)
$$

如果记：

$$
C = \left.\frac{\partial Q}{\partial x}\right|_{x^\*}, \qquad
G = \left.\frac{\partial F}{\partial x}\right|_{x^\*}
$$

那么就得到：

$$
C\,\frac{d\hat{x}}{dt} + G\,\hat{x} = \hat{b}(t)
$$

这就是 `AC` 的真正时域小信号方程。

所以“怎么就线性化了”的答案其实很直接：

```text
不是把原始 nonlinear DAE 直接神秘替换掉，
而是在 DCOP 处对 Q 和 F 做一阶泰勒展开，
再利用工作点平衡条件把常值项消掉。
```

## 第三步：为什么这时可以从时域转到频域

上一步得到的是：

$$
C\,\frac{d\hat{x}}{dt} + G\,\hat{x} = \hat{b}(t)
$$

这已经和原始 `transient` 很不一样了。  
原始 `transient` 是非线性、随状态变化的；而这里我们已经得到一个在工作点附近的**线性时不变系统**：

- `C` 是在 $$x^\*$$ 处固定下来的矩阵
- `G` 也是在 $$x^\*$$ 处固定下来的矩阵

只要我们讨论的是“小信号、固定频率”的响应，就可以设：

$$
\hat{x}(t) = X(\omega)e^{j\omega t}
$$

$$
\hat{b}(t) = B(\omega)e^{j\omega t}
$$

因为对指数函数有：

$$
\frac{d}{dt}e^{j\omega t} = j\omega e^{j\omega t}
$$

代回去：

$$
C\,(j\omega X e^{j\omega t}) + G\,(X e^{j\omega t}) = B e^{j\omega t}
$$

把公共因子 $$e^{j\omega t}$$ 消掉，就得到：

$$
\left(G + j\omega C\right)X(\omega) = B(\omega)
$$

这就是 `AC` 真正的频域方程来源。

所以“怎么就从时域变成频域了”的本质不是“凭空做 Fourier 变换”，而是：

```text
先在 DCOP 附近把系统线性化成 LTI，
再利用正弦/复指数在 LTI 系统里的本征函数性质，
把 d/dt 变成 jω。
```

这一步一定要吃住，因为它就是 `AC` 和 `transient` 的真正分界线。

## 第四步：代码里为什么能把 dQdx 和 dFdx 当成 C 和 G

先看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `AC::doInit()`

这里会显式调用：

- `nonlinearManager_.solve();`

而且发生在 frequency loop 之前。

这一步最关键的函数是：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `updateLinearSystem_C_and_G_()`

它做的事情很关键：

1. 先清零：
   - `daeQVectorPtr`
   - `daeFVectorPtr`
   - `daeBVectorPtr`
   - `dQdxMatrixPtr`
   - `dFdxMatrixPtr`
2. 调：
   - `loader_.updateState(...)`
   - `loader_.loadDAEVectors(...)`
   - `loader_.loadDAEMatrices(...)`
3. 最后把：
   - `C_ = dQdxMatrixPtr`
   - `G_ = dFdxMatrixPtr`

也就是说，从当前学习主线看，最本质的一句话是：

```text
AC 并没有发明一套完全新的器件装配接口，
它仍然复用前面学过的 DAE 装配主线，
只是把 dQdx 和 dFdx 重新解释成频域线性系统里的 C 和 G。
```

这也是为什么我前面一直说：

```text
先学 DC / transient，再学 AC
```

因为到这里你会明显感觉到，前面的 `Q/F/dQdx/dFdx` 主线都没有白学。

## 第五步：频域线性系统是怎么组出来的

再看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `createLinearSystem_()`
- 和 `updateLinearSystemFreq_()`

这里非常关键的一点是：  
Xyce 在实现上没有直接把复数系统当成“一个抽象复矩阵”简单丢出去，而是显式构造了一个 2-block 线性系统。

在 `createLinearSystem_()` 里可以看到：

- `numBlocks = 2`
- 创建 `BlockVector`
- 创建 `BlockMatrix`

这一步可以先理解成：

```text
把复数系统拆成 real / imag 两个块来解
```

再看 `updateLinearSystemFreq_()`，这里会构造：

- 对角块加 `G`
- 非对角块放 `± ω C`

从代码结构上可以直接读出：

$$
\begin{bmatrix}
G & -\omega C \\
\omega C & G
\end{bmatrix}
\begin{bmatrix}
x_r \\
x_i
\end{bmatrix}
=
\begin{bmatrix}
b_r \\
b_i
\end{bmatrix}
$$

这就是把：

$$
\left(G + j\omega C\right)x = b
$$

拆成实部和虚部之后的线性系统。

## 第六步：每个频点真正解的是什么

继续看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `AC::doLoopProcess()`

这里的频点循环可以先压成：

1. 更新当前频率
2. 更新 `G`、`C`
3. 更新 `ω`
4. 更新激励 `B`
5. 调：
   - `solveLinearSystem_()`

而 `solveLinearSystem_()` 的关键动作是：

- `blockSolver_->solve();`

所以这一步最值得先站稳的认识是：

```text
AC 的频点循环里，核心求解动作已经不是 Newton，
而是“在每个频点上解一个组装好的线性系统”。
```

这就是 `AC` 和 `DC / transient` 最本质的求解差别。

## 第七步：AC 和 DC / transient 的最核心差别

到这一步，可以把三者压成一个对照。

### DC

$$
F(x) - B = 0
$$

- 非线性
- 需求工作点
- 用 Newton

### transient

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

- 非线性
- 有时间离散
- 每个时间步做 Newton

### AC

$$
\left(G + j\omega C\right)x(\omega) = b(\omega)
$$

- 建立在 `DCOP` 上
- 小信号线性化
- 每个频点解线性系统

所以一句话总结就是：

```text
AC 不是“再一种时间域 nonlinear solve”，
而是“围绕 DC 工作点形成的频域 linear solve”。
```

## 这一篇最想让你先吃下来的本质

你现在最值得真正吃住的一点是：

```text
AC 的起点不是“频域技巧”，
而是“在 DCOP 处把 nonlinear DAE 变成小信号 LTI 系统”；
只有在这一步之后，才谈得上把 d/dt 变成 jω，
以及把 dQdx / dFdx 解释成 C / G。
```

这就是为什么 `AC` 是进入进阶仿真最好的第一站。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `AC` 必须先有一个满足 $$F(x^\*)-B_0=0$$ 的工作点，后面的线性化才真正成立？
2. 为什么 `AC` 里把时域方程变成 $$\left(G+j\omega C\right)X=B$$ 的前提，不是“直接做频域变换”，而是“先得到一个围绕 DCOP 的线性时不变小信号系统”？
