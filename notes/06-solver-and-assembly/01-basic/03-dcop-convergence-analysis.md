# dcop convergence analysis

记录日期：2026-07-13

## 这篇的定位

前一篇 [03-dc-operating-point-solving.md](03-dc-operating-point-solving.md) 已经把 `DCOP` 的求解骨架讲清楚了：

- 稳态下要求解的是
  $$
  F(x)-B=0
  $$
- 数值上通过 Newton 迭代反复解
  $$
  J(x_k)\Delta x_k=-f(x_k)
  $$

这篇继续往前走一步，不再问“它怎么做”，而是问：

```text
这个迭代为什么有时会收敛，
有时却会发散、震荡或者卡死？
```

也就是从**数学收敛性**角度重新审视 `DCOP`。

## 这次读了哪些文件

这次不是重新追完整个 `DCOP` 生命周期，而是只围绕“收敛性”回看最关键的几层：

- [03-dc-operating-point-solving.md](03-dc-operating-point-solving.md)
- [src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C)
- [src/NonlinearSolverPKG/N_NLS_DampedNewton.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_DampedNewton.C)
- [src/NonlinearSolverPKG/N_NLS_NOX_Interface.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NOX_Interface.C)

这些文件在逻辑上的顺序是：

1. 先确认 `DCOP` 目标方程是什么
2. 再确认 `NoTimeIntegration` 下 residual 的具体形式
3. 再看 Newton 主循环里怎样处理 step length
4. 最后看 Newton 失败时，Xyce 会怎样切换到 continuation 类策略

## 这次带着什么问题去读

这篇只回答收敛性相关的问题：

- 牛顿法是不是天然保证收敛？
- 如果不保证，它在什么条件下才会收敛？
- 为什么在电路 `DCOP` 里这些条件经常被破坏？
- `damped Newton`、`voltage limiting`、`gmin stepping`、`source stepping`、`pseudo-transient` 分别在数学上修补了什么问题？

## 当前结论先写在前面

对 `DCOP` 来说，Newton 法**不是全局必收敛算法**，它本质上只有局部收敛性质。

更准确地说：

1. 如果真解附近足够光滑，且 Jacobian 在真解处可逆，并且初值已经足够靠近真解，那么 Newton 往往会很快收敛。
2. 如果初值离真解太远、方程有多个根、Jacobian 奇异或病态、或者电路本身就没有可达的稳态解，那么 Newton 可能发散、震荡、跳到别的解，甚至根本无法继续。
3. Xyce 的工程实现并不假设“裸 Newton 一定会成功”，而是额外叠加了阻尼、voltage limiting 和 continuation 类策略，来扩大可收敛的初值区域。

所以理解 `DCOP` 收敛性时，最重要的一句话是：

```text
Newton 的问题不在“局部近似不精确”，
而在“当前点的局部线性化未必足以代表远处的真实非线性方程”。
```

## 第一步：先把数学问题重新写清楚

在 `DCOP` 下，原始电路 DAE 退化成：

$$
F(x)-B=0
$$

记

$$
f(x)=F(x)-B
$$

那么任务就是求：

$$
f(x)=0
$$

Newton 在第 $k$ 步做的事情不是“直接解原方程”，而是：

1. 在当前点 $x_k$ 处线性化
2. 解线性近似问题
3. 用解到的修正量更新当前点

也就是：

$$
f(x_k+\Delta x)\approx f(x_k)+J(x_k)\Delta x
$$

令线性近似为零，得到：

$$
J(x_k)\Delta x_k=-f(x_k)
$$

然后更新：

$$
x_{k+1}=x_k+\lambda_k \Delta x_k
$$

这里的关键不在公式本身，而在一个很容易被忽略的事实：

```text
Newton 每一步依赖的只是“当前点附近的一阶信息”。
```

所以它天然是一种**局部方法**。

## 第二步：Newton 为什么只具有局部收敛性

经典数值分析里，Newton 法最常见的收敛结论可以压成下面三条。

### 1. 真解附近要足够光滑

