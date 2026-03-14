# MTG Quiz — Project Plan

## What This Is

A flashcard quiz for floor staff at a Magic event venue to get comfortable with common rules situations they'll encounter running Commander, Draft, and Sealed events.

A local Ruby pipeline downloads MTG card data and rules, questions are generated via Claude Code prompts, reviewed through a local UI, and exported to a static quiz hosted on GitHub Pages. No backend. No accounts.

---

## The Two Parts

### 1. Pipeline (local only, never deployed)
Runs on your machine. Downloads data, manages review, exports JSON.

### 2. Frontend (static, GitHub Pages)
A single `index.html` + `questions.json` in `docs/`. Staff open it in a browser. That's it.

---

## Directory Structure

```
mtg-quiz/
├── .claude/
│   └── commands/                  # Claude Code skills (slash commands)
│       └── mtg-lookup.md          # /mtg-lookup — query MTGJSON for card data
├── docs/                          # GitHub Pages root — ONLY deployed artifacts
│   ├── index.html                 # quiz UI (flashcard interface)
│   └── questions.json             # approved questions only
├── planning/                      # project plans, dev docs, notes
│   ├── MTG_QUIZ_PLAN.md
│   └── generation_prompt.md       # how to prompt Claude Code for questions
├── pipeline/
│   ├── review_server.rb           # WEBrick server for local review UI
│   └── export.rb                  # writes approved questions → docs/questions.json
├── data/                          # GITIGNORED — large, local only
│   ├── AllPrintings.sqlite        # from MTGJSON (~400MB)
│   ├── comprehensive_rules.txt    # plain text from Wizards
│   └── questions.sqlite           # generated questions live here
├── review/                        # local-only review UI assets
│   └── index.html                 # approve/reject/edit interface
├── test/                          # minitest tests for pipeline logic
├── Rakefile                       # all rake tasks — run from project root
├── Gemfile                        # sqlite3 + minitest
├── .ruby-version                  # 3.4.4
├── .gitignore
├── CLAUDE.md
└── README.md
```

---

## Data Sources

### MTGJSON
- **File**: `AllPrintings.sqlite` — pre-built SQLite database
- **Download**: `https://mtgjson.com/api/v5/AllPrintings.sqlite`
- **Version check**: `https://mtgjson.com/api/v5/Meta.json` — returns `{"date": "...", "version": "5.3.0+20260314"}`
- **Integrity**: SHA256 hash at `https://mtgjson.com/api/v5/AllPrintings.sqlite.sha256`
- **Schema** (verified):
  - `cards` — `name`, `text` (oracle text), `type`, `manaCost`, `keywords` (comma-separated), `uuid` (unique per printing). Cards have multiple rows across printings — query by name, pick any.
  - `cardRulings` — `uuid`, `date`, `text`. Join on `cards.uuid`. Separate table, not a JSON column.
  - `cardLegalities` — `uuid`, plus one column per format (`commander`, `modern`, `standard`, `legacy`, etc.). Values: "Legal", "Banned", "Restricted", etc. Separate table, not JSON.
  - `meta` — `date`, `version`. Exists inside the SQLite itself.
- **Updates**: Rebuilds daily at 9 AM EST
- **Purpose**: Reference tool for accurate oracle text and Gatherer rulings during question generation and review. Not a direct generation input — Claude Code queries it as needed via the `/mtg-lookup` skill.

### Comprehensive Rules
- **File**: Plain `.txt` from Wizards, ~250KB, fits entirely in an LLM context window
- **URL changes per update**: format is `https://media.wizards.com/YYYY/downloads/MagicCompRules%20YYYYMMDD.txt`
- **No stable permalink** — the date is embedded in the filename
- **Update frequency**: ~every 3 months with each set release, plus occasional mid-cycle errata
- **Download strategy**: `rake data:update` prompts user to paste the current URL from the Wizards rules page
- **Purpose**: Primary source of truth for all rules questions. Loaded directly into Claude Code context during generation.

### How `rake data:update` works
1. Create `data/` directory if missing
2. If `AllPrintings.sqlite` exists: query its `meta` table for local version. Fetch remote `Meta.json` and compare.
3. If newer (or first run / no local file): stream-download `AllPrintings.sqlite` (~400MB), verify SHA256 hash
4. If current: print "MTGJSON is up to date (version X)"
5. Prompt user: "Paste the Comprehensive Rules .txt URL from magic.wizards.com/en/rules:"
6. Download the .txt file to `data/comprehensive_rules.txt`

---

## Difficulty Levels

