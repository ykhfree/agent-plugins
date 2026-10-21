# Resolver eval

## Positive triggers (must activate this skill)
1. "cross-memory의 sync 로직을 리뷰해서 문제점을 정리해줘." (a review report citing code Claude did not write)
2. "로그인 실패 원인을 조사해서 보고해줘." after Claude read the auth module and is about to cite its lines.
3. "방금 네가 쓴 분석 보고서의 인용이 실제 코드와 맞는지 확인해줘."

## Negative triggers (must NOT activate)
1. "README 오타 하나 고쳐줘." (trivial edit, no report)
2. "내가 방금 고친 함수에 대한 테스트가 통과하는지 확인해줘." (own edit, verified by tests)
3. "이 프로젝트에서 deprecated API를 쓰는 곳이 없는지 확인해줘." ("no X exists" claim: search, not a quote check)
