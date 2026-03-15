Generate Magic: The Gathering rules quiz questions for the specified difficulty level.

Usage: /generate-mtg-questions [level] [count]
- level: fundamentals, multiplayer, 2hg, stack_triggers, interactions, edge_cases
- count: number of questions to generate (default 25)

The user's input is: $ARGUMENTS

## Step 1: Determine level and count

Parse the arguments. First argument is the difficulty level, second (optional) is the count (default 25). If the level is missing or invalid, ask the user which level they want.

Valid levels: fundamentals, multiplayer, 2hg, stack_triggers, interactions, edge_cases

## Step 2: Read the relevant CR sections

Read the Comprehensive Rules from `data/comprehensive_rules.txt`. Use Grep to find the line numbers for the relevant sections, then Read those sections. Load these sections based on the level:

| Level | CR Sections to Read |
|---|---|
| `fundamentals` | 500-514 (turn structure), 601 (casting spells), 117 (timing/priority), 302 (creatures), 305 (lands) |
| `multiplayer` | 800-810 (multiplayer rules), 117 (priority in multiplayer) |
| `2hg` | 810 (Two-Headed Giant), 800-801 (multiplayer general) |
| `stack_triggers` | 603-605 (triggered abilities, static abilities, mana abilities), 117 (timing/priority), 608 (resolving) |
| `interactions` | 613-616 (interaction of continuous effects, replacement effects), 704 (state-based actions), 903 (commander) |
| `edge_cases` | 613 (layers), 614 (replacement effects), 706 (copying), 305.7 (Blood Moon type interactions) |

## Step 3: Query MTGJSON for relevant cards

Use the Bash tool to query `data/AllPrintings.sqlite` for cards relevant to this level. Query cards with many rulings that relate to the topic. Look up their exact oracle text and rulings. Example:

```bash
sqlite3 -header data/AllPrintings.sqlite "SELECT DISTINCT c.name, c.text FROM cards c JOIN cardRulings r ON c.uuid = r.uuid JOIN cardLegalities l ON c.uuid = l.uuid WHERE l.commander = 'Legal' AND c.name IN ('Card1', 'Card2', ...) LIMIT 20;"
```

Good cards per level:
- **fundamentals**: Lightning Bolt, Giant Growth, Serra Angel, Llanowar Elves, Counterspell, Fog, Murder
- **multiplayer**: Fact or Fiction (political), Selvala (group effects), Rhystic Study, Smothering Tithe
- **2hg**: Cards that reference "each opponent," life totals, shared turns
- **stack_triggers**: Panharmonicon, Yarok, Teysa Karlov, Blood Artist, Soul Warden, Oblivion Ring, Strionic Resonator, Purphoros
- **interactions**: Humility, Blood Moon, Urborg, Opalescence, Leyline of the Void, Rest in Peace, Darksteel Mutation
- **edge_cases**: Blood Moon + Urborg, Humility + Opalescence, Sakashima, Spark Double, multiple replacement effects

## Step 4: Determine the next batch number

Check what files already exist in `data/batches/` for this level to determine the batch number:

```bash
ls data/batches/LEVEL_*.json 2>/dev/null
```

Name the file `data/batches/LEVEL_NN.json` where NN is the next number (01, 02, etc.).

## Step 5: Generate questions

Generate the requested number of questions as a JSON array. Each question object must have:

```json
{
  "difficulty": "the_level",
  "question": "The question text",
  "answer": "The direct answer",
  "explanation": "Detailed explanation of why",
  "rule_refs": ["603.2", "117.3c"],
  "cards_ref": ["Card Name"],
  "tags": ["relevant", "tags"]
}
```

### Generation rules — follow these strictly:
- Every question must have ONE deterministic, unambiguous answer
- When referencing a card, include its exact oracle text inline in the question (from MTGJSON, not from memory)
- `rule_refs` must cite actual CR section numbers you read in Step 2
- Never write questions where the answer depends on knowing a card the question doesn't quote
- Test understanding of rules mechanics, not card trivia
- Frame questions as practical scenarios that come up during events
- Work backwards from Gatherer rulings — each ruling suggests a natural question
- One mechanic per question for fundamentals/stack_triggers; combine for interactions/edge_cases

## Step 6: Save and import

1. Write the JSON array to the batch file using the Write tool
2. Run the import:

```bash
bundle exec rake "questions:import[data/batches/LEVEL_NN.json]"
```

3. Report how many questions were imported and their ID range.
