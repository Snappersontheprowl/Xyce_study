# notation conventions

记录日期：2026-07-04

本文件只定义 `06-solver-and-assembly` 专题统一使用的符号。

## 总规则

- `x`：状态/未知量向量
- `p`：参数向量
- `y`：输出/观测量
- `t`：时间
- `\omega`：角频率
- `j`：虚数单位

## 工作点与扰动

- $x^*$：`DC operating point`
- $\Delta x(t)$：围绕 $x^*$ 的时域小扰动
- $\hat{x}$：单频小扰动的频域相量
- $B_0$：直流偏置激励
- $\Delta b(t)$：时域小信号激励
- $\hat{b}$：频域相量形式的小信号激励

统一默认：

$$
x(t)=x^*+\Delta x(t)
$$

$$
B(t)=B_0+\Delta b(t)
$$

$$
\Delta x(t)=\Re\{\hat{x}e^{j\omega t}\},
\qquad
\Delta b(t)=\Re\{\hat{b}e^{j\omega t}\}
$$

## 原始 DAE 与基本对象

- $Q(x,p)$：动态电荷/状态项
- $F(x,p)$：静态导通/代数项
- $B(t,p)$：外部激励项

原始 DAE 统一写成：

$$
\frac{dQ(x,p)}{dt}+F(x,p)-B(t,p)=0
$$

## Jacobian 与线性化

- $J=\dfrac{\partial f}{\partial x}$：一般残差 Jacobian
- $G=\left.\dfrac{\partial F}{\partial x}\right|_{x^*}$：工作点处的 conductance-like Jacobian
- $C=\left.\dfrac{\partial Q}{\partial x}\right|_{x^*}$：工作点处的 capacitance-like Jacobian

## 各分析的常用写法

### DC

$$
F(x,p)-B(p)=0
$$

### transient

$$
\frac{dQ(x,p)}{dt}+F(x,p)-B(t,p)=0
$$

### AC

时域小信号方程：

$$
C\,\frac{d(\Delta x)}{dt}+G\,\Delta x=\Delta b(t)
$$

频域相量方程：

$$
J_{AC}(\omega)\hat{x}=\hat{b}
$$

其中：

$$
J_{AC}(\omega)=G+j\omega C
$$

## 灵敏度

- $\dfrac{\partial x}{\partial p}$：解对参数的敏感度
- $\dfrac{\partial y}{\partial p}$：输出对参数的敏感度
- $\lambda$：adjoint / 伴随向量

direct sensitivity 基本式：

$$
J\frac{\partial x}{\partial p}=-\frac{\partial f}{\partial p}
$$

输出映射：

$$
\frac{\partial y}{\partial p}
=
\frac{\partial g}{\partial x}\frac{\partial x}{\partial p}
+
\frac{\partial g}{\partial p}
$$

adjoint 基本式：

$$
J^T\lambda=\left(\frac{\partial g}{\partial x}\right)^T
$$

## 索引与维度

- $n$：状态变量个数
- $m$：参数个数
- $q$：输出个数
- $i,j$：状态索引
- $k$：参数索引
- $\ell$：输出索引

统一默认：

$$
x\in\mathbb{R}^n,\qquad
p\in\mathbb{R}^m,\qquad
y\in\mathbb{R}^q
$$

## 使用约束

- 带 `*`：工作点/基准点
- 带 `\Delta`：时域小扰动
- 带 `\hat{}`：频域相量
- 写成 `(\omega)`：强调频率依赖
- 若无特殊说明，`x`、`p`、`y` 默认指向量而不是标量
