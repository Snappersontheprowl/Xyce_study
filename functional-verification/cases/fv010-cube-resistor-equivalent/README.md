# FV-010: cube resistor equivalent resistance

## 目的

验证 Xyce 对稍复杂线性电阻网络的 DC operating point / MNA 求解是否正确。

本用例构造一个立方体电阻网络：

```text
8 个顶点
12 条边
每条边一个 1 kΩ 电阻
```

在一对空间对角顶点之间加 `1 V` 测试电压源，测量电压源电流，从而计算等效电阻。

## 理论值

对于所有边电阻均为 `R` 的立方体电阻网络，空间对角顶点之间的等效电阻为：

```text
Req = 5R / 6
```

本用例取：

```text
R = 1 kΩ
```

因此：

```text
Req = 5 * 1000 Ω / 6 = 833.333333 Ω
I = 1 V / Req = 1.2 mA
```

Xyce 电压源电流 `I(VTEST)` 的符号按电压源电流参考方向解释；验收时主要看绝对值：

```text
|I(VTEST)| ≈ 1.2 mA
```

## 节点命名

按立方体坐标命名：

```text
a = (0,0,0)
b = (1,0,0)
c = (1,1,0)
d = (0,1,0)
e = (0,0,1)
f = (1,0,1)
g = (1,1,1)
h = (0,1,1)
```

其中 `a` 与 `g` 是空间对角顶点。本 netlist 将 `g` 接为 SPICE ground `0`，并在 `a` 与 `0` 之间放置 `1 V` 测试源。

## 预期节点电压

由对称性可知：

```text
V(a) = 1.0 V
V(g) = 0.0 V
V(b) = V(d) = V(e) = 0.6 V
V(c) = V(f) = V(h) = 0.4 V
```

## 运行命令

```bash
cd /home/eda/my_lab/projects/study/xyce_study/functional-verification/cases/fv010-cube-resistor-equivalent
/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release/bin/Xyce cube-resistor-equivalent.cir > run.log 2>&1
```

## 验收

```text
V(a)        ≈ 1.0 V
V(b,d,e)    ≈ 0.6 V
V(c,f,h)    ≈ 0.4 V
|I(VTEST)|  ≈ 1.2 mA
Req         ≈ 833.333333 Ω
```

