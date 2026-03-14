# MTG Quiz

Ruby pipeline that generates Magic: The Gathering rules quiz questions for event staff. Two parts that never mix:

- **Pipeline** — local only, generates questions, manages review, exports JSON
- **Frontend** — `docs/` only, static HTML + JSON, served via GitHub Pages

## Stack
- Ruby + Rake
- SQLite via `sqlite3` gem (`data/` — gitignored, local only)
- Anthropic Ruby SDK for question generation
- WEBrick (stdlib) for local review server

## Key Paths
- `site/index.html` + `site/questions.json` — the only deployed artifacts
- `pipeline/` — all generation, review, export logic
- `data/AllPrintings.sqlite` — MTGJSON source (~400MB, never committed)
- `data/comprehensive_rules.txt` — full CR text, load entirely (fits in context)
- `docs/questions.json` — approved only, array of objects matching above (snake_case, no status/timestamps)

## Data
MTGJSON `AllPrintings.sqlite` — key fields: `cards.text`, `cards.rulings`, `cards.legalities`
CR is plain text with numbered sections (100–999) — reference by section number in explanations

## Difficulty Levels
`fundamentals` — turn structure, phases, casting, card types, combat
`multi-player` — rules unique to playing Magic in multiplayer formats
`2HG` — rules unique to Two Headed Giant
`stack_triggers` — stack, priority, triggered vs activated, ETBs
`interactions` — replacement effects, state-based actions, layers, commander rules
`edge_cases` — Blood Moon, Urborg, timestamps, dependency, obscure corner cases

## Rules for Generation
- Questions test rules concepts, not card trivia
- When a card is referenced, include its oracle text inline in the question
- `rule_refs` must cite actual CR section numbers
- Never write questions where the answer depends on knowing a card the question doesn't quote

## Review Gate
Pipeline → SQLite (`pending`) → local review UI → (`approved`) → `rake export` → `docs/questions.json`
Nothing reaches docs/ without explicit approval. This is intentional.

## What This Is Not
No user accounts, no backend, no persistent staff progress tracking server-side. localStorage only for session state in the quiz UI.
