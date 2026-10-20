# InferSurge ISG — Windows 一键安装脚本
#   powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/infersurge/isg/main/install.ps1 | iex"
# 用法: install.ps1 -Version v0.1.0   (默认 latest)
param(
    [string]$Version = 'latest'
)

$ErrorActionPreference = 'Stop'
$Repo = 'infersurge/isg'
$Binary = 'isg'

function Say($msg) { Write-Host $msg }
function Fail($msg) { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }

# --- 检测架构 ---
$arch = $env:PROCESSOR_ARCHITECTURE
switch ($arch) {
    'AMD64' { $goarch = 'amd64' }
    'ARM64' { $goarch = 'arm64' }
    default { Fail "不支持的架构: $arch（ISG 当前提供 amd64 / arm64）" }
}
$asset = "$Binary-windows-$goarch.exe"

# --- 解析 URL ---
if ($Version -eq 'latest') {
    $url = "https://github.com/$Repo/releases/latest/download/$asset"
} else {
    $url = "https://github.com/$Repo/releases/download/$Version/$asset"
}

# --- 安装目录 ---
$installDir = if ($env:ISG_INSTALL_DIR) { $env:ISG_INSTALL_DIR }
             else { Join-Path $env:LOCALAPPDATA 'InferSurge\bin' }

Say 'InferSurge ISG 安装器'
Say "  平台:   windows/$goarch"
Say "  版本:   $Version"
Say "  安装到: $installDir"
Say ''

# --- 下载 ---
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    Say "下载 $asset ..."
    $target = Join-Path $tmp "$Binary.exe"
    try {
        Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing
    } catch {
        Fail "下载失败: $url`n（该版本可能没有此平台的产物）"
    }

    # --- 校验 ---
    try {
        Invoke-WebRequest -Uri "$url.sha256" -OutFile "$target.sha256" -UseBasicParsing
        $expected = (Get-Content "$target.sha256" -Raw).Trim().Split(' ')[0]
        $actual = (Get-FileHash -Path $target -Algorithm SHA256).Hash.ToLower()
        if ($expected -ne $actual) {
            Fail "校验和不匹配（可能下载被篡改或不完整），已放弃安装"
        }
        Say '  校验通过'
    } catch {
        Say '  警告: 未找到 .sha256 文件，跳过校验'
    }

    # --- 安装 ---
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Move-Item -Path $target -Destination (Join-Path $installDir "$Binary.exe") -Force
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

Say ''
Say "已安装到 $installDir\$Binary.exe"

# --- PATH ---
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$installDir", 'User')
    Say "已将 $installDir 加入用户 PATH（新开终端生效）"
    $env:Path = "$env:Path;$installDir"
}

Say ''
Say "验证: $Binary version"
Say '下一步: 在 https://app.infersurge.com 添加设备，取得一次性注册命令'
