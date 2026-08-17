# 功能验证用例目录

## 功能

本目录保存每个可复现的 Xyce 功能验证用例，包括输入 netlist、运行日志和输出结果。

汇总性结论维护在 [../02-verification-results.md](../02-verification-results.md)，本目录只保存单个 case 的材料。

## 本级模块职责

- `README.md`：说明用例目录职责、命名规则和维护约定。
- `fv001-resistor-op/`：线性电阻 operating point 冒烟验证。
- `fv002-diode-iv/`：二极管 DC IV 非线性 sweep 验证。
- `fv003-rc-tran/`：RC 阶跃瞬态响应验证。
- `fv004-rc-ac/`：RC 小信号 AC 频响验证。
- `fv005-mos-dc/`：简单 MOSFET DC 曲线验证。
- `fv006-common-source-ac/`：共源放大器 OP + AC 验证。
- `fv007-noise/`：基础噪声分析验证。
- `fv008-model-card-compat/`：模型卡 include 兼容性验证。
- `fv009-xdm-hspice-minimal/`：XDM HSPICE-like 最小转换验证。
- `fv010-cube-resistor-equivalent/`：立方体电阻网络等效电阻验证。

## 命名规则

- 用例目录使用 `fvNNN-short-name/`。
- `NNN` 为三位递增编号，编号进入结果汇总后不复用、不重排。
- `short-name` 使用英文小写和连字符，描述验证目标。

## 当前约定

- 每个 case README 只说明本用例功能、文件职责和稳定验收标准。
- 数值结果和最终判断集中维护在上级 `02-verification-results.md`。
- 新增 case 后同步更新上级验证矩阵和结果汇总。
