# FV-007: basic noise analysis

## 目的

确认当前 Xyce binary 是否支持常见 NOISE 分析路径，以及输出格式是否可用。

## 预期

若当前构建支持 `.NOISE`，应生成噪声相关输出；若语法或功能失败，记录首个错误作为当前能力边界。