| Level | Key | Focus |
|---|---|---|
| 1 | `fundamentals` | Turn structure, phases, casting, card types, basic combat, draft/sealed procedure |
| 2 | `multiplayer` | Rules unique to multiplayer formats |
| 3 | `2hg` | Two-Headed Giant specific rules |
| 4 | `stack_triggers` | Stack ordering, priority, triggered vs activated abilities, ETBs |
| 5 | `interactions` | Replacement effects, state-based actions, layers, Commander-specific rules |
| 6 | `edge_cases` | Blood Moon, Urborg, timestamps, dependency, multiple replacement effects |

Edge Cases (level 6) is for completeness and ambitious staff. Day-to-day events mostly live in levels 1–2.

---

## Question Schema

Questions live in `data/questions.sqlite`, exported to JSON only after approval.

### SQLite table: `questions`
```sql
CREATE TABLE questions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  difficulty  TEXT NOT NULL,       -- fundamentals | multiplayer | 2hg | stack_triggers | interactions | edge_cases
  question    TEXT NOT NULL,
  answer      TEXT NOT NULL,
  explanation TEXT NOT NULL,
  rule_refs   TEXT,                -- JSON array, e.g. ["603.2", "603.3b"]
  cards_ref   TEXT,                -- JSON array, e.g. ["Blood Moon"]
  tags        TEXT,                -- JSON array, e.g. ["combat", "layers"]
  status      TEXT DEFAULT 'pending', -- pending | approved | rejected
  created_at  TEXT DEFAULT (datetime('now')),
  reviewed_at TEXT
);
```

### Exported JSON shape (docs/questions.json)
Only `approved` questions ever reach this file. No status or timestamps in the export.
```json
[
  {
    "id": 1,
    "difficulty": "stack_triggers",
    "question": "You cast a creature spell. Your opponent casts Counterspell targeting it. Can you respond?",
    "answer": "Yes. Both players get priority after each spell or ability is added to the stack.",
    "explanation": "After Counterspell is placed on the stack, priority passes back to you. You may cast instants or activate abilities before the counterspell resolves.",
    "rule_refs": ["116.3c", "116.4"],
    "cards_ref": ["Counterspell"],
    "tags": ["stack", "priority"]
  }
]
```

---

## Question Generation

Questions are generated by prompting Claude Code directly — no API integration.

### How it works
1. Read CR text into Claude Code context (it fits entirely — ~250KB)
2. Use the `/mtg-lookup` skill to query MTGJSON for exact oracle text and Gatherer rulings as needed
3. Prompt Claude Code to generate questions for a specific difficulty level
4. Claude Code outputs JSON matching the schema
5. Save to a file, import via `rake questions:import`

### The `/mtg-lookup` skill
A Claude Code slash command (`.claude/commands/mtg-lookup.md`) that queries `AllPrintings.sqlite` to:
- Look up a card's exact oracle text, type line, and rulings
- Find cards with specific keywords or mechanics (e.g. "all cards with triggered abilities that are commander-legal")
- Find cards with the most Gatherer rulings (these are the confusing ones — great question fodder)

This avoids re-prompting for the same procedural SQLite queries during generation sessions.

### Working backwards from rulings
Cards with many Gatherer rulings are literally the cards people ask questions about. The rulings themselves are answers to common questions. Generation strategy:
1. Query for cards with 3+ rulings in a relevant format
2. Read the rulings — each one suggests a natural quiz question
3. Pair with the relevant CR section for the explanation

### Generation rules
- **Concept-first**: questions test understanding of rules mechanics, not card trivia
- **Card references**: when a card is referenced, include its exact oracle text inline so staff don't need prior card knowledge
- **Rule citations**: `rule_refs` must cite actual CR section numbers
- **Self-contained**: never write questions where the answer depends on knowing a card the question doesn't quote
- **Precision**: Magic rulings are deterministic. Every question must have one unambiguously correct answer. Use exact oracle text from MTGJSON, not approximations.

### Target volume
~250 per level for most levels, ~50 for `2hg`. Human review required — LLM output will have errors on edge cases.

### Prompt documentation
Detailed generation prompts and examples live in `planning/generation_prompt.md`.

---

## Rake Tasks

All tasks run from the project root.

```
rake data:update                        # download MTGJSON (auto version check) + CR (prompts for URL)
rake db:setup                           # create questions table in data/questions.sqlite
rake questions:import[path/to/file]     # import JSON file into SQLite as pending
rake review:start                       # WEBrick at localhost:4567
rake export                             # approved rows → docs/questions.json
rake test                               # run minitest suite
```

