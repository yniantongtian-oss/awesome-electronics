[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME "EDA-Workspace"),

    [ValidateSet("altium", "kicad", "both")]
    [string]$Backend = "altium",

    [bool]$IncludeContextGraph = $true,

    [switch]$IncludeKiKit,

    [switch]$SkipRepositoryUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message"
}

function Assert-Command {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$InstallHint
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "缺少命令 '$Name'。$InstallHint"
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "命令执行失败（退出码 $LASTEXITCODE）：$Command $($Arguments -join ' ')"
    }
}

function Resolve-Python311 {
    if (Get-Command "py" -ErrorAction SilentlyContinue) {
        & py -3.11 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return [PSCustomObject]@{
                Exe = "py"
                Prefix = @("-3.11")
            }
        }
    }

    if (Get-Command "python" -ErrorAction SilentlyContinue) {
        & python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return [PSCustomObject]@{
                Exe = "python"
                Prefix = @()
            }
        }
    }

    throw "未找到 Python 3.11 或更高版本。请安装 64 位 Python 3.11/3.12，并启用 py launcher 或加入 PATH。"
}

function Sync-Repository {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][string]$ReposDirectory,
        [switch]$SkipUpdate
    )

    $Destination = Join-Path $ReposDirectory $Name
    $GitDirectory = Join-Path $Destination ".git"

    if (Test-Path $GitDirectory) {
        if (-not $SkipUpdate) {
            Write-Step "更新 $Name"
            Invoke-Checked -Command "git" -Arguments @("-C", $Destination, "fetch", "origin", $Branch, "--prune")
            Invoke-Checked -Command "git" -Arguments @("-C", $Destination, "checkout", $Branch)
            Invoke-Checked -Command "git" -Arguments @("-C", $Destination, "pull", "--ff-only", "origin", $Branch)
        }
        else {
            Write-Host "跳过更新：$Destination"
        }
    }
    elseif (Test-Path $Destination) {
        throw "目标目录已经存在但不是 Git 仓库：$Destination"
    }
    else {
        Write-Step "克隆 $Name"
        Invoke-Checked -Command "git" -Arguments @(
            "clone",
            "--filter=blob:none",
            "--single-branch",
            "--branch", $Branch,
            $Url,
            $Destination
        )
    }

    return $Destination
}

if ($env:OS -ne "Windows_NT") {
    throw "此脚本面向 Windows。其他系统请按 workspace/README.md 中的命令手动安装。"
}

Write-Step "检查基础工具"
Assert-Command -Name "git" -InstallHint "请安装 Git for Windows。"
$Python = Resolve-Python311
$PythonExe = $Python.Exe
$PythonPrefix = @($Python.Prefix)
$PythonVersion = & $PythonExe @PythonPrefix -c "import platform; print(platform.python_version())"
Write-Host "Python：$PythonVersion"
Write-Host "工作区：$Root"
Write-Host "后端：$Backend"

$ReposDir = Join-Path $Root "repos"
$VenvDir = Join-Path $Root ".venv"
New-Item -ItemType Directory -Force -Path $ReposDir | Out-Null

$EdaAgentPath = Sync-Repository `
    -Name "eda-agent" `
    -Url "https://github.com/yniantongtian-oss/eda-agent.git" `
    -Branch "main" `
    -ReposDirectory $ReposDir `
    -SkipUpdate:$SkipRepositoryUpdate

$ContextGraphPath = $null
if ($IncludeContextGraph) {
    $ContextGraphPath = Sync-Repository `
        -Name "contextgraph" `
        -Url "https://github.com/yniantongtian-oss/contextgraph.git" `
        -Branch "main" `
        -ReposDirectory $ReposDir `
        -SkipUpdate:$SkipRepositoryUpdate
}

