# ============================================================
# 주간보고서 자동 작성 스크립트
# 매주 수요일 오후 4시 실행 (Windows 작업 스케줄러)
# ============================================================

param([switch]$Preview)

function Assert-StringList($value, $label) {
    if ($null -eq $value) { return }
    foreach ($text in @($value)) {
        if ($text -isnot [string] -or [string]::IsNullOrWhiteSpace($text)) {
            throw "설정 '$label'에는 비어 있지 않은 문자열만 입력하세요."
        }
    }
}

function Assert-ReportRules($settings) {
    if ($settings.DEFAULT_CATEGORY -isnot [string] -or [string]::IsNullOrWhiteSpace($settings.DEFAULT_CATEGORY)) {
        throw 'DEFAULT_CATEGORY에 기본 분류명을 입력하세요.'
    }
    foreach ($key in @('CATEGORIES','GROUP_RULES','EXCLUDED_STATUSES')) {
        if (-not $settings.ContainsKey($key) -or $null -eq $settings[$key]) {
            throw "설정 '$key'가 없습니다. 예시 설정 파일을 참고하세요. 사용하지 않으면 @()로 지정하세요."
        }
    }
    $names = @()
    foreach ($rule in @($settings.CATEGORIES)) {
        if ($rule -isnot [hashtable] -or $rule.NAME -isnot [string] -or [string]::IsNullOrWhiteSpace($rule.NAME)) {
            throw 'CATEGORIES의 각 항목에 NAME을 입력하세요.'
        }
        if ($rule.NAME -in $names -or $rule.NAME -eq $settings.DEFAULT_CATEGORY) {
            throw "분류명 '$($rule.NAME)'이 중복되거나 기본 분류명과 같습니다."
        }
        $names += $rule.NAME
        Assert-StringList $rule.KEYWORDS 'KEYWORDS'
        Assert-StringList $rule.PROJECT_KEYS 'PROJECT_KEYS'
        if (-not $rule.KEYWORDS -and -not $rule.PROJECT_KEYS) {
            throw "분류 '$($rule.NAME)'에 KEYWORDS 또는 PROJECT_KEYS를 입력하세요."
        }
    }
    foreach ($rule in @($settings.GROUP_RULES)) {
        if ($rule -isnot [hashtable]) { throw 'GROUP_RULES에는 @{ ... } 항목을 입력하세요.' }
        foreach ($key in @('KEYWORD','LABEL','CATEGORY','SCHEDULE','STATUS')) {
            if ($rule[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($rule[$key])) {
                throw "묶음 규칙의 '$key'에 값을 입력하세요."
            }
        }
        if ($rule.CATEGORY -notin ($names + @($settings.DEFAULT_CATEGORY))) {
            throw "묶음 분류 '$($rule.CATEGORY)'를 CATEGORIES 또는 DEFAULT_CATEGORY에 먼저 정의하세요."
        }
    }
    Assert-StringList $settings.EXCLUDED_STATUSES 'EXCLUDED_STATUSES'
    Assert-StringList $settings.CATEGORY_ORDER 'CATEGORY_ORDER'
    foreach ($name in @($settings.CATEGORY_ORDER)) {
        if ($null -eq $name) { continue }
        if ($name -notin ($names + @($settings.DEFAULT_CATEGORY))) { throw "표시 순서의 분류 '$name'이 정의되어 있지 않습니다." }
    }
    if ($settings.ContainsKey('IGNORE_TEAM_PREFIX') -and $settings.IGNORE_TEAM_PREFIX -isnot [bool]) {
        throw 'IGNORE_TEAM_PREFIX에는 $true 또는 $false를 입력하세요.'
    }
}

function Get-ReportCategoryOrder($settings) {
    $result = @()
    foreach ($name in @($settings.CATEGORY_ORDER) + @($settings.CATEGORIES | ForEach-Object { $_.NAME }) + @($settings.DEFAULT_CATEGORY)) {
        if ($name -and $name -notin $result) { $result += $name }
    }
    return $result
}

function Get-MatchingGroupRule($issue) {
    foreach ($rule in @($rules.GROUP_RULES)) {
        # 와일드카드 문자가 있는 키워드도 문자 그대로 검색합니다.
        if ($issue.fields.summary.IndexOf($rule.KEYWORD, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $rule }
    }
    return $null
}

function Get-Category($issue) {
    $groupRule = Get-MatchingGroupRule $issue
    if ($null -ne $groupRule) { return $groupRule.CATEGORY }
    $summary = $issue.fields.summary
    if (-not $rules.ContainsKey('IGNORE_TEAM_PREFIX') -or $rules.IGNORE_TEAM_PREFIX) {
        $summary = $summary -replace '^\s*(?:\([^()\r\n]*팀\)\s*)+', ''
    }
    foreach ($rule in @($rules.CATEGORIES)) {
        if ($issue.fields.project.key -in @($rule.PROJECT_KEYS)) { return $rule.NAME }
        foreach ($keyword in @($rule.KEYWORDS)) {
            if ($null -eq $keyword) { continue }
            if ($summary.IndexOf($keyword, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $rule.NAME }
        }
    }
    return $rules.DEFAULT_CATEGORY
}

$installRoot = $PSScriptRoot
$configPath = Join-Path $installRoot 'weekly_report.config.psd1'
try {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw 'weekly_report.config.psd1을 같은 폴더에 두고 본인 정보를 입력하세요.'
    }
    $config = Import-PowerShellDataFile -LiteralPath $configPath -ErrorAction Stop
    $rulesPath = Join-Path $installRoot 'weekly_report.rules.psd1'
    if (-not (Test-Path -LiteralPath $rulesPath -PathType Leaf)) {
        throw 'weekly_report.rules.psd1을 같은 폴더에 두세요.'
    }
    $rules = Import-PowerShellDataFile -LiteralPath $rulesPath -ErrorAction Stop
    Assert-ReportRules $rules
    foreach ($key in @('EMAIL', 'TOKEN', 'NAME', 'DOMAIN', 'FOLDER_ID', 'SPACE_KEY')) {
        if ($config[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($config[$key])) {
            throw "설정값 '$key'이 없거나 비어 있습니다."
        }
        if ($config[$key] -match '^\[.*\]$') {
            throw "설정값 '$key'의 대괄호 안내 문구를 본인 정보로 바꿔 주세요."
        }
    }
} catch {
    Write-Error "주간보고서 설정 로딩 실패: $($_.Exception.Message)"
    exit 1
}
$EMAIL     = $config.EMAIL
$TOKEN     = $config.TOKEN
$NAME      = $config.NAME
$DOMAIN    = $config.DOMAIN
$SERVER_ID = $config.SERVER_ID
$FOLDER_ID = $config.FOLDER_ID
$SPACE_KEY = $config.SPACE_KEY
$LOG_FILE  = "$installRoot\weekly_report.log"

# TLS 1.2 강제 적용 (PowerShell 5.1 기본값 TLS 1.0/1.1 → Confluence 연결 실패 방지)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12



function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Tee-Object -FilePath $LOG_FILE -Append
}

function Get-HttpError($ex) {
    $code = $ex.Exception.Response.StatusCode.value__
    $msg  = $ex.Exception.Message
    if ($code -eq 401) { return "[HTTP 401] 인증 실패 - API 토큰을 확인하세요" }
    if ($code -eq 403) { return "[HTTP 403] 권한 없음 - API 토큰이 만료되었거나 권한이 없습니다" }
    if ($code -eq 404) { return "[HTTP 404] 리소스를 찾을 수 없음" }
    return "[HTTP $code] $msg"
}

function Show-Toast($title, $message) {
    try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    $xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $title = [System.Security.SecurityElement]::Escape($title)
    $message = [System.Security.SecurityElement]::Escape($message)
    $xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$title</text><text>$message</text></binding></visual></toast>")
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Weekly Report").Show($toast)
    } catch {
        Write-Log 'WARN Windows 알림을 표시하지 못했습니다. 보고서 실행 결과는 위 로그를 확인하세요.'
    }
}

# ── 중복 실행 방지 ─────────────────────────────────────────
$mutex = New-Object System.Threading.Mutex($false, "Global\WeeklyReportScript")
if (-not $mutex.WaitOne(0)) {
    Write-Log "SKIP 이미 실행 중인 인스턴스가 있어 종료합니다 (중복 실행 방지)"
    exit 0
}

try {

# ── 날짜 계산 ──────────────────────────────────────────────
$today      = Get-Date
$dow        = [int]$today.DayOfWeek   # 0=일, 1=월 ... 6=토
$daysToMon  = if ($dow -eq 0) { 6 } else { $dow - 1 }
$thisMon    = $today.AddDays(-$daysToMon).ToString("yyyy-MM-dd")
$nextMon    = $today.AddDays(7 - $daysToMon).ToString("yyyy-MM-dd")
$thisFri    = $today.AddDays(5 - $daysToMon - 1).ToString("MM'/'dd")  # 지역 설정과 관계없이 슬래시로 표시
$pageTitle  = $today.ToString("yyyy-MM-dd") + " ($NAME)"

Write-Log "START $pageTitle ($thisMon ~ $nextMon)"

# ── 인증 헤더 ─────────────────────────────────────────────
$creds   = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${EMAIL}:${TOKEN}"))
$headers = @{
    Authorization  = "Basic $creds"
    Accept         = "application/json"
    "Content-Type" = "application/json"
}

# ── Jira 이슈 조회 ────────────────────────────────────────
Write-Log "Jira 이슈 조회 중..."
$jql = "assignee = currentUser() AND (statusCategory = `"In Progress`" OR (statusCategory = `"Done`" AND resolved >= `"$thisMon`" AND resolved <= now()) OR (statusCategory = `"new`" AND updated >= `"$thisMon`" AND updated <= now())) ORDER BY status ASC, updated DESC"
$request = @{ jql = $jql; maxResults = 100; fields = @("summary","status","issuetype","duedate","updated","created","resolutiondate","project") }

