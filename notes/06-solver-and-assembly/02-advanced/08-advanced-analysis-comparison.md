# advanced analysis comparison

记录日期：2026-06-07

## 这篇的定位

这一篇不是新分析类型，也不是新的代码追踪笔记。  
它只做一件事：

```text
把 AC / NOISE / HB / MPDE 放到同一张地图里，
横向比较它们在“数学目标、未知量、方程形态、求解骨架”上的差异。
```

如果只抓一句话，我希望你先抓住：

```text
这四类分析的真正分界线，
不在“文件名不同”，
而在“它们到底把原始电路 DAE 变成了什么样的问题”。
```

## 这一组横向收束所依赖的前置笔记

- [02-ac-small-signal-solving.md](02-ac-small-signal-solving.md)
- [03-noise-analysis-solving.md](03-noise-analysis-solving.md)
- [04-adjoint-for-noise.md](04-adjoint-for-noise.md)
- [05-hb-solving-roadmap.md](05-hb-solving-roadmap.md)
- [06-hb-time-frequency-bridge.md](06-hb-time-frequency-bridge.md)
- [07-mpde-solving-roadmap.md](07-mpde-solving-roadmap.md)

## 共同起点：它们都从同一条原始 DAE 出发

这几类分析的共同起点仍然是原始电路 DAE：

$$
\frac{dQ(x)}{dt} + F(x) - B(t) = 0
$$

真正的差别不在起点，而在它们各自怎样“重新组织问题”。

- `AC`：先找 `DCOP`，再围绕工作点做小信号线性化
- `NOISE`：在 `AC` 的小信号频域线性系统上继续做噪声传播
- `HB`：直接假设目标是周期稳态，把问题改写到有限谐波系数空间
- `MPDE`：把时间拆成 `slow time + fast time`，先沿 fast time 离散，再在 slow time 上推进 block 系统

## 先给一张总表

| 分析类型 | 数学目标 | 是否依赖 DCOP | 主要未知量 | 系统类型 | 主要求解动作 |
| --- | --- | --- | --- | --- | --- |
| `AC` | 工作点附近的小信号频域响应 | 是 | 小信号频域向量 $$X(\omega)$$ | 线性 | 每个频点解一次线性系统 |
| `NOISE` | 小信号线性系统中的噪声传播 | 是，且依赖 `AC` 框架 | 输出响应/adjoint 向量 | 线性 | 正向小信号解 + adjoint/噪声投影 |
| `HB` | 周期稳态的大信号非线性平衡 | 常常需要 DCOP/Transient 初值，但本体不是 DC 小信号 | 有限谐波系数 $$\hat{x}$$ | 非线性代数系统 | 对谐波系数做 Newton |
| `MPDE` | 多时间尺度下的慢包络 + 快振荡联合求解 | 常常需要 DCOP/Transient 初值 | slow-time 上的 block-vector $$X(t_1)$$ | block DAE | fast-time 离散后，再用 transient 外壳推进 slow time |

## 第一组对比：AC 和 NOISE

### AC 在做什么

`AC` 的关键步骤是：

1. 先求一个 `DC operating point`
2. 在工作点 $$x^\*$$ 附近做一阶线性化
3. 得到小信号时域系统

$$
C\frac{d\hat{x}}{dt}+G\hat{x}=\hat{b}(t)
$$

4. 再把它转到频域

$$
\left(G+j\omega C\right)X(\omega)=B(\omega)
$$

所以 `AC` 的本质是：

```text
DCOP 附近的小信号频域线性响应
```

### NOISE 在做什么

`NOISE` 并没有重新定义一套完全不同的方程。  
它建立在 `AC` 已经给出的线性频域系统上，进一步回答：

```text
器件噪声源经过这个小信号网络后，怎样传到输出？
```

所以它的本体不是新的 nonlinear 求解，而是：

- 先有 `AC` 的线性系统
- 再把噪声源当作频域小信号源
- 再计算输出噪声谱密度和输入参考噪声

也就是说：

```text
AC 解决“响应是什么”
NOISE 解决“噪声如何传播到输出”
```

### 这一组最该抓住的分界

`AC` 和 `NOISE` 都属于：

```text
DCOP 上的小信号频域线性世界
```

其中：

- `AC` 更像主框架
- `NOISE` 更像在这个线性框架上的扩展分析

