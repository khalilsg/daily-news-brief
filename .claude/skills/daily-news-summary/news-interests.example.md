# News interests

Template for the `daily-news-summary` skill. Copy this to `news-interests.md` in the directory
you run the brief from, then replace the contents with your own topics.

The skill reads that file at the start of every run. The `## Topics` headings below become the
brief's sections, in the order they appear here. Nothing else in the skill needs editing —
everything editorial lives in this one file.

## Topics

Numbered, in priority order. Each `###` heading is a section title in the brief. Under each:
a sentence or two on what counts, then any of the optional fields.

### 1. Top Stories

The day's most significant news, whatever the subject — major breaking events, national and
world developments.

- Stories per day: 4–6
- Searches: "top news today", "breaking news today"

### 2. Business & Markets

Earnings, major deals, central bank decisions, market-moving developments. Skip routine daily
index moves.

- Stories per day: 2–4
- Searches: "business news today", "markets news today"
- Note: skip "stocks to watch" and outlook pieces — they have no news peg and recur daily.

### 3. Science & Health

Published research with real results, public-health developments, space missions. Skip
single-study health scares and press-release-driven claims.

- Stories per day: 2–3
- Searches: "science news today", "health news today"

Optional fields, all per topic:

- **Stories per day** — a target range, not a quota. Fewer is fine; the skill drops the section
  entirely rather than padding it.
- **Searches** — suggested queries. Omit and the skill will derive its own from the description.
- **Note** — topic-specific traps: the kinds of stale or low-value stories that keep surfacing in
  searches for this subject, or subjects to skip.

## Watchlist

Specific people, franchises, teams, or companies to search for directly every run, whether or not
they'd surface in the topic searches. Each maps to the section it belongs to — a watchlist hit
runs inline in that section, never as a section of its own.

Delete this whole heading if you don't want a watchlist.

- **[Your representative]** → Top Stories. Any news, statements, votes.
- **[A company or franchise you follow]** → Business & Markets. Announcements, releases,
  earnings.

## Source preferences

Outlets to avoid or prefer when citing. Delete the heading if you have none.

- Do not cite [outlet]. If a story's only coverage found is from [outlet], cite an alternate
  outlet covering the same story, or drop the story if no alternate is found.
