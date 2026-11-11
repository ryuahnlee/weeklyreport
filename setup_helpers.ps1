function Read-RequiredValue([string]$Label) {
    do { $value = Read-Host $Label } while ([string]::IsNullOrWhiteSpace($value))
    return $value.Trim()
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
