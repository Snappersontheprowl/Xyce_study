# 源码归档目录

## 功能

本目录用于保存下载得到的上游源码包或发布归档，方便在需要时重新展开对应源码快照。

本目录不负责记录构建过程；构建命令、补丁和验收结论维护在 [../../docs/notes/build-and-install/](../../docs/notes/build-and-install/)。

## 本级模块职责

- `README.md`：说明源码归档目录的职责和维护边界。
- `Release-7.10.0.tar.gz`：Xyce 7.10.0 发布包归档。
- `SuiteSparse-7.8.3/`：本地展开的 SuiteSparse 7.8.3 源码。
- `SuiteSparse-7.8.3.tar.gz`：SuiteSparse 7.8.3 发布包归档。
- `Trilinos-14.4/`：本地展开的 Trilinos 14.4 源码。
- `Trilinos-14.4.zip`：Trilinos 14.4 发布分支归档。

## 当前约定

- 下载包、展开源码和校验值应优先在构建安装记录中登记。
- 本目录下的第三方 README 属于上游内容，除非有明确理由，不做项目风格化改写。
