Query the MTGJSON AllPrintings.sqlite database at `data/AllPrintings.sqlite`.

The user will provide a query — a card name, a keyword, a mechanic, or a request to find cards with many rulings. Run the appropriate SQL using the Bash tool with `sqlite3`.

## Schema

- `cards` — `uuid`, `name`, `text` (oracle text), `type` (full type line), `manaCost`, `keywords` (comma-separated), `power`, `toughness`, `loyalty`. Cards have multiple rows across printings — always use `GROUP BY name` or `DISTINCT` on name to deduplicate.
- `cardRulings` — `uuid`, `date`, `text`. Join on `cards.uuid`.
- `cardLegalities` — `uuid`, plus one column per format: `commander`, `modern`, `standard`, `legacy`, `vintage`, `pioneer`, `pauper`, etc. Values are "Legal", "Banned", "Restricted", or NULL.

## Common queries

### Look up a card by name
```bash
sqlite3 -header data/AllPrintings.sqlite "
  SELECT DISTINCT c.name, c.manaCost, c.type, c.text, c.power, c.toughness
  FROM cards c
  WHERE c.name = 'CARD_NAME'
  LIMIT 1;
"
```

Then get its rulings:
```bash
sqlite3 -header data/AllPrintings.sqlite "
  SELECT r.date, r.text
  FROM cardRulings r
  JOIN cards c ON c.uuid = r.uuid
  WHERE c.name = 'CARD_NAME'
  GROUP BY r.date, r.text
  ORDER BY r.date;
"
```

### Search cards by keyword or oracle text
```bash
sqlite3 -header data/AllPrintings.sqlite "
  SELECT DISTINCT c.name, c.type, c.text
  FROM cards c
  JOIN cardLegalities l ON c.uuid = l.uuid
  WHERE c.text LIKE '%SEARCH_TERM%'
    AND l.commander = 'Legal'
  LIMIT 20;
"
```

### Find cards with the most rulings
```bash
sqlite3 -header data/AllPrintings.sqlite "
  SELECT c.name, COUNT(DISTINCT r.text) as ruling_count
  FROM cards c
  JOIN cardRulings r ON c.uuid = r.uuid
  JOIN cardLegalities l ON c.uuid = l.uuid
  WHERE l.commander = 'Legal'
  GROUP BY c.name
  ORDER BY ruling_count DESC
  LIMIT 20;
"
```

### Search by keyword ability
```bash
sqlite3 -header data/AllPrintings.sqlite "
  SELECT DISTINCT c.name, c.type, c.text
  FROM cards c
  JOIN cardLegalities l ON c.uuid = l.uuid
  WHERE c.keywords LIKE '%KEYWORD%'
    AND l.commander = 'Legal'
  LIMIT 20;
"
```

## Instructions

1. Figure out what the user is asking for (card lookup, keyword search, rulings search, etc.)
2. Run the appropriate query, adapting the examples above as needed
3. Format the results clearly — card name, type line, oracle text, and rulings if relevant
4. If looking up a specific card, always include its rulings (they're the most useful part for question generation)
5. For format filtering, default to `commander = 'Legal'` unless the user specifies otherwise
