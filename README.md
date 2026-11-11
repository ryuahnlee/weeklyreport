# 주간보고서 자동 작성

Jira에서 내게 할당된 업무를 가져와 Confluence에 보고서를 만듭니다.
**설정 파일을 메모장으로 열어 본인 정보만 입력하면 됩니다.** 설치 도우미나 CMD 파일은 없습니다.

## 1. 다운로드

위쪽 **Code → Download ZIP**을 누르고 압축을 완전히 풀어 원하는 위치에 두세요.
예: `D:\Automation\WeeklyReport`

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

## 3. 사용하기

설정 파일을 저장하는 것만으로 보고서가 생성되거나 예약 작업이 등록되지는 않습니다.

실제 실행은 **회사에서 허용한 PowerShell 실행 방법**을 사용하세요. 실행할 파일은 `weekly_report.ps1`입니다. 이미 등록한 예약 작업이 있다면 이 파일의 현재 경로를 지정해야 합니다.

이 배포본은 보안 정책을 변경하거나 자동으로 예약 작업을 등록하지 않습니다. 회사 정책상 실행이 막히면 설정을 우회하지 말고 담당자에게 확인하세요.

## 꼭 알아 두세요

- Windows PowerShell 5.1용입니다. Jira와 Confluence는 같은 Atlassian Cloud 사이트여야 합니다.
- 본인 계정에 Jira 조회와 Confluence 보고서 작성 권한이 있어야 합니다.
- 보고서 제목은 `2026-11-11 (본인 이름)`처럼 만들어집니다.
- **같은 날 다시 실행하면 기존 본문 전체를 덮어씁니다. 직접 적은 내용과 차주 업무도 지워집니다.**
- 결과와 보고서 주소는 `weekly_report.log`에 남습니다.
- **정보를 입력한 config에는 개인 토큰이 들어 있습니다. 이 파일이나 폴더 전체를 공유하거나 GitHub에 올리지 마세요.** 팀원에게는 이 저장소 링크를 보내세요. config는 배포에 포함된 파일이므로 `.gitignore`가 수정 내용을 보호해 주지 않습니다.

분류 변경과 자세한 실행·예약 설정은 [상세 안내](개발용/설정안내.md)를 참고하세요. `개발용` 폴더는 처음 사용할 때 열 필요 없습니다.
