# 个人电子与 AI-EDA 仓库目录

> 维护者：`yniantongtian-oss`  
> 最后审查：2026-07-28  
> 目标：把近期加入的 EDA、KiCad、PCB 自动化、元件库和编程智能体仓库整理成可使用、可验证、可维护的工作流。

## 直接使用入口

完整安装、架构和验收说明位于：

- [`workspace/README.md`](workspace/README.md)
- [`workspace/STACK_ARCHITECTURE.md`](workspace/STACK_ARCHITECTURE.md)
- [`workspace/scripts/bootstrap-windows.ps1`](workspace/scripts/bootstrap-windows.ps1)
- [`workspace/scripts/verify-windows.ps1`](workspace/scripts/verify-windows.ps1)

Windows 默认安装：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\workspace\scripts\bootstrap-windows.ps1 -Backend altium
```

## 已确定的最终工作栈

不再把三个 AI-EDA 仓库都作为“候选主项目”。当前决策为：

1. **唯一主力 EDA 控制层：** [`eda-agent`](https://github.com/yniantongtian-oss/eda-agent)
2. **代码上下文检索：** [`contextgraph`](https://github.com/yniantongtian-oss/contextgraph)
3. **PCB 制造与拼板：** [`KiKit`](https://github.com/yniantongtian-oss/KiKit)
4. **外部元件资产源：** [`hardware-components`](https://github.com/yniantongtian-oss/hardware-components)
5. **KiCad 对照实现：** [`kicad-mcp-1`](https://github.com/yniantongtian-oss/kicad-mcp-1)
6. **KiCad 功能参考：** [`KiCAD-MCP-Server`](https://github.com/yniantongtian-oss/KiCAD-MCP-Server)

## 仓库角色

| 仓库 | 角色 | 当前状态 | 维护原则 |
| --- | --- | --- | --- |
| [`eda-agent`](https://github.com/yniantongtian-oss/eda-agent) | AI 到 Altium/KiCad 的主控制层 | **主力** | 默认安装；所有正式 EDA 接入优先从这里完成。 |
| [`contextgraph`](https://github.com/yniantongtian-oss/contextgraph) | Python 代码图谱和上下文检索 | **主动使用** | 保持通用，不写入 Altium/KiCad 专属业务逻辑。 |
| [`KiKit`](https://github.com/yniantongtian-oss/KiKit) | 拼板和制造自动化 | **按需安装** | PCB 通过 DRC 后使用，不作为 MCP 主入口。 |
| [`hardware-components`](https://github.com/yniantongtian-oss/hardware-components) | KiCad 符号、封装、元数据和三维模型 | **外部资源** | 不默认完整克隆；不手动修改流水线生成文件。 |
| [`kicad-mcp-1`](https://github.com/yniantongtian-oss/kicad-mcp-1) | 精简型 KiCad MCP | **基准/备选** | 不与主力服务同时写同一工程；用于功能和测试对照。 |
| [`KiCAD-MCP-Server`](https://github.com/yniantongtian-oss/KiCAD-MCP-Server) | 大型 KiCad MCP 实现 | **功能参考** | 用来确认能力覆盖和兼容行为，不进入默认生产安装。 |

## 为什么不直接合并三个 AI-EDA 仓库

它们虽然功能重叠，但架构、工具命名、依赖、许可证、测试方式和运行模型并不相同。直接复制或合并容易产生：

- MCP 工具重名。
- 多个服务同时修改同一个工程。
- KiCad/Altium 运行时依赖冲突。
- 上游同步困难。
- 修复无法回馈原始项目。
- 同一功能出现多个行为不一致的实现。

正确关系是：

```text
AI 客户端
   |
   v
eda-agent                       [唯一生产入口]
   |----------------------|
   v                      v
Altium Designer          KiCad 9+
   |
   +--> ERC / DRC / BOM / 审查
   +--> KiKit 制造流程
   +--> hardware-components 按需取用

contextgraph                     [代码维护辅助]
kicad-mcp-1                      [对照测试]
KiCAD-MCP-Server                 [功能参考]
```

## 默认安装策略

默认安装：

- `eda-agent`
- `contextgraph`

可选安装：

- `KiKit`

不默认安装：

- `hardware-components`
- `kicad-mcp-1`
- `KiCAD-MCP-Server`

机器可读清单位于 [`workspace/repos.json`](workspace/repos.json)。

## 上游仓库维护规则

- 保留原作者、许可证和版权声明。
- README 中明确上游地址和当前仓库的定位。
- 个人改动使用单独分支，不把镜像说成独立原创项目。
- 大改前先同步上游，并记录基准 commit/tag。
- 不在多个镜像仓库重复维护同一个补丁。
- 通用修复优先向上游提交 PR；个人产品差异留在自有层。

## 大型和生成型仓库规则

针对 `hardware-components`：

- 把流水线提交和生成资产视为不可手改输出。
- 自制元件放入独立的小型自有元件库。
- 只需要部分资产时使用 partial clone、sparse checkout 或按文件下载。
- 不提交缓存、临时渲染、KiCad 备份、rescue 文件和编辑器临时文件。
- 不把整个仓库嵌入其他项目或普通 CI。

## 命名规范

以后自建仓库统一使用：

- 产品拼写：**KiCad**
- 仓库 slug：小写 kebab-case，例如 `kicad-agent-tools`
- 默认分支：`main`
- 只读镜像后缀：`-mirror`
- 实验分支仓库后缀：`-lab`

`kicad-mcp-1` 建议未来重命名为能表示来源和用途的名称，例如：

```text
kicad-mcp-blwfish-mirror
```

## 统一评测项目

评测三个 EDA 实现时，应使用同一个测试工程，至少覆盖：

- Windows 安装成功率。
- KiCad/Altium 版本兼容性。
- 原理图读取、创建和修改。
- PCB 元件放置、布线和区域操作。
- ERC/DRC。
- 符号、封装和三维模型处理。
- BOM、Gerber 和装配输出。
- 中断、超时、部分失败后的恢复。
- 文件覆盖保护和显式保存。
- 测试套件、文档和安全边界。

评测结果应写入独立文档，不修改上游项目的原始 README。

## 当前完成情况

- [x] 明确 `eda-agent` 为唯一主力入口。
- [x] 明确其余仓库的生产、辅助、参考和资源角色。
- [x] 增加机器可读仓库清单。
- [x] 增加 Windows 一键安装脚本。
- [x] 增加离线和在线验收脚本。
- [x] 增加 Windows GitHub Actions 烟雾测试。
- [ ] 在本机完成 Altium 在线 `doctor`。
- [ ] 在本机完成 KiCad API 连接验证。
- [ ] 建立一个不会影响真实项目的固定测试板。
- [ ] 完成一次只读审查、一次小范围写入和一次制造输出。
- [ ] 建立自己的小型 KiCad/Altium 元件库。

## 最终原则

仓库整理的目标不是让账号里“项目更多”，而是形成一条稳定链路：

> 安装可重复、连接可诊断、修改可追踪、错误可恢复、工程可验证、制造资料可导出。
