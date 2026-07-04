# transient sensitivity solving

记录日期：2026-07-04

## 这篇的定位

这一篇只讲 `Transient sensitivity` 的数学骨架。

这是三种灵敏度里最复杂的一种，因为它不再只面对：

- 一个静态工作点
- 或一个单频点线性系统

而是要面对：

```text
整条时间轨迹
+ 时间离散
+ 历史项
+ 每一步上的局部线性化
+ 以及可能的反向时间 adjoint
```

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_Transient.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

## 当前结论先写在前面

`Transient sensitivity` 最适合先压成下面两句话：

```text
direct transient sensitivity:
在每个时间步上，顺着 forward 时间积分，一步步求状态对参数的响应

transient adjoint sensitivity:
先跑完整条 forward 轨迹并把历史存起来，
再围绕某个输出时间点反向积分，把输出敏感度回传到各个参数
```

## 第一步：为什么 transient 比 DC 多出一个层次

原始电路 DAE 是：

$$
\frac{dQ(x,p)}{dt}+F(x,p)-B(t,p)=0
$$

这和 `DC` 最大的不同是：

- 有 $Q(x,p)$
- 有时间导数
- 现在要解的是轨迹 $x(t)$，不是单个工作点

所以参数变化的影响也不再只体现在一个静态残差上，而会沿时间传播。

## 第二步：直接在连续时间上看灵敏度方程

对

$$
\frac{dQ(x,p)}{dt}+F(x,p)-B(t,p)=0
$$

对参数 $p_k$ 求导，可得：

$$
\frac{d}{dt}
\left(
\frac{\partial Q}{\partial x}\frac{\partial x}{\partial p_k}
+
\frac{\partial Q}{\partial p_k}
\right)
+
\frac{\partial F}{\partial x}\frac{\partial x}{\partial p_k}
+
\frac{\partial F}{\partial p_k}
-
\frac{\partial B}{\partial p_k}
=0
$$

如果记

$$
s_k(t)=\frac{\partial x(t)}{\partial p_k}
$$

那么可以直觉地写成：

$$
\frac{d}{dt}\big(C(x,p)\,s_k + Q_{p_k}\big)
+
G(x,p)\,s_k
+
F_{p_k}
-
B_{p_k}
=0
$$

这里：

- $C=\partial Q/\partial x$
- $G=\partial F/\partial x$
- $Q_{p_k}=\partial Q/\partial p_k$
- $F_{p_k}=\partial F/\partial p_k$
- $B_{p_k}=\partial B/\partial p_k$

这一步说明：

```text
Transient sensitivity 的右端项不再只有 df/dp 和 db/dp，
还会出现 dq/dp 的时间导数项。
```

这正是它比 `DC sensitivity` 更复杂的根源。

## 第三步：真正进入数值求解时，方程会先被离散化

Xyce 实际上不是直接解连续时间灵敏度微分方程，而是先对原 transient 方程做时间离散。

离散后，每个时间步都会形成一个非线性残差：

$$
R_n(x_n, x_{n-1}, x_{n-2}, \dots, p)=0
$$

这里：

- $x_n$ 是当前时间步未知量
- 其余是历史量
- 具体形式依赖时间积分法，比如 BDF

这时对参数求导得到：

$$
\frac{\partial R_n}{\partial x_n}\frac{\partial x_n}{\partial p_k}
+
\frac{\partial R_n}{\partial p_k}
+
\text{history terms}
=0
$$

也就是：

$$
J_n\,s_{n,k}
=
-r_{n,k}^{(p,\text{hist})}
$$

其中：

- $J_n=\partial R_n/\partial x_n$ 是当前时间步 Jacobian
- $s_{n,k}=\partial x_n/\partial p_k$
- 右端项同时包含参数直接项和历史灵敏度项

所以 `Transient direct sensitivity` 的本质其实是：

```text
每个时间步上解一个“当前 Jacobian + 新右端项”的线性系统，
并把结果作为下一步历史的一部分继续往前传。
```

## 第四步：为什么 transient direct sensitivity 要顺着时间往前走

因为第 $n$ 步的灵敏度方程不只依赖当前步，还依赖前面已经发生过的历史：

$$
s_{n-1,k},\; s_{n-2,k},\;\dots
$$

所以它天然是一个 forward recurrence：

1. 先有 DCOP 或初值处的灵敏度起点
2. 再逐步推进到后续时间点
3. 每一步都用当前 Jacobian 和已有历史来求新的 $s_{n,k}$

这和普通 transient 求解的推进方式是同构的。

## 第五步：为什么 transient adjoint 需要反向时间积分

如果你只关心某个输出，比如：

- 某个终点时刻的电压
- 某个时间窗里的函数值
- 若干指定时刻的观测量

那么 direct 的问题是：

```text
它会把所有参数在整条轨迹上的状态灵敏度都算出来，
哪怕你最后只关心一个时间点的一个输出。
```

