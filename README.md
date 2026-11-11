# WeeklyReport — Jira 주간보고서 자동 작성

본인에게 할당된 Jira 이슈를 분류해 Confluence에 주간보고서를 만들고, 매주 정해진 시간에 자동으로 실행합니다.

## 처음 사용하기

**Windows 10/11과 Windows PowerShell 5.1**에서 사용합니다. Git이나 Python 설치는 필요 없습니다. 같은 Atlassian Cloud 사이트에서 Jira와 Confluence를 사용하고, 이슈 조회 및 보고서 생성·수정 권한이 있어야 합니다.

1. 이 저장소 위쪽의 **Code → Download ZIP**으로 내려받습니다.
2. ZIP을 완전히 압축 해제하고, 계속 사용할 폴더에 둡니다. 예: `문서\WeeklyReport`. ZIP 안에서 직접 실행하지 마세요.
3. **`처음설정.cmd`를 더블클릭**합니다.
4. 본인 이름, Atlassian 계정 이메일, API 토큰, 보고서를 저장할 **Confluence 폴더 또는 상위 페이지 주소**를 입력합니다. 토큰은 입력 중 화면에 표시되지 않습니다.
5. 안내에 따라 보고서를 한 번 생성해 확인하고, 원하면 매주 수요일 오후 4시 자동 실행을 등록합니다. 질문에서 `y`를 입력하면 실행하며, Enter만 누르면 건너뜁니다.

설정 후에는 **`지금실행.cmd`를 더블클릭**하면 언제든 보고서를 만들 수 있습니다. 자동 실행은 PC가 켜져 있고 본인 Windows 계정으로 로그인한 상태에서 동작합니다. 예약 시간을 놓치면 이후 실행 가능한 시점에 실행합니다.

### 입력할 정보 준비

