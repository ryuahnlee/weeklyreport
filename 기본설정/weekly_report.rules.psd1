# 필요에 맞게 분류와 키워드를 수정하세요. 위쪽 규칙이 우선합니다.
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
