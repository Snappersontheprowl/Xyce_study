# sensitivity solver and math

记录日期：2026-06-07

这个子目录放的是灵敏度分析在“方程与求解”层面的专题。

这一组只回答：

- 解对参数的敏感度是什么
- 某个输出对参数的敏感度是什么
- direct sensitivity 和 adjoint sensitivity 分别在算什么
- 为什么 `adjoint` 在“参数很多、输出很少”时更省计算

## 当前内容

1. [01-sensitivity-analysis-solving.md](01-sensitivity-analysis-solving.md)

## 这一组的边界

这一组仍然属于 `06-solver-and-assembly`，所以只讲：

- 数学对象
- 方程推导
- Jacobian / 输出映射 / 转置求解
- `DC / AC / Transient` 中的求解骨架

如果你想先看：

- `.SENS` 是怎么进入系统的
- 灵敏度为什么不是独立主分析对象
- `DC / AC / Transient` 在生命周期上怎样挂入 sensitivity

应该先回到：

- [../../05-analysis-flow/03-sensitivity/README.md](../../05-analysis-flow/03-sensitivity/README.md)
