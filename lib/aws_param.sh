# use_aws_param: load AWS SSM Parameter Store parameters into the environment
#
#   use_aws_param /myapp/dev/            every parameter under the path, named after its last segment
#   use_aws_param DB_URL=/myapp/dev/db   a single parameter with an explicit variable name

# stdin: aws ssm JSON, $1: explicit variable name (optional)
# stdout: NUL-delimited name/value pairs
_aws_param_emit() {
  jq -j --arg name "$1" '
    (.Parameters // [.Parameter])[]
    | (if $name != "" then $name
       else (.Name | split("/") | last | ascii_upcase | gsub("[^A-Z0-9_]"; "_")) end),
      "\u0000", .Value, "\u0000"'
}

use_aws_param() {
  if [[ $# -eq 0 ]]; then
    log_error "use_aws_param: usage: use_aws_param [NAME=]/param/path ..."
    return 1
  fi
  has aws || { log_error "use_aws_param: aws not found"; return 1; }
  has jq || { log_error "use_aws_param: jq not found"; return 1; }

  local arg name param_path json key value count=0
  for arg in "$@"; do
    name="" param_path=$arg
    if [[ $arg == *=* ]]; then
      name=${arg%%=*}
      param_path=${arg#*=}
    fi

    if [[ $param_path == */ ]]; then
      if [[ -n $name ]]; then
        log_error "use_aws_param: cannot name a variable for path $param_path"
        return 1
      fi
      json=$(_aws_run ssm get-parameters-by-path --path "$param_path" \
        --recursive --with-decryption --output json) || {
        log_error "use_aws_param: failed to read $param_path"
        return 1
      }
    else
      json=$(_aws_run ssm get-parameter --name "$param_path" \
        --with-decryption --output json) || {
        log_error "use_aws_param: failed to read $param_path"
        return 1
      }
    fi

    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      if [[ ! $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        log_error "use_aws_param: invalid variable name '$key'"
        return 1
      fi
      export "$key=$value"
      ((count++))
    done < <(printf '%s' "$json" | _aws_param_emit "$name")
  done

  log_status "use_aws_param: loaded $count parameter(s)"
}
