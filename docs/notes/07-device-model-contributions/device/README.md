# 07-device-model-contributions / device

## 功能

本目录是器件模型贡献专题的扩展阅读，用于建立 `DeviceModelPKG` 器件家族地图和 ADMS 接入方式背景。

本目录不逐个深入每种器件模型的方程实现。

## 本级模块职责

- `README.md`：说明本扩展目录职责和阅读顺序。
- `01-device-modelpkg-map.md`：`DeviceModelPKG` 器件家族地图。
- `02-specialized-device-families.md`：混合信号、神经元、TCAD、IBIS、外部耦合等专门器件家族。
- `03-adms-integration.md`：ADMS 接入方式及其与手写模型的区别。

## 使用建议

如果主线只关心 `Q/F/dQdx/dFdx` 贡献，可以先跳过本目录；当需要理解 Xyce 支持哪些模型家族时再读。

## 当前约定

- 本目录作为背景地图，不承担每个器件模型的精读任务。
- 具体模型精读应回到上一级创建独立子专题。