### `rake questions:import` details
- Accepts file path as argument: `rake questions:import[data/batches/fundamentals_01.json]`
- Validates required fields: `difficulty`, `question`, `answer`, `explanation`
- Validates `difficulty` is one of the 6 known values
- Auto-generates integer IDs (autoincrement)
- Inserts all questions as `pending`
- Prints summary: "Imported N questions (fundamentals: X, stack_triggers: Y, ...)"

---

## Review Workflow

1. Generate questions via Claude Code → save as JSON file
2. Run `rake questions:import[file.json]` → questions land in SQLite as `pending`
3. Run `rake review:start` → opens `localhost:4567` with review UI
4. Review UI shows one question at a time: approve, reject, or edit any field inline
5. Each action writes back to SQLite (`status` + `reviewed_at`)
6. Run `rake export` → only `approved` rows written to `docs/questions.json`
7. `git add docs/questions.json && git commit && git push` → GitHub Pages auto-deploys

The review UI is purely local. It will never be deployed. WEBrick is stdlib — no extra gems.

### Review UI details
- **Server**: WEBrick with JSON API endpoints
  - `GET /` — serve `review/index.html`
  - `GET /api/questions?status=pending` — list questions, filterable by status
  - `GET /api/stats` — `{pending: N, approved: N, rejected: N}`
  - `PATCH /api/questions/:id` — update any field (status, text, difficulty, etc.)
- **UI**: vanilla HTML/JS, Bulma CDN
  - Shows one pending question at a time
  - Displays all fields
  - Approve / Reject buttons
  - All fields editable inline (text inputs for short fields, textareas for long ones, comma-separated for JSON arrays, dropdown for difficulty)
  - Navigation: next/prev, count of remaining pending
  - Stats bar: N pending / N approved / N rejected

---

## Frontend Quiz UI (docs/index.html)

Single self-contained HTML file. Loads `questions.json` at startup.

### Stack
- Vanilla JavaScript — no frameworks, no build step
- Bulma CSS via CDN (pin a specific version)
- No external JS dependencies

### UX flow
1. Select a difficulty level (or "all") — tabs or dropdown
2. 10 random questions from that pool, shuffled
3. Flashcard: shows question, tap/click to reveal answer + explanation + rule refs + card refs
4. "Got it" / "Missed it" buttons after reveal → next card
5. After 10 (or fewer if pool is small): score screen ("7/10")
6. Options: "Go again" (new random 10) or "Review missed" (replay the ones you got wrong)

### What it does NOT do
- No persistent tracking — every session starts fresh, no localStorage
- No user accounts
- No cross-device sync
- No leaderboard
- No backend whatsoever

### Edge cases
- Empty or missing `questions.json` → show friendly "No questions available" message
- Fewer than 10 questions in selected difficulty → use however many exist
- Mobile responsive (Bulma handles most of this)

---

## GitHub Pages Setup

- Repo lives in a GitHub organization that already has a domain-pointed `orgname.github.io` site (separate repo)
- This repo is a **project site** — served at `https://orgname.github.io/mtg-quiz/`
- Pages source: **`main` branch, `/docs` folder** (zero-config, no GitHub Actions needed)
- Only `docs/` is ever deployed. The pipeline, data, and review UI exist only on your machine.
- **Important**: because the site lives at a subpath (`/mtg-quiz/`), all asset references in `index.html` must use relative paths (`./questions.json`, not `/questions.json`)

---

## .gitignore

```
data/
*.sqlite
*.db
.env
.DS_STORE
```

---

## Ruby Dependencies

### Gemfile
```ruby
source "https://rubygems.org"

gem "sqlite3"
gem "minitest", group: :test
```

One production gem. WEBrick is stdlib. Downloads use `Net::HTTP` (stdlib).

### .ruby-version
```
3.4.4
```

---

## Testing

Minitest. Tests live in `test/`. Run with `rake test`.

### What we test
- `rake db:setup` creates the table with correct schema
- `rake questions:import` parses valid JSON, inserts rows, generates IDs
- `rake questions:import` rejects JSON with missing required fields
- `rake questions:import` handles both file path and stdin
- `rake export` only includes approved questions
- `rake export` output matches expected JSON shape (no status/timestamps)
- Review server API endpoints return correct responses
- `PATCH` updates fields correctly

### What we don't test
- Frontend UI — manual testing by clicking through is sufficient
- Review UI — same, manual testing
- Data downloads — these hit external servers, not worth mocking

---

## When a New Set Releases

```
rake data:update                # re-download MTGJSON + paste new CR URL
# use /mtg-lookup to explore new cards and rulings
# prompt Claude Code to generate new questions
rake questions:import[batch.json]
rake review:start               # review new batch
rake export
git push
```

