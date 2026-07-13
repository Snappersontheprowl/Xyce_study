# dae solving checkpoint

记录日期：2026-07-13

## 这篇的定位

前面四篇已经分别讲了：

- [01-dae-assembly-pipeline.md](01-dae-assembly-pipeline.md)：`Q/F/B/dQdx/dFdx` 是怎么被装出来的
- [02-dae-math-solving.md](02-dae-math-solving.md)：`DC` 和 `transient` 在数学上各自解什么
- [03-dc-operating-point-solving.md](03-dc-operating-point-solving.md)：`DCOP` 怎样退化成稳态非线性方程
- [04-transient-time-discretization-and-solving.md](04-transient-time-discretization-and-solving.md)：`transient` 怎样变成“每步一个 nonlinear solve”

这篇不再新增并列概念，而是做一个阶段检查点，只回答一个问题：

```text
把前面四篇压缩成一句话，
Xyce 到底是怎样把电路 DAE 变成“可被 Newton + linear solve 处理的问题”的？
```

## 这次读了哪些文件

为了把前面四篇真正串起来，这次回看和核对了这些源码位置：

- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)
- [src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C)
- [src/TimeIntegrationPKG/N_TIA_Gear12.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_Gear12.C)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)

重点盯的函数只有 6 个：

- `NonlinearEquationLoader::loadRHS()`
- `NonlinearEquationLoader::loadJacobian()`
- `NoTimeIntegration::obtainResidual()`
- `NoTimeIntegration::obtainJacobian()`
- `Gear12::obtainResidual()`
- `Gear12::obtainJacobian()`

## 当前结论先写在前面

Xyce 并不是让器件“直接生成最终 residual 和最终 Jacobian”，而是按下面这条链来工作：

```text
device equations
-> Q / F / B / dQdx / dFdx
-> NonlinearEquationLoader 收集 DAE 组件
-> time integration 负责把 DAE 组件重组成当前分析所需的方程
-> nonlinear solver 反复执行 residual load / Jacobian load / linear solve
```

所以这条主线里最重要的分工，不是“谁调用了谁”，而是：

- device 层负责写出物理方程组件
- time integration 层负责把组件改写成当前分析的代数问题
- nonlinear solver 层负责迭代求解这个代数问题

## 一张总图先压住全局

可以先把 Xyce 的 DAE 求解心智模型记成下面这张图：

```text
原始电路方程：
    dQ(x)/dt + F(x) - B(t) = 0

device 层写出：
    Q, F, B, dQdx, dFdx

loadRHS / loadJacobian：
    先把 DAE 组件清零、收集、放进 DataStore

time integration：
    DC    -> 构造 F - B
    TRAN  -> 构造 alpha/dt * Q + F - B

nonlinear solver：
    rhs_() -> jacobian_() -> newton_()

linear solver：
    解当前 Newton 步对应的线性修正量
```

如果这张图稳了，后面看 `AC / HB / sensitivity` 时就不容易乱。

## 第一步：器件层先写的不是“最终方程”，而是 DAE 组件

这一点前面已经出现过，但非常值得在检查点里再强调一次。

器件层最先写出来的是：

- `Q`
- `F`
- `B`
- `dQdx`
- `dFdx`

也就是说，器件并不知道当前外面到底是在做：

- `DC`
- `transient`
- 还是别的时间/频域分析

它只负责把自己的物理贡献写成 DAE 的标准组件形式。

这一步的意义很大，因为它让：

- 器件建模
- 时间离散
- 非线性求解

三件事彼此解耦了。

## 第二步：`NonlinearEquationLoader` 负责把 DAE 组件组织起来

在 [N_LOA_NonlinearEquationLoader.C](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C) 里：

- `loadRHS()` 会先清零 `daeQ / daeF / daeB`
- 然后 `updateState(...)`
- 再调用 `loadDAEVectors(...)`
- 最后才交给 `wim_.obtainResidual()`

对应地：

- `loadJacobian()` 会先清零 `dQdx / dFdx`
- 再调用 `loadDAEMatrices(...)`
- 最后交给 `wim_.obtainJacobian()`

所以这一层最值得先抓住的话是：

```text
NonlinearEquationLoader 负责把“器件给的 DAE 组件”
交给“时间积分方法”去拼成当前 residual / Jacobian。
```

它本身并不决定 `DC` 和 `transient` 的数学区别，真正决定区别的是下一层 `time integration`。

## 第三步：time integration 决定“当前方程长什么样”

这是这次学习最核心的一步。

同样一组 `Q/F/B/dQdx/dFdx`，在不同时间积分方法下会被拼成不同的方程。

### `DC`：`NoTimeIntegration`

在 [N_TIA_NoTimeIntegration.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C) 里：

- `obtainResidual()` 把 `daeF - daeB` 组出来，然后整体乘 `-1`
- `obtainJacobian()` 基本把 `dFdx` 当成主 Jacobian

所以 `DC` 下要解的本体是：

$$
F(x) - B = 0
$$

而 nonlinear solver 实际拿到的 `RHSVectorPtr` 是：

$$
-(F(x)-B)
$$

这也是为什么读 Xyce 源码时，必须一直记得：

```text
RHS 里存的是 -f(x)，不是 f(x)
```

### `transient`：`Gear12`

在 [N_TIA_Gear12.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_Gear12.C) 里：

- `obtainResidual()` 先把历史 `Q` 项和当前 `Q` 项按 `alpha` 系数拼起来
- 再把 `F - B` 合进去
- 最后同样乘 `-1`