try {
    $candidates = @()
    do {
        $body = $request | ConvertTo-Json
        $resp = Invoke-RestMethod -Uri "$DOMAIN/rest/api/3/search/jql" -Method POST -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 60 -ErrorAction Stop
        $candidates += @($resp.issues)
        Write-Log "Jira 후보 $($candidates.Count)개 조회 중..."
        if ($resp.isLast -eq $true -or -not $resp.nextPageToken) { break }
        if ($request.nextPageToken -eq $resp.nextPageToken) { throw 'Jira 페이지 토큰이 반복되어 조회를 중단합니다.' }
        $request.nextPageToken = $resp.nextPageToken
    } while ($resp.nextPageToken)
    $issues = @($candidates | Where-Object { $_.fields.status.name.Trim() -notin @($rules.EXCLUDED_STATUSES) })
} catch {
    $errDetail = Get-HttpError $_
    Write-Log "ERR Jira 조회 실패 - $errDetail"
    Show-Toast "주간보고서 작성 실패" "Jira 조회 실패: $errDetail"
    exit 1
}

Write-Log "Jira 이슈 $($issues.Count)개 조회 완료"
if ($Preview) {
    $issues | Select-Object key, @{Name='Status'; Expression={$_.fields.status.name}} | Format-Table | Out-Host
    Write-Log 'PREVIEW 보고서를 변경하지 않고 조회 검증 완료'
    return
}