---

## Implementation Stages

### Stage 1 — Skeleton + Data ✓
```
[x] Directory structure: docs/, planning/, pipeline/, review/, data/, test/
[x] .gitignore (data/, *.sqlite, *.db, .env, .DS_Store)
[x] .ruby-version (3.4.4)
[x] Gemfile at project root (rake + sqlite3 + minitest)
[x] bundle install
[x] Rakefile at project root
    [x] rake data:update (version check via meta table, stream download, SHA256, CR URL prompt)
    [x] rake db:setup (creates questions table with integer autoincrement PK)
[x] MTGJSON schema verified — see Data Sources section for confirmed table/column details
[x] Tests: test/test_db_setup.rb (5 tests passing)
```

### Stage 2 — Question Generation Tooling ✓
```
[x] Claude Code skill: .claude/commands/mtg-lookup.md
    [x] Query card by name (oracle text + rulings)
    [x] Search cards by keyword/mechanic
    [x] Find cards with most rulings (filterable by format legality)
    [x] Built against verified schema from Stage 1
[x] rake questions:import[path/to/file.json]
    [x] Accept file path as argument
    [x] Validate required fields + difficulty values
    [x] Insert as pending, auto-generate IDs
    [x] Print import summary with ID range and difficulty breakdown
[x] Document generation workflow in planning/generation_prompt.md
    [x] How to prompt Claude Code (with examples)
    [x] Expected JSON output format
    [x] Tips: use /mtg-lookup for exact oracle text
    [x] Tips: work backwards from rulings
[x] Dry run: generated 2 test questions, imported, verified pipeline, cleaned up
[x] Tests: test/test_import.rb (8 tests passing)
```

### Stage 2b — Generate First Batch (separate session)
```
[ ] Generate fundamentals batch (~25 questions)
    [ ] Fresh Claude Code session with full context budget
    [ ] Read CR into context
    [ ] Use /mtg-lookup for exact oracle text + rulings
    [ ] Generate, save to data/batches/fundamentals_01.json
    [ ] rake questions:import[data/batches/fundamentals_01.json]
    [ ] Spot-check: do rule_refs cite real CR sections?
```

### Stage 3 — Review UI + Export
```
[ ] pipeline/review_server.rb (WEBrick)
    [ ] GET / — serve review/index.html
    [ ] GET /api/questions?status=X
    [ ] GET /api/stats
    [ ] PATCH /api/questions/:id — update any field
[ ] review/index.html
    [ ] Bulma CDN
    [ ] One pending question at a time
    [ ] All fields displayed and editable
    [ ] Approve / Reject buttons
    [ ] Difficulty dropdown
    [ ] Comma-separated editing for JSON array fields
    [ ] Next/prev navigation, remaining count
    [ ] Stats bar
[ ] rake review:start — WEBrick on localhost:4567
[ ] rake export
    [ ] Query approved questions
    [ ] Strip status, created_at, reviewed_at
    [ ] Write docs/questions.json (pretty-printed)
    [ ] Print summary, warn if empty
[ ] Tests: test/test_export.rb
    [ ] Only exports approved
    [ ] Correct JSON shape
    [ ] Strips internal fields
[ ] Tests: test/test_review_server.rb
    [ ] API endpoints return correct responses
    [ ] PATCH updates fields
```

### Stage 4 — Frontend Quiz
```
[ ] docs/index.html
    [ ] Bulma CDN (pinned version)
    [ ] Fetch questions.json on load
    [ ] Difficulty filter (tabs or dropdown)
    [ ] Shuffle, serve rounds of 10
    [ ] Flashcard: question front, answer/explanation/refs back
    [ ] Got it / Missed it → next card
    [ ] Score screen after round (7/10)
    [ ] "Go again" / "Review missed" options
    [ ] Empty state message
    [ ] Mobile responsive
[ ] Test with real exported questions
```

### Stage 5 — Polish
```
[ ] UX tweaks after real use
[ ] Generate batches for remaining difficulty levels
[ ] README.md
    [ ] What this is — one paragraph (flashcard quiz for event staff)
    [ ] Setup — Ruby version, bundle install, rake data:update
    [ ] Generating questions — how to use Claude Code + /mtg-lookup, rake questions:import
    [ ] Reviewing questions — rake review:start, how the review UI works
    [ ] Exporting & deploying — rake export, git push, GitHub Pages
    [ ] Using the quiz — link to live site, how the flashcard UI works (for staff)
    [ ] Updating for a new set — the rake data:update → generate → review → export → push workflow
```
