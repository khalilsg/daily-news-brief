---
name: "daily-news-summary"
description: "Use when the user asks for a daily/morning news summary, news brief, or \"what's happening in the news\". Topics, watchlist, and source preferences are read from a news-interests.md file in the working directory. Also used by scheduled morning-brief jobs."
---

Produce the user's daily news summary as the chat message. When the run has an archive file
(`brief.md`, see "Where the files live"), also prepend the day to it — see "Archive file" below.

Everything about *what* the brief covers — topics, section order, story counts, tracked people
and franchises, source preferences — lives in a separate config file, not in this skill. This
skill holds only the mechanics: how to research, how fresh a story has to be, what to drop, and
how to format the result. See "Interests file" below for the contract.

If run as part of a scheduled/automated task (no user present to answer questions), execute
autonomously without asking clarifying questions — make reasonable choices and note them only if
truly necessary. Only take "write" actions (sending, posting, creating, updating, deleting via
other tools) if explicitly asked; otherwise the chat message and the in-place update to
`brief.md` are the only outputs.

## Where the files live

Three files matter. All paths are relative to the working directory, and the rest of this skill
refers to them by short name:

| Short name | Path | Role |
| --- | --- | --- |
| `news-interests.md` | `content/inputs/news-interests.md` | input, hand-edited |
| `brief.md` | `content/outputs/brief.md` | output, generated — never hand-edited |
| `releases.md` | `content/outputs/releases.md` | optional input from a separate job |

**If there is no `content/` directory, look for all three at the working-directory root instead**
(`news-interests.md`, `brief.md`, `releases.md`). That is the older flat layout and it still
works — check `content/` first, fall back to the root, and use whichever you find.

## Interests file

Read `news-interests.md` before anything else. It defines:

- **Topics** — a numbered, priority-ordered list. Each becomes a section of the brief, using the
  topic's heading as the section title, in the order given. Each topic may carry a description
  of what counts, a target number of stories per day, suggested searches, and topic-specific
  notes (common stale-story traps, subjects to skip).
- **Watchlist** — specific people, franchises, teams, or companies to search for directly every
  run, each mapped to the topic section it belongs to. Watchlist stories are never a section of
  their own; a hit runs inline in its mapped section alongside that section's other stories.
- **Source preferences** — outlets to avoid or prefer when citing.

[`news-interests.example.md`](news-interests.example.md) sits beside this file and documents the
format. It is a template, not a config — never read it as the user's actual preferences.

**If `news-interests.md` is missing:**

- With a user present: ask what topics they want covered and whether there's anyone or anything
  specific to track, then offer to write `news-interests.md` from their answer (copy the example
  file as the starting shape). Produce the brief from their answer either way.
- On an automated run with no user: fall back to a broad general-news brief — Top Stories, World,
  Business & Tech — and mention the missing file in one line at the end of the message. Don't
  create the file unprompted.

The interests file is the standing preference. If the user gives feedback in conversation that
adjusts topics, the watchlist, source preferences, depth, or format, follow the most recent
instruction instead — and offer to update `news-interests.md` to match. Edit that file, never
this one, for anything editorial.

## Recency requirement

Applies to every section, including watchlist items.

- Every story included must be from the last 24–48 hours (today or yesterday relative to the run
  date). Check each candidate's actual publish/event date before including it — don't rely on a
  search result's framing ("today" in a headline, a roundup article title) as proof of recency;
  verify the underlying event date.
- Reject or drop: recap or roundup articles that bundle older developments, "momentum building"
  or trend pieces with no fresh news peg, and any story whose dated coverage is more than ~2 days
  old — even if it still ranks prominently in search results.
- **Duplicate-day check:** before finalizing selection, read the most recent day(s) already
  recorded in `brief.md` (if the archive file exists) — yesterday's
  entry at minimum, further back for slower-moving stories (see "Reading the archive" below for
  how to pull just those days) — and drop any candidate that already
  appeared there. A story counts as a duplicate if it covers the same underlying event or
  development, even if today's headline is worded differently (e.g. a creator's death reported
  again a day later). This is a silent drop like the others — no "as reported yesterday" callout,
  just omit it. A genuine follow-up (new details, an official statement, a name confirmation, an
  investigation update) is not a duplicate and can be included. If `brief.md` isn't present
  (ad-hoc chat request with no archive), skip this check — there's nothing to compare against.
