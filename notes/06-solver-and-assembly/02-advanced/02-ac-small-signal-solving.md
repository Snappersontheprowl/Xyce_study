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

## 第一步：为什么 AC 先做 DCOP

先看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `AC::doInit()`

这里会显式调用：

- `nonlinearManager_.solve();`

而且发生在 frequency loop 之前。

这一步的数学意义非常直接：

```text
先找到工作点 x*
后面的 AC 不是围绕“任意状态”做分析，
而是围绕这个工作点做 small-signal linearization
```

所以 `AC` 并不是“绕开了 nonlinear solve”，而是：

- 先用 nonlinear solve 拿到 `DCOP`
- 再在这个 `DCOP` 附近转入线性频域分析

## 第二步：AC 用到的 G 和 C 从哪里来

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

## 第三步：频域线性系统是怎么组出来的

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

## 第四步：每个频点真正解的是什么

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

## 第五步：AC 和 DC / transient 的最核心差别

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
AC 仍然复用前面的器件装配骨架，
但它把 dQdx / dFdx 变成了频域小信号系统中的 C / G，
然后在每个频点上解一个线性块系统。
```

这就是为什么 `AC` 是进入进阶仿真最好的第一站。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `AC` 真正的求解核心不是“再做一轮 transient”，而是“围绕 DCOP 的小信号线性系统求解”？
2. 在 `AC` 里，`dQdx` 和 `dFdx` 为什么可以被重新理解成 `C` 和 `G`？
