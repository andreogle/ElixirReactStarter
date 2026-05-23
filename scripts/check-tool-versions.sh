#!/usr/bin/env bash
# Fail if the Erlang/Elixir/Node versions pinned in the Dockerfile drift
# away from the versions declared in mise.toml. Wired into `mix precommit`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MISE_FILE="$ROOT/mise.toml"
DOCKERFILE="$ROOT/Dockerfile"

extract_mise() {
  awk -v key="$1" '
    /^\[tools\]/ { in_tools = 1; next }
    /^\[/        { in_tools = 0 }
    in_tools && $1 == key {
      gsub(/"/, "", $3)
      print $3
      exit
    }
  ' "$MISE_FILE"
}

extract_arg() {
  awk -v name="$1" '
    $1 == "ARG" {
      split($2, kv, "=")
      if (kv[1] == name) {
        # Strip surrounding quotes so `ARG FOO="1.2.3"` and `ARG FOO=1.2.3`
        # compare equal.
        gsub(/^"|"$/, "", kv[2])
        print kv[2]
        exit
      }
    }
  ' "$DOCKERFILE"
}

mise_elixir="$(extract_mise elixir)"
mise_erlang="$(extract_mise erlang)"
mise_node="$(extract_mise node)"
docker_elixir="$(extract_arg ELIXIR_VERSION)"
docker_otp="$(extract_arg OTP_VERSION)"
docker_node="$(extract_arg NODE_VERSION)"

# mise elixir is "<version>-otp-<major>" (e.g. "1.19.5-otp-28").
mise_elixir_version="${mise_elixir%-otp-*}"
mise_elixir_otp_major="${mise_elixir##*-otp-}"
docker_otp_major="${docker_otp%%.*}"
# Node majors only — mise can pin "26", Dockerfile pins "26.2.0".
mise_node_major="${mise_node%%.*}"
docker_node_major="${docker_node%%.*}"

errors=()

if [[ "$docker_elixir" != "$mise_elixir_version" ]]; then
  errors+=("Dockerfile ELIXIR_VERSION=$docker_elixir, mise elixir=$mise_elixir_version")
fi

# Dockerfile OTP must exactly match mise erlang or be a patch release of it
# (mise can pin major.minor, hexpm/elixir tags include major.minor.patch).
if [[ "$docker_otp" != "$mise_erlang" && "$docker_otp" != "$mise_erlang".* ]]; then
  errors+=("Dockerfile OTP_VERSION=$docker_otp does not satisfy mise erlang=$mise_erlang")
fi

if [[ "$docker_otp_major" != "$mise_elixir_otp_major" ]]; then
  errors+=("Dockerfile OTP major=$docker_otp_major but mise elixir expects OTP $mise_elixir_otp_major")
fi

# Node is checked at the major level only — the Dockerfile pins a precise
# minor/patch for reproducibility, while mise.toml can pin just the major.
if [[ "$docker_node_major" != "$mise_node_major" ]]; then
  errors+=("Dockerfile NODE_VERSION major=$docker_node_major, mise node major=$mise_node_major")
fi

if (( ${#errors[@]} > 0 )); then
  echo "Tool version drift between mise.toml and Dockerfile:" >&2
  for err in "${errors[@]}"; do
    echo "  - $err" >&2
  done
  echo "" >&2
  echo "Update mise.toml or Dockerfile so the Erlang/Elixir/Node versions agree." >&2
  exit 1
fi