这就会很浪费。

所以 transient adjoint 会改写成：

1. 先完整跑一遍 forward transient
2. 保存后面反向所需的历史
3. 对目标输出构造伴随终端条件
4. 从目标时间点向过去反向积分伴随方程
5. 在反向过程中累积参数敏感度

所以它天然是：

```text
forward run 用来存历史
backward run 用来回传输出信息
```

## 第六步：为什么 forward 阶段必须先保存历史

这一点从代码里看得非常清楚。

在 `Transient::saveTransientAdjointSensitivityInfo()` 里，Xyce 会保存：

- `timeHistory`
- `dtHistory`
- `orderHistory`
- `solutionHistory`
- `stateHistory`
- `storeHistory`

并且还会把参数导数相关的函数右端项历史也保存起来。

这背后的数学原因是：

```text
反向积分时，
每一个伴随步都不是凭空算出来的，
它需要知道 forward 轨迹在那个时刻的真实状态、
时间步长、阶数、以及 df/dp、dq/dp、db/dp 等信息。
```

所以 transient adjoint 不像 `DC adjoint` 或 `AC adjoint` 那样只靠一个矩阵转置就完事了，它必须“回看”整条 forward 历史。

## 第七步：为什么 transient adjoint 的右端项里会出现 `df/dp + ddt(dq/dp) - db/dp`

在代码注释里，Xyce 明确把 transient adjoint 所需的函数导数写成：

```text
function derivative = df/dp + ddt(dq/dp) - db/dp
```

这和连续时间灵敏度方程完全一致。

因为原始 DAE 里最特殊的一项就是：

$$
\frac{dQ}{dt}
$$

所以对参数求导时，不可能只得到 `df/dp`，而一定还会产生：

$$
\frac{d}{dt}\left(\frac{\partial Q}{\partial p_k}\right)
$$

这也是 transient 比 `DC`、`AC` 数学上更重的地方。

## 第八步：DCOP 在 transient adjoint 里为什么被单独处理

在 `saveTransientAdjointSensitivityInfoDCOP()` 里，代码专门给 `DCOP` 存了一份历史，并且用一个极大的“伪时间步”：

$$
\Delta t = 10^{20}
$$

它的数学动机是：

```text
DCOP 本来是 steady-state，
理论上没有真正的时间推进；
但为了让 Jacobian 和后续 transient adjoint 的框架接得上，
实现里仍然需要把它放进统一的离散公式里。
```

所以这里的巨大时间步本质上是一种实现上的桥接技巧。

## 第九步：transient adjoint 的反向流程该怎样理解

从数学上，最关键的是把它理解成：

### 对每个目标时间点

选一个感兴趣的输出时刻 $t_\star$。

### 在这个时刻初始化伴随问题

把输出对状态的导数注入进去，相当于建立“这个输出到底关心哪些状态方向”。

### 再沿时间反向传播

从 $t_\star$ 往回走到更早时刻，把“输出对状态的关心”一点点回传。

### 在反向过程中对参数导数做积分/累积

于是最终得到：

$$
\frac{dy(t_\star)}{dp_k}
$$

这个结构和一般 ODE/PDE 伴随法是同一个思想。

## 第十步：和代码怎么对照

顺着代码看，最自然的顺序是：

1. 先读 `.options sensitivity` 里的 transient 专用选项：
   - [N_ANP_Transient.C:505](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L505)
2. 再读 `.SENS` 参数列表和 `SENSDEVICENAME`：
   - [N_ANP_Transient.C:635](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L635)
3. 再看初始化时怎样 `enableSensitivity(...)`：
   - [N_ANP_Transient.C:714](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L714)
4. 然后看 DCOP 成功后做什么：
   - [N_ANP_Transient.C:1681](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L1681)
5. 再看每个 transient 成功步后做什么：
   - [N_ANP_Transient.C:1834](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L1834)
6. 接着看 adjoint 需要保存哪些 forward 历史：
   - [N_ANP_Transient.C:2192](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L2192)
   - [N_ANP_Transient.C:2274](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L2274)
7. 最后看反向 adjoint 主循环：
   - [N_ANP_Transient.C:2357](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C#L2357)

## 当前这一篇学完后，应该记住什么

1. `Transient sensitivity` 的母方程来自
   $$
   \frac{dQ(x,p)}{dt}+F(x,p)-B(t,p)=0
   $$
   对参数求导，所以一定会出现 `dq/dp` 项。
2. 真正数值求解时，它先变成“每个时间步上的离散灵敏度方程”。
3. `Transient direct sensitivity` 是顺着时间正向推进的状态灵敏度递推。
4. `Transient adjoint sensitivity` 是先存完整 forward 历史，再围绕输出时间点反向积分。
5. 这也是为什么 transient adjoint 在工程实现上比 `DC`、`AC` 都要重得多。
