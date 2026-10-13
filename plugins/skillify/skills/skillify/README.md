# skillify

일회성 대화에서 검증된 해결책·재발 위험 패턴을 **영구 재사용 가능한 스킬**로 승격시키는 메타 스킬.

> **철칙:** "한 번 돌아갔다"는 완료가 아니다. "같은 방식으로 다시는 실패할 수 없다"가 완료다.

## 무엇을 하는가

`skillify`는 다음을 디스크 위의 디렉터리 산출물로 강제한다.

- `SKILL.md` (정확한 frontmatter, 헤징 표현 금지)
- `scripts/` 의 실행 가능한 결정론적 코드
- `tests/unit`, `tests/integration`, `tests/e2e` 의 테스트
- `evals/llm.md`, `evals/resolver.md` 의 평가 시나리오
- 트리거가 등록된 resolver

프롬프트 수정·AGENTS.md/CLAUDE.md 메모·채팅 요약은 산출물이 **아니다**. 그것들은 결정론적 게이트가 아니라 리마인더이며, `skillify`가 막으려는 실패 모드 그 자체다.

## 트리거 조건

`SKILL.md` 의 `description` frontmatter에 의해 라우팅된다. 다음 중 하나라도 해당되면 활성화된다.

- `skillify`, `이걸 스킬로 만들어`, `영구화`, `재발 방지`, `표준화`, `템플릿화` 등의 명시적 키워드
- 동일 클래스의 실패가 현재 또는 이전 세션에서 ≥1회 발생
- 결정론적 스크립트로 풀 수 있었던 문제를 모델 추론으로 해결한 경우
- 검증된 패턴이 교차 프로젝트 재사용 가치를 갖는 경우

자세한 활성/비활성 케이스는 `evals/resolver.md` 참고.

## 디렉터리 구조

```
skillify/
├── SKILL.md                         # 13단계 절차, 금지 행동, 합리화 표
├── README.md                        # (이 문서)
├── scripts/                         # 결정론적 실행 도구
│   ├── scaffold.sh                  # 새 스킬 디렉터리 골격 생성
│   ├── validate.sh                  # 구조·frontmatter·헤징·위치 게이트
│   ├── audit_duplicates.sh          # 이름 충돌 / 키워드 중복 검사
│   └── run_tests.sh                 # unit → integration → e2e 순차 실행
├── tests/
│   ├── unit/                        # 개별 스크립트 단위 테스트
│   ├── integration/                 # 픽스처 스킬 대상 통합 테스트
│   ├── e2e/smoke.sh                 # 파이프라인 전체 스모크
│   └── fixtures/
│       ├── valid-skill/             # 게이트 통과해야 하는 표본
│       └── hedging-skill/           # 헤징 단어로 게이트 실패해야 하는 표본
└── evals/
    ├── llm.md                       # 모델 거동 평가 (positive/negative)
    └── resolver.md                  # 라우팅 평가 (positive/negative)
```

## 스크립트 계약

| 스크립트                                     | 입력                                       | 출력 / 종료 코드                                            |
| -------------------------------------------- | ------------------------------------------ | ----------------------------------------------------------- |
| `scaffold.sh <skill-dir>`                    | 비어 있거나 존재하지 않는 디렉터리 경로     | `0` 생성 완료 / `2` 인자 오류 / `3` 비어있지 않은 경로       |
| `validate.sh <skill-dir>`                    | 검증 대상 스킬 디렉터리                    | `0` 통과 / `1` 구조 위반 / `2` 인자 오류                     |
| `audit_duplicates.sh <name> [<keyword>...]`  | 제안 이름과 핵심 키워드                    | `0` 충돌 없음·overlap<3 / `1` 충돌 또는 overlap≥3 / `2` 인자 오류 |
| `run_tests.sh <skill-dir>`                   | 검증 대상 스킬 디렉터리                    | `0` 전체 통과 / `1` 하나라도 실패 / `2` 인자 오류            |
| `check_recommended_skills.sh`                | (없음)                                     | stdout에 5개 권장 스킬의 `present`/`absent` 상태 / 항상 `0` (정보성) |
| `check_test_home_pollution.sh <skill-dir>`   | 검증 대상 스킬 디렉터리                    | `0` 통과 / `1` `tests/` 가 실제 런타임 스킬 디렉터리를 오염시킴 / `2` 인자 오류 |

