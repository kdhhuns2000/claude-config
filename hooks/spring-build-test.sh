#!/bin/bash
# Spring Boot 컴파일 & 테스트 체크 Hook
# 파일 수정 후 자동으로 컴파일 및 테스트 확인

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
    COMPILE_OUTPUT=$(./mvnw compile -q 2>&1)
    COMPILE_EXIT=$?
    if [ $COMPILE_EXIT -eq 0 ]; then
      TEST_OUTPUT=$(./mvnw test -q 2>&1)
      TEST_EXIT=$?
    fi
  else
    exit 0  # 빌드 도구 없음
  fi
else
  # Gradle 프로젝트 - 컴파일 먼저
  COMPILE_OUTPUT=$(./gradlew compileJava compileTestJava --quiet 2>&1)
  COMPILE_EXIT=$?

  # 컴파일 성공 시 테스트 실행
  if [ $COMPILE_EXIT -eq 0 ]; then
    TEST_OUTPUT=$(./gradlew test --quiet 2>&1)
    TEST_EXIT=$?
  fi
fi

# 결과 반환
FILENAME=$(basename "$FILE_PATH")

if [ $COMPILE_EXIT -ne 0 ]; then
  # 컴파일 실패
  ERROR_MSG=$(echo "$COMPILE_OUTPUT" | grep -E "(error:|Error:|BUILD FAILED)" | head -5)
  if [ -z "$ERROR_MSG" ]; then
    ERROR_MSG=$(echo "$COMPILE_OUTPUT" | head -5)
  fi
  echo "{\"systemMessage\": \"✗ 컴파일 실패: $FILENAME\\n$ERROR_MSG\"}"
elif [ $TEST_EXIT -ne 0 ]; then
  # 테스트 실패
  FAILED_TESTS=$(echo "$TEST_OUTPUT" | grep -E "^[A-Za-z].*FAILED$" | head -5)
  FAILED_COUNT=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ tests completed, [0-9]+ failed" | head -1)
  if [ -n "$FAILED_COUNT" ]; then
    echo "{\"systemMessage\": \"✓ 컴파일 성공 | ✗ 테스트 실패: $FAILED_COUNT\\n$FAILED_TESTS\"}"
  else
    echo "{\"systemMessage\": \"✓ 컴파일 성공 | ✗ 테스트 실패\\n$(echo "$TEST_OUTPUT" | tail -5)\"}"
  fi
else
  # 모두 성공
  TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ tests" | head -1)
  if [ -n "$TEST_COUNT" ]; then
    echo "{\"systemMessage\": \"✓ 컴파일 성공: $FILENAME | ✓ 테스트 통과: $TEST_COUNT\"}"
  else
    echo "{\"systemMessage\": \"✓ 컴파일 성공: $FILENAME | ✓ 테스트 통과\"}"
  fi
fi

exit 0
