#!/usr/bin/env bash
# Daily news brief -> commit to the archive repo.
# Runs headless from cron. Everything it touches is inside $REPO.
set -uo pipefail

# Defaults to the repo this script lives in, so a fresh clone works with no
# configuration; BRIEF_REPO overrides it (the crontab entry sets it explicitly).
REPO="${BRIEF_REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
LOG_DIR="${BRIEF_LOGS:-$HOME/.local/state/morning-brief}"
STAMP="$(date +%Y-%m-%d)"

mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$STAMP.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date -Is) starting ==="

cd "$REPO" || { echo "FATAL: no repo at $REPO"; exit 1; }

git pull --ff-only || { echo "FATAL: git pull failed; not overwriting anything"; exit 1; }

claude -p "Run my daily news summary. Read the daily-news-summary skill and follow it exactly." \
  --allowedTools "WebSearch,WebFetch,Read,Write,Edit,Bash" \
  --permission-mode acceptEdits \
  --max-turns 60
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "FATAL: claude exited $STATUS; leaving the repo untouched"
  exit $STATUS
fi

# A zero exit from claude does not mean the brief got written: an aborted or
# short-circuited run can exit 0 having touched nothing, which is otherwise
# indistinguishable from a quiet news day. The brief's newest day marker is the
# real success signal — the skill always writes today's entry, however few
# sections survive its recency rules.
TOP_DAY="$(sed -n 's/^<!-- day:\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\) -->$/\1/p' brief.md 2>/dev/null | head -1)"
if [ "$TOP_DAY" != "$STAMP" ]; then
  echo "FATAL: brief.md's newest entry is '${TOP_DAY:-none}', expected $STAMP."
  echo "       The generation did not write today's brief. Nothing committed."
  if ! git diff --quiet -- brief.md; then
    cp brief.md "$LOG_DIR/failed-$STAMP.brief.md"
    echo "       Partial brief.md saved to $LOG_DIR/failed-$STAMP.brief.md;"
    echo "       reverting it so tomorrow's 'git pull --ff-only' isn't blocked."
    git checkout -- brief.md
  fi
  exit 1
fi

if git diff --quiet -- brief.md; then
  echo "NOTE: brief.md already carried $STAMP and is unchanged — nothing committed"
  exit 0
fi

git add brief.md
git commit -m "Brief for $STAMP" || { echo "FATAL: commit failed"; exit 1; }
git push || { echo "FATAL: push failed; commit is local, run 'git push' by hand"; exit 1; }
echo "=== $(date -Is) done: pushed ==="
