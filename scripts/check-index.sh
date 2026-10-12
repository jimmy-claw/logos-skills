#!/usr/bin/env bash
# Every skill directory must appear in the canonical index (logos-app-charter, "Which sibling skill
# for which layer") and in the README table, so the lists can't drift apart. Also prints each skill's
# last change (git), the date a reader should weigh its version-specific claims against.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
index=$(sed -n '/^## Which sibling skill for which layer/,/^## /p' logos-app-charter/SKILL.md)
for d in */; do
  d=${d%/}; [ -f "$d/SKILL.md" ] || continue
  grep -q "\`$d\`" <<<"$index" || { echo "MISSING from logos-app-charter index: $d"; fail=1; }
  grep -q "^| \*\*$d\*\*" README.md || { echo "MISSING from README table: $d"; fail=1; }
  printf '%-34s last changed %s\n' "$d" "$(git log -1 --format=%cs -- "$d" 2>/dev/null || echo '?')"
done
exit $fail