- **SILENT DROPS — important:** if a topic has no genuinely fresh (last 1–2 days), non-duplicate
  stories, just omit that section entirely. Do NOT write a note explaining that the topic was
  quiet, do NOT summarize the stale, duplicate, or minor stories that were rejected, and do NOT
  explain why they were rejected. The same applies to watchlist items: with no fresh watchlist
  news, none appears anywhere — there's no separate section to omit, the item just contributes
  nothing to its topic section. A dropped section or story should be invisible to the reader.
  Never write lines like "Sports is quiet — only minor signings turned up..." or "No fresh
  watchlist news today: nothing new on X since...". Silence is the correct output.
- **Extra-fresh flag:** for any story confirmed to be from within the last 12 hours, prepend the
  bold tag "[Just in]" before the headline (e.g. "**[Just in] Headline text.**") so it stands out
  from the rest of that section. Only use this tag when the publish/event time genuinely supports
  it — don't guess or apply it loosely just because a story appeared in a "today" search.

## Steps

1. Read `news-interests.md` (see "Where the files live" and "Interests file" above).
2. Use WebSearch to find today's major stories in each topic from that file — run separate
   targeted searches per topic, using its suggested searches where given, rather than one generic
   query. Include the actual current date in searches where useful (e.g. "[topic] news [current
   date]") to bias toward fresh results, and prefer phrasing like "[topic] news last 24 hours" or
   checking article bylines/dates over generic queries that surface evergreen roundups.
3. Run one targeted search per watchlist entry (e.g. "[name] news today"). Only include a result
   if it's an actual news development from the last 1–2 days, not background/evergreen content or
   an older announcement still circulating in search results. A watchlist hit gets folded into
   its mapped topic section, not treated separately.
4. If `brief.md` exists, read its most recent day (and further back for
   anything that looks like a slow-moving story) so candidates can be checked against it in the
   next step. Pull those days with the command in "Reading the archive" below — never read the
   whole file.
5. Select the most significant, distinct, and genuinely recent (last 24–48 hours) stories per
   topic, aiming for that topic's target story count from the interests file. Prioritize real
   developments over speculation, rumors, or opinion pieces. Avoid duplicates covering the same
   event within today's selection, and drop anything that already ran in a recent `brief.md`
   entry per the duplicate-day check. Apply the source preferences and the recency requirement
   when selecting and citing — it's better to include fewer stories in a section (or drop it)
   than to pad with stale or repeated ones. While checking dates, note which stories (if any) are
   confirmed from within the last 12 hours so they can get the "[Just in]" tag. When a candidate's
   exact date is ambiguous, run one more targeted search to pin down the actual event/publish
   date before including it.
6. Write a chat message with a short one-line header (e.g. "Morning news — Tuesday, July 22"),
   followed by the topic sections in the interests file's order. Under each, list stories as: a
   bold 1-line headline (prefixed with "[Just in]" if confirmed within the last 12 hours),
   followed by 1–2 plain sentences summarizing it, with the source name noted (e.g. "— Reuters").
   A fresh watchlist story is just another story in its section, in no particular position
   relative to the others. Keep it scannable, no excessive formatting. Drop a section entirely
   and silently if nothing substantive (fresh and non-duplicate) turned up for it that day. If a
   `releases.md` file is present, append a "Release Radar" section after the topic sections — see
   "Release Radar" below.
7. End the message with the last story (plus the Sources list). Do NOT append a closing line
   inviting feedback, offering to adjust topics/depth/format, or any similar sign-off. The
   summary just ends.
8. Update the archive file (see "Archive file" below), if this run has one. It carries the same
   stories as the chat message — never a different or trimmed selection.
9. End with the chat message. Nothing after it.

## Release Radar

An unrelated, optional job may drop a `releases.md` file before this skill
runs — a separate tracker watching for dated releases (games, movies, whatever it's configured
for) matching some standing watchlist. This skill doesn't know or care what that watchlist
contains; it only ever reads `releases.md` as a finished, pre-formatted block to fold in verbatim.

- **If `releases.md` doesn't exist, skip this entirely.** Most setups won't have this job configured
  — don't mention its absence, don't create the file.
- If it exists, read its `<!-- generated:TIMESTAMP -->` marker on the first line. If that
  timestamp is more than ~36 hours old, the tracker didn't run today — still include the section,
  but prefix it with one line noting it's stale (e.g. "_Release radar last updated Aug 10._").
  Never let a missing, stale, or malformed `releases.md` block or delay the rest of the brief.
