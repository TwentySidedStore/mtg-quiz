# Question Generation Guide

How to generate quiz questions using Claude Code.

## Setup

Before generating, make sure you have:
1. `data/AllPrintings.sqlite` — run `rake data:update` if missing
2. `data/comprehensive_rules.txt` — downloaded during `rake data:update`
3. `data/questions.sqlite` — run `rake db:setup` if missing

## Generation workflow

1. Start a fresh Claude Code session (you want full context budget)
2. Ask Claude Code to read the relevant CR sections into context
3. Use `/mtg-lookup` to pull exact oracle text and rulings for cards you want to reference
4. Prompt Claude Code to generate questions (see prompts below)
5. Save the output to `data/batches/<difficulty>_<batch_number>.json`
6. Import: `rake questions:import[data/batches/<filename>.json]`

## Output format

Claude Code should output a JSON array. Each object has these fields:

```json
{
  "difficulty": "fundamentals",
  "question": "The question text",
  "answer": "The direct answer",
  "explanation": "A more detailed explanation of why",
  "rule_refs": ["502.3", "503.1"],
  "cards_ref": ["Card Name"],
  "tags": ["turn_structure", "priority"]
}
```

**Required**: `difficulty`, `question`, `answer`, `explanation`
**Optional**: `rule_refs`, `cards_ref`, `tags` (but strongly encouraged)

No `id` or `status` — those are added by the import task.

## Difficulty levels

- `fundamentals` — turn structure, phases, casting, card types, basic combat, draft/sealed procedure
- `multiplayer` — rules unique to multiplayer formats
- `2hg` — Two-Headed Giant specific rules
- `stack_triggers` — stack ordering, priority, triggered vs activated abilities, ETBs
- `interactions` — replacement effects, state-based actions, layers, commander rules
- `edge_cases` — Blood Moon, Urborg, timestamps, dependency, obscure corners

## Example prompts

### Basic generation
```
Read data/comprehensive_rules.txt sections 500-514 (turn structure).
Generate 15 fundamentals questions about turn structure and phases.
Output as a JSON array matching the format in planning/generation_prompt.md.
```

### Using rulings as question seeds
```
/mtg-lookup Find the 20 commander-legal cards with the most rulings

Now read data/comprehensive_rules.txt sections 603-604 (triggered and activated abilities).
For each of the top 10 cards, generate one stack_triggers question based on their rulings.
Include exact oracle text in the question. Output as JSON array.
```

### Targeted mechanic generation
```
/mtg-lookup Search for commander-legal cards with "replacement effect" in oracle text

Read data/comprehensive_rules.txt sections 614-616 (replacement effects).
Generate 10 interactions questions about replacement effects using these cards.
Include exact oracle text inline in each question. Output as JSON array.
```

## Rules for generation

- **Precision**: Every question must have one deterministic, unambiguous answer. Magic rulings are deterministic.
- **Self-contained**: Include oracle text inline when referencing a card. Never assume the reader knows a card.
- **Real rule citations**: `rule_refs` must cite actual CR section numbers. Verify them against the CR text.
- **Concept-first**: Test understanding of rules mechanics, not card trivia or flavor.
- **Use MTGJSON data**: Use `/mtg-lookup` to get exact oracle text. Don't rely on memory — card text changes with errata.

## Tips

- **Work backwards from rulings**: Cards with many Gatherer rulings are literally the cards people ask questions about. Each ruling suggests a natural quiz question.
- **One mechanic per question**: Don't combine multiple complex interactions in a fundamentals question. Save that for interactions/edge_cases.
- **Practical scenarios**: Frame questions as situations that would actually come up during an event. "A player asks you..." is a good framing.
- **Draft/sealed procedure**: For fundamentals, include questions about draft and sealed procedures (deck construction rules, match structure, etc.). These are CR sections 100.6 and related tournament rules.
