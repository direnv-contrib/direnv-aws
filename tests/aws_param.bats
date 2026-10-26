#!/usr/bin/env bats

# Tests for lib/aws_param.sh (use_aws_param)
#
# Requires bats-core: https://github.com/bats-core/bats-core, direnv and jq
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

# ---------------------------------------------------------------------------
# Loading parameters
# ---------------------------------------------------------------------------

@test "a path ending in / exports every parameter under it" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Parameters\":[{\"Name\":\"/myapp/dev/db_url\",\"Value\":\"postgres://example/db\"},{\"Name\":\"/myapp/dev/api-key\",\"Value\":\"abc123\"}]}"; }
    use_aws_param /myapp/dev/
    echo "DB_URL=$DB_URL API_KEY=$API_KEY"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "DB_URL=postgres://example/db API_KEY=abc123" ]]
}

@test "a single parameter is named after the last path segment" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Parameter\":{\"Name\":\"/myapp/dev/db_url\",\"Value\":\"postgres://example/db\"}}"; }
    use_aws_param /myapp/dev/db_url
    echo "DB_URL=$DB_URL"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "DB_URL=postgres://example/db" ]]
}

@test "NAME=/path exports a single parameter under that name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Parameter\":{\"Name\":\"/myapp/dev/db\",\"Value\":\"single\"}}"; }
    use_aws_param TOKEN=/myapp/dev/db
    echo "TOKEN=$TOKEN"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "TOKEN=single" ]]
}

@test "a path ending in / uses get-parameters-by-path with decryption" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "args: $*" >&2; echo "{\"Parameters\":[]}"; }
    use_aws_param /myapp/dev/
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: ssm get-parameters-by-path --path /myapp/dev/ --recursive --with-decryption --output json"* ]]
}

@test "a single path uses get-parameter with decryption" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "args: $*" >&2; echo "{\"Parameter\":{\"Name\":\"/a/b\",\"Value\":\"v\"}}"; }
    use_aws_param /a/b
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: ssm get-parameter --name /a/b --with-decryption --output json"* ]]
}

@test "the status line reports how many parameters were loaded" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Parameters\":[{\"Name\":\"/a/one\",\"Value\":\"1\"},{\"Name\":\"/a/two\",\"Value\":\"2\"}]}"; }
    use_aws_param /a/
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_aws_param: loaded 2 parameter(s)"* ]]
}

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

@test "no arguments prints the usage and fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_aws_param
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_aws_param [NAME=]/param/path"* ]]
}

@test "fails when aws is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    has() { [[ "$1" != "aws" ]] && type "$1" &>/dev/null; }
    use_aws_param /a/b
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"aws not found"* ]]
}

@test "fails when jq is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    aws() { :; }
    has() { [[ "$1" != "jq" ]] && type "$1" &>/dev/null; }
    use_aws_param /a/b
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"jq not found"* ]]
}

@test "fails when a name is given for a path ending in /" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    aws() { :; }
    use_aws_param BAD=/myapp/dev/
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"cannot name a variable for path /myapp/dev/"* ]]
}

@test "fails when a parameter cannot be read" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { return 255; }
    use_aws_param /a/missing
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"failed to read /a/missing"* ]]
}

@test "fails when a path cannot be read" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { return 255; }
    use_aws_param /a/
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"failed to read /a/"* ]]
}

@test "fails on a name that is not a valid variable name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AWS_PROFILE AWS_SESSION_TOKEN
    aws() { echo "{\"Parameter\":{\"Name\":\"/a/b\",\"Value\":\"v\"}}"; }
    use_aws_param 1BAD=/a/b
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid variable name '1BAD'"* ]]
}
