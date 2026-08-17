#!/usr/bin/env bash
# Daily news brief -> commit to the archive repo.
# Runs headless from cron. Everything it touches is inside $REPO.
set -uo pipefail

# Defaults to the repo this script lives in, so a fresh clone works with no
# configuration; BRIEF_REPO overrides it (the crontab entry sets it explicitly).
REPO="${BRIEF_REPO:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
LOG_DIR="${BRIEF_LOGS:-$HOME/.local/state/morning-brief}"
STAMP="$(date +%Y-%m-%d)"

# The archive, relative to $REPO, named once so every check, revert and commit
# below goes through one path. Two layouts are supported: outputs grouped under
# content/, or a flat repo with brief.md at the root. Detected rather than
# configured so the same wrapper works in either without editing. BRIEF_FILE
# overrides if a repo does something else.
BRIEF="${BRIEF_FILE:-}"
if [ -z "$BRIEF" ]; then
  if [ -f "$REPO/content/outputs/brief.md" ]; then
    BRIEF="content/outputs/brief.md"
  else
    BRIEF="brief.md"
  fi
fi

mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$STAMP.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date -Is) starting ==="

cd "$REPO" || { echo "FATAL: no repo at $REPO"; exit 1; }

git pull --ff-only || { echo "FATAL: git pull failed; not overwriting anything"; exit 1; }

# --model is pinned rather than left to the default: this run is search,
# date-checking and formatting against a fixed contract, and the context grows
# large enough that per-token price dominates the cost of a morning. Raise it
# only if brief quality visibly drops.
#
# --output-format json makes the run emit a single result object rather than
# the brief text, so stdout goes to a temp file instead of the log; the brief is
# pulled back out of it below and printed, leaving the log as readable as it was.
# The point is the usage block that comes with it: token counts and cost
# straight from the API, recorded per run. Session transcripts are pruned after
# ~30 days ("cleanupPeriodDays"), so reconstructing this later is not an option.
RUN_JSON="$(mktemp)"
trap 'rm -f "$RUN_JSON"' EXIT

claude -p "Run my daily news summary. Read the daily-news-summary skill and follow it exactly." \
  --model sonnet \
  --output-format json \
  --allowedTools "WebSearch,WebFetch,Read,Write,Edit,Bash" \
  --permission-mode acceptEdits \
  --max-turns 60 > "$RUN_JSON"
STATUS=$?

# Print the brief and append one row to the usage record. This runs before the
# status check on purpose: a failed run still costs tokens, and those are the
# runs worth being able to see. Accounting must never change the run's outcome,
# so every failure here is a note, not a FATAL.
python3 - "$RUN_JSON" "$LOG_DIR/usage.tsv" "$STAMP" "$STATUS" <<'PY'
import json, os, sys

src, tsv, stamp, status = sys.argv[1:5]

try:
    with open(src) as fh:
        run = json.load(fh)
except (OSError, ValueError):
    run = None

if run is None:
    # Not JSON: the run died before emitting a result object. Show whatever it
    # did write, so the operator is not left with an empty log.
    try:
        with open(src, errors="replace") as fh:
            raw = fh.read(4000).strip()
        if raw:
            print(raw)
    except OSError:
        pass
    run = {}
else:
    print(run.get("result") or "")

usage = run.get("usage") or {}
inp = usage.get("input_tokens", 0)
cr = usage.get("cache_read_input_tokens", 0)
cw = usage.get("cache_creation_input_tokens", 0)
out = usage.get("output_tokens", 0)
searches = (usage.get("server_tool_use") or {}).get("web_search_requests", 0)
cost = run.get("total_cost_usd")
models = ",".join(sorted((run.get("modelUsage") or {}).keys()))
duration = run.get("duration_ms")

row = [
    stamp,
    status,
    run.get("num_turns", ""),
    inp,
    cr,
    cw,
    out,
    inp + cr + cw,
    searches,
    f"{cost:.4f}" if isinstance(cost, (int, float)) else "",
    round(duration / 1000) if isinstance(duration, (int, float)) else "",
    models,
]

header = "date\tstatus\tturns\tinput\tcache_read\tcache_write\toutput\tbilled_in\tsearches\tcost_usd\tsecs\tmodels"
new = not os.path.exists(tsv) or os.path.getsize(tsv) == 0
with open(tsv, "a") as fh:
    if new:
        fh.write(header + "\n")
    fh.write("\t".join(str(c) for c in row) + "\n")

if cost is not None:
    print(f"\n=== usage: {inp + cr + cw:,} billed input + {out:,} output tokens, "
          f"{searches} searches, ${cost:.2f} — appended to {tsv}")
PY
[ $? -eq 0 ] || echo "NOTE: could not record usage for this run"

if [ $STATUS -ne 0 ]; then
  echo "FATAL: claude exited $STATUS; leaving the repo untouched"
  exit $STATUS
fi

# A zero exit from claude does not mean the brief got written: an aborted or
# short-circuited run can exit 0 having touched nothing, which is otherwise
# indistinguishable from a quiet news day. The brief's newest day marker is the
# real success signal — the skill always writes today's entry, however few
# sections survive its recency rules.
TOP_DAY="$(sed -n 's/^<!-- day:\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\) -->$/\1/p' "$BRIEF" 2>/dev/null | head -1)"
if [ "$TOP_DAY" != "$STAMP" ]; then
  echo "FATAL: $BRIEF's newest entry is '${TOP_DAY:-none}', expected $STAMP."
  echo "       The generation did not write today's brief. Nothing committed."
  if ! git diff --quiet -- "$BRIEF"; then
    cp "$BRIEF" "$LOG_DIR/failed-$STAMP.brief.md"
    echo "       Partial brief saved to $LOG_DIR/failed-$STAMP.brief.md;"
    echo "       reverting it so tomorrow's 'git pull --ff-only' isn't blocked."
    git checkout -- "$BRIEF"
  fi
  exit 1
fi

if git diff --quiet -- "$BRIEF"; then
  echo "NOTE: $BRIEF already carried $STAMP and is unchanged — nothing committed"
  exit 0
fi

git add "$BRIEF"
git commit -m "Brief for $STAMP" || { echo "FATAL: commit failed"; exit 1; }
git push || { echo "FATAL: push failed; commit is local, run 'git push' by hand"; exit 1; }
echo "=== $(date -Is) done: pushed ==="