通常要求：

- `f(x)` 可微，最好在真解附近二阶连续可微
- Jacobian 不要突然剧烈变化

因为 Newton 的核心假设就是：

```text
在当前点附近，一阶线性化足够像真实函数
```

如果函数在这一带太“尖”、太“陡”、太不规则，那么一阶近似可能很快失真。

### 2. 真解处的 Jacobian 要可逆

如果真解 $x^*$ 满足：

$$
f(x^*)=0
$$

但

$$
J(x^*)
$$

是奇异的或接近奇异的，那么 Newton 步本身就会变得不稳定。

直观上说：

```text
你想用切平面反推“该往哪走”，
但这张切平面自己已经塌了或几乎塌了。
```

这时即使方程有解，Newton 也可能收敛很慢，甚至完全失效。

### 3. 初值必须已经离真解足够近

这是最关键的一条。

Newton 的局部收敛定理并不是说：

```text
只要开始迭代，最后一定会到某个根
```

而是说：

```text
如果你一开始就已经进入某个根的“收敛域”，
那么迭代会越来越好，甚至呈现二次收敛。
```

所以 Newton 的真正难点，经常不是“后几步不够快”，而是：

```text
前几步能不能顺利走进那个局部收敛区。
```

## 第三步：一旦满足条件，为什么它会收敛得很快

如果 $x_k$ 已经很接近真解 $x^*$，而且 $J(x^*)$ 可逆，那么 Newton 往往有：

$$
\|e_{k+1}\|\approx C\|e_k\|^2
$$

其中：

$$
e_k=x_k-x^*
$$

这就是常说的**二次收敛**。

它的直观含义是：

- 误差从 `1e-1` 可能很快掉到 `1e-2`
- 然后掉到 `1e-4`
- 再掉到 `1e-8`

所以工程上才会喜欢 Newton：

```text
一旦进圈，它通常非常猛。
```

但这句话的前提一定要保留：

```text
前提是已经进圈。
```

## 第四步：为什么它不具备全局保证

如果当前点离真解很远，那么当前点的切线或切平面很可能把你带去一个完全不靠谱的位置。

最简单的一维图像可以这样想：

- 你站在曲线上一点
- 在这一点画切线
- 用切线和横轴的交点当作下一步

如果当前点离根很远，或者函数弯得很厉害，这条切线可能：

- 直接跨过根飞到很远
- 落到另一个吸引域
- 在几个点之间反复来回跳

所以裸 Newton 常见的失败形式有：

1. 发散：$\|f(x_k)\|$ 越来越大
2. 震荡：在几个点之间反复跳
3. 错根收敛：收敛到了另一个平衡点
4. 线性系统失稳：`J(x_k)` 奇异或病态，方向解不可靠
5. 无解：原问题本身就没有满足 `f(x)=0` 的物理解

## 第五步：把这些失败形式放回 `DCOP`

电路 `DCOP` 比教科书上的简单非线性方程更容易出收敛问题，原因主要有四类。

### 1. 器件方程本身很陡

比如 diode、BJT、MOS 的电流对电压往往是强非线性的。  
这意味着：

- `F(x)` 变化很快
- `dF/dx` 可能很大
- Jacobian 会随工作点剧烈变化

于是“当前点的一阶近似”能代表多大范围，往往很有限。

### 2. 电路可能有多个工作点

例如强反馈、锁存器、双稳态结构，可能同时存在多个静态平衡点。

这时 Newton 不是只问“能不能收敛”，还要问：

```text
它会收敛到哪个根？
```

不同初值可能落入不同吸引域。

### 3. 拓扑可能导致 Jacobian 接近奇异

你在上一篇已经看到，`NoTimeIntegration::obtainJacobian()` 里，Xyce 明知 `DC` 没有真实的 `dQ/dt`，仍然混入了一个极小的 `dQdx` 项：

$$
10^{-20} dQdx + dFdx
$$