- **API 토큰:** [Atlassian API 토큰 관리](https://id.atlassian.com/manage-profile/security/api-tokens)에서 본인 계정으로 범위 없는 토큰을 발급합니다. 이 도구는 사이트 주소에 이메일 + API 토큰으로 인증합니다. 범위가 지정된 토큰의 별도 API gateway 방식은 지원하지 않습니다. 인증 주소의 차이는 [Atlassian 공식 안내](https://support.atlassian.com/confluence/kb/scoped-api-tokens-in-confluence-cloud/)를 참고하세요.
- **저장할 주소:** Confluence에서 폴더나 상위 페이지를 연 뒤 브라우저 주소를 복사합니다. `https://your-team.atlassian.net/wiki/spaces/SPACE/folder/123456789` 또는 `.../pages/123456789/페이지제목` 형식입니다. `/x/...` 같은 단축 공유 주소 대신 실제 페이지 주소를 사용하세요.

폴더 ID와 스페이스 키는 주소에서 자동으로 읽으므로 따로 찾을 필요가 없습니다. Jira와 Confluence가 서로 다른 사이트에 있거나 자체 서버 설치 버전이면 이 도구의 지원 범위에 해당하지 않습니다.

## 실행 결과와 주의사항

- 제목은 `yyyy-MM-dd (이름)`입니다. 같은 스페이스에 같은 제목이 있으면 **기존 본문 전체를 덮어씁니다. 수동으로 적은 차주 업무도 초기화됩니다.**
- 진행 중 상태 범주의 이슈는 날짜 제한 없이, 완료 범주는 이번 주 월요일부터 실행 시점까지 완료 처리된 이슈만, 신규 범주는 이번 주 업데이트된 이슈만 포함합니다.
- 페이지당 100개씩 마지막 페이지까지 조회한 뒤 설정한 제외 상태를 걸러냅니다.
- 완료된 이슈 일정에는 완료일을, 나머지는 마감일을 표시합니다. 차주 항목은 빈칸입니다.
- 기본적으로 Jira 이슈를 클릭 가능한 링크로 표시합니다. 매크로 표시가 필요하면 개인 설정의 `SERVER_ID`에 Confluence의 Jira application link ID를 입력하세요. 이 값은 사이트 관리자에게 확인합니다.
- 실행 내역과 보고서 주소는 같은 폴더의 `weekly_report.log`에서 확인합니다.
- 개인 설정에는 API 토큰이 평문으로 저장됩니다. **설정 완료 후 폴더 전체를 다른 사람에게 공유하지 마세요.** 배포는 이 저장소의 ZIP을 사용하세요.

## 분류 규칙 바꾸기

처음 설정하면 `weekly_report.rules.psd1`이 생성됩니다. 메모장 등으로 열어 수정하고 **UTF-8 BOM**으로 저장하세요. 실행 코드는 수정할 필요가 없습니다.

```powershell
CATEGORIES = @(
    @{ NAME = '개발'; PROJECT_KEYS = @('DEV'); KEYWORDS = @('개발', '기능 추가') }
    @{ NAME = '문의'; KEYWORDS = @('문의') }
)
DEFAULT_CATEGORY = '기타'
CATEGORY_ORDER = @('개발', '문의', '기타')
EXCLUDED_STATUSES = @('HOLDING')
```

프로젝트 키 또는 제목 키워드 중 하나라도 맞으면 분류합니다. 위쪽 규칙이 우선하며 키워드는 대소문자를 구분하지 않는 문자 그대로의 검색입니다. 조건이 없는 분류나 중복 분류명은 허용하지 않습니다. 일치하지 않는 이슈는 기본 분류로 갑니다. `CATEGORY_ORDER`는 표 순서이며 분류 우선순위와 별개입니다. 새 분류를 적지 않아도 뒤에 추가됩니다. 분류를 삭제하면 표시 순서에서도 삭제하세요.

여러 티켓을 한 행으로 묶으려면 `GROUP_RULES`를 설정합니다.

```powershell
GROUP_RULES = @(
    @{ KEYWORD = '정기 점검'; LABEL = '정기 점검'; CATEGORY = '기타'; SCHEDULE = '~{FRIDAY}'; STATUS = '진행중' }
)
```

묶음 규칙은 일반 분류보다 먼저 적용하며 첫 번째로 맞는 묶음에만 배정합니다. `CATEGORY`는 정의된 분류 또는 기본 분류여야 합니다. `{FRIDAY}`는 이번 주 금요일의 `MM/dd`로 바뀝니다. 묶음의 일정과 상태는 지정한 문구이며 개별 이슈의 실제 값을 합산하지 않습니다. 묶음이 필요 없으면 `GROUP_RULES = @()`로 둡니다. `IGNORE_TEAM_PREFIX = $true`이면 제목 앞 `(개발팀)`처럼 '팀'으로 끝나는 괄호 접두어는 일반 분류 검사에서 제외하고 표시 제목은 유지합니다.

## 설정 변경·업데이트·자동 실행 해제

- **계정이나 저장 위치 변경:** `처음설정.cmd`를 다시 실행하고 기존 설정을 다시 입력하겠다는 질문에 `y`를 입력합니다. 분류 규칙은 유지합니다.
- **업데이트:** 새 ZIP에서 프로그램 파일과 예시 파일만 기존 폴더에 덮어씁니다. 본인의 `weekly_report.config.psd1`, `weekly_report.rules.psd1`은 유지하세요. 설치 폴더를 옮기지 않으면 스케줄러를 다시 등록할 필요가 없습니다.
- **폴더 이동:** Windows 작업 스케줄러에서 기존 작업을 삭제하고, 이동한 폴더에서 `처음설정.cmd`로 자동 실행을 다시 등록하세요.
- **자동 실행 해제:** Windows 작업 스케줄러에서 설정 완료 시 표시된 `WeeklyReport-…` 작업을 사용 안 함으로 바꾸거나 삭제합니다. 이름은 설치 폴더마다 다릅니다. 기존에 직접 등록한 `WeeklyReport` 작업이 있다면 중복 실행을 막기 위해 별도로 해제하세요.

## 문제가 생기면

| 증상 | 확인할 내용 |
| --- | --- |
| 설정 파일을 찾을 수 없음 | 압축을 완전히 풀었는지, `처음설정.cmd`를 먼저 실행했는지 확인 |
| HTTP 401 | 계정 이메일·토큰의 오타, 만료 여부, 인증 방식 확인 |
| HTTP 403 | Jira 조회 또는 Confluence 공간·폴더·페이지 작성 권한 확인 |
| HTTP 404 / 저장 실패 | 실제 폴더·상위 페이지 주소와 사이트가 맞는지 확인 |
| 자동 실행 안 됨 | PC 켜짐·Windows 로그인 여부, 작업 스케줄러의 작업과 설치 경로 확인 |
| 한글 깨짐 | 수정한 `.ps1`, `.psd1` 파일을 UTF-8 BOM으로 저장 |

회사 정책으로 스크립트나 토큰 발급이 막혀 있다면 관리자에게 문의하세요. 오류를 공유할 때 개인 설정이나 API 토큰을 첨부하지 마세요.

Jira 조회만 확인하려면 해당 폴더에서 다음 명령을 실행합니다. **Confluence 저장 권한과 최종 보고서까지 검증하는 명령은 아닙니다.**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\weekly_report.ps1 -Preview
```

## 파일 구성과 개발자 검증

| 파일 | 역할 |
| --- | --- |
| `처음설정.cmd`, `setup.ps1`, `setup_helpers.ps1` | 개인 설정 생성, 주소 해석, 선택적 실행·스케줄러 등록 |
| `지금실행.cmd`, `weekly_report.ps1` | 보고서 생성·갱신 |
| `weekly_report.config.example.psd1` | 개인정보 없는 계정 설정 양식 |
| `weekly_report.rules.example.psd1` | 공통 분류 예시 |
| `verify_rules.ps1` | 개인 설정 없이 오프라인 검증 |

실제 개인 설정·개인 규칙·로그는 `.gitignore`로 제외합니다. 예시 파일에는 실제 토큰, 개인 이메일, 회사 주소, 저장 위치 ID를 넣지 마세요.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify_rules.ps1
```

검증은 API를 호출하거나 보고서를 게시하거나 스케줄러를 등록하지 않습니다.
