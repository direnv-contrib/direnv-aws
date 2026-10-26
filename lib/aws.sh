# Shared helpers for the use_aws_* extensions.
#
# Credentials: when AWS_PROFILE is set and no session is active, aws runs
# through aws-vault (same convention as zsh-aws).

_aws_run() {
  if [[ -n ${AWS_PROFILE:-} && -z ${AWS_SESSION_TOKEN:-} ]] && has aws-vault; then
    aws-vault exec "$AWS_PROFILE" -- aws "$@"
  else
    aws "$@"
  fi
}
