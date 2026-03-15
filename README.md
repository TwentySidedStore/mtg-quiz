# MTG Rules Quiz

A flashcard quiz for Magic: The Gathering event staff to practice common rules situations they'll encounter running Commander, Draft, and Sealed events.

**Live quiz**: [twentysidedstore.github.io/mtg-quiz](https://twentysidedstore.github.io/mtg-quiz/)

## How it works

Staff open the quiz in a browser, pick a topic, and answer 10 random questions per round. After each round they see their score and can review the ones they missed. No accounts, no tracking — just practice.

Topics: **Basics**, **Procedures**, **Multiplayer**, **2HG**, **Stack**, **Interactions**, **Edge Cases**

## Setup (for question management)

You only need this if you're generating, reviewing, or exporting questions. Staff just use the live site.

### Requirements

- Ruby 3.4.4+ (via rbenv)
- Bundler
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (for question generation)

### Install

```bash
git clone https://github.com/TwentySidedStore/mtg-quiz.git
cd mtg-quiz
bundle install
```

### Download data

```bash
rake data:update
```

This downloads [MTGJSON](https://mtgjson.com)'s AllPrintings.sqlite (~540MB) and prompts you to paste the Comprehensive Rules URL from [magic.wizards.com/en/rules](https://magic.wizards.com/en/rules). Paste the direct `.txt` file link.

### Set up the questions database

```bash
rake db:setup
```

## Generating questions

Questions are generated using the `/generate-mtg-questions` Claude Code skill, which automates the entire pipeline: reads the relevant Comprehensive Rules sections, queries MTGJSON for card oracle text and rulings, generates questions, and imports them into the database.

```bash
# In a Claude Code session:
/generate-mtg-questions fundamentals 20
/generate-mtg-questions multiplayer 20
/generate-mtg-questions event_procedures 15
```

The skill accepts a difficulty level and an optional count (default 25). You can also add instructions:

```
/generate-mtg-questions edge_cases 20 Focus on Blood Moon and Urborg interactions
```

Valid levels: `fundamentals`, `event_procedures`, `multiplayer`, `2hg`, `stack_triggers`, `interactions`, `edge_cases`

For card lookups during review or ad-hoc research, use the `/mtg-lookup` skill:

```
/mtg-lookup Blood Moon
```

Generated questions are saved to `data/batches/` and automatically imported as `pending`.

## Reviewing questions

All imported questions start as `pending`. Review them before they go live:

```bash
rake review:start
```

Open [localhost:4567](http://localhost:4567) in your browser. For each question you can:

- **Edit** any field (question text, answer, explanation, rule refs, difficulty, etc.)
- **Approve** — question will be included in the next export
- **Reject** — question won't be exported

Use the status tabs to filter by Pending, Approved, or Rejected. Use the jump-to dropdown to navigate to a specific question.

## Exporting and deploying

Export approved questions and push to GitHub Pages:

```bash
rake export
git add docs/questions.json
git commit -m "Update approved questions"
git push origin main
```

GitHub Pages auto-deploys from the `docs/` folder on `main`. The quiz site updates within ~60 seconds.

### First-time GitHub Pages setup

1. Go to repo Settings → Pages → Source
2. Select: **Deploy from a branch**
3. Branch: `main`, Folder: `/docs`
4. Click Save

## Using the quiz (for staff)

1. Open the quiz URL in a browser (works on phone or desktop)
2. Pick a topic from the tabs at the top
3. Tap **Start Quiz** — you'll get 10 random questions
4. Read the question, tap **Reveal Answer**, then mark **Got it** or **Missed it**
5. After 10 questions, see your score
6. Tap **Review Missed** to study the ones you got wrong
7. Tap **Try Again** for another round, or pick another topic from the tabs

## Updating for a new set

When a new MTG set releases and the Comprehensive Rules are updated:

```bash
rake data:update                                       # re-download MTGJSON + paste new CR URL
# In a Claude Code session:
/generate-mtg-questions fundamentals 20                # generate new questions
/generate-mtg-questions stack_triggers 20
rake review:start                                      # review the new batch
rake export                                            # export approved
git add docs/questions.json && git commit && git push   # deploy
```

## Rake tasks

| Task | Description |
|---|---|
| `rake data:update` | Download MTGJSON + Comprehensive Rules |
| `rake db:setup` | Create the questions database |
| `rake questions:import[file]` | Import questions from a JSON file |
| `rake review:start` | Start the review server at localhost:4567 |
| `rake export` | Export approved questions to docs/questions.json |
| `rake test` | Run the test suite |

## Project structure

```
docs/               → GitHub Pages (index.html + questions.json + preview.png) — deployed files
planning/           → Project plans, UI layouts, generation prompts
pipeline/           → Review server (WEBrick)
review/             → Local review UI
data/               → MTGJSON, Comprehensive Rules, questions DB (gitignored)
data/batches/       → Generated question JSON files (gitignored)
test/               → Minitest tests
.claude/commands/   → Claude Code skills (/generate-mtg-questions, /mtg-lookup)
```
