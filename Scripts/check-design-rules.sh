#!/usr/bin/env bash
# check-design-rules.sh — enforces design/RULES.md against app source.
# Exit 0 = clean. Exit non-zero = violations (reported to stderr).
#
# Usage:
#   ./Scripts/check-design-rules.sh                 # full scan
#   ./Scripts/check-design-rules.sh file1.swift …   # scan only listed files

set -u
cd "$(dirname "$0")/.." || exit 2

# Default search scope: app code only. Skip design/, reference, tests, generated.
DEFAULT_PATHS=(
  "PulseWatch"
  "PulseWatchWatch"
  "PulseWatchWidget"
  "Shared"
)
EXCLUDE_DIRS=(
  "*/design/*"
  "*/Assets.xcassets/*"
  "*/.build/*"
  "*/DerivedData/*"
  "*Tests/Fixtures*"
)

# DS.swift is the one place tokens are defined. It's also in Shared/Theme/.
ALLOWED_FILES=(
  "Shared/Theme/DS.swift"
)

# Decide scan target: explicit file args (filtered) or full default scan.
SCAN_TARGETS=()
if [[ $# -gt 0 ]]; then
  for f in "$@"; do
    [[ "$f" == *.swift ]] || continue
    [[ -f "$f" ]] || continue
    skip=false
    for allowed in "${ALLOWED_FILES[@]}"; do
      [[ "$f" == "$allowed" ]] && skip=true && break
    done
    $skip && continue
    in_scope=false
    for p in "${DEFAULT_PATHS[@]}"; do
      [[ "$f" == "$p"/* ]] && in_scope=true && break
    done
    $in_scope && SCAN_TARGETS+=( "$f" )
  done
  if [[ ${#SCAN_TARGETS[@]} -eq 0 ]]; then
    echo "→ No in-scope Swift files staged. Skipping design check."
    exit 0
  fi
  echo "→ Scanning ${#SCAN_TARGETS[@]} staged file(s) for design rule violations…"
else
  SCAN_TARGETS=( "${DEFAULT_PATHS[@]}" )
  echo "→ Full scan: ${SCAN_TARGETS[*]} for design rule violations…"
fi

violations=0

# rg helper — prints "<rule>: <file>:<line>: <match>" lines.
check() {
  local rule="$1"
  local pattern="$2"
  shift 2
  # Build excludes
  local excludes=()
  for d in "${EXCLUDE_DIRS[@]}"; do
    excludes+=( --glob "!$d" )
  done
  for f in "${ALLOWED_FILES[@]}"; do
    excludes+=( --glob "!$f" )
  done

  local hits
  hits=$(rg --line-number --no-heading --color=never "${excludes[@]}" -e "$pattern" "${SCAN_TARGETS[@]}" 2>/dev/null || true)
  if [[ -n "$hits" ]]; then
    echo "" >&2
    echo "❌ $rule" >&2
    echo "$hits" | sed 's/^/   /' >&2
    local count
    count=$(echo "$hits" | wc -l | tr -d ' ')
    violations=$((violations + count))
  fi
}

# R1 · Tokens are the only constants
check "R1 · raw Color(red:…) literal — use DS.Color.<token>"      'Color\(red:'
check "R1 · raw Color(hex:…) outside DS.swift — use DS.Color.<token>" 'Color\(hex:'
check "R1 · raw Color(rgb:…) outside DS.swift — use DS.Color.<token>" 'Color\(rgb:'
check "R1 · numeric .padding(N) — use .padding(DS.Spacing.<token>)" '\.padding\(\s*[0-9]'
check "R1 · numeric .cornerRadius(N) — use DS.Radius.<token>"      '\.cornerRadius\(\s*[0-9]'
check "R1 · numeric font size — use DS.Type.<token>"               '\.font\(\.system\(size:\s*[0-9]'
check "R1 · numeric .frame for icon — use a named constant"        '\.frame\(width:\s*[0-9]+,\s*height:\s*[0-9]+\)' # icon-shaped frames

# R7 · No drop shadows
check "R7 · drop shadow forbidden — depth via bgElev/bgSunk + hairline" '\.shadow\('

# R3 · Bilingual parity — hardcoded user-visible strings
# Heuristic: Text("…") containing Chinese chars or English sentence-like content
# We allow Text("") (empty), Text(verbatim:) (intentional), and Text(<var>).
check "R3 · hardcoded Chinese in Text — use String(localized:)"  'Text\("[^"]*[\x{4e00}-\x{9fff}][^"]*"\)'

# R6 · Reduce Motion
check "R6 · raw .animation(.<curve>) — wrap in DS.Motion.respecting(_:reduce:)" '\.animation\(\s*\.[a-zA-Z]'

# Summary
echo ""
if (( violations == 0 )); then
  echo "✅ Design rules: clean."
  exit 0
else
  echo "❌ Design rules: $violations violation(s). See above. Fix or escalate per RULES.md." >&2
  exit 1
fi
