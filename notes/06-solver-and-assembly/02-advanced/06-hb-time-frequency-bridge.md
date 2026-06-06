# hb time frequency bridge

记录日期：2026-06-06

## 这篇的定位

这一篇继续承接：

- [05-hb-solving-roadmap.md](05-hb-solving-roadmap.md)

但不再只停留在“HB 是什么”的层面，而是进一步回答：

```text
HB 在代码里到底是怎样把“频域谐波系数上的 nonlinear 问题”
和“普通器件更自然的时域装配”接起来的？
```

这条桥的核心角色就是：

- `HBLoader`
- `HBBuilder`
- `permutedIFT / permutedFFT`

## 这次读了哪些文件

- [src/LoaderServicesPKG/N_LOA_HBLoader.h](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_HBLoader.h)
- [src/LoaderServicesPKG/N_LOA_HBLoader.C](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_HBLoader.C)
- [src/LinearAlgebraServicesPKG/N_LAS_HBBuilder.h](../../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_HBBuilder.h)
- [src/AnalysisPKG/N_ANP_HB.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_HB.C)

## 当前结论先写在前面

`HB` 在实现上的关键桥梁，可以先压成下面这条主线：

```text
频域谐波系数向量 Xf
-> HBLoader::permutedIFT(...)
-> 一组 fast-time 时域样本块
-> 普通 appLoader 在每个 fast-time 样本上做器件装配
-> 得到时域 Q/F/B 和 time-domain Jacobian
-> HBLoader::permutedFFT(...)
-> 回到频域残差和频域 Jacobian 贡献
```

如果只抓一句话，我希望你先抓住：

```text
HB 不是要求器件自己直接写出封闭频域公式，
而是大量复用“普通时域器件装配”，
再靠时频变换把它包装成谐波系数上的 nonlinear 系统。
```

## 第一步：HB 的未知量在代码里到底是什么形状

在 `HB` 主线里，真正送进 nonlinear solve 的未知量，已经不是单个时刻的：

$$
x(t_n)
$$

而是一组谐波系数。

在代码里，这一层先由：

- [N_LAS_HBBuilder.h](../../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_HBBuilder.h)

负责组织。

从这个头文件里最值得先记住的是两类 block vector：

### 1. time-domain block vector

例如：

- `createTimeDomainBlockVector()`
- `createTimeDomainStateBlockVector()`

它对应的直觉是：

```text
block(i) = 第 i 个 fast-time 采样点上的整套电路未知量
```

### 2. expanded real form transpose block vector

例如：

- `createExpandedRealFormTransposeBlockVector()`

它对应的直觉是：

```text
block(n) = 第 n 个电路未知量在所有谐波上的 real/imag 系数
```

所以在 `HB` 里，最先要切开的一个概念就是：

```text
时域样本块
vs
频域谐波系数块
```

这两个 block 结构都不是“装饰性数据结构”，而是整个 HB 桥接的核心。

## 第二步：为什么要先从频域向量回到时域样本

现在看：

- [N_LOA_HBLoader.C](../../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_HBLoader.C)
  里的 `HBLoader::loadDAEVectors(...)`

这个函数一开始最关键的动作之一就是：

```cpp
Linear::BlockVector & bXf = *dynamic_cast<Linear::BlockVector*>(Xf);
permutedIFT(bXf, &*bXtPtr_);
```

也就是说：

```text
当前 nonlinear solver 送进来的频域未知量 Xf，
先被逆变换成时域样本块 bXtPtr_
```

为什么要先这么做？

因为普通器件更自然的装配接口，仍然是围绕：

- 某个时刻下的节点电压/状态
- 某个时刻下的 `Q/F/B`
- 某个时刻下的 `dQdx/dFdx`

而不是直接围绕“一组 Fourier 系数”。

所以从数学和实现的连接点看，`HB` 在这里做的事情非常朴素：

```text
先把谐波系数还原成一组时域采样点，
这样普通器件代码就还能继续在它熟悉的世界里工作。
```

## 第三步：在每个 fast-time 样本上，普通装配是怎么复用的

继续看 `HBLoader::loadDAEVectors(...)` 的主循环。

这里你会看到：

```cpp
for( int i = 0; i < BlockCount; ++i )
```

也就是：

```text
对每一个 fast-time 样本块，逐个处理
```

在每个样本块上，最关键的动作是：

1. `deviceManager_.setFastTime(times_[i] / fScalar);`
2. `appLoaderPtr_->updateSources();`
3. `appLoaderPtr_->updateState(..., Xyce::Device::NONLINEAR_FREQ);`
4. `appLoaderPtr_->loadDAEVectors(..., Xyce::Device::NONLINEAR_FREQ);`
5. `appLoaderPtr_->loadDAEMatrices(..., Xyce::Device::LINEAR_FREQ / NONLINEAR_FREQ);`

这一段最值得先抓住的本质是：

```text
HB 并没有发明一套完全不同的器件装配 API，
而是把普通 appLoader 在“某个时域样本点”上的工作，
一块一块地复用起来。
```

也就是说，在每个 fast-time 样本点上，器件仍然是在做你已经熟悉的事情：

- 写时域的 `Q`
- 写时域的 `F`
- 写时域的 `B`
- 写时域的 `dQdx`
- 写时域的 `dFdx`

