#!/bin/bash
# Spring Boot 컴파일 체크 Hook
# 파일 수정 후 자동으로 컴파일 확인

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# .java 또는 .kt 파일만 체크
if [[ "$FILE_PATH" != *.java && "$FILE_PATH" != *.kt ]]; then
  exit 0
fi

# 프로젝트 루트로 이동
cd "$CLAUDE_PROJECT_DIR" || exit 0

# Gradle wrapper 존재 여부 확인
if [ ! -f "./gradlew" ]; then
  # Maven 프로젝트인 경우
  if [ -f "./mvnw" ]; then
    OUTPUT=$(./mvnw compile -q 2>&1)
    EXIT_CODE=$?
  else
    exit 0  # 빌드 도구 없음
  fi
else
  # Gradle 프로젝트
  OUTPUT=$(./gradlew compileJava compileTestJava --quiet 2>&1)
  EXIT_CODE=$?
fi

# 결과 반환
if [ $EXIT_CODE -eq 0 ]; then
  echo "{\"systemMessage\": \"✓ 컴파일 성공: $(basename "$FILE_PATH")\"}"
else
  # 에러 메시지 정리 (처음 5줄만)
  ERROR_MSG=$(echo "$OUTPUT" | grep -E "(error:|Error:|BUILD FAILED)" | head -5)
  if [ -z "$ERROR_MSG" ]; then
    ERROR_MSG=$(echo "$OUTPUT" | head -5)
  fi
  echo "{\"systemMessage\": \"✗ 컴파일 실패:\\n$ERROR_MSG\"}"
fi

exit 0
