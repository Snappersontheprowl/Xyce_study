# advanced analysis type map

记录日期：2026-06-04

## 这篇的定位

这一篇先不深入数学细节，只建立 `AC / NOISE / HB / MPDE` 在分析层的总地图。

如果把 `05-analysis-flow/01-basic/` 理解成：

```text
.OP / .DC / .TRAN 的调度主线
```

那么这一篇就是在回答：

```text
Xyce 还有哪些更进阶的 analysis type，
它们在调度系统里大致站在什么位置？
```

## 建议的代码入口顺序

1. 先看 [N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)
2. 再看 [N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
3. 最后再按需要去看：
   - [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
   - [N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
   - [N_ANP_HB.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.C)
   - [N_ANP_MPDE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_MPDE.C)

这个顺序的逻辑是：

```text
先看注册和选择
-> 再看具体分析类的生命周期入口
```

## 当前可以先稳定记住的地图

从 [N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C) 可以直接看到，除了 `DCSweep` 和 `Transient`，Xyce 还注册了：

- `AC`
- `NOISE`
- `HB`
- `MPDE`
- `MOR`
- `ROL`

当前最值得先纳入主线的，是：

- `AC`
- `NOISE`
- `HB`
- `MPDE`

因为它们和“仿真类型扩展”关系最直接。

## 推荐的后续学习顺序

1. 先学 `AC`
   - 因为它最自然承接 `DCOP + Jacobian linearization`
2. 再学 `NOISE`
   - 因为它通常建立在 small-signal / frequency-domain 框架上
3. 再看 `HB`
4. 最后看 `MPDE`

## 这篇的边界

这一篇只做地图，不回答：

- `AC` 具体解什么方程
- `NOISE` 的噪声数学对象是什么
- `HB` 为什么不是普通 transient
- `MPDE` 的多时间尺度方程怎样展开

这些都属于 [../../06-solver-and-assembly/README.md](../../06-solver-and-assembly/README.md) 的进阶求解部分。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `AC` 比 `HB` 或 `MPDE` 更适合作为第一种进阶分析类型来学？
2. 为什么这一篇只做“分析类型地图”，而不直接去讲 `AC` 的 small-signal 方程？