## 第二组对比：HB 和 MPDE

### HB 在做什么

`HB` 的核心假设是：

$$
x(t+T)=x(t)
$$

也就是直接寻找周期稳态解。  
它会把周期波形写成有限谐波展开：

$$
x(t)\approx x_0+\sum_{k=1}^{K}\left(a_k\cos(k\omega_0 t)+b_k\sin(k\omega_0 t)\right)
$$

最终未知量不再是时间轨迹，而是这组谐波系数。

所以 `HB` 的本质是：

```text
直接在有限谐波系数空间里解一个周期稳态的大信号 nonlinear system
```

### MPDE 在做什么

`MPDE` 的核心不是“直接周期稳态化”，而是引入双时间变量：

$$
x(t)\approx \hat{x}(t_1,t_2)
$$

其中：

- $$t_1$$ 是 slow time
- $$t_2$$ 是 fast time

然后把原始 DAE 提升成多时间尺度 PDE，再先对 fast time 离散，最后得到：

```text
slow-time 上推进的 block-vector DAE
```

所以 `MPDE` 的本质是：

```text
保留 slow-time 演化，
只把 fast oscillation 作为第二个时间尺度显式拆出来
```

### 这一组最该抓住的分界

这两类都比 `AC/NOISE` 更“重”，而且都常常要借 `DCOP/transient` 来喂初值。  
但它们的目标问题不一样：

- `HB`：直接求周期稳态，不再推进轨迹
- `MPDE`：仍然推进 slow-time 轨迹，只是快周期结构被单独拆开

一句话压缩：

```text
HB 是“周期稳态系数求解”
MPDE 是“多时间尺度 block transient”
```

## 第三组对比：AC/NOISE 与 HB/MPDE 的大分界

如果把这四类再压成两大阵营，最清楚的分界是：

### 阵营 A：围绕 DCOP 的小信号频域分析

- `AC`
- `NOISE`

它们的共同特征是：

- 先有 `DC operating point`
- 再做局部线性化
- 后续主要求解是线性的
- 频率点之间通常彼此独立

### 阵营 B：大信号 / 多时间尺度分析

- `HB`
- `MPDE`

它们的共同特征是：

- 不只是围绕一个工作点的小扰动
- 系统仍然保留显著非线性
- 需要更重的初始化和 block 结构
- 代码里会出现更专门的 `Builder / Loader / block vector` 基础设施

这就是最重要的一层分界：

```text
AC/NOISE 属于“小信号线性化世界”
HB/MPDE 属于“大信号/多时间尺度世界”
```

## 如果只从“最终未知量”来记，会更稳

有时候按最终未知量去记，比按文件名去记更牢。

- `AC`
  - 未知量：$$X(\omega)$$
  - 含义：某个频点上的小信号响应

- `NOISE`
  - 未知量：线性系统响应 / adjoint 量
  - 含义：输出对噪声源的传播结果

- `HB`
  - 未知量：$$\hat{x}$$
  - 含义：一个周期波形的有限谐波系数

- `MPDE`
  - 未知量：$$X(t_1)$$ block vector
  - 含义：slow time 上每个时刻对应的一整套 fast-time 样本块

如果你记住这四个“未知量长什么样”，后面再看代码会清楚很多。

## 当前学习主线可以怎样收束

到这里，你可以把进阶分析类型的第一轮学习收束成下面这张图：

$$
\frac{dQ(x)}{dt}+F(x)-B(t)=0
$$

从这条原始 DAE 出发：

- `AC`
  - `DCOP` + 小信号线性化 + 频域线性求解
- `NOISE`
  - `AC` 线性系统 + 噪声传播 + adjoint
- `HB`
  - 周期稳态假设 + 有限谐波展开 + 频域 nonlinear 平衡
- `MPDE`
  - slow/fast 双时间变量 + fast-time 离散 + slow-time block transient

## 当前这篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
这四类分析不是“多了几个不同菜单项”，
而是对同一条原始电路 DAE 施加了四种不同的问题重组方式。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `NOISE` 和 `AC` 更像同一个“小信号频域世界”的两层，而 `HB` 和 `MPDE` 已经进入另一个“大信号/多时间尺度世界”？
2. 如果只看最终未知量，你会怎么用一句话区分 `HB` 和 `MPDE`？
