function Read-RequiredValue([string]$Label) {
    do { $value = Read-Host $Label } while ([string]::IsNullOrWhiteSpace($value))
    return $value.Trim()
}

function Initialize-ReportRules([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return }
    $text = @'
# 본인 업무에 맞게 수정하세요. UTF-8 BOM으로 저장합니다.
@{
    CATEGORIES = @(
        @{ NAME = '개발'; KEYWORDS = @('개발', '기능 추가', '기능 수정') }
        @{ NAME = '문의'; KEYWORDS = @('문의') }
    )
    DEFAULT_CATEGORY = '기타'
    CATEGORY_ORDER = @('개발', '문의', '기타')
    EXCLUDED_STATUSES = @()
    IGNORE_TEAM_PREFIX = $true
    GROUP_RULES = @()
}
'@
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($true))
}

function ConvertFrom-ConfluenceUrl([string]$Url) {
    $uri = $null
    if (-not [Uri]::TryCreate($Url.Trim(), [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or $uri.Host -notmatch '^[a-zA-Z0-9-]+\.atlassian\.net$' -or
        $uri.UserInfo -or -not $uri.IsDefaultPort) {
        throw 'https://your-team.atlassian.net/wiki/spaces/SPACE/folder/123 형식의 실제 폴더 또는 페이지 주소를 입력하세요. 단축 공유 주소는 사용할 수 없습니다.'
    }
    if ($uri.AbsolutePath -notmatch '^/wiki/spaces/([^/]+)/(?:folder|pages)/(\d+)(?:/.*)?$') {
        throw '폴더나 상위 페이지를 브라우저에서 연 뒤 /wiki/spaces/.../folder/숫자 또는 /pages/숫자가 포함된 전체 주소를 복사하세요.'
    }
    return @{
        Domain = $uri.GetLeftPart([UriPartial]::Authority)
        SpaceKey = [Uri]::UnescapeDataString($Matches[1])
        ParentId = $Matches[2]
    }
}

function Write-AccountConfig([string]$Path, [hashtable]$Config) {
    $lines = @('# 개인 설정: API 토큰이 포함되어 있으므로 공유하지 마세요.', '@{')
    foreach ($key in @('EMAIL', 'TOKEN', 'NAME', 'DOMAIN', 'FOLDER_ID', 'SPACE_KEY', 'SERVER_ID')) {
        $value = [string]$Config[$key]
        if ($value.Contains("`r") -or $value.Contains("`n") -or $value.Contains([char]0)) { throw "설정 '$key'에는 줄바꿈을 사용할 수 없습니다." }
        $lines += "    $key = '" + $value.Replace("'", "''") + "'"
    }
    $lines += '}'
    [IO.File]::WriteAllLines($Path, [string[]]$lines, [Text.UTF8Encoding]::new($true))
}

function Get-ReportTaskName([string]$Folder) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Folder).TrimEnd('\').ToLowerInvariant())
        return 'WeeklyReport-' + ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-', '').Substring(0, 12)
    } finally { $hash.Dispose() }
}

# Windows PowerShell 5.1 / UTF-8 BOM
$ErrorActionPreference = 'Stop'
$installRoot = Split-Path $PSScriptRoot -Parent

try {
    Write-Host '주간보고서 처음 설정' -ForegroundColor Cyan
    Write-Host "실행 위치: $installRoot"
    Write-Host '이 폴더를 계속 사용할 위치에 둔 뒤 설정하세요. Git이나 별도 프로그램 설치는 필요 없습니다.'
    $configPath = Join-Path $installRoot 'weekly_report.config.psd1'
    if ((Test-Path -LiteralPath $configPath) -and (Read-Host '기존 개인 설정이 있습니다. 다시 입력할까요? [y/N]') -notmatch '^(?i:y|yes)$') {
        Import-PowerShellDataFile -LiteralPath $configPath -ErrorAction Stop | Out-Null
        Write-Host '기존 개인 설정을 사용합니다.'
    } else {
        $name = Read-RequiredValue '보고서에 표시할 본인 이름'
        $email = Read-RequiredValue 'Atlassian 계정 이메일'
        if ($email -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw '이메일 형식을 확인하세요.' }
        Write-Host 'API 토큰 발급: https://id.atlassian.com/manage-profile/security/api-tokens'
        Write-Host '이메일 + 토큰 인증을 지원하는 범위 없는 API 토큰을 사용하세요.'
        $secret = Read-Host 'API 토큰 (화면에 표시되지 않습니다)' -AsSecureString
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
        try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
        if ([string]::IsNullOrWhiteSpace($token)) { throw 'API 토큰을 입력하세요.' }
        $location = ConvertFrom-ConfluenceUrl (Read-RequiredValue 'Confluence의 저장할 폴더 또는 상위 페이지 주소')
        $config = @{
            EMAIL = $email; TOKEN = $token.Trim(); NAME = $name
            DOMAIN = $location.Domain; FOLDER_ID = $location.ParentId
            SPACE_KEY = $location.SpaceKey; SERVER_ID = ''
        }
        Write-AccountConfig $configPath $config
        $token = $null; $config = $null; $secret.Dispose()
        Write-Host '개인 설정을 저장했습니다. 이 파일은 공유하지 마세요.'
    }
    $rulesPath = Join-Path $installRoot 'weekly_report.rules.psd1'
    if (-not (Test-Path -LiteralPath $rulesPath)) {
        Initialize-ReportRules $rulesPath
    }

    Write-Host '수동 실행은 Confluence에 오늘 날짜의 보고서를 생성하며, 같은 제목이 있으면 본문 전체를 덮어씁니다.'
    if ((Read-Host '지금 보고서를 생성해 확인할까요? [y/N]') -match '^(?i:y|yes)$') {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'weekly_report.ps1')
        if ($LASTEXITCODE -ne 0) { throw '보고서 실행에 실패했습니다. 설정과 weekly_report.log를 확인한 뒤 다시 설정하세요.' }
    }
    if ((Read-Host '매주 수요일 오후 4시 자동 실행을 등록할까요? [y/N]') -match '^(?i:y|yes)$') {
        $scriptPath = Join-Path $PSScriptRoot 'weekly_report.ps1'
        $taskName = Get-ReportTaskName $installRoot
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday -At '16:00'
        $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -StartWhenAvailable
        $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description '주간보고서 자동 작성' -Force | Out-Null
        Write-Host "자동 실행 등록 완료: $taskName"
        Write-Host 'PC가 켜져 있고 본인 Windows 계정에 로그인되어 있어야 실행됩니다.'
    }
    Write-Host '설정 완료. 필요할 때 지금실행.cmd를 더블클릭하세요.' -ForegroundColor Green
} catch {
    Write-Host "설정 실패: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
