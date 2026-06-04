# device 扩展阅读

记录日期：2026-06-04

这个目录放的是 `07-device-model-contributions` 的扩展阅读。

根目录那几篇主线笔记，重点在回答：

- 一个器件怎样贡献 `Q / F / dQdx / dFdx`
- 这些贡献怎样进入 `time integration` 和 `Newton`
- `MOSFET_B4` 这种复杂 compact model 怎样把这些贡献合在一起

而这个 `device/` 目录更偏“器件家族地图”和“模型接入方式”：

- `DeviceModelPKG` 里到底有哪些器件家族
- 哪些属于常规 `OpenModels`
- 哪些是混合信号、神经元、TCAD、IBIS、外部耦合这类专门方向
- `ADMS` 到底是什么，它和手工写 `OpenModels` 的差别是什么

## 推荐阅读顺序

1. 先读 [01-device-modelpkg-map.md](01-device-modelpkg-map.md)
2. 再读 [02-specialized-device-families.md](02-specialized-device-families.md)
3. 最后读 [03-adms-integration.md](03-adms-integration.md)

## 这一组笔记的定位

如果只压成一句话，这一组笔记要补上的，是下面这个背景问题：

```text
除了我们已经精读过的 resistor / capacitor / diode / MOSFET_B4，
Xyce 整体到底支持哪些模型家族，
它们是按什么方式组织和接入进来的？
```