- Otherwise, add a "Release Radar" section (chat message and archive entry both) using the file's
  "Changes since last run" and "Upcoming" content directly — same silent-drop principle as every
  other section: if a block is empty, omit it, don't note that nothing changed.
- **An "Awaiting approval" block is a count, not a list.** If the file has one, don't reproduce its
  entries or its "ask to review" line. Close the section with a single italic line saying how many
  there are — `_1 title pending review._`, or `_3 titles pending review._` for more than one. Those
  titles are the tracker's own queue: nothing about them is settled yet, so they aren't news, and
  the file itself is where the actual list gets read. No such block, no line.
- **Keep the list a list.** Every entry gets its own bullet on its own line, exactly as it appears
  in the file. Never merge them into a run-on paragraph, and never separate them with periods on a
  single line — this section is scanned for dates, not read as prose, so it stays a list even
  though the topic sections above it are written as prose. Each block's lead-in is bold and ends
  with a **colon**, not a period, with a blank line before the bullets:

  ```
  **Upcoming releases (next 30 days):**

  - Sep 4 — cocoon: One Summer of Girlhood (theaters, limited)
  - Sep 8 — The Paper Season 2 (Peacock)
  - Sep 17 — Fire Emblem: Fortune's Weave (Nintendo Switch 2)

  _1 title pending review._
  ```

## Archive file

One markdown file, `brief.md`, newest day at the top, living in a git repo. The wrapper script
handles git — pull before, commit and push after — so this skill only rewrites the file in place.
Never run git commands here.

`build_brief.py` sits beside this SKILL.md and does the assembly.

**If `brief.md` is not present, skip this section entirely** and produce only
the chat message. That is the normal case for an ad-hoc request rather than the scheduled run;
don't create the file, don't mention its absence.

### Reading the archive

The archive holds up to 90 days, so it grows to hundreds of kilobytes — far too large to read
into context, and the duplicate-day check never needs more than the newest few days. Never open
`brief.md` with a plain file read. Pull only the days you need:

```bash
awk '/^<!-- day:/{n++} n>2{exit} {print}' content/outputs/brief.md
```

`n>2` yields the two newest days; raise it to look further back for a slow-moving story, and
raise it only that far. Run this once and work from the result — re-reading the archive costs
the same again on every later turn.

### Writing today's entry

Steps:

1. Write today's entry to `today.json` in a temp directory (not in the repo):

```json
{
  "date": "2026-08-10",
  "label": "Monday, August 10, 2026",
  "sections": [
    {
      "title": "Politics & Policy",
      "stories": [
        {
          "headline": "One-line headline.",
          "summary": "1-2 plain sentences.",
          "source": "Reuters",
          "url": "https://...",
          "justIn": true
        }
      ]
    }
  ]
}
```

   `date` is the ISO date and the de-duplication key — a second run on the same day replaces that
   day rather than adding a duplicate. `label` is the heading readers see. Section titles and
   their order match the chat message exactly — watchlist stories live inside their mapped topic
   section, not a section of their own. `url` and `justIn` are optional; omit `url` rather than
   guessing one, and set `justIn` only when the story is confirmed within 12 hours. Write plain
   text — the builder adds the markdown, so no asterisks or bracket tags inside `headline` or
   `summary`.

   The silent-drop rule applies here too: a section dropped from the chat message is simply
   absent. The builder rejects a section with an empty `stories` array, so never pad one with a
   placeholder story.

2. Build in place:

```bash
python3 .claude/skills/daily-news-summary/build_brief.py \
  --today /tmp/today.json --prev content/outputs/brief.md --out content/outputs/brief.md
```

   Reading and writing the same path is safe — the builder reads the whole file before writing.
   The builder validates the entry and fails loudly on a malformed one; fix the JSON rather than
   working around it. It keeps 90 days.

3. If the builder fails, say so plainly in one line at the end of the chat message and leave
   `brief.md` as it was. Do not hand-edit the file to compensate.

Beyond the chat message and updating `brief.md`, take no other actions (no emails, no other
tools) unless the user explicitly asks for follow-up actions in the same request. If WebSearch
turns up little of substance for a topic, drop that section silently rather than padding with
minor stories or narrating the absence.
