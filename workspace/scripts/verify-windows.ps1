[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME "EDA-Workspace"),

    [ValidateSet("altium", "kicad", "both")]
    [string]$Backend = "altium",

    [switch]$Live,

    [switch]$Deep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Check,
        [ValidateSet("PASS", "WARN", "FAIL")][string]$Status,
        [string]$Details
    )

    $Results.Add([PSCustomObject]@{
        Check = $Check
        Status = $Status
        Details = $Details
    })
}

function Invoke-TestCommand {
    param(
        [string]$Check,
        [string]$Command,
        [string[]]$Arguments,
        [switch]$WarningOnly
    )

    try {
        $Output = & $Command @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
        $Text = ($Output | Out-String).Trim()

        if ($ExitCode -eq 0) {
            Add-Result -Check $Check -Status "PASS" -Details (($Text -split "`r?`n" | Select-Object -First 3) -join " | ")
            return $true
        }

        $Status = if ($WarningOnly) { "WARN" } else { "FAIL" }
        Add-Result -Check $Check -Status $Status -Details "退出码 $ExitCode。$Text"
        return $false
    }
    catch {
        $Status = if ($WarningOnly) { "WARN" } else { "FAIL" }
        Add-Result -Check $Check -Status $Status -Details $_.Exception.Message
        return $false
    }
}

if ($env:OS -ne "Windows_NT") {
    throw "此验收脚本面向 Windows。"
}

$ConfigPath = Join-Path $Root ".eda-workspace.json"
$VenvDir = Join-Path $Root ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$EdaAgentExe = Join-Path $VenvDir "Scripts\eda-agent.exe"
$ContextGraphExe = Join-Path $VenvDir "Scripts\contextgraph.exe"
$EdaAgentRepo = Join-Path $Root "repos\eda-agent"
$ContextGraphRepo = Join-Path $Root "repos\contextgraph"

if (Test-Path $ConfigPath) {
    Add-Result -Check "工作区配置" -Status "PASS" -Details $ConfigPath
}
else {
    Add-Result -Check "工作区配置" -Status "FAIL" -Details "未找到 $ConfigPath，请先运行 bootstrap-windows.ps1。"
}

if (Test-Path $VenvPython) {
    Invoke-TestCommand -Check "Python 虚拟环境" -Command $VenvPython -Arguments @("-c", "import sys; print(sys.version)") | Out-Null
}
else {
    Add-Result -Check "Python 虚拟环境" -Status "FAIL" -Details "未找到 $VenvPython"
}

if (Test-Path $EdaAgentExe) {
    Invoke-TestCommand -Check "eda-agent CLI" -Command $EdaAgentExe -Arguments @("--help") | Out-Null
    Invoke-TestCommand -Check "eda-agent health" -Command $EdaAgentExe -Arguments @("--backend", $Backend, "health") -WarningOnly | Out-Null
}
else {
    Add-Result -Check "eda-agent CLI" -Status "FAIL" -Details "未找到 $EdaAgentExe"
}

if (Test-Path $ContextGraphExe) {
    Invoke-TestCommand -Check "contextgraph CLI" -Command $ContextGraphExe -Arguments @("--help") | Out-Null
}
else {
    Add-Result -Check "contextgraph CLI" -Status "WARN" -Details "未安装 ContextGraph；这不影响基础 EDA 控制。"
}

if (Test-Path (Join-Path $EdaAgentRepo ".git")) {
    Invoke-TestCommand -Check "eda-agent 仓库状态" -Command "git" -Arguments @("-C", $EdaAgentRepo, "status", "--short") | Out-Null
}
else {
    Add-Result -Check "eda-agent 仓库状态" -Status "FAIL" -Details "未找到 Git 仓库：$EdaAgentRepo"
}

if ($Backend -in @("kicad", "both")) {
    $KiCadCli = Get-Command "kicad-cli" -ErrorAction SilentlyContinue
    if ($KiCadCli) {
        Invoke-TestCommand -Check "KiCad CLI" -Command $KiCadCli.Source -Arguments @("--version") | Out-Null
    }
    else {
        Add-Result -Check "KiCad CLI" -Status "WARN" -Details "PATH 中没有 kicad-cli。请确认已安装 KiCad 9+，并启用 KiCad API server。"
    }
}

if ($Live -and $Backend -in @("altium", "both")) {
    if (Test-Path $EdaAgentExe) {
        Invoke-TestCommand -Check "Altium 在线 doctor" -Command $EdaAgentExe -Arguments @("--backend", $Backend, "doctor", "--json") | Out-Null
    }
}
elseif ($Backend -in @("altium", "both")) {
    Add-Result -Check "Altium 在线 doctor" -Status "WARN" -Details "未启用 -Live；启动 Altium 和 Dispatcher.pas 后重新运行完整验收。"
}

if ($Deep -and (Test-Path $ContextGraphExe) -and (Test-Path $ContextGraphRepo)) {
    Invoke-TestCommand -Check "ContextGraph 扫描" -Command $ContextGraphExe -Arguments @("scan", $EdaAgentRepo) | Out-Null
    Invoke-TestCommand -Check "ContextGraph 查询" -Command $ContextGraphExe -Arguments @("query", "where backend selection is configured", "--project", $EdaAgentRepo, "--budget", "500") | Out-Null
}

Write-Host "`nAI-EDA 工作区验收结果`n"
$Results | Format-Table -AutoSize -Wrap

$FailureCount = @($Results | Where-Object { $_.Status -eq "FAIL" }).Count
$WarningCount = @($Results | Where-Object { $_.Status -eq "WARN" }).Count
$PassCount = @($Results | Where-Object { $_.Status -eq "PASS" }).Count

Write-Host "PASS=$PassCount  WARN=$WarningCount  FAIL=$FailureCount"

if ($FailureCount -gt 0) {
    Write-Host "验收未通过。先处理 FAIL 项，再进行任何工程写入。" -ForegroundColor Red
    exit 1
}

if ($WarningCount -gt 0) {
    Write-Host "基础验收通过，但仍有警告。首次写入前应完成在线 doctor。" -ForegroundColor Yellow
    exit 0
}

Write-Host "验收通过。仍建议首次修改只在工程副本上进行。" -ForegroundColor Green
exit 0
