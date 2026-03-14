# MTG Quiz — Project Plan

## What This Is

A local Ruby pipeline that queries MTG card data and rules, generates staff training questions via the Claude API, and exports them to a static quiz UI hosted on GitHub Pages. No backend. No accounts. Two distinct parts that never mix.

---

## The Two Parts

### 1. Pipeline (local only, never deployed)
Runs on your machine. Pulls data, generates questions, manages review, exports JSON.

### 2. Frontend (static, GitHub Pages)
A single `index.html` + `questions.json`. Staff open it in a browser. That's it.

---

## Directory Structure

```
mtg-quiz/
├── .github/
│   └── workflows/              # future: auto-trigger on MTGJSON releases
├── site/                       # GitHub Pages serves this folder
│   ├── index.html              # quiz UI (flashcard interface)
│   └── questions.json          # approved questions only — committed to repo
├── pipeline/
│   ├── Rakefile                # all tasks live here
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── generate.rb             # queries data + calls Claude API
│   ├── review_server.rb        # tiny WEBrick server for local review UI
│   ├── export.rb               # writes approved questions → docs/questions.json
│   └── prompts/
│       ├── system.md           # base LLM system prompt
│       └── schema.json         # enforced output shape
├── data/                       # GITIGNORED — large, local only
│   ├── AllPrintings.sqlite     # from MTGJSON (~400MB)
│   └── comprehensive_rules.txt # plain text, versioned by date
├── review/                     # local-only review UI assets
│   └── index.html              # approve/reject interface (hits local WEBrick)
├── .gitignore
├── CLAUDE.md
└── README.md
```

---

## Data Sources

### MTGJSON
- **File**: `AllPrintings.sqlite` — pre-built SQLite, download directly
- **URL**: https://mtgjson.com/api/v5/AllPrintings.sqlite
- **Key fields used**: `cards.text` (oracle text), `cards.rulings` (Gatherer rulings), `cards.legalities`
- **Format filtering**: Only cards legal in Commander, Draft (via Standard/Modern proxies), Sealed

### Comprehensive Rules
- **File**: Plain `.txt` from Wizards, ~250KB, fits in a context window entirely
- **URL**: https://magic.wizards.com/en/game-info/gameplay/rules-and-formats/rules
- **Already structured** with numbered sections (100–999) — no chunking needed

---

## Difficulty Levels

| Level | Name | Focus |
|---|---|---|
| 1 | **Fundamentals** | Turn structure, phases, casting, card types, basic combat |
| 2 | **Stack & Triggers** | Stack ordering, priority, triggered vs activated abilities, ETBs |
| 3 | **Interactions** | Replacement effects, state-based actions, layers, Commander-specific rules |
| 4 | **Edge Cases** | Blood Moon, Urborg, timestamps, dependency, multiple replacement effects |

Edge Cases (level 4) is included for completeness and ambitious staff. Day-to-day events mostly live in levels 1–2.

---

## Question Schema

Questions generated into SQLite first, exported to JSON only after approval.

### SQLite table: `questions`
```sql
CREATE TABLE questions (
  id          TEXT PRIMARY KEY,
  difficulty  TEXT NOT NULL,       -- fundamentals | stack_triggers | interactions | edge_cases
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
Only `approved` questions ever reach this file.
```json
[
  {
    "id": "q_abc123",
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

## Rake Tasks

```
rake data:update                          # download latest MTGJSON sqlite + CR text
rake questions:generate[level,count]      # e.g. rake questions:generate[fundamentals,25]
rake questions:generate[all,100]          # generate across all levels
rake review:start                         # spin up local WEBrick at localhost:4567
rake export                               # write approved questions → docs/questions.json
```

---

## Review Workflow

1. Run `rake questions:generate[...]` → questions land in local SQLite as `pending`
2. Run `rake review:start` → opens `localhost:4567` with `review/index.html`
3. Review UI shows one question at a time: approve, reject, or edit inline
4. Each action writes back to SQLite (status + reviewed_at)
5. Run `rake export` → only `approved` rows written to `docs/questions.json`
6. `git add docs/questions.json && git commit && git push` → GitHub Pages auto-deploys

The review UI is purely local. It will never be deployed. WEBrick is stdlib Ruby — no extra gems.

---

## Frontend Quiz UI (docs/index.html)

Single self-contained HTML file. Loads `questions.json` at startup.

### Features
- Flashcard mode: question displayed, tap/click to reveal answer + explanation + rule references
- Filter by difficulty level (tab or dropdown)
- "I got it / I missed it" buttons — tracks session score in localStorage
- No accounts. No server. Resets when browser storage is cleared — that's fine.
- Works on desktop (primary) and mobile

### What it does NOT do
- No persistent user accounts
- No cross-device sync
- No leaderboard
- No backend whatsoever

---

## GitHub Pages Setup

- Repo: `github.com/yourname/mtg-quiz`
- Pages source: **`main` branch, `/docs` folder**
- Live URL: `https://yourname.github.io/mtg-quiz`
- Config location: repo Settings → Pages → Source

Only `docs/` is ever deployed. The pipeline, data, and review UI exist only on your machine.

---

## .gitignore

```
data/
*.sqlite
*.db
.env
```

---

## Ruby Gems (Gemfile)

```ruby
gem 'sqlite3'
gem 'anthropic'   # official Anthropic Ruby SDK
gem 'httparty'    # for downloading MTGJSON + CR
```

WEBrick is stdlib — no gem needed.

---

## Generation Logic (high level)

`generate.rb` for a given difficulty level:
1. Query SQLite for cards relevant to the level (e.g. cards with triggered abilities for `stack_triggers`)
2. Load the relevant CR sections (e.g. rule 116.x for priority, 603.x for triggered abilities)
3. Build a prompt: card oracle text + rulings + CR excerpts + difficulty instructions + JSON schema
4. POST to Claude API, parse response, validate against schema
5. Insert into `questions` table as `pending`

Formats filtered to Commander, Standard (Draft pool), and Limited (Sealed pool) via `cards.legalities`.

---

## Question Generation Strategy

- **Concept-first**: questions test understanding of rules mechanics, not card trivia
- **Card references when necessary**: Blood Moon, Urborg, Phenomenon cards, etc. — include oracle text inline in the question so staff don't need to know the card
- **Target volume**: ~250 per level = ~1000 total
- **Human review required**: LLM output will have errors on edge cases — every question gets reviewed before export

---

## When a New Set Releases

```
rake data:update
rake questions:generate[all,50]   # generate new batch focused on new mechanics
rake review:start                 # review new batch
rake export
git push
```

---

## What This Is NOT

- Not a web app
- Not a SaaS product
- Not a database with user accounts
- Not a grading system
- Not a judge training certification tool

It is a flashcard quiz for floor staff at a Magic event venue to get comfortable with common rules situations they'll encounter running Commander, Draft, and Sealed events.
