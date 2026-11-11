# 계정, 네트워크, 스케줄러 없이 실행하는 오프라인 검증
$ErrorActionPreference = 'Stop'
function Assert-Equal($Actual, $Expected, [string]$Label) {
    if ($Actual -cne $Expected) { throw "FAIL: $Label" }
}
$repoRoot = Split-Path $PSScriptRoot -Parent
foreach ($file in Get-ChildItem -LiteralPath $repoRoot -Filter '*.ps1' -Recurse) {
    $tokens = $null; $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count) { throw "Syntax error in $($file.Name): $($parseErrors.Message -join ', ')" }
}
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'app/weekly_report.ps1'), [ref]$tokens, [ref]$parseErrors)
foreach ($fn in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]}, $true)) {
    . ([scriptblock]::Create($fn.Extent.Text))
}
$setupAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'app/setup.ps1'), [ref]$tokens, [ref]$parseErrors)
foreach ($fn in $setupAst.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]}, $true)) {
    . ([scriptblock]::Create($fn.Extent.Text))
}

$folder = ConvertFrom-ConfluenceUrl 'https://example.atlassian.net/wiki/spaces/~abc/folder/123?view=all'
Assert-Equal $folder.Domain 'https://example.atlassian.net' 'Site from folder URL'
Assert-Equal $folder.ParentId '123' 'Parent ID from folder URL'
Assert-Equal $folder.SpaceKey '~abc' 'Space from folder URL'
$page = ConvertFrom-ConfluenceUrl 'https://example.atlassian.net/wiki/spaces/TEAM/pages/456/Report'
Assert-Equal $page.ParentId '456' 'Parent page URL'
Assert-Equal (ConvertFrom-ConfluenceUrl 'https://example.atlassian.net/wiki/spaces/%7Eabc/pages/456').SpaceKey '~abc' 'Encoded space'
foreach ($url in @('http://example.atlassian.net/wiki/spaces/A/folder/1', 'https://example.com/wiki/spaces/A/folder/1', 'https://example.atlassian.net/x/abc', 'https://example.atlassian.net/wiki/spaces/A/folder/no-id', 'https://user:password@example.atlassian.net/wiki/spaces/A/folder/1')) {
    $rejected = $false
    try { ConvertFrom-ConfluenceUrl $url | Out-Null } catch { $rejected = $true }
    Assert-Equal $rejected $true 'Reject invalid destination URL'
}

$tempFile = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName() + '.psd1')
try {
    $account = @{EMAIL='tester@example.com'; TOKEN='fake-token'; NAME="O'Brien `$name"; DOMAIN=$folder.Domain; FOLDER_ID=$folder.ParentId; SPACE_KEY=$folder.SpaceKey; SERVER_ID=''}
    Write-AccountConfig $tempFile $account
    $saved = Import-PowerShellDataFile -LiteralPath $tempFile
    Assert-Equal $saved.NAME $account.NAME 'Quote and dollar sign round trip'
    Assert-Equal $saved.TOKEN 'fake-token' 'Token round trip'
    $bytes = [IO.File]::ReadAllBytes($tempFile)
    Assert-Equal ([BitConverter]::ToString($bytes[0..2])) 'EF-BB-BF' 'Config UTF-8 BOM'
    $account.NAME = "invalid`nname"
    $rejected = $false
    try { Write-AccountConfig $tempFile $account } catch { $rejected = $true }
    Assert-Equal $rejected $true 'Reject multiline setting'
} finally { if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile } }
Assert-Equal (Get-ReportTaskName $PSScriptRoot) (Get-ReportTaskName $PSScriptRoot.ToUpperInvariant()) 'Stable task name'
if ((Get-ReportTaskName $PSScriptRoot) -eq (Get-ReportTaskName (Join-Path $PSScriptRoot 'other'))) { throw 'FAIL: Separate task names' }

$rulesFile = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName() + '.psd1')
try {
    Initialize-ReportRules $rulesFile
    $rules = Import-PowerShellDataFile -LiteralPath $rulesFile
} finally { if (Test-Path -LiteralPath $rulesFile) { Remove-Item -LiteralPath $rulesFile } }
Assert-ReportRules $rules
$SERVER_ID = ''; $DOMAIN = 'https://example.atlassian.net'; $thisFri = '10/23'
function New-Issue([string]$Key, [string]$Title, [string]$Project = 'DEMO') {
    [pscustomobject]@{key=$Key; fields=@{summary=$Title; project=@{key=$Project}; status=@{name='진행 중'; statusCategory=@{key='indeterminate'}}; duedate='2026-10-23'; resolutiondate=$null}}
}
Assert-Equal (Get-Category (New-Issue 'DEMO-1' '(개발팀) 일반 요청')) '기타' 'Team prefix ignored'
Assert-Equal (Get-Category (New-Issue 'DEMO-2' '문의 기능 추가')) '개발' 'First rule wins'
$rules.CATEGORIES += @{NAME='장애'; PROJECT_KEYS=@('INC')}
Assert-ReportRules $rules
Assert-Equal (Get-Category (New-Issue 'INC-1' '확인' 'INC')) '장애' 'Custom project'
Assert-Equal ((Get-ReportCategoryOrder $rules) -join ',') '개발,문의,기타,장애' 'Automatic category order'
Assert-Equal (Get-JiraMacro 'DEMO-1') '<a href="https://example.atlassian.net/browse/DEMO-1">DEMO-1</a>' 'Issue link without server ID'
$rules.GROUP_RULES = @(@{KEYWORD='점검'; LABEL='점검 & 확인'; CATEGORY='기타'; SCHEDULE='~{FRIDAY}'; STATUS='진행중'})
Assert-ReportRules $rules
$items = @((New-Issue 'DEMO-3' '점검 A'), (New-Issue 'DEMO-4' '점검 B'), (New-Issue 'DEMO-5' '일반 A & B'))
$table = [xml]('<table xmlns:ac="urn:test">' + (Get-Row '기타' $items).Replace('&nbsp;', '&#160;') + '</table>')
Assert-Equal $table.table.tr.Count 2 'Grouped rows'
Assert-Equal $table.table.tr[0].td[0].rowspan '2' 'Category rowspan'
Assert-Equal $table.SelectNodes('//a').Count 3 'No missing or duplicate issues'
Assert-Equal $table.table.tr[1].td[1].InnerText '~10/23' 'Grouped Friday date'
Assert-Equal $table.table.tr[1].td[0].InnerText.Contains('점검 & 확인') $true 'Escaped group label'
$done = New-Issue 'DEMO-6' 'Completed'
$done.fields.status.statusCategory.key = 'done'
$done.fields.resolutiondate = '2026-10-19T16:00:00+0900'
$table = [xml]('<table>' + (Get-Row '기타' @($done)).Replace('&nbsp;', '&#160;') + '</table>')
Assert-Equal $table.table.tr.td[2].InnerText '10/19' 'Completed date'
$SERVER_ID = 'test'
if ((Get-JiraMacro 'DEMO-1') -notmatch 'structured-macro') { throw 'FAIL: Optional Jira macro' }
$rules.CATEGORIES = @(); $rules.GROUP_RULES = @(); $rules.CATEGORY_ORDER = @()
Assert-ReportRules $rules
Assert-Equal (Get-Category $done) '기타' 'Empty categories'
$rules.CATEGORIES = @(@{NAME='Invalid'})
$rejected = $false
try { Assert-ReportRules $rules } catch { $rejected = $true }
Assert-Equal $rejected $true 'Reject empty matching rule'
Write-Host 'PASS: Syntax, destination URLs, safe config serialization, task names, categories, grouping, links, macros, escaping and dates.'
