#!/usr/bin/env python3
"""Build the morning brief markdown file.

Takes today's entry as JSON and the previous brief.md, prepends today, and
writes the full file back out. Days are delimited by <!-- day:YYYY-MM-DD -->
markers, which GitHub hides when rendering.

    python3 build_brief.py --today today.json --prev brief.md --out brief.md

--prev is optional; without it the file starts fresh with today alone.

--days-dir is optional. Given one, the validated entry is also written there
as <date>.json, one file per day, kept forever. That directory is the
structured archive: brief.md is capped at MAX_DAYS because a single markdown
file has a size ceiling, and nothing about a directory of per-day files does.
It is written before brief.md on purpose -- if it cannot be written the run
fails with the archive untouched, rather than leaving brief.md a day ahead of
the structured copy.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime

MAX_DAYS = 90
HEADER = "# Morning Brief\n"
DAY_RE = re.compile(r"<!-- day:(\d{4}-\d{2}-\d{2}) -->")


def split_days(text):
    """Return [(date, block_text)] from a previous brief, newest order preserved."""
    if not text:
        return []
    parts = DAY_RE.split(text)
    # parts = [preamble, date1, body1, date2, body2, ...]
    out = []
    for i in range(1, len(parts) - 1, 2):
        out.append((parts[i], parts[i + 1].strip()))
    return out


def render_day(entry):
    lines = ["## " + entry["label"], ""]
    for section in entry["sections"]:
        lines.append("### " + section["title"])
        lines.append("")
        for story in section["stories"]:
            flag = "[Just in] " if story.get("justIn") else ""
            lines.append("**%s%s**  " % (flag, story["headline"]))  # 2 spaces = hard break
            body = story.get("summary", "").strip()
            source = story.get("source", "").strip()
            if source and story.get("url"):
                source = "[%s](%s)" % (source, story["url"])
            tail = " — " + source if source else ""
            if body or tail:
                lines.append(body + tail)
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def validate(entry):
    if not isinstance(entry, dict):
        raise SystemExit("today's entry must be a JSON object")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(entry.get("date", ""))):
        raise SystemExit("entry needs a 'date' in YYYY-MM-DD form")
    if not entry.get("label"):
        raise SystemExit("entry needs a 'label'")
    sections = entry.get("sections")
    if not isinstance(sections, list) or not sections:
        raise SystemExit("entry needs a non-empty 'sections' list")
    for section in sections:
        if not section.get("title"):
            raise SystemExit("every section needs a 'title'")
        stories = section.get("stories")
        if not isinstance(stories, list) or not stories:
            raise SystemExit(
                "section %r has no stories — drop the section instead" % section.get("title"))
        for story in stories:
            if not story.get("headline"):
                raise SystemExit("every story needs a 'headline'")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--today", required=True)
    ap.add_argument("--prev", help="previous brief.md pulled from GitHub")
    ap.add_argument("--out", required=True)
    ap.add_argument("--days-dir",
                    help="also write the entry here as <date>.json, kept forever")
    args = ap.parse_args()

    with open(args.today, encoding="utf-8") as fh:
        entry = json.load(fh)
    validate(entry)

    if args.days_dir:
        # Before the archive, deliberately: see the module docstring.
        try:
            os.makedirs(args.days_dir, exist_ok=True)
            day_path = os.path.join(args.days_dir, "%s.json" % entry["date"])
            # When the brief was actually made, recorded here because nothing
            # else survives: a file mtime is reset by any fresh clone, and a
            # commit time is only a proxy for a step that happens afterwards.
            # Local time with its offset, since the question being answered is
            # "how old is this brief" and the reader is in one timezone.
            day_entry = dict(entry)
            day_entry["generated"] = datetime.now().astimezone().isoformat(timespec="seconds")
            with open(day_path, "w", encoding="utf-8") as fh:
                json.dump(day_entry, fh, ensure_ascii=False, indent=2)
                fh.write("\n")
        except OSError as exc:
            raise SystemExit("could not write the per-day entry: %s" % exc)
        print("wrote %s" % day_path)

    previous = ""
    if args.prev:
        try:
            with open(args.prev, encoding="utf-8") as fh:
                previous = fh.read()
        except OSError as exc:
            print("warning: previous brief unreadable (%s)" % exc, file=sys.stderr)

    days = [(d, b) for d, b in split_days(previous) if d != entry["date"]]
    days.insert(0, (entry["date"], render_day(entry)))
    days.sort(key=lambda pair: pair[0], reverse=True)
    days = days[:MAX_DAYS]

    body = "\n\n".join(
        "<!-- day:%s -->\n\n%s" % (date, block.strip()) for date, block in days)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(HEADER + "\n" + body + "\n")
    print("wrote %s (%d day%s)" % (args.out, len(days), "" if len(days) == 1 else "s"))


if __name__ == "__main__":
    main()
