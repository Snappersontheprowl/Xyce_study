# sensitivity analysis solving

记录日期：2026-06-07

## 这篇的定位

这一篇集中回答你关心的三件事：

1. 解对参数的敏感度
2. 某个输出对参数的敏感度
3. `adjoint` 为什么能省计算

这一篇先讲数学原理，再配合 `DC / AC / Transient` 的代码入口去对照。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_DCSweep.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
- [src/AnalysisPKG/N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
- [src/AnalysisPKG/N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

## 当前结论先写在前面

灵敏度分析最适合先压成下面这三句话：

```text
解敏感度：参数 p 变化时，整套状态向量 x 怎么变
输出敏感度：参数 p 变化时，某个观测量 y 怎么变
adjoint：当“参数很多、输出很少”时，用一次或少量转置求解替代大量正向求解
```

如果只抓一句话，我希望你先抓住：

```text
输出敏感度通常不是“另一个完全独立的问题”，
而是“解敏感度经过输出映射后的结果”；
adjoint 的价值，就在于它能直接针对输出映射工作，而不必先把整套解敏感度都算出来。
```

## 第一步：先把“解”和“输出”分开

设系统方程写成：

$$
f(x,p)=0
$$

这里：

- $x$ 是整套仿真未知量
- $p$ 是某个参数

==那么**解对参数的敏感度**是：==

$$
\frac{\partial x}{\partial p}
$$

它表示：

```text
参数 p 变一点，整个状态向量 x 会怎样变
```
如果输出写成：

$$
y = g(x,p)
$$
> 模拟电路中观测量基本上就是只依赖于状态解和参数，或者再加一个时间维度

==那么**输出敏感度**是：==

$$
\frac{\partial y}{\partial p}
$$

它表示：

```text
参数 p 变一点，我真正关心的那个观测量 y 会怎样变
```

这两个对象不是一回事。

## 第二步：输出敏感度和解敏感度的关系

根据链式法则：

$$
\frac{\partial y}{\partial p}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial g}{\partial p}
$$

这条式子很关键，因为它说明：

- 如果先有 $\partial x / \partial p$
- 再有输出映射 $g$

就能得到 $\partial y / \partial p$，所以更准确地说：

```text
输出敏感度通常是“解敏感度经过输出映射后的结果”
```

## 第三步：从系统方程推导“解敏感度方程”

现在从：

$$
f(x,p)=0
$$

对参数 $p$ 求导：
*细节参考：*[detail_matrix](docs/notes/06-solver-and-assembly/03-sensitivity/detail_matrix.md)

$$
\frac{\partial f}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial f}{\partial p}
=0
$$

记：

$$
J = \frac{\partial f}{\partial x}
$$

则有：

$$
J\frac{\partial x}{\partial p} = -\frac{\partial f}{\partial p}
$$

这就是最核心的 direct sensitivity 方程。

这一条式子告诉你：

```text
解敏感度并不是“额外神秘对象”，
而是一个和原系统 Jacobian 共用同一左端矩阵的线性方程组。
```

## 第四步：这为什么天然导向 direct sensitivity

对每一个参数 $p_i$，都要解：

$$
J\frac{\partial x}{\partial p_i} = -\frac{\partial f}{\partial p_i}
$$
*细节参考：*[detail_solver_process](docs/notes/06-solver-and-assembly/03-sensitivity/detail_solver_process.md)
所以如果参数有很多个，就意味着：

- 左端矩阵都是同一个 $J$
- 右端项每个参数不同
- 需要重复解很多次

这就是 direct sensitivity 的核心特征：

```text
按参数一个个解出整套状态对参数的变化
```

如果你关心的是：

- 每个状态量对参数怎么变
- 或者参数不多

这种方法就很自然。

## 第五步：adjoint 为什么会出现

如果你不关心整套 $\partial x/\partial p$，而只关心某一个输出：

$$
y=g(x,p)
$$

那么直接先把每个参数的 $\partial x/\partial p$ 全部算出来，往往会很贵。

这时从：

$$
\frac{\partial y}{\partial p}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial g}{\partial p}
$$

和：

$$
J\frac{\partial x}{\partial p} = -\frac{\partial f}{\partial p}
$$

结合起来，可以得到：

$$
\frac{\partial y}{\partial p}
=
\frac{\partial g}{\partial p}
-
\frac{\partial g}{\partial x}J^{-1}\frac{\partial f}{\partial p}
$$

