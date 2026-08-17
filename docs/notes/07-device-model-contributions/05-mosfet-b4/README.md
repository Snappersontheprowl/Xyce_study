# 07-device-model-contributions / 05-mosfet-b4

## 功能

本目录把 `MOSFET_B4` 作为复杂 compact model 独立追踪，观察它如何组织 unknown、stamp、`F/dFdx` 和 `Q/dQdx`。

本目录不作为 BSIM4 物理模型完整教材，只服务于理解 Xyce 器件实现结构。

## 本级模块职责

- `README.md`：说明本子专题职责和阅读顺序。
- `01-roadmap.md`：`MOSFET_B4` 阅读路线图。
- `02-unknowns-and-stamp.md`：unknown 与 stamp 结构。
- `03-f-and-dfdx.md`：`F` 和 `dFdx` 贡献。
- `04-q-and-dqdx.md`：`Q` 和 `dQdx` 贡献。
- `05-merge-summary.md`：与前面简单器件贡献方式的合并总结。

## 使用建议

建议先读上一级的 [../04-from-device-equations-to-stamp.md](../04-from-device-equations-to-stamp.md)，再进入本目录按编号阅读。

## 当前约定

- 本目录只追踪 `MOSFET_B4` 这一个复杂模型。
- 其它器件家族背景放在上一级 `device/`。
