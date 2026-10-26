#!/usr/bin/env bats

# Tests for lib/aws.sh (_aws_run)
#
# Requires bats-core: https://github.com/bats-core/bats-core and direnv
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

@test "aws runs directly when AWS_PROFILE is unset" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "aws $*"; }
    aws-vault() { echo "aws-vault $*"; }
    _aws_run sts get-caller-identity
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == "aws sts get-caller-identity" ]]
}

@test "aws runs through aws-vault when AWS_PROFILE is set and no session is active" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    export AWS_PROFILE="dev"
    unset AWS_SESSION_TOKEN
    aws() { echo "aws $*"; }
    aws-vault() { echo "aws-vault profile=$2"; shift 3; "$@"; }
    _aws_run sts get-caller-identity
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "aws-vault profile=dev" ]]
  [[ "${lines[1]}" == "aws sts get-caller-identity" ]]
}

@test "aws runs directly when a session token is already set" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    export AWS_PROFILE="dev" AWS_SESSION_TOKEN="existing-token"
    aws() { echo "aws $*"; }
    aws-vault() { echo "aws-vault $*"; }
    _aws_run sts get-caller-identity
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == "aws sts get-caller-identity" ]]
}

@test "aws runs directly when aws-vault is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    export AWS_PROFILE="dev"
    unset AWS_SESSION_TOKEN
    aws() { echo "aws $*"; }
    # pretend aws-vault is missing even if it is installed on this machine
    has() { [[ "$1" != "aws-vault" ]] && type "$1" &>/dev/null; }
    _aws_run sts get-caller-identity
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == "aws sts get-caller-identity" ]]
}
