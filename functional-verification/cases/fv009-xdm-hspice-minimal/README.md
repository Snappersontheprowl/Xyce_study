# FV-009: XDM HSPICE-like minimal conversion

## 功能

本用例验证 XDM binary 是否能将最小 HSPICE-like 电阻网表转换为 Xyce 网表，并验证当前 Xyce 是否能解析和运行转换结果。

## 本级模块职责

- `README.md`：说明本用例目标和验收标准。
- `input/`：保存原始 HSPICE-like 输入网表。
- `out/`：保存 XDM 转换后的网表和 Xyce 输出结果。

## 验收标准

- XDM 转换无 critical issue / error。
- 转换后网表可被当前 Xyce 解析和运行。
- 最小电阻电路结果符合：

```text
V(1)    = 1 V
|I(V1)| = 1 mA
```

`.option post` 被 XDM 作为注释保留时，属于本用例可接受 warning。