`validate.sh`가 강제하는 10개 게이트의 정의는 단일 진실 원천인 `SKILL.md` Step 11을 참조한다.

## 빠른 사용법

새 스킬을 만들 때 `SKILL.md` 의 13단계 Mandatory Procedure를 따른다. 결정론적 부분은 다음 명령으로 자동화된다.

```bash
# Resolve the current skillify directory first.
skillify_dir=<path-to-skillify>

# (사전 점검) — 권장 서브 스킬 설치 여부 확인
"$skillify_dir/scripts/check_recommended_skills.sh"

# Step 3 — 이름·키워드 중복 감사
"$skillify_dir/scripts/audit_duplicates.sh" <proposed-name> <kw1> <kw2>

# Step 6 — 스킬 디렉터리 골격 생성
"$skillify_dir/scripts/scaffold.sh" <skill-dir>

# Step 11 — 구조 게이트
"$skillify_dir/scripts/validate.sh" <skill-dir>

# Step 12 — 전체 테스트 실행
"$skillify_dir/scripts/run_tests.sh" <skill-dir>
```

`check_recommended_skills.sh` 가 어떤 항목을 `absent` 로 보고하면, 해당 책임은 `SKILL.md` 의 `## Inline fallback procedures` 의 (D1)/(D2)/(D3) 절차로 대체한다.

## skillify 자체에 대한 테스트

`skillify` 자신도 게이트를 통과해야 한다. 자기 검증 절차:

```bash
# skillify 자체의 모든 테스트 실행
"$skillify_dir/scripts/run_tests.sh" "$skillify_dir"

# E2E: scaffold → validate → run_tests 의 전 파이프라인
"$skillify_dir/tests/e2e/smoke.sh"
```

E2E 스모크는 격리된 임시 HOME의 런타임 스킬 경로에 스킬을 만들고, 종료 시 `trap` 으로 정리한다.

## 관련 스킬 (권장)

다섯 항목 모두 **권장 (Recommended)** 이며 필수 의존성이 아니다. 부재 시 `SKILL.md` 의 `## Inline fallback procedures` 의 (D1)/(D2)/(D3) 절차로 대체한다.

- **`$skill-creator`** — Codex의 Step 5(SKILL.md 저작) 권장 도우미. Step 6–13을 대체하지 않는다. 부재 시 → (D1).
- **`superpowers:writing-skills`** — Step 5(SKILL.md 저작) 권장. 부재 시 → (D1).
- **`superpowers:test-driven-development`** — Step 7–9 권장 규율. 부재 시 → (D2).
- **`superpowers:verification-before-completion`** — Step 13(재발 방지 검증) 권장. 부재 시 → (D3).
- **`claude-plugins-official:skill-creator`** — Step 5의 UI 보조. Step 6–13을 대체하지 않는다. 부재 시 → (D1).

설치 여부는 `scripts/check_recommended_skills.sh` 로 확인한다. `validate.sh` 는 권장 스킬을 참조하는 SKILL.md가 미설치 환경에서 검증될 때 stderr에 `WARN:` 한 줄을 출력하지만, 종료 코드는 항상 10개 게이트 정책에 따른다.

## 사용해서는 안 되는 경우

- 재발 위험 없는 일회성 미관 수정 → 그냥 고치고 끝.
- 단일 레포 한정 컨벤션 → Codex는 `AGENTS.md`, Claude Code는 `CLAUDE.md` 에 기록.
- lint·regex·CI 가 이미 강제하는 기계적 제약 → 그것이 곧 결정론적 해결책. 스킬로 감싸지 않는다.
- 운영에서 아직 검증되지 않은 해결책 → 한 번 돌려본 뒤 skillify 한다.