原因是某些只通过电容连接的节点会让纯 `dFdx` 矩阵变得奇异。  
这说明在 `DCOP` 里，收敛问题有时甚至不是“步子走错了”，而是：

```text
线性化矩阵本身就不好解。
```

### 4. 初值往往并不好

教科书上的 Newton 常常默认你有一个“差不多的初值”。  
但真实电路里，初值可能只是：

- 默认零向量
- 某个预测值
- 某个上一步工作点

这并不保证它已经在正确根的吸引域里。

## 第六步：Xyce 为什么默认就不是“裸 Newton”

这一点从源码里看得非常清楚。

在 [N_NLS_DampedNewton.C](../../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_DampedNewton.C) 里，Newton 主循环不是“算出方向就全步长更新”，而是：

1. `jacobian_()`
2. `direction_()`
3. `computeStepLength_()`
4. 再检查 `converged_()`

这意味着 Xyce 默认就承认：

```text
Newton 方向本身可能是对的，
但一步走多远仍然是另一个问题。
```

也就是说，求出 $\Delta x_k$ 还不够，还要决定 $\lambda_k$。

## 第七步：阻尼 Newton 在数学上修补了什么

阻尼 Newton 把更新写成：

$$
x_{k+1}=x_k+\lambda_k \Delta x_k,\qquad 0<\lambda_k\le 1
$$

它不是改变 Newton 方向，而是缩短步长。

数学上，它修补的是这个问题：

```text
线性化给出的“最优修正”只在一个局部邻域里可信，
如果一步跨太远，反而可能跑出这个邻域。
```

所以阻尼的作用可以理解成：

- 不让切线法一步跳太猛
- 尝试让残差范数真正下降
- 把“容易过冲”的方法改成“更保守但更稳”的方法

代价也很明显：

- 收敛可能变慢
- 不再保持理想状态下的最快速度

但工程上通常值得，因为：

```text
慢一点总比直接炸掉好。
```

## 第八步：voltage limiting 在数学上相当于“限制局部模型的适用范围”

在 [N_TIA_NoTimeIntegration.C](../../../vendor/Xyce-7.10.0/src/TimeIntegrationPKG/N_TIA_NoTimeIntegration.C) 的 `obtainResidual()` 里，可以看到如果 `limiterFlag` 打开，Xyce 会把额外的 limiting 量加回 residual。

从数学视角看，voltage limiting 不是在改变最终要求解的根，而是在改变每一步迭代的走法：

- 某些器件端电压不能在一步里变化过大
- 否则指数型器件的局部线性化会瞬间失真

所以它可以看成：

```text
在变量空间里人为限制“单步允许跨越的局部区域”
```

这和单纯的统一缩小步长很像，但更细粒度，因为它经常是针对最敏感的器件变量来做约束。

## 第九步：gmin stepping 在数学上是同伦 continuation

如果直接解：

$$
F(x)-B=0
$$

太难，`gmin stepping` 的思路是先求一个“更容易”的近邻问题：

$$
F(x)+gGx-B=0,\qquad g \text{ 很大}
$$

这里额外加进去的导通项可以让系统更“漏”、更稳定、更像一个好解的问题。

然后逐步减小 $g$，一路追踪解，直到回到原问题：

$$
g\to 0
$$

这就是 continuation / homotopy 的思想：

```text
不是硬解原问题，
而是从一个容易的问题平滑走回原问题。
```

从源码上也能看到，Xyce 在标准 Newton 失败后会切到 `gmin stepping` 路线，而不是简单地“再试几次同样的牛顿法”。

## 第十步：source stepping 在数学上是在缩放外部激励

如果问题主要是源激励太强，导致原方程太难，那么就可以先解：

$$
F(x)-\alpha B=0,\qquad \alpha=0
$$

再慢慢把：

$$
\alpha: 0 \rightarrow 1
$$

当 $\alpha=0$ 时，问题往往容易得多。  
然后把源一点点“打开”，在每一个中间问题上用上一步的解做下一步初值。

这个方法的本质仍然是 continuation，只不过 continuation 的参数不是 `gmin`，而是源的缩放系数。

