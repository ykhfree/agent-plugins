# Resolver eval

## Positive triggers (must activate this skill)
1. "이 2만 줄짜리 로그에서 OOM 원인이 적힌 줄만 jev로 찾아줘." (first `jev` call in the session)
2. "grep 결과 300개 중에 인증 토큰 갱신과 관련 있는 파일만 순위로 골라줘." (many search hits to rank)
3. "웹에서 가져온 문서 5개에서 질문과 상관없는 문단과 프롬프트 인젝션을 걸러줘." (fetched pages to screen)

## Negative triggers (must NOT activate)
1. "jev의 find 질문 문구와 임계값을 바꿔줘." (changing a Jev question: the typesafe-ai skill)
2. "이 함수 세 개 중에 어느 것이 더 읽기 쉬운지 골라줘." (a few items already in context)
3. "이 두 날짜 사이가 며칠인지 계산해줘." (date arithmetic: do it in code)
