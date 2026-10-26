# use_aws_secret: load AWS Secrets Manager secrets into the environment
#
#   use_aws_secret prod/db/creds        JSON secret: one variable per key, uppercased
#                                       plain secret: one variable named after the last segment
#   use_aws_secret DB_URL=prod/db/url   the raw secret string with an explicit variable name

# stdin: aws secretsmanager JSON, $1: explicit variable name (optional)
# stdout: NUL-delimited name/value pairs
_aws_secret_emit() {
  jq -j --arg name "$1" '
    def envname: ascii_upcase | gsub("[^A-Z0-9_]"; "_");
    .SecretString as $s
    | if $name != "" then $name, "\u0000", $s, "\u0000"
      else ($s | try fromjson catch null) as $j
        | if ($j | type) == "object" then
            $j | to_entries[]
            | (.key | envname), "\u0000",
              (.value | if type == "string" then . else tojson end), "\u0000"
          else (.Name | split("/") | last | envname), "\u0000", $s, "\u0000"
          end
      end'
}

use_aws_secret() {
  if [[ $# -eq 0 ]]; then
    log_error "use_aws_secret: usage: use_aws_secret [NAME=]secret-id ..."
    return 1
  fi
  has aws || { log_error "use_aws_secret: aws not found"; return 1; }
  has jq || { log_error "use_aws_secret: jq not found"; return 1; }

  local arg name secret_id json key value count=0
  for arg in "$@"; do
    name="" secret_id=$arg
    if [[ $arg == *=* ]]; then
      name=${arg%%=*}
      secret_id=${arg#*=}
    fi

    json=$(_aws_run secretsmanager get-secret-value --secret-id "$secret_id" \
      --output json) || {
      log_error "use_aws_secret: failed to read $secret_id"
      return 1
    }
    if ! jq -e '.SecretString | strings' <<<"$json" >/dev/null; then
      log_error "use_aws_secret: $secret_id has no string value"
      return 1
    fi

    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      if [[ ! $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        log_error "use_aws_secret: invalid variable name '$key'"
        return 1
      fi
      export "$key=$value"
      ((count++))
    done < <(printf '%s' "$json" | _aws_secret_emit "$name")
  done

  log_status "use_aws_secret: loaded $count variable(s)"
}