# ── 이슈 분류 ─────────────────────────────────────────────
$categoryOrder = @(Get-ReportCategoryOrder $rules)
$groups = @{}
foreach ($category in $categoryOrder) { $groups[$category] = @() }
foreach ($issue in $issues) {
    $cat = Get-Category $issue
    $groups[$cat] += $issue
}

# ── Confluence 스토리지 HTML 생성 ─────────────────────────
function Get-JiraMacro($key) {
    if ([string]::IsNullOrWhiteSpace($SERVER_ID)) {
        $url = [System.Net.WebUtility]::HtmlEncode("$DOMAIN/browse/$([Uri]::EscapeDataString($key))")
        $label = [System.Net.WebUtility]::HtmlEncode($key)
        return "<a href=`"$url`">$label</a>"
    }
    return "<ac:structured-macro ac:name=`"jira`" ac:schema-version=`"1`"><ac:parameter ac:name=`"key`">$key</ac:parameter><ac:parameter ac:name=`"serverId`">$SERVER_ID</ac:parameter><ac:parameter ac:name=`"server`">System Jira</ac:parameter></ac:structured-macro>"
}

function Get-StatusKr($s) {
    $map = @{ "진행 중" = "진행중"; "완료" = "완료"; "Backlog" = "Backlog"; "개발중" = "개발중" }
    if ($map.ContainsKey($s)) { return $map[$s] } else { return $s }
}

function Get-Row($cat, $items) {
    $items = @($items)
    if ($items.Count -eq 0) { return "" }
    $rows = ""
    $categoryText = [System.Net.WebUtility]::HtmlEncode($cat)

    # 각 티켓은 첫 번째로 일치한 묶음 규칙에만 배정합니다.
    $entries = @()
    $buckets = @{}
    foreach ($item in $items) {
        $rule = Get-MatchingGroupRule $item
        if ($null -eq $rule) {
            $entries += @{ Items = @($item); Grouped = $false }
        } else {
            $ruleIndex = [array]::IndexOf(@($rules.GROUP_RULES), $rule)
            if (-not $buckets.ContainsKey($ruleIndex)) { $buckets[$ruleIndex] = @() }
            $buckets[$ruleIndex] += $item
        }
    }
    for ($ruleIndex = 0; $ruleIndex -lt @($rules.GROUP_RULES).Count; $ruleIndex++) {
        if ($buckets.ContainsKey($ruleIndex)) {
            $entries += @{ Items = $buckets[$ruleIndex]; Grouped = $true; Rule = $rules.GROUP_RULES[$ruleIndex] }
        }
    }
    for ($index = 0; $index -lt $entries.Count; $index++) {
        $entry = $entries[$index]
        $item = $entry.Items[0]
        $summary = [System.Net.WebUtility]::HtmlEncode($item.fields.summary)
        $status = Get-StatusKr $item.fields.status.name
        $statusText = [System.Net.WebUtility]::HtmlEncode($status)
        $due = $item.fields.duedate
        $completed = $item.fields.resolutiondate
        $dueTxt = if ($item.fields.status.statusCategory.key -eq "done" -and $completed) { $completed.Substring(5,5).Replace("-","/") } elseif ($due) { $due.Substring(5).Replace("-","/") } else { "&nbsp;" }
        $categoryCell = if ($index -eq 0) {
            "<td data-highlight-colour=`"#ffffff`" rowspan=`"$($entries.Count)`"><p>$categoryText</p></td>"
        } else { "" }
        $work = "<ul><li><p>$summary</p><ul><li><p>$(Get-JiraMacro $item.key)</p></li></ul></li></ul>"
        if ($entry.Grouped) {
            $macros = ($entry.Items | ForEach-Object { "<li><p>$(Get-JiraMacro $_.key)</p></li>" }) -join ""
            $label = [System.Net.WebUtility]::HtmlEncode($entry.Rule.LABEL)
            $work = "<ul><li><p>$label</p><ul>$macros</ul></li></ul>"
            $dueTxt = [System.Net.WebUtility]::HtmlEncode($entry.Rule.SCHEDULE.Replace('{FRIDAY}', $thisFri))
            $statusText = [System.Net.WebUtility]::HtmlEncode($entry.Rule.STATUS)
        }
        $rows += "<tr>$categoryCell<td data-highlight-colour=`"#ffffff`">$work</td><td data-highlight-colour=`"#ffffff`"><p>$dueTxt</p></td><td data-highlight-colour=`"#ffffff`"><p>$statusText</p></td><td data-highlight-colour=`"#ffffff`"><p>&nbsp;</p></td><td data-highlight-colour=`"#ffffff`"><p>&nbsp;</p></td></tr>"
    }
    return $rows
}

$tableHeader = @"
<h2><strong>업무 진행 사항 상세 보고</strong></h2><p>&nbsp;</p><hr /><h3>업무 진행 사항</h3>
<table data-table-width="1430" data-layout="center">
<colgroup><col style="width: 158.0px;"/><col style="width: 636.0px;"/><col style="width: 70.0px;"/><col style="width: 69.0px;"/><col style="width: 365.0px;"/><col style="width: 89.0px;"/></colgroup>
<tbody>
<tr><th data-highlight-colour="#f0f0f0" rowspan="2"><p style="text-align: center;"><strong>분류</strong></p></th><th data-highlight-colour="#f0f1f2" colspan="3"><p style="text-align: center;"><strong>금주</strong></p></th><th data-highlight-colour="#f0f1f2" colspan="2"><p style="text-align: center;"><strong>차주</strong></p></th></tr>
<tr><td data-highlight-colour="#f0f0f0"><p style="text-align: center;"><strong>진행업무</strong></p></td><td data-highlight-colour="#f0f0f0"><p style="text-align: center;"><strong>일정</strong></p></td><td data-highlight-colour="#f0f0f0"><p style="text-align: center;"><strong>상태</strong></p></td><td data-highlight-colour="#f0f0f0"><p style="text-align: center;"><strong>예정업무</strong></p></td><td data-highlight-colour="#f0f0f0"><p style="text-align: center;"><strong>일정</strong></p></td></tr>
"@

$rows = ""
foreach ($cat in $categoryOrder) {
    $rows += Get-Row $cat $groups[$cat]
}
$content = $tableHeader + $rows + "</tbody></table><p>&nbsp;</p>"

# ── Confluence 기존 페이지 확인 (CQL 검색) ───────────────
Write-Log "Confluence 페이지 확인 중..."
$cql = "title=`"$pageTitle`" AND space=`"$SPACE_KEY`" AND type=page"

try {
    $searchResp = Invoke-RestMethod -Uri "$DOMAIN/wiki/rest/api/content/search?cql=$([Uri]::EscapeDataString($cql))&expand=version" -Method GET -Headers $headers
} catch {
    $errDetail = Get-HttpError $_
    Write-Log "ERR Confluence 페이지 조회 실패 - $errDetail"
    Show-Toast "주간보고서 작성 실패" "Confluence 조회 실패: $errDetail"
    exit 1
}

$existingPage = $searchResp.results | Select-Object -First 1

try {
    if ($existingPage) {
        # ── 기존 페이지 업데이트 ──────────────────────────────
        Write-Log "Confluence 기존 페이지 업데이트 중... (v$($existingPage.version.number) → v$($existingPage.version.number + 1))"
        $newVersion = $existingPage.version.number + 1
        $pageBody = @{
            type    = "page"
            title   = $pageTitle
            version = @{ number = $newVersion }
            body    = @{ storage = @{ representation = "storage"; value = $content } }
        } | ConvertTo-Json -Depth 10

        $result = Invoke-RestMethod -Uri "$DOMAIN/wiki/rest/api/content/$($existingPage.id)" -Method PUT -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($pageBody)) -ContentType "application/json; charset=utf-8"
    } else {
        # ── 신규 페이지 생성 ──────────────────────────────────
        Write-Log "Confluence 신규 페이지 생성 중..."
        $pageBody = @{
            type      = "page"
            title     = $pageTitle
            space     = @{ key = $SPACE_KEY }
            ancestors = @(@{ id = $FOLDER_ID })
            body      = @{ storage = @{ representation = "storage"; value = $content } }
        } | ConvertTo-Json -Depth 10

        $result = Invoke-RestMethod -Uri "$DOMAIN/wiki/rest/api/content" -Method POST -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($pageBody)) -ContentType "application/json; charset=utf-8"
    }
} catch {
    $errDetail = Get-HttpError $_
    Write-Log "ERR Confluence 페이지 저장 실패 - $errDetail"
    Show-Toast "주간보고서 작성 실패" "페이지 저장 실패: $errDetail"
    exit 1
}

$pageUrl = "$DOMAIN/wiki/spaces/$SPACE_KEY/pages/$($result.id)"
Write-Log "OK  이슈 $($issues.Count)개 | $pageUrl"
Show-Toast "주간보고서 작성 완료" "$pageTitle | 이슈 $($issues.Count)개"

} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
