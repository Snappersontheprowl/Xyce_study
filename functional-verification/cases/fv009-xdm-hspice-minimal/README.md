# FV-009 XDM HSPICE-like Minimal Conversion

## 目标

验证 XDM 2.7.0 binary 能否将一个最小 HSPICE-like 电阻网表转换为 Xyce 网表，并验证当前 Xyce 7.10.0 串行安装能否解析和运行转换结果。

## 输入

```text
input/resistor-hspice.sp
```

核心电路：

```text
V1 1 0 DC 1
R1 1 0 1k
.op
.print dc V(1) I(V1)
```

## 输出

XDM 转换后网表：

```text
out/resistor-hspice.sp
```

Xyce 结果文件：

```text
out/resistor-hspice.sp.csd
```

## 结果

```text
V(1)  =  1.00000000e+00
I(V1) = -1.00000000e-03
```

判断：通过。结果符合 `1 V / 1 kΩ = 1 mA`，电源电流按 Xyce 符号约定为负。

## 备注

XDM 将 `.option post` 保留为注释并报告 1 条 warning：

```text
* .option post; HSpice Parser Retained (as a comment). Continuing.
```

该 warning 不影响本用例运行。