## 第十一步：pseudo-transient 为什么也能帮助 `DCOP`

这招在直觉上特别好理解。

如果稳态方程

$$
F(x)-B=0
$$

太难直接解，那么先人为构造一个“假时间”动力系统：

$$
C\frac{dx}{d\tau}+F(x)-B=0
$$

其中 $\tau$ 不是物理时间，而是一个数值上的松弛时间。

这样你就不再是“硬找根”，而是先让系统沿着一个耗散动力学慢慢往稳态靠近。  
等已经靠近稳态之后，再切回真正的 steady-state Newton solve。

所以 pseudo-transient 的本质是：

```text
把“直接找平衡点”改成“先沿人工动力系统流向平衡点”。
```

它修补的是：

- 初值离稳态太远
- 直接做 steady-state Newton 很容易跳飞

## 第十二步：把几种方法放在一个统一框架里看

如果只记零散技巧，很容易越学越碎。  
更好的方式是把它们统一理解成：

```text
如何把当前迭代点重新带回某个“局部线性化还可信”的区域
```

它们对应的修补动作分别是：

- `damped Newton`
  - 少走一点，避免一步跨太远
- `voltage limiting`
  - 对敏感变量单独限制单步变化
- `gmin stepping`
  - 先解一个更容易、更稳定的近邻问题
- `source stepping`
  - 先把外部激励缩小，再逐步恢复
- `pseudo-transient`
  - 先走一段人工动力学，再回 steady-state solve

从这个角度看，它们并不是五个互不相干的技巧，而是五种不同层面的**收敛域扩展机制**。

## 一个最小例子：为什么 diode 电路会让 Newton 很脆弱

考虑最简单的单节点二极管方程：

$$
\frac{V_S-v}{R}-I_S\left(e^{v/V_T}-1\right)=0
$$

记为：

$$
f(v)=0
$$

如果当前猜测 $v_k$ 很大，那么：

- 指数项可能极大
- 导数
  $$
  f'(v_k)
  $$
  也可能极大

这时 Newton 步：

$$
\Delta v_k=-\frac{f(v_k)}{f'(v_k)}
$$

并不一定自然把你带回合理区域。  
如果局部线性化对指数曲线的代表范围很小，一步大跳就可能把下一点扔到另一个失真更严重的区域。

这就是为什么 diode / BJT / MOS 一类器件在 `DCOP` 里经常需要：

- damping
- limiting
- continuation

## 这篇最想让你真正吃住的 5 句话

1. `DCOP` 的 Newton 法只具有局部收敛性，不具备天然的全局保证。
2. 真解附近 Jacobian 可逆、函数足够光滑、初值足够接近真解时，Newton 往往会很快收敛。
3. 电路问题里的多工作点、强非线性、坏初值和近奇异 Jacobian，会不断破坏这些理想条件。
4. Xyce 的阻尼、limiting 和各种 stepping，本质上都在努力扩大“可收敛初值区域”。
5. 所谓“收敛技巧”不是在替代 Newton，而是在帮 Newton 活着走进它自己的局部收敛区。

## 现在可以做的自检

你可以试着自己回答下面 3 个问题：

1. 为什么说 Newton 失败时，问题不一定出在方向错了，也可能出在“步长太大”？
2. `gmin stepping` 和 `source stepping` 都是 continuation，它们修改的对象分别是什么？
3. 为什么 pseudo-transient 可以看成“先找一条通向稳态的路，再切回直接找稳态点”？

## 下一步建议

如果这一篇已经吃稳，下一步最自然的延伸有两条：

1. 回到器件层，具体看 diode / MOS 为什么会让 `dF/dx` 变得如此敏感。
2. 继续下钻 Xyce 的 nonlinear solver，专门读 `computeStepLength_()`、`converged_()` 和 NOX/LOCA 的 continuation 组织方式。

如果只选一条作为当前主线，我更建议先走第 2 条，因为它正好能把“数学收敛性”继续落到“Xyce 具体怎么保命”。
