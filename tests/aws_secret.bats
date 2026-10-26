#!/usr/bin/env bats

# Tests for lib/aws_secret.sh (use_aws_secret)
#
# Requires bats-core: https://github.com/bats-core/bats-core, direnv and jq
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

# ---------------------------------------------------------------------------
# Loading secrets
# ---------------------------------------------------------------------------

@test "a JSON secret exports one uppercased variable per key" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Name\":\"prod/db/creds\",\"SecretString\":\"{\\\"username\\\":\\\"alice\\\",\\\"pass-word\\\":\\\"hunter2\\\",\\\"port\\\":5432}\"}"; }
    use_aws_secret prod/db/creds
    echo "USERNAME=$USERNAME PASS_WORD=$PASS_WORD PORT=$PORT"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "USERNAME=alice PASS_WORD=hunter2 PORT=5432" ]]
}

@test "a plain secret is named after the last path segment" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Name\":\"prod/db/url\",\"SecretString\":\"postgres://example/db\"}"; }
    use_aws_secret prod/db/url
    echo "URL=$URL"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "URL=postgres://example/db" ]]
}

@test "NAME=secret-id exports the raw secret string under that name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Name\":\"prod/db/creds\",\"SecretString\":\"{\\\"user\\\":\\\"alice\\\"}\"}"; }
    use_aws_secret DB_CREDS=prod/db/creds
    echo "$DB_CREDS"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == '{"user":"alice"}' ]]
}

@test "several secrets can be loaded in one call" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() {
      case "$*" in
        *first*) echo "{\"Name\":\"first\",\"SecretString\":\"one\"}" ;;
        *second*) echo "{\"Name\":\"second\",\"SecretString\":\"two\"}" ;;
      esac
    }
    use_aws_secret first second
    echo "FIRST=$FIRST SECOND=$SECOND"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "FIRST=one SECOND=two" ]]
}

@test "the secret id is passed to aws secretsmanager" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "args: $*" >&2; echo "{\"Name\":\"x\",\"SecretString\":\"v\"}"; }
    use_aws_secret my/secret
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: secretsmanager get-secret-value --secret-id my/secret --output json"* ]]
}

@test "the status line reports how many variables were loaded" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Name\":\"x\",\"SecretString\":\"{\\\"a\\\":\\\"1\\\",\\\"b\\\":\\\"2\\\"}\"}"; }
    use_aws_secret x
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_aws_secret: loaded 2 variable(s)"* ]]
}

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

@test "no arguments prints the usage and fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_aws_secret
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_aws_secret [NAME=]secret-id"* ]]
}

@test "fails when aws is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    has() { [[ "$1" != "aws" ]] && type "$1" &>/dev/null; }
    use_aws_secret prod/db/url
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"aws not found"* ]]
}

@test "fails when jq is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    aws() { :; }
    has() { [[ "$1" != "jq" ]] && type "$1" &>/dev/null; }
    use_aws_secret prod/db/url
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"jq not found"* ]]
}

@test "fails when the secret cannot be read" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { return 255; }
    use_aws_secret prod/missing
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"failed to read prod/missing"* ]]
}

@test "fails when the secret has no string value" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Name\":\"blob\",\"SecretBinary\":\"AAEC\"}"; }
    use_aws_secret blob
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"blob has no string value"* ]]
}

@test "fails on a key that is not a valid variable name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Name\":\"x\",\"SecretString\":\"{\\\"1bad\\\":\\\"v\\\"}\"}"; }
    use_aws_secret x
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid variable name '1BAD'"* ]]
}
