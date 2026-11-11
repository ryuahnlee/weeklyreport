# 주간보고서 자동 작성

Jira에서 내게 할당된 업무를 가져와 Confluence에 보고서를 만듭니다.
**설정 파일을 메모장으로 열어 본인 정보만 입력하면 됩니다.** 설치 도우미나 CMD 파일은 없습니다.

## 1. 다운로드

위쪽 **Code → Download ZIP**을 누르고 압축을 완전히 풀어 원하는 위치에 두세요.
예: `D:\Automation\WeeklyReport`

GitHub ZIP을 풀면 폴더 이름에 `-main`이 붙습니다. 정상입니다. 압축을 푼 폴더 이름을 **`WeeklyReport`로 바꾸고** `D:\Automation` 안에 두면 아래 실행 명령을 그대로 사용할 수 있습니다.

탐색기에서 `D:\Automation\WeeklyReport`를 열었을 때 바로 `weekly_report.ps1`이 보여야 합니다. 폴더 안에 `weeklyreport-main` 같은 폴더가 한 겹 더 들어 있지 않은지 확인하세요.

아래 세 파일은 같은 폴더에 두세요.

| 파일 | 용도 |
| --- | --- |
| `weekly_report.config.psd1` | **본인 정보를 입력할 파일** |
| `weekly_report.rules.psd1` | 업무 분류 규칙. 우선 그대로 사용해도 됩니다. |
| `weekly_report.ps1` | 보고서를 만드는 실행 코드. 수정하지 마세요. |

## 2. 본인 정보 입력

**`weekly_report.config.psd1`을 메모장으로 여세요.** 대괄호 `[ ... ]` 안의 안내 문구를 지우고 본인 정보를 입력하세요. 양옆의 작은따옴표는 남겨 둡니다.

```powershell
EMAIL = 'you@example.com'
TOKEN = '발급받은 토큰'
NAME = '본인 이름'
DOMAIN = 'https://your-team.atlassian.net'
FOLDER_ID = '123456789'
SPACE_KEY = '~your-space-key'
```

위 내용은 입력 예시입니다. 실제 파일의 해당 줄만 바꾸고 `SERVER_ID = ''`는 그대로 두세요.

