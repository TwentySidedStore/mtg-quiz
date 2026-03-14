# UI Layouts

## Review UI (review/index.html)

Local only. Audience: you (developer/manager) on a laptop.

### Layout

```
┌─────────────────────────────────────────────────────┐
│  MTG Quiz Review                                    │
│  Pending: 26  ·  Approved: 0  ·  Rejected: 0       │
├───────────┬───────────┬─────────────────────────────┤
│  Pending  │  Approved │  Rejected                   │  ← Bulma tabs, filter by status
├───────────┴───────────┴─────────────────────────────┤
│                                                     │
│  ID: 5                        Question 3 of 26      │
│                                                     │
│  Difficulty: [fundamentals ▼]                       │
│                                                     │
│  Question:                                          │
│  ┌────────────────────────────────────────────┐     │
│  │ Can a player cast an instant during the    │     │
│  │ untap step?                                │     │  ← textarea
│  └────────────────────────────────────────────┘     │
│                                                     │
│  Answer:                                            │
│  ┌────────────────────────────────────────────┐     │
│  │ No. No player receives priority during     │     │
│  │ the untap step...                          │     │  ← textarea
│  └────────────────────────────────────────────┘     │
│                                                     │
│  Explanation:                                       │
│  ┌────────────────────────────────────────────┐     │
│  │ The untap step is one of only two steps    │     │
│  │ where players don't receive priority...    │     │  ← textarea
│  └────────────────────────────────────────────┘     │
│                                                     │
│  Rule Refs:  [502.4                            ]    │  ← text input, comma-separated
│  Cards:      [                                 ]    │  ← text input, comma-separated
│  Tags:       [turn_structure, priority         ]    │  ← text input, comma-separated
│                                                     │
│  ┌─────────┐                  ┌────────┐ ┌────────┐│
│  │ ← Prev  │                  │ Reject │ │Approve ││
│  └─────────┘                  └────────┘ └────────┘│
│                    ┌─────────┐                      │
│                    │ Next →  │                      │
│                    └─────────┘                      │
└─────────────────────────────────────────────────────┘
```

### Semantic structure

```html
<body>
  <nav>         <!-- Bulma navbar: title + stats -->
  <section>     <!-- Bulma tabs: Pending | Approved | Rejected -->
  <main>
    <article>   <!-- Bulma card: the question being reviewed -->
      <form>    <!-- all editable fields with labels -->
      <footer>  <!-- action buttons: prev/next, reject/approve -->
    </article>
  </main>
</body>
```

### Bulma components used
- `navbar` — title + stats
- `tabs` — status filtering
- `card` — question container
- `field` + `label` + `control` — form fields
- `textarea` — question, answer, explanation
- `input` — rule_refs, cards_ref, tags
- `select` — difficulty dropdown
- `button is-danger` — reject
- `button is-success` — approve
- `button` — prev/next navigation

---

## Quiz UI (docs/index.html)

Deployed via GitHub Pages. Audience: event floor staff on their phone.

### Select mode (landing)

```
┌─────────────────────────────────────────────┐
│  MTG Rules Quiz                             │
├────────┬────────┬────────┬────────┬────────┤
│ Basics │ Multi  │  2HG   │ Stack  │  ...   │  ← Bulma scrollable tabs
├────────┴────────┴────────┴────────┴────────┤
│                                             │
│  Basics                                     │
│                                             │
│  Turn structure, casting spells,            │
│  card types, combat, and draft/sealed       │
│  basics.                                    │
│                                             │
│  26 questions available                     │
│                                             │
│          ┌──────────────────┐               │
│          │    Start Quiz    │               │
│          └──────────────────┘               │
│                                             │
└─────────────────────────────────────────────┘
```

### Quiz mode

```
┌─────────────────────────────────────────────┐
│  Basics                    Question 3 of 10 │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 30%        │  ← progress bar
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │                                       │  │
│  │  A 2/2 creature with trample is       │  │
│  │  blocked by a 1/1 creature. How       │  │
│  │  much damage is dealt to the          │  │
│  │  defending player?                    │  │
│  │                                       │  │  ← Bulma card
│  │         ┌─────────────────┐           │  │
│  │         │  Reveal Answer  │           │  │
│  │         └─────────────────┘           │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

### Quiz mode (after reveal)

```
┌─────────────────────────────────────────────┐
│  Basics                    Question 3 of 10 │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 30%        │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │                                       │  │
│  │  A 2/2 creature with trample is       │  │
│  │  blocked by a 1/1 creature. How       │  │
│  │  much damage is dealt to the          │  │
│  │  defending player?                    │  │
│  │                                       │  │
│  │  ─────────────────────────────────    │  │
│  │                                       │  │
│  │  Answer: 1 damage. The attacking      │  │
│  │  creature must assign at least        │  │
│  │  lethal damage (1) to the blocker,    │  │
│  │  and the remaining 1 damage           │  │
│  │  tramples over.                       │  │
│  │                                       │  │
│  │  Explanation: A creature with         │  │
│  │  trample can assign its excess        │  │
│  │  combat damage to the player...       │  │
│  │                                       │  │
│  │  Rules: 702.19c                       │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│   ┌──────────────┐   ┌──────────────┐       │
│   │  ✗ Missed it │   │  ✓ Got it    │       │  ← large buttons
│   └──────────────┘   └──────────────┘       │
│                                             │
└─────────────────────────────────────────────┘
```

### Score mode

```
┌─────────────────────────────────────────────┐
│  Basics                                     │
├─────────────────────────────────────────────┤
│                                             │
│              7 out of 10                    │
│                                             │
│            Nice work!                       │
│                                             │
│      ┌────────────────────────┐             │
│      │    Review Missed (3)   │             │
│      └────────────────────────┘             │
│                                             │
│      ┌────────────────────────┐             │
│      │      Try Again         │             │
│      └────────────────────────┘             │
│                                             │
│      ┌────────────────────────┐             │
│      │  Pick Another Topic    │             │
│      └────────────────────────┘             │
│                                             │
└─────────────────────────────────────────────┘
```

### Review mode (missed questions)

```
┌─────────────────────────────────────────────┐
│  Reviewing Missed             1 of 3        │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │                                       │  │
│  │  Q: Can a player cast an instant      │  │
│  │  during the untap step?               │  │
│  │                                       │  │
│  │  ─────────────────────────────────    │  │
│  │                                       │  │
│  │  A: No. No player receives priority   │  │
│  │  during the untap step...             │  │
│  │                                       │  │
│  │  The untap step is one of only two    │  │
│  │  steps where players don't receive    │  │
│  │  priority...                          │  │
│  │                                       │  │
│  │  Rules: 502.4                         │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│          ┌────────────────────┐              │
│          │      Next →        │              │
│          └────────────────────┘              │
│                                             │
│     ┌──────────────────────────────┐        │
│     │  Back to Results             │        │
│     └──────────────────────────────┘        │
│                                             │
└─────────────────────────────────────────────┘
```

### Semantic structure

```html
<body>
  <nav>           <!-- Bulma tabs: topic selection (select mode only) -->
  <header>        <!-- topic name + question counter + progress bar -->
  <main>
    <article>     <!-- Bulma card: flashcard content -->
  </main>
  <footer>        <!-- action buttons (reveal, got it/missed it, etc.) -->
</body>
```

### Bulma components used
- `tabs is-toggle is-centered` — topic selection (scrollable on mobile)
- `card` — flashcard container
- `progress` — round progress bar
- `button is-large is-fullwidth` — action buttons (thumb-friendly)
- `notification` or `hero` — score display
- `content` — text formatting inside cards
- `tag` — rule refs display
