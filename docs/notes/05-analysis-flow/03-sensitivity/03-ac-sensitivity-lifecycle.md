# ac sensitivity lifecycle

记录日期：2026-07-04

## 这篇的定位

这一篇只看 `AC sensitivity` 在工程代码里的挂接顺序。

不展开数学推导，只回答：

```text
AC 灵敏度的配置在哪里读入，
对象什么时候准备好，
每个频点上 direct / adjoint 又是在什么位置被调用？
```

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)

## 当前结论先写在前面

`AC sensitivity` 的工程主线可以压成：

```text
.SENS / .options sensitivity 先把参数、目标和策略读进来
-> 创建 AC block system 时顺手分配 sensitivity 相关对象
-> 每个频点先求 AC 主系统
-> 成功后再进入 solveSensitivity_()
-> 再分成 direct / adjoint 两个分支
```

## 第一步：先看 `.SENS` 读了什么

顺着文件最先看：

- [N_ANP_AC.C:259](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L259)

`AC::setSensAnalysisParams(...)` 负责处理 `.SENS` 这一层。

这里主要读两类东西：

1. 目标函数 / 观测量
   - `ACOBJFUNC`
   - `OBJVARS`
2. 参数列表
   - `PARAM...`

所以在 `AC` 里，灵敏度配置的第一层是：

```text
我要对哪些参数求灵敏度
我要观察哪些 AC 输出
```

## 第二步：再看 `.options sensitivity` 读了什么

继续顺着同一个文件往下读：

- [N_ANP_AC.C:331](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L331)

`AC::setSensitivityOptions(...)` 负责处理策略层选项。

这里最重要的是：

- `ADJOINT`
- `DIRECT`
- `FORCEDEVICEFD`
- `FORCEANALYTIC`
- `REUSEFACTORS`

这说明 `AC` 的 sensitivity 配置明确分成两层：

### 第一层：我要做 sensitivity

来自 `.SENS`

### 第二层：我具体怎么做

来自 `.options sensitivity`

这比 `DC` 多了一层显式策略控制。

## 第三步：创建 AC 线性系统时，就顺手把 sensitivity 对象建好

再顺着文件往下读：

- [N_ANP_AC.C:1037](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1037)

在 `AC::createLinearSystem_()` 里，先创建 AC block matrix / block vector。

然后你会看到一段：

```cpp
if (sensFlag_)
{
  ...
}
```

里面会分配：

- `sensRhs_`
- `dXdp_`
- `lambda_`
- `dBdpVector_`
- `dJdpVector_`
- `dOdXreal_`
- `dOdXimag_`

这说明从工程结构上，`AC sensitivity` 不是后面零散临时拼出来的，而是：

```text
AC analysis object 在初始化 block system 时，
就一起把 sensitivity 所需的工作区和中间对象准备好了。
```

## 第四步：每个频点先求主 AC 系统，再追加灵敏度

继续顺着主流程往下看：

- [N_ANP_AC.C:1004](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1004)

这段控制流非常关键：

1. 先更新频点和线性系统
2. 调 `solveLinearSystem_()` 求 AC 主系统
3. 如果这一步成功
4. 并且 `sensFlag_` 打开
5. 才调用 `solveSensitivity_()`

所以它和 `DC` 一样，也遵守一个非常稳定的规律：

```text
先让主分析在当前工作点/频点上成功
再在这个成功状态上追加灵敏度求解
```

## 第五步：`solveSensitivity_()` 只是总调度器

接着顺着看：

- [N_ANP_AC.C:1643](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1643)

`AC::solveSensitivity_()` 并不直接做所有数学，它先做两件事：

1. 计算 / 刷新目标函数值
2. 根据选项决定走哪个分支

后面再分成：

- `solveDirectSensitivity_()`
- `solveAdjointSensitivity_()`

所以这一层的角色更像：

```text
AC sensitivity 的一次“频点后处理总入口”
```

而不是某个具体算法本身。

## 第六步：direct 分支和 adjoint 分支在代码上是平行结构

顺着同一个文件继续看：

- [N_ANP_AC.C:1915](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1915)
- [N_ANP_AC.C:1990](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C#L1990)

这两段在工程形态上很整齐：

### direct 分支

- 以参数为主循环
- 对每个参数构造 `sensRhs_`
- 调同一个 block solver
- 得到 `dXdp_`
- 再映射到输出

### adjoint 分支

- 以输出导数向量为起点
- 调 `solveTranspose(...)`
- 得到 `lambda_`
- 再对每个参数做内积回收结果

所以工程上它们的差别可以先粗暴记成：

```text
direct：按参数解
adjoint：按输出解
```

## 第七步：为什么 AC 这一条线比 DC 更值得单独拆出来

因为 `AC sensitivity` 比 `DC sensitivity` 多了几件工程上的事：

1. 要创建 2x2 block system
2. 要维护 `dJdp` / `dBdp`
3. 要同时支持 real / imag / mag / phase 输出
4. 要有 `solveTranspose(...)` 这种伴随路径

所以如果还把它和 `DC`、`Transient` 放在一篇总论里看，很容易把“哪里是 AC 特有复杂度”看糊掉。

## 当前这一篇学完后，应该记住什么

1. `AC sensitivity` 的代码主线完整集中在 `N_ANP_AC.C`。
2. `.SENS` 读“参数与目标”，`.options sensitivity` 读“策略与实现细节”。
3. 创建 AC block system 时，sensitivity 相关对象就一起被分配了。
4. 每个频点永远是“先求 AC 主系统，再追加 sensitivity 求解”。
5. `solveSensitivity_()` 是总入口，后面再分 direct 和 adjoint 两个平行分支。
