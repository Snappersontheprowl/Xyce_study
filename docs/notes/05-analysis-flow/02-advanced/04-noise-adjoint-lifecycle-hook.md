# noise adjoint lifecycle hook

记录日期：2026-06-06

## 这篇的定位

这一篇不是去重复讲 `adjoint` 的数学原理。  
那部分已经放在：

- [../../06-solver-and-assembly/02-advanced/04-adjoint-for-noise.md](../../06-solver-and-assembly/02-advanced/04-adjoint-for-noise.md)

这一篇只回答：

```text
从分析调度和生命周期视角看，
adjoint 在 NOISE analysis 里是在哪几个阶段被挂进去的？
```

也就是说，我们只看：

- 它什么时候准备
- 它什么时候被调用
- 它为什么被放在 frequency loop 的这个位置

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
- [03-noise-lifecycle.md](03-noise-lifecycle.md)

## 当前结论先写在前面

从生命周期视角看，`NOISE` 里的 adjoint 主线可以先压成：

```text
NOISE::doLoopProcess()
-> setupAdjointRHS_()
-> frequency sweep loop
   -> solveACLinearSystem_()
   -> resetAdjointNOISELinearSystem_()
   -> solveAdjointNOISE_()
```

最值得先记住的一点是：

```text
adjoint 不是在 NOISE 初始化期一次性做完的，
而是每个频点上都要在 AC 小信号解之后再接一段“转置系统求解”。
```

## 第一步：为什么 adjoint 不放在 doInit() 里

先回忆：

- [03-noise-lifecycle.md](03-noise-lifecycle.md)

里已经讲过，`NOISE::doInit()` 主要负责：

1. 整理 sweep 参数
2. 求 `DCOP`
3. 装 AC 用的 `B` 向量
4. 处理输出节点
5. 准备噪声源容器

这一步还不能真正完成 adjoint solve，原因很直接：

```text
adjoint 对应的是“当前频点下的线性系统”
```

而当前频点对应的：

- `omega`
- `G + j\omega C`

还没有在 `doInit()` 里真正循环建立起来。

所以从生命周期角度看，adjoint 不能被塞进初始化阶段一次性做完。  
它必须等到：

```text
当前频点已经确定，
当前频点的 AC 线性系统已经更新好
```

之后才能接上。

## 第二步：adjoint 的准备动作为什么先放在 loop 外

看：

- [N_ANP_NOISE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_NOISE.C)
  里的 `NOISE::doLoopProcess()`

在进入 frequency loop 之前，你会先看到：

- `setupAdjointRHS_();`

这一步的位置很重要。

它说明从控制流角度看：

```text
和输出观测量有关、且不依赖具体频点的那一部分 adjoint 信息，
可以先在 loop 外准备一次。
```

也就是说：

- 输出节点是谁
- 观测量是单端还是差分
- 对应的 RHS 结构是什么

这些东西不需要每个频点都重新构造。

所以这一步最值得先记成：

```text
adjoint 的“输出观测量编码”先做一次
```

而不是：

```text
adjoint 的整个求解过程都先做一次
```

## 第三步：为什么每个频点都要先 solve AC 再 solve adjoint

再看 `doLoopProcess()` 的主循环，你会看到顺序是：

1. 更新当前频点
2. 更新 AC 线性系统
3. `solveACLinearSystem_()`
4. `resetAdjointNOISELinearSystem_()`
5. `solveAdjointNOISE_()`

这个顺序非常值得先吃住，因为它说明：

```text
NOISE 里的 adjoint 不是替代 AC solve，
而是接在 AC 频点系统之后的第二段动作。
```

为什么是这个顺序？

因为生命周期上，当前频点至少要先把这些东西定住：

- 当前 `omega`
- 当前的 block 线性系统
- 当前输出响应和增益信息

只有这些都建立好，后面的：

- 输出参考噪声
- 输出噪声谱密度
- `GainSqInv_`

这些量才有意义。

所以从控制流视角，你可以先这样记：

```text
一个频点上的 NOISE 工作流
= 先做 AC 正向解
+ 再做 adjoint 噪声解
```

## 第四步：resetAdjointNOISELinearSystem_() 在生命周期上是什么意思

看：

- `resetAdjointNOISELinearSystem_()`

从生命周期角度，它最值得先理解成：

```text
把当前这次线性求解，从“普通 AC 右端项”切换成“adjoint 右端项”
```

也就是说：

- 线性系统矩阵本身还是那个当前频点下的系统
- 变化的是右端项 `B_`
- 以及接下来要调用的求解方向

所以这一步不是：

```text
重新建一个完全不同的 NOISE 矩阵
```

而更像：

```text
在同一个频点线性系统框架下，
切换到 adjoint 那个求解任务
```

这就是为什么它适合作为一个单独的 lifecycle hook。

## 第五步：solveAdjointNOISE_() 在生命周期上扮演什么角色

再看：

- `solveAdjointNOISE_()`

这一步内部当然包含：

- `solveTranspose()`
- `loader_.getNoiseSources(noiseDataVec_)`

但从 `05` 的视角，我们不急着讲它们的线性代数意义，而先记它的生命周期角色：

```text
它是“当前频点上，把输出观测量和器件噪声源真正接起来”的那一步
```

也就是说，只有到了这一步，`NOISE` 的主循环才真正开始从：

- AC 小信号响应

过渡到：

- 器件噪声贡献评估

所以在控制流层，这一步最值得先抓的不是公式，而是它的地位：

```text
它是 frequency loop 里噪声分析真正落地的核心 hook
```

## 第六步：为什么 adjoint hook 必须在每个频点上重复

这一点从调度视角也很关键。

虽然：

- `setupAdjointRHS_()` 可以 loop 外做一次

但：

- `resetAdjointNOISELinearSystem_()`
- `solveAdjointNOISE_()`

都必须每个频点重做。

原因不是“代码想写成这样”，而是因为从 lifecycle 角度：

```text
adjoint 对应的是“当前频点下”的线性系统，
而频点一变，系统也就变了。
```

所以这里最自然的组织方式就是：

- loop 外做与输出观测量相关的固定准备
- loop 内对每个频点单独完成 adjoint 求解和噪声评估

## 这篇和 03-noise-lifecycle 的关系

这一篇和：

- [03-noise-lifecycle.md](03-noise-lifecycle.md)

的关系是：

- `03`
  - 先给出 NOISE 整体生命周期地图
  - 告诉你它是 “DCOP + frequency sweep + noise processing”

- `04`
  - 把其中最容易卡住的 `adjoint` 这一段单独抽出来
  - 解释它在控制流上是怎样插进 frequency loop 的

这样拆开之后，`03` 不会太重，而 `04` 又能把这个关键钩子单独讲清楚。

## 这一篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
从生命周期视角看，
adjoint 在 NOISE 里不是“额外附会的一段数学”，
而是 frequency loop 里一个固定的位置：
先 AC solve，
再切换 RHS 和求解方向，
再做噪声贡献评估。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `setupAdjointRHS_()` 可以放在 frequency loop 外，而 `solveAdjointNOISE_()` 必须放在 loop 内？
2. 为什么从控制流视角看，`adjoint` 最适合被理解成 `NOISE` 在每个频点上追加的一段第二阶段线性动作？
