# sensitivity analysis flow

记录日期：2026-07-03

这个子目录放的是灵敏度分析在 **工程代码实现层** 的专题。

这一组只回答：

- 灵敏度分析怎样附着在现有主分析上
- `.SENS` / `SENSITIVITY` 在调度层如何进入系统
- `DC / AC / Transient` 在生命周期上怎样分别挂入灵敏度求解
- 为什么灵敏度更像一个 capability layer，而不是独立主分析类型

## 当前内容

1. [01-sensitivity-lifecycle.md](01-sensitivity-lifecycle.md)
2. [02-dc-sensitivity-lifecycle.md](02-dc-sensitivity-lifecycle.md)
3. [03-ac-sensitivity-lifecycle.md](03-ac-sensitivity-lifecycle.md)
4. [04-transient-sensitivity-lifecycle.md](04-transient-sensitivity-lifecycle.md)

## 这一组的边界

这一组仍然属于 `05-analysis-flow`，所以只讲工程实现上的：

- 注册
- 选择
- 生命周期
- 灵敏度功能在主分析流程中的接入位置
- 哪一层打开 `sensFlag_`
- 哪一层进入 `direct / adjoint` 分支

真正涉及：

- 解对参数的敏感度
- 输出对参数的敏感度
- direct / adjoint 的数学推导
- 为什么 adjoint 更省计算

这些内容统一放到：

- [../../06-solver-and-assembly/03-sensitivity/README.md](../../06-solver-and-assembly/03-sensitivity/README.md)
