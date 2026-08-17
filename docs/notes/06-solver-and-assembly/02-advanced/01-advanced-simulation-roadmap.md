# advanced simulation roadmap

记录日期：2026-06-04

## 这篇的定位

这一篇先不直接进入 `AC / NOISE / HB / MPDE` 的细节，而是先建立一个进阶仿真的学习顺序。

如果把 [../01-basic/README.md](../01-basic/README.md) 理解成：

```text
DC / transient 的通用求解骨架
```

那么这一篇要回答的就是：

```text
在这个骨架之上，
其他分析类型该按什么顺序继续学？
```

## 推荐学习顺序

1. `AC`
2. `NOISE`
3. `HB`
4. `MPDE`

## 为什么先学 AC

因为 `AC` 最自然承接你已经学过的几件事：

- `DC operating point`
- Jacobian / linearization
- linear solver

也就是说，`AC` 通常最适合先理解成：

```text
先围绕 DCOP 建立工作点
-> 再在工作点附近做 small-signal linearization
-> 再在频域解线性系统
```

所以它是从基础仿真进入进阶仿真的最好入口。

## 为什么 NOISE 放在 AC 后面

因为 `NOISE` 往往不是一条完全独立于 `AC` 的主线。

更自然的理解方式通常是：

- 先有 small-signal / frequency-domain 框架
- 再在这个框架上考虑噪声源和噪声传播

所以先学 `AC`，再看 `NOISE`，层次更稳。

## 为什么 HB 和 MPDE 再往后放

`HB` 和 `MPDE` 都更专门。

它们的问题已经不再只是：

- operating point
- 单步时间离散
- 普通 small-signal linearization

而是进入更专门的：

- 频域平衡
- 多时间尺度

所以它们更适合作为第二轮、第三轮深入，而不是进阶仿真的第一步。

## 这一篇最想让你先吃下来的本质

进阶仿真并不是“把所有新分析类型并排罗列”，而是要按依赖关系和理解成本排顺序。

当前最合理的顺序就是：

```text
AC
-> NOISE
-> HB
-> MPDE
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `AC` 比 `HB` 或 `MPDE` 更适合作为第一种进阶仿真来学？
2. 为什么进阶仿真这里，也要继续坚持“先立地图，再展开细节”的顺序？