只是现在这些东西不再只对应一个时间步，而是对应：

```text
一个周期内若干个采样点
```

## 第四步：为什么 HBLoader 要分别处理 linear 和 nonlinear Jacobian

在这个循环里，你会看到：

- 线性部分：
  - `Xyce::Device::LINEAR_FREQ`
- 非线性部分：
  - `Xyce::Device::NONLINEAR_FREQ`

而且：

- 线性部分会被放进 `linAppdQdxPtr_ / linAppdFdxPtr_`
- 非线性部分会按每个时间块存进：
  - `vecNLAppdQdxPtr_[i]`
  - `vecNLAppdFdxPtr_[i]`

这一步从实现角度先不用一下子吃透所有细节，但最重要的理解是：

```text
HBLoader 不只是把时域向量搬来搬去，
它还在为“频域上的 Jacobian 作用”提前把线性和非线性部分分开存好。
```

后面 matrix-free 应用时，才有可能：

- 对线性频域部分直接在频域上处理
- 对非线性部分先回时域再作用

这也解释了为什么你会在 `applyDAEMatrices(...)` 里看到：

- `permutedIFT(...)`
- 时域 matvec
- `permutedFFT(...)`
- 再加上线性频域矩阵作用

## 第五步：Q/F/B 是怎样从时域再回到频域的

在 `HBLoader::loadDAEVectors(...)` 后半段，你会看到：

```cpp
permutedFFT2(*bBt, bB);
permutedFFT2(*bQt, bQ);
permutedFFT2(*bFt, bF);
```

这三句非常关键。

它们说明：

```text
前面在每个时域采样点上装出来的 B/Q/F，
最后又被变换回频域 block 结构，
从而形成 HB nonlinear solve 真正要看到的频域残差对象。
```

也就是说：

- 时域样本块只是中间工作空间
- 最终交给 HB nonlinear solve 的，仍然是频域系数意义下的向量

这是 `HB` 这条桥里最核心的闭环之一：

```text
频域未知量
-> 时域样本装配
-> 频域残差
```

## 第六步：时间导数项在 HB 里怎么体现

这一点很容易混。

在 `transient` 里，我们熟悉的是：

$$
\frac{dQ}{dt}
$$

通过时间离散变成：

$$
\frac{1}{\Delta t}\frac{\partial Q}{\partial x}
$$

那在 `HB` 里，时间导数并不是靠时间步长离散出来，而是通过频域关系体现。

在 `applyDAEMatrices(...)` 那段代码里，你会看到它对 `bdQdxV` 做类似：

```text
乘以 ±ω
```

这正对应频域里：

$$
\frac{d}{dt} \leftrightarrow j\omega
$$

所以从本质上说：

```text
HB 里 dQ/dt 这一项没有消失，
只是它不再通过时间步长离散，
而是通过谐波频率上的 ±jω 作用体现在频域残差/Jacobian 里。
```

这正是 `HB` 与 `transient` 在“处理导数”上的根本不同。

## 第七步：为什么还会有 frequency-domain devices

在 `HBLoader::loadDAEVectors(...)` 里，除了时域样本循环，你还会看到：

- `updateFDIntermediateVars(...)`
- `loadFreqDAEVectors(...)`
- `loadFreqDAEMatrices(...)`

这说明 `HB` 不是百分之百都靠“先回时域再回来”。

某些器件/贡献可以更自然地直接按频域形式加载。  
所以 `HBLoader` 实际上在做两件事：

1. 大量复用时域装配
2. 同时允许某些 frequency-domain contribution 直接进入系统

所以更准确地说：

```text
HBLoader 是“时域样本装配 + 频域专用贡献”的混合桥梁
```

而不是单纯的 FFT 外壳。

## 第八步：applyDAEMatrices() 为什么值得单独记住

如果 `loadDAEVectors()` 主要是在建立：

```text
Q / F / B 的频域残差对象
```

那么：

- `applyDAEMatrices(...)`

更值得先理解成：

```text
频域 Jacobian 对某个向量 V 的作用，怎样被高效实现
```

它的大致逻辑是：

1. 先把频域向量 `Vf` 逆变换到时域块
2. 在时域上用存好的 nonlinear Jacobian 做 matvec
3. 再 FFT 回频域
4. 再叠加线性频域部分
5. 再把 `dQdx` 对应的导数项通过频率因子并入 `dFdx` 那一边

这一步的意义在于：

```text
HB 的 nonlinear solve 虽然是“频域系数上的 solve”，
但 Jacobian 的作用并不是通过一张朴素大矩阵硬乘出来的，
而是通过时频桥接和分块存储高效实现的。
```

## 这一篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
HB 在实现上的关键，不是先写出一张巨大的频域方程，
而是用 HBLoader 把“频域谐波系数上的 nonlinear 问题”
反复翻译成“时域采样点上的普通器件装配”，
再把结果送回频域残差和 Jacobian 作用。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `HBLoader::loadDAEVectors()` 一开始最关键的动作之一是 `permutedIFT(...)`，而不是直接在频域里调用普通器件装配？
2. 为什么 `HB` 里时间导数项的处理，更接近“频域中的 ±jω 作用”，而不是 `transient` 里的时间步长离散？