最朴素地理解，它对应的就是：

$$
\Phi_n(x_n)
=
\frac{Q(x_n)-Q(x_{n-1})}{\Delta t}
+ F(x_n) - B(t_n)
= 0
$$

高阶 `Gear/BDF` 只是把“一个历史点”推广成“多个历史点加权”。

而 `obtainJacobian()` 里最关键的一句就是：

$$
J_n =
\frac{\alpha_0}{\Delta t}\frac{\partial Q}{\partial x}(x_n)
+
\frac{\partial F}{\partial x}(x_n)
$$

所以 transient 和 DC 的真正区别，不是“有没有 Newton”，而是：

```text
每一步 Newton 所面对的方程不同。
```

## 第四步：nonlinear solver 只做迭代求解，不重新发明方程

在 [N_NLS_NonLinearSolver.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C) 里，这个角色分工非常清楚：

- `rhs_()` 调 `nonlinearEquationLoader_->loadRHS()`
- `jacobian_()` 调 `nonlinearEquationLoader_->loadJacobian()`
- `newton_()` 调线性求解器 `solve(false)`

这说明 nonlinear solver 的任务是：

```text
对“已经由 DAE + time integration 形成好的当前方程”
反复做 Newton 迭代
```

它不负责解释器件物理，也不负责定义时间离散公式。

所以这层最适合记住的一句话是：

```text
nonlinear solver 求的是“当前 Newton 修正量”，
不是直接一次算出整条波形。
```

## 一个最小例子：RC 节点在 `DC` 和 `transient` 下分别会变成什么

为了把公式落地，可以一直用一个最小心智例子：

```text
一个节点 v
并到地的电容 C
并到地的电阻 R
再加一个注入电流源 I(t)
```

把节点电压记成未知量 `v`，那么原始 DAE 可以写成：

$$
\frac{d(Cv)}{dt} + \frac{v}{R} - I(t) = 0
$$

这时：

- `Q(v) = Cv`
- `F(v) = v/R`
- `B(t) = I(t)`
- `dQ/dv = C`
- `dF/dv = 1/R`

### 在 `DC` 下

因为稳态时：

$$
\frac{d(Cv)}{dt}=0
$$

所以方程退化成：

$$
\frac{v}{R} - I = 0
$$

注意这里电容不通过 `Q` 参与稳态平衡方程本体。

### 在 `transient` 下

如果先用最朴素的 backward Euler 去理解，那么当前步方程就是：

$$
\frac{C(v_n-v_{n-1})}{\Delta t} + \frac{v_n}{R} - I_n = 0
$$

于是当前步 Jacobian 会变成：

$$
\frac{C}{\Delta t} + \frac{1}{R}
$$

这个小例子正好把两类分析的差别压得很清楚：

- `DC` 只看静态平衡
- `transient` 会把储能元件通过 `Q` 和 `dQdx` 拉进当前步方程

## 这次最值得单独记住的 4 个易混点

### 1. `RHSVectorPtr` 存的是 `-f(x)`

这在 `DC` 和 `transient` 两边都成立。  
如果把它看成 `f(x)`，后面很多符号都会整体反掉。

### 2. transient 不是“解一整个时间区间的大方程”

它本质上是：

```text
时间推进
+ 每个时间步上的 nonlinear solve
```

### 3. linear solver 解的是 Newton 修正量，不是最终答案

线性求解器负责的是当前迭代中的：

$$
J(x_k)\Delta x_k = -f(x_k)
$$

或 transient 当前步对应的线性化修正系统。

### 4. `DC` 代码里仍然能看到一点点 `dQdx`

在 `NoTimeIntegration::obtainJacobian()` 里，Xyce 用了一个极小系数把 `dQdx` 混进 Jacobian，主要是为了避免某些纯电容拓扑带来的奇异矩阵问题。  
这不是在说 `DC` 真的重新引入了物理时间导数，而是一种数值上的防护手段。

## 到这里应该具备的能力

如果这一轮学到位了，你现在应该已经能独立回答下面 4 个问题：

1. 为什么说 device 层先写的是 `Q/F/B/dQdx/dFdx`，而不是最终 residual / Jacobian？
2. 为什么同一套 DAE 组件，在 `DC` 和 `transient` 下会变成不同方程？
3. 为什么 transient 的 Jacobian 比 DC 多出一块 `alpha/dt * dQdx`？
4. 为什么 linear solver 求到的是“当前 Newton 步修正量”，而不是“一次算完的时域轨迹”？

## 一个小练习

试着不用翻前文，自己回答下面这个变式：

```text
如果一个节点只连电容，不连任何直流导通路径，
为什么 DCOP 可能会遇到奇异问题，
而 transient 却会因为 alpha/dt * dQdx 的存在而多出一条“当前步导纳”？
```

如果你能把这个问题讲顺，说明你已经不只是记住了公式，而是真的抓住了 `Q` 和 `F` 在两类分析中的角色差异。

## 下一步建议

这个检查点之后，最自然的下一步不是继续补 solver 抽象层，而是顺着 `Q/F/B/dQdx/dFdx` 回到器件端，重点读：

- [../../07-device-model-contributions/02-capacitor-and-q-contribution.md](../../07-device-model-contributions/02-capacitor-and-q-contribution.md)
- [../../07-device-model-contributions/03-diode-and-nonlinear-f.md](../../07-device-model-contributions/03-diode-and-nonlinear-f.md)

因为到这里以后，真正值得继续深挖的问题已经变成：

```text
这些 DAE 组件到底是器件层怎样写出来的？
```
