# Resolver eval

## Positive triggers (must activate this skill)
1. "오케스트레이션 정책 적용해. 그리고 로그인 버그 고쳐줘."
2. "Apply the orchestration policy to this refactor."
3. "/orchestration-policy:orchestration-policy 켜고 이 기능 구현해줘."

## Negative triggers (must NOT activate)
1. "이 함수 이름을 fetchUser로 바꿔줘." (no request for the policy)
2. "서브에이전트 여러 개로 이 저장소를 조사해줘." (asks for subagents, not for the policy by name)
3. "오케스트레이션 정책은 이제 그만 적용해." (the user says to stop)
