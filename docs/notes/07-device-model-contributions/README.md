# 07-device-model-contributions

## 功能

本目录记录器件模型如何把自身物理关系贡献到全局电路方程中，包括 `Q/F/B/dQdx/dFdx`、stamp、instance/master/model 分工。

本目录承接 [../06-solver-and-assembly/](../06-solver-and-assembly/)；求解器已经假定方程存在，本目录追问这些方程贡献来自哪里。

## 本级模块职责

- `README.md`：说明器件贡献专题的职责、阅读顺序和边界。
- `01-device-model-roadmap.md`：器件模型贡献路线图。
- `02-capacitor-and-q-contribution.md`：电容如何贡献 `Q`。
- `03-diode-and-nonlinear-f.md`：二极管如何贡献非线性 `F`。
- `04-from-device-equations-to-stamp.md`：器件方程如何变成 stamp。
- `05-mosfet-b4/`：以 `MOSFET_B4` 为复杂 compact model 进行独立追踪。
- `device/`：器件家族地图和 ADMS 接入方式扩展阅读。

## 使用建议

建议按 `resistor/capacitor/diode -> stamp -> MOSFET_B4` 的复杂度递增路线阅读；需要器件家族背景时，再读 `device/`。

## 当前约定

- 本目录关注器件如何贡献方程，不重复推导求解器如何解方程。
- 复杂模型优先拆成独立子专题，避免把根目录 README 写成长篇模型综述。