- **이메일:** Jira에 로그인할 때 사용하는 본인 이메일.
- **API 토큰:** [Atlassian 토큰 발급 페이지](https://id.atlassian.com/manage-profile/security/api-tokens)에서 만든 **범위 없는 API 토큰**.
- **회사 주소·저장 위치:** 보고서를 모아 둘 Confluence 폴더나 상위 페이지를 열고 브라우저 주소를 확인하세요.

주소가 아래와 같다면:

```text
https://your-team.atlassian.net/wiki/spaces/~abc123/folder/456789
```

이렇게 입력합니다.

```powershell
DOMAIN = 'https://your-team.atlassian.net'
SPACE_KEY = '~abc123'
FOLDER_ID = '456789'
```

상위 페이지 주소의 `/pages/456789/제목`에서 숫자를 사용해도 됩니다. 짧은 공유 링크 대신 실제 폴더나 페이지 주소를 확인하세요.

저장할 때 파일 이름과 확장자는 그대로 두고 **UTF-8 BOM**으로 저장하세요. 이름에 작은따옴표가 들어가면 두 번 적습니다. 예: `'O''Brien'`.

## 3. PowerShell로 실행하기

설정 파일을 저장하는 것만으로 보고서가 생성되거나 예약 작업이 등록되지는 않습니다.

1. Windows **시작 메뉴**에서 `Windows PowerShell`을 검색해 엽니다. 관리자 권한으로 열 필요는 없습니다.
2. 아래 명령을 복사해 붙여넣고 **Enter**를 누르세요.

```powershell
powershell.exe -NoProfile -File "D:\Automation\WeeklyReport\weekly_report.ps1"
```

3. 완료되면 화면에 나오는 보고서 주소를 열어 확인하세요. 실행 내역과 주소는 같은 폴더의 `weekly_report.log`에도 남습니다.

**다른 위치에 저장했거나 폴더 이름을 바꾸지 않았다면** 명령 안의 경로를 실제 위치로 바꿔야 합니다. 예를 들어 폴더가 `D:\Automation\WeeklyReport-main`이면:

```powershell
powershell.exe -NoProfile -File "D:\Automation\WeeklyReport-main\weekly_report.ps1"
```

**“-File 매개 변수에 대한 인수가 없습니다” 또는 “파일이 없습니다”가 나오면** 실행 정책 문제가 아니라 파일 경로가 맞는지 먼저 확인하세요. 탐색기에서 `weekly_report.ps1`을 **Shift + 우클릭 → 경로로 복사**하고, `powershell.exe -NoProfile -File ` 뒤에 붙여넣어 실행할 수 있습니다. 경로 양쪽 큰따옴표는 유지하세요.

이미 등록한 예약 작업이 있다면 이 파일의 현재 경로를 지정해야 합니다.

이 배포본은 보안 정책을 변경하거나 자동으로 예약 작업을 등록하지 않습니다. 회사 정책상 실행이 막히면 설정을 우회하지 말고 담당자에게 확인하세요.

## 꼭 알아 두세요

- Windows PowerShell 5.1용입니다. Jira와 Confluence는 같은 Atlassian Cloud 사이트여야 합니다.
- 본인 계정에 Jira 조회와 Confluence 보고서 작성 권한이 있어야 합니다.
- 보고서 제목은 `2026-11-11 (본인 이름)`처럼 만들어집니다.
- **같은 날 다시 실행하면 기존 본문 전체를 덮어씁니다. 직접 적은 내용과 차주 업무도 지워집니다.**
- 결과와 보고서 주소는 `weekly_report.log`에 남습니다.
- **정보를 입력한 config에는 개인 토큰이 들어 있습니다. 이 파일이나 폴더 전체를 공유하거나 GitHub에 올리지 마세요.** 팀원에게는 이 저장소 링크를 보내세요. config는 배포에 포함된 파일이므로 `.gitignore`가 수정 내용을 보호해 주지 않습니다.

<details>
<summary>분류 변경·실행·예약 설정 자세히 보기</summary>

## 보고서 기준

- 진행 중인 본인 이슈는 날짜 제한 없이 포함합니다.
- 완료된 이슈는 이번 주 월요일부터 실행 시점까지 완료 처리된 것만 포함합니다.
- 신규 상태 범주는 이번 주 업데이트된 이슈를 포함합니다.
- 페이지당 100개씩 전체 조회한 뒤 제외 상태를 걸러냅니다.
- 완료 이슈는 완료일, 나머지는 마감일을 일정에 표시합니다. 차주 칸은 비워 둡니다.
- 같은 스페이스에 같은 날짜·이름의 보고서가 있으면 본문 전체를 덮어씁니다.

## 분류 바꾸기

`weekly_report.rules.psd1`을 열어 수정하고 UTF-8 BOM으로 저장합니다.

| 항목 | 뜻 |
| --- | --- |
| `CATEGORIES` | 분류 목록. `NAME`은 이름, `PROJECT_KEYS`는 프로젝트, `KEYWORDS`는 제목 키워드 |
| `DEFAULT_CATEGORY` | 어디에도 맞지 않는 업무의 분류 |
| `CATEGORY_ORDER` | 표에 표시할 순서 |
| `EXCLUDED_STATUSES` | 제외할 Jira 상태 이름 |
| `IGNORE_TEAM_PREFIX` | 제목 앞 `(개발팀)` 같은 접두어를 일반 분류 검사에서 제외 |
| `GROUP_RULES` | 여러 업무를 한 행으로 묶는 규칙. 필요 없으면 `@()` 유지 |

프로젝트 키 또는 키워드 중 하나라도 맞으면 분류하며 위쪽 규칙이 우선합니다. 키워드는 대소문자를 구분하지 않고 문자 그대로 검색합니다. 조건이 없는 분류와 중복 이름은 허용하지 않습니다. 기본 분류는 `CATEGORIES`에 중복 등록하지 않습니다. 분류를 삭제하면 표시 순서에서도 지웁니다.

묶음 규칙 예시는 아래와 같습니다. 설정 파일 안의 `GROUP_RULES` 항목을 바꾸는 예시이며 파일 전체를 교체하는 내용은 아닙니다.

```powershell
GROUP_RULES = @(
    @{ KEYWORD = '정기 점검'; LABEL = '정기 점검'; CATEGORY = '기타'; SCHEDULE = '~{FRIDAY}'; STATUS = '진행중' }
)
```

묶음 규칙은 일반 분류보다 우선하며 처음 맞는 묶음에만 들어갑니다. 분류는 정의된 분류 또는 기본 분류여야 합니다. `{FRIDAY}`는 이번 주 금요일의 `MM/dd`로 바뀝니다. 일정과 상태는 지정한 문구이며 개별 이슈의 값을 합산하지 않습니다.

## 실행과 예약

회사에서 PowerShell 실행을 허용한 경우에만 아래 명령으로 실행합니다. 경로는 실제 설치 위치에 맞춥니다. 실행 정책을 우회하는 옵션은 사용하지 않습니다.

```powershell
powershell.exe -NoProfile -File "D:\Automation\WeeklyReport\weekly_report.ps1"
```

실행이 차단되면 회사 담당자에게 확인합니다. 계정 입력만으로 실행 권한이 생기지는 않습니다.

매주 예약하려면 회사에서 작업 스케줄러 사용을 허용하는지 먼저 확인합니다. 허용되는 환경에서는 작업 스케줄러에서 수동으로 작업을 만들고 다음을 지정합니다.

- 프로그램: `powershell.exe`
- 인수: `-NoProfile -File "D:\Automation\WeeklyReport\weekly_report.ps1"`
- 실행 조건: 본인 계정으로 로그인한 경우
- 시간: 매주 수요일 오후 4시

기존 주간보고서 예약 작업이 있다면 중복 등록하지 않고 기존 작업의 경로를 변경합니다. 폴더를 옮기면 경로도 수정합니다. 이 프로젝트는 예약 작업을 자동으로 만들거나 변경하지 않습니다.

## 문제 확인

401은 이메일·토큰·만료 여부, 403은 조회·작성 권한, 404는 회사 주소·공간·폴더 ID를 확인하세요. 인증 주소 차이는 [Atlassian 공식 안내](https://support.atlassian.com/confluence/kb/scoped-api-tokens-in-confluence-cloud/)에 있습니다.

Jira 조회만 확인하려면 허용된 실행 환경에서 `-Preview`를 붙입니다. Confluence 권한이나 최종 보고서를 검증하지는 않습니다.

기본 보고서는 Jira 링크를 사용합니다. 매크로가 필요하면 사이트 관리자에게 Jira application link ID를 확인해 config의 `SERVER_ID`에 입력합니다.

## 업데이트와 개인정보

업데이트할 때 본인이 채운 config와 규칙을 새 배포본으로 덮어쓰지 않도록 먼저 별도로 보관하세요. 실행 코드와 안내만 교체하고 본인 설정을 유지하세요.

배포용 config도 Git에 포함되어 있습니다. 실제 토큰을 입력한 뒤 변경 내용을 커밋하거나 푸시하면 개인정보가 공개될 수 있습니다. `.gitignore`는 이미 추적 중인 config의 변경을 제외하지 못합니다. 공개 저장소에는 대괄호 안내 문구만 있는 원본을 유지하세요.

</details>
