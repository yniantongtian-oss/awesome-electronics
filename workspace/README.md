# AI-EDA Workspace

这是一套面向 Windows 的可落地工作区，用来把当前账号下分散的 EDA、KiCad、Altium、制造自动化和代码检索仓库组织成一条可运行的链路。

## 最终选型

默认生产链路只保留一个主入口：

```text
AI 客户端
   |
   v
eda-agent                 主力 MCP/EDA 控制层
   |-- Altium Designer    默认后端
   `-- KiCad 9+           可选后端

contextgraph              代码仓库上下文检索
KiKit                     PCB 完成后的拼板与制造输出
hardware-components       按需使用的远程元件资源库
```

以下仓库不进入默认安装：

- `kicad-mcp-1`：对照测试和备选实现。
- `KiCAD-MCP-Server`：功能参考与兼容性测试。
- `hardware-components`：体积过大，不默认完整克隆。

这样可以避免多个 MCP 服务同时修改同一个工程、工具名称冲突、依赖版本冲突和维护方向分裂。

## 一键准备

在 PowerShell 中运行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\workspace\scripts\bootstrap-windows.ps1 -Backend altium
```

KiCad 用户：

```powershell
.\workspace\scripts\bootstrap-windows.ps1 -Backend kicad
```

同时安装两个后端：

```powershell
.\workspace\scripts\bootstrap-windows.ps1 -Backend both
```

默认安装目录为：

```text
%USERPROFILE%\EDA-Workspace
```

脚本会完成：

1. 检查 Git 和 Python 3.11+。
2. 克隆或更新 `eda-agent` 与 `contextgraph`。
3. 创建独立 Python 虚拟环境。
4. 安装与所选后端匹配的依赖。
5. 运行 `eda-agent health` 和基础命令验证。
6. 生成工作区配置文件 `.eda-workspace.json`。

## Altium 首次配置

安装完成后执行：

```powershell
& "$HOME\EDA-Workspace\.venv\Scripts\eda-agent.exe" install-scripts --force
```

然后在 Altium Designer 中：

1. 打开 `DXP -> Preferences -> Scripting System -> Global Projects`。
2. 安装 `%USERPROFILE%\EDA Agent\scripts\Altium_API.PrjScr`。
3. 打开 `File -> Run Script...`。
4. 选择 `Dispatcher.pas -> StartMCPServer`。
5. 保持需要操作的 Altium 工程处于打开状态。

基础检查：

```powershell
.\workspace\scripts\verify-windows.ps1
```

Altium 已启动并运行脚本后进行完整检查：

```powershell
.\workspace\scripts\verify-windows.ps1 -Live
```

## KiCad 首次配置

需要 KiCad 9 或更高版本，并在 KiCad 中启用：

```text
Preferences -> Plugins -> KiCad API server
```

验证：

```powershell
.\workspace\scripts\verify-windows.ps1 -Backend kicad
```

## 接入 Claude Code

安装完成后，可使用虚拟环境中的可执行文件注册 MCP：

```powershell
claude mcp add -s user altium "$HOME\EDA-Workspace\.venv\Scripts\eda-agent.exe"
claude mcp add -s user kicad -e EDA_AGENT_BACKEND=kicad "$HOME\EDA-Workspace\.venv\Scripts\eda-agent.exe"
```

对于严格遵守 stdio 的客户端，建议使用无仪表盘模式：

```text
command: %USERPROFILE%\EDA-Workspace\.venv\Scripts\eda-agent.exe
args: ["--no-dashboard"]
```

KiCad 后端同时设置环境变量：

```text
EDA_AGENT_BACKEND=kicad
```

## 验收标准

只有满足以下条件，才视为“可以使用”：

- [ ] `bootstrap-windows.ps1` 无错误完成。
- [ ] `eda-agent health` 返回成功或只有明确可修复警告。
- [ ] MCP 客户端能看到 `eda-agent` 工具。
- [ ] Altium 的 `eda-agent doctor` 通过，或 KiCad API 后端可以连接。
- [ ] 能读取当前工程的项目、元件和网络信息。
- [ ] 在工程副本上完成一次安全的非破坏性修改并保存。
- [ ] 执行 ERC/DRC 或设计审查并得到结构化结果。
- [ ] 能生成 BOM；PCB 完成后可进入 KiKit/制造输出流程。

## 安全规则

- 首次使用只对工程副本操作。
- 不允许两个 EDA MCP 服务同时写同一工程。
- 修改前提交 Git 或创建完整备份。
- 元件参数、封装、SPICE 模型必须依据厂家数据手册，不由模型猜测。
- `hardware-components` 只作为外部资产源，不作为普通项目依赖完整克隆。
- 先运行只读检查，再允许写入；先保存小改动，再执行批量修改。

## 文件说明

- `STACK_ARCHITECTURE.md`：最终架构和迭代边界。
- `repos.json`：仓库角色、分支和默认安装策略。
- `scripts/bootstrap-windows.ps1`：安装与更新脚本。
- `scripts/verify-windows.ps1`：离线/在线验收脚本。