$KiKitPath = $null
if ($IncludeKiKit) {
    $KiKitPath = Sync-Repository `
        -Name "KiKit" `
        -Url "https://github.com/yniantongtian-oss/KiKit.git" `
        -Branch "master" `
        -ReposDirectory $ReposDir `
        -SkipUpdate:$SkipRepositoryUpdate
}

if (-not (Test-Path (Join-Path $VenvDir "Scripts\python.exe"))) {
    Write-Step "创建 Python 虚拟环境"
    & $PythonExe @PythonPrefix -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        throw "无法创建虚拟环境：$VenvDir"
    }
}

$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$EdaAgentExe = Join-Path $VenvDir "Scripts\eda-agent.exe"
$ContextGraphExe = Join-Path $VenvDir "Scripts\contextgraph.exe"

Write-Step "更新 Python 打包工具"
Invoke-Checked -Command $VenvPython -Arguments @("-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel")

$Extras = if ($Backend -eq "altium") {
    "web,render"
}
else {
    "web,render,kicad"
}

$EdaInstallSpec = "${EdaAgentPath}[$Extras]"
Write-Step "安装 eda-agent（$Extras）"
Invoke-Checked -Command $VenvPython -Arguments @("-m", "pip", "install", "-e", $EdaInstallSpec)

if ($IncludeContextGraph -and $ContextGraphPath) {
    Write-Step "安装 contextgraph"
    Invoke-Checked -Command $VenvPython -Arguments @("-m", "pip", "install", "-e", $ContextGraphPath)
}

if ($IncludeKiKit -and $KiKitPath) {
    Write-Step "尝试安装 KiKit"
    try {
        Invoke-Checked -Command $VenvPython -Arguments @("-m", "pip", "install", "-e", $KiKitPath)
    }
    catch {
        Write-Warning "KiKit 安装未完成。主 EDA 工作区仍然可用；KiKit 常受本机 KiCad Python 环境影响。错误：$($_.Exception.Message)"
    }
}

if ($Backend -in @("altium", "both")) {
    Write-Step "安装 Altium DelphiScript"
    Invoke-Checked -Command $EdaAgentExe -Arguments @("install-scripts", "--force")
}

Write-Step "运行基础健康检查"
& $EdaAgentExe --backend $Backend health
$HealthExitCode = $LASTEXITCODE
if ($HealthExitCode -ne 0) {
    Write-Warning "eda-agent health 返回退出码 $HealthExitCode。请运行 workspace/scripts/verify-windows.ps1 查看详细信息。"
}

if ($IncludeContextGraph) {
    Invoke-Checked -Command $ContextGraphExe -Arguments @("--help")
}

$ContextGraphConfig = $null
if ($ContextGraphPath) {
    $ContextGraphConfig = [ordered]@{
        repository = $ContextGraphPath
        executable = $ContextGraphExe
    }
}

$KiKitConfig = $null
if ($KiKitPath) {
    $KiKitConfig = [ordered]@{
        repository = $KiKitPath
    }
}

$Config = [ordered]@{
    schema_version = 1
    created_at = (Get-Date).ToString("o")
    root = $Root
    backend = $Backend
    virtual_environment = $VenvDir
    eda_agent = [ordered]@{
        repository = $EdaAgentPath
        executable = $EdaAgentExe
    }
    contextgraph = $ContextGraphConfig
    kikit = $KiKitConfig
}

$ConfigPath = Join-Path $Root ".eda-workspace.json"
$Config | ConvertTo-Json -Depth 6 | Set-Content -Path $ConfigPath -Encoding UTF8

Write-Step "安装完成"
Write-Host "配置文件：$ConfigPath"
Write-Host "EDA Agent：$EdaAgentExe"
if ($ContextGraphPath) {
    Write-Host "ContextGraph：$ContextGraphExe"
}

Write-Host "`n下一步："
if ($Backend -in @("altium", "both")) {
    Write-Host "1. 在 Altium 中安装并运行：%USERPROFILE%\EDA Agent\scripts\Altium_API.PrjScr"
    Write-Host "2. 运行：.\workspace\scripts\verify-windows.ps1 -Root `"$Root`" -Backend $Backend -Live"
}
else {
    Write-Host "1. 在 KiCad 中启用 Preferences -> Plugins -> KiCad API server"
    Write-Host "2. 运行：.\workspace\scripts\verify-windows.ps1 -Root `"$Root`" -Backend $Backend"
}

Write-Host "`n注意：首次自动修改必须使用工程副本，不要直接操作唯一原始文件。"
