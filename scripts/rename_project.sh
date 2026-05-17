#!/usr/bin/env bash
#
# Renames the project from its current name to a new one, then verifies the
# rename by rebuilding and running the precommit suite.
#
# Usage:
#   scripts/rename_project.sh NewPascalCaseName [--dry-run] [--no-verify]
#
# Example:
#   scripts/rename_project.sh MyElixirApp
#
# What it does:
#   - Reads the current snake_case name from mix.exs (the `app:` atom)
#   - Derives the current PascalCase form from that
#   - Computes new snake_case from the provided PascalCase
#   - Replaces both forms in every text file under the repo (skipping
#     _build/, deps/, node_modules/, priv/static/, .git/, lockfiles)
#   - Renames any files/directories whose paths contain the snake_case form
#   - Reinstalls deps and runs `mix precommit` to confirm the rename is clean
#
# Flags:
#   --dry-run    Print every edit and rename that would happen, change nothing
#   --no-verify  Skip the rebuild + precommit step at the end
#
# Notes:
#   - Input must be PascalCase: starts uppercase, alphanumeric only.
#   - The script does not touch generated lockfiles (package-lock.json) or
#     binary artifacts (.beam, priv/ssr.js).
#   - The script does not commit anything. Run `git diff` afterwards to
#     review, and commit when you are happy.

set -euo pipefail

DRY_RUN=0
NO_VERIFY=0
NEW_PASCAL=""

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    --no-verify)
      NO_VERIFY=1
      ;;
    -h|--help)
      sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
    *)
      if [ -z "$NEW_PASCAL" ]; then
        NEW_PASCAL="$arg"
      else
        echo "Unexpected argument: $arg" >&2
        exit 1
      fi
      ;;
  esac
done

if [ -z "$NEW_PASCAL" ]; then
  echo "Usage: $0 NewPascalCaseName [--dry-run] [--no-verify]" >&2
  exit 1
fi

if ! printf '%s' "$NEW_PASCAL" | grep -qE '^[A-Z][A-Za-z0-9]*$'; then
  echo "Error: new name must be PascalCase (got '$NEW_PASCAL')." >&2
  echo "       Example: MyElixirApp" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

if [ ! -f mix.exs ]; then
  echo "Error: mix.exs not found at $REPO_ROOT" >&2
  exit 1
fi

OLD_SNAKE="$(grep -E '^[[:space:]]*app:[[:space:]]*:[a-z_][a-z0-9_]*' mix.exs \
  | head -1 \
  | sed -E 's/.*app:[[:space:]]*:([a-z_][a-z0-9_]*).*/\1/')"

if [ -z "$OLD_SNAKE" ]; then
  echo "Error: could not detect current project name from mix.exs" >&2
  echo "       Looked for a line like:  app: :my_app," >&2
  exit 1
fi

snake_to_pascal() {
  printf '%s' "$1" \
    | awk -F_ '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1' OFS=''
}

pascal_to_snake() {
  printf '%s' "$1" \
    | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' \
    | sed -E 's/([A-Z]+)([A-Z][a-z])/\1_\2/g' \
    | tr '[:upper:]' '[:lower:]'
}

OLD_PASCAL="$(snake_to_pascal "$OLD_SNAKE")"
NEW_SNAKE="$(pascal_to_snake "$NEW_PASCAL")"

if [ "$OLD_PASCAL" = "$NEW_PASCAL" ] && [ "$OLD_SNAKE" = "$NEW_SNAKE" ]; then
  echo "Project is already named '$NEW_PASCAL'. Nothing to do."
  exit 0
fi

echo "Renaming project:"
echo "  $OLD_PASCAL -> $NEW_PASCAL"
echo "  $OLD_SNAKE -> $NEW_SNAKE"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "  (dry run — no changes will be made)"
fi
echo

# Build the file list. Skip:
#   - VCS / build / deps / docs
#   - node_modules
#   - the digested static asset output
#   - the compiled Node SSR bundle (build artifact)
#   - package-lock.json (huge, npm regenerates it)
#   - .DS_Store and compiled .beam files
list_text_files() {
  find . \
    \( \
      -path './.git' -o \
      -path './_build' -o \
      -path './deps' -o \
      -path './doc' -o \
      -path './assets/node_modules' -o \
      -path './priv/static' \
    \) -prune -o \
    \( \
      -name '.DS_Store' -o \
      -name '*.beam' -o \
      -name 'package-lock.json' -o \
      -path './priv/ssr.js' \
    \) -prune -o \
    -type f -print
}

list_named_paths() {
  find . \
    \( \
      -path './.git' -o \
      -path './_build' -o \
      -path './deps' -o \
      -path './doc' -o \
      -path './assets/node_modules' -o \
      -path './priv/static' \
    \) -prune -o \
    -name "*${OLD_SNAKE}*" -print \
    | sort -r
}

# -----------------------------------------------------------------------------
# Pass 1 — file contents
# -----------------------------------------------------------------------------
edited=0
while IFS= read -r f; do
  if grep -qE "${OLD_PASCAL}|${OLD_SNAKE}" "$f" 2>/dev/null; then
    edited=$((edited + 1))
    if [ "$DRY_RUN" -eq 1 ]; then
      hits="$(grep -cE "${OLD_PASCAL}|${OLD_SNAKE}" "$f" || true)"
      echo "  edit $f ($hits hit(s))"
    else
      # macOS- and GNU-portable in-place sed: write a backup, then delete it.
      sed -E -i.rename_bak \
        -e "s/${OLD_PASCAL}/${NEW_PASCAL}/g" \
        -e "s/${OLD_SNAKE}/${NEW_SNAKE}/g" \
        "$f"
      rm -f "${f}.rename_bak"
    fi
  fi
done < <(list_text_files)

echo "Edited $edited file(s)."

# -----------------------------------------------------------------------------
# Pass 2 — file and directory paths (reverse-sorted so children move first)
# -----------------------------------------------------------------------------
renamed=0
while IFS= read -r path; do
  parent="$(dirname "$path")"
  base="$(basename "$path" | sed -E "s/${OLD_SNAKE}/${NEW_SNAKE}/g")"
  newpath="${parent}/${base}"
  if [ "$path" != "$newpath" ]; then
    renamed=$((renamed + 1))
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  mv $path -> $newpath"
    else
      mv "$path" "$newpath"
    fi
  fi
done < <(list_named_paths)

echo "Renamed $renamed path(s)."

# -----------------------------------------------------------------------------
# Pass 3 — verify by rebuilding and running precommit
# -----------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ] || [ "$NO_VERIFY" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 0 ]; then
    echo
    echo "Skipping verification (--no-verify). Review with: git diff && mix precommit"
  fi
  exit 0
fi

echo
echo "Verifying rename..."
echo "  → mix clean"
mix clean >/dev/null
echo "  → mix deps.get"
mix deps.get >/dev/null
echo "  → mix compile --warnings-as-errors"
mix compile --warnings-as-errors
echo "  → cd assets && npm install"
( cd assets && rm -rf node_modules && npm install >/dev/null 2>&1 )
echo "  → mix precommit"
mix precommit

echo
echo "Rename complete and verified. Suggested follow-up:"
echo "  git diff      # review the rewrite"
echo "  git add -A && git commit -m \"Rename $OLD_PASCAL → $NEW_PASCAL\""