现在引入 adjoint 变量 $\lambda$，令：

$$
J^T\lambda = \left(\frac{\partial g}{\partial x}\right)^T
$$

则有：

$$
\frac{\partial y}{\partial p}
=
\frac{\partial g}{\partial p}
-
\lambda^T \frac{\partial f}{\partial p}
$$

这一步就是 adjoint 方法的核心。

## 第六步：为什么 adjoint 能省计算
*细节参考：*[detail_less_computation](docs/notes/06-solver-and-assembly/03-sensitivity/detail_less_computation.md)
现在可以直接看复杂度。

### direct 方法

如果有：

- 参数个数 = $N_p$
- 输出个数 = $N_o$

那么 direct 更像：

```text
按参数做求解
```

通常需要大约 $N_p$ 次线性求解。

### adjoint 方法

adjoint 更像：

```text
按输出做求解
```

通常需要大约 $N_o$ 次转置线性求解。

所以：

- 参数很多、输出很少：adjoint 更划算
- 输出很多、参数很少：direct 更自然

这就是最本质的省计算原因：

```text
adjoint 不是把数学变简单了，
而是把“求解次数按参数计”改成了“求解次数按输出计”。
```

## 第七步：AC 里的灵敏度为什么最容易看懂

`AC` 里灵敏度的数学最直观，因为它主系统本来就是线性的。

`AC` 主系统可以写成：

$$
A(p)x = b(p)
$$

这里的 $A$ 就是小信号频域系统矩阵。

对参数求导：

$$
A\frac{\partial x}{\partial p}
=
\frac{\partial b}{\partial p}
-
\frac{\partial A}{\partial p}x
$$

这就是 `AC` 里 direct sensitivity 的直接形式。

在：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)

里，`solveDirectSensitivity_()` 的注释其实已经把这条式子写得很清楚了。

你会看到它反复做：

- `loadSensitivityRHS_(ipar);`
- `blockSolver_->solve(...)`

也就是说：

```text
对每个参数构造一个新的 RHS，
然后用同一个 AC 小信号矩阵去求对应的 dx/dp
```

## 第八步：AC 里的输出敏感度和 adjoint

在 `AC` 里，输出通常是某个目标函数：

$$
y = g(x)
$$

于是 adjoint 变量满足：

$$
A^T\lambda = \left(\frac{\partial g}{\partial x}\right)^T
$$

在代码里，对应的就是：

- `solveAdjointSensitivity_()`
- `blockSolver_->solveTranspose(...)`

然后再对每个参数做：

```text
sensRhs · lambda
```

从而得到各个参数对应的输出敏感度。

这一层最值得先记住的是：

```text
AC adjoint 不是在求整个 dx/dp，
而是在先求“输出怎么看整个线性系统”的 λ，
再让每个参数的 RHS 去投影这份 λ。
```

## 第九步：Transient 里的 direct 和 adjoint 为什么更重

`Transient` 比 `AC` 重，是因为这里的主系统不再只是单个频点上的线性方程，而是整个时间过程。

### direct transient sensitivity

在 forward transient 过程中，Xyce 会在每个时间步上调用：

- `nonlinearManager_.calcSensitivity(...)`

也就是说，direct transient sensitivity 更像：

```text
跟着每个时间步一起推进状态敏感度
```

### adjoint transient sensitivity

而 `Transient::doTransientAdjointSensitivity()` 会在 forward transient 结束后：

- 选定目标输出时间点
- 反向时间积分
- 在每个反向步调用：
  - `initializeAdjoint(...)`
  - `updateAdjointCoeffs()`
  - `calcTransientAdjoint(...)`

所以它更像：

```text
先保存 forward 历史，
再从某个输出时刻往回做一轮或多轮反向积分
```

这也是为什么 transient adjoint 在生命周期上会明显比 AC 的 adjoint 更重。


## 当前这篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
灵敏度分析的核心，不是“再解一个新电路”，
而是对已有方程系统 f(x,p)=0 做参数微分；
direct 先求整个解对参数的变化，
adjoint 则直接围绕输出对参数的变化来组织求解次数。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说“输出敏感度”通常是“解敏感度经过输出映射后的结果”，而不是一个和解敏感度毫无关系的新对象？
2. 如果一个问题里参数很多、输出很少，为什么 adjoint 通常比 direct 更划算？
