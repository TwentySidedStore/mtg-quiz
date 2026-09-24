# Feature: Log Results

> **Branch:** `log-results`
> **Status:** Draft

## Problem

Staff have stopped taking the quizzes. The owner cannot see this. The site is static and keeps no record of completed quizzes. The owner needs to know who completes a quiz, on which topic, and with what score.

## Solution

When a quiz reaches the score screen, the page posts one row to a Google Form. Google writes the row to a linked sheet. The sheet is the log.

The page asks for a name on the topic-select screen. The Start button is disabled until the name is not blank. The page stores the name in `localStorage` with a timestamp. The page prefills the name when the stored name is less than 8 hours old. This limit exists because different staff use the same terminal on different days.

The post uses `fetch` with `mode: 'no-cors'`. The browser cannot read the response. The page does not report success or failure.

The page does not post when it runs on `localhost`, `127.0.0.1`, or a `file:` URL. This keeps local testing out of the sheet.

Architectural choices:

- **Google Form, not a Discord webhook.** The goal is a record, not a notification. A form needs no proxy and no secret.
- **A new module `docs/results-log.js`, not the full inline script.** Only the new pure logic moves to the file. The existing inline script stays in `index.html`. This keeps the change small. The inline script becomes `type="module"` so it can import the new file.
- **Node's built-in test runner.** No packages. Node 26 is installed. It runs ES module syntax in `.js` files without configuration.
- **Form ids in the source.** The site is public. The form URL and entry ids are not secrets.

Google Form data:

| Field | Entry id |
|---|---|
| Name | `entry.1116517870` |
| Topic | `entry.1038066343` |
| Correct | `entry.738007954` |
| Total | `entry.375375561` |
| Missed | `entry.784422944` |

Post URL: `https://docs.google.com/forms/d/e/1FAIpQLSf6WBi9dpKhygqHkHQ9HmDUY0jUP8zFaloYG-kUrcnBAf_31g/formResponse`

Topic is the difficulty key, for example `fundamentals`. Missed is a comma-separated list of question ids.

### Files to Read

- `docs/index.html` — the full frontend. Read `renderSelect`, `startQuiz`, and `renderScore`.
- `Rakefile` — the `test` task at the bottom. It runs the Ruby tests.
- `CLAUDE.md` — the layout rule for `docs/`.

### Files to Touch

| File | Change | Why |
|------|--------|-----|
| `docs/results-log.js` | New. Pure functions: payload, guard, name storage. | Testable without a browser. |
| `test/results_log.test.mjs` | New. Node tests for the module. | TDD. |
| `docs/index.html` | Add name input. Import the module. Post on score. | The feature. |
| `Rakefile` | Run `node --test` from the `test` task. | One command runs all tests. |
| `CLAUDE.md` | Add `results-log.js` to the `docs/` layout line. | Keep the layout rule true. |

## Risks & Edge Cases

### Data & State

- The stored name is JSON: `{ "name": "Alex", "savedAt": 1727000000000 }`. Bad or missing JSON reads as no name.
- A stored name older than 8 hours reads as no name.
- The Start button is disabled while the input is blank. Whitespace-only is blank.
- The page saves the name when the quiz starts, not when the user types.
- "Try Again" posts a new row each time. This is correct. Each row is one completed quiz.

### Timing & Concurrency

- The post fires once per arrival at the score screen from `judgeAnswer`. "Back to Results" from the review screen also calls `renderScore`. The post must not fire there. Put the post call in `judgeAnswer`, next to the `renderScore` call, not inside `renderScore`.
- The post is asynchronous. The score screen does not wait for it.

### Security & Access

- The form URL and entry ids are public. Anyone can post rows. This is accepted.
- The name is self-reported. This is accepted.
- The form does not require sign-in and does not collect email.

### Failure & Recovery

- `localStorage` can throw in private windows. Wrap access in `try`/`catch`. A failure reads as no name and the input starts empty.
- The post can fail with no signal. The user sees nothing. The owner sees a missing row.
- Google can change the endpoint or the form. No local test can catch this. Check the sheet after the first deploy.

## Out of Scope

- Discord notifications.
- Any server or proxy.
- Success or failure messages in the UI.
- Moving the existing inline script out of `index.html`.
- Tracking seen questions or per-person progress.

## Done When

- [ ] The topic-select screen shows a name input above Start.
- [ ] Start is disabled while the name is blank.
- [ ] The name is prefilled when the stored name is less than 8 hours old.
- [ ] Completing a quiz on the live site adds one row to the sheet with name, topic, correct, total, missed ids.
- [ ] Completing a quiz on `localhost` adds no row.
- [ ] "Back to Results" adds no row.
- [ ] `rake test` runs the Ruby tests and the Node tests, and all pass.

---
## Open Questions
- N/A — all questions were answered in discovery.
---

## Implementation Stages

> TDD: Every stage writes tests first, then implementation. Complete each stage fully before starting the next.

### Stage 1: Test runner

**Status:** Not Started
**What:** Make `rake test` run Node tests.
**Tests:** A placeholder test in `test/results_log.test.mjs` that imports `docs/results-log.js`.
**Steps:**

1. Write `test/results_log.test.mjs` with one test that imports `../docs/results-log.js`. Run `node --test`. It fails because the file is missing.
2. Create `docs/results-log.js` as an empty ES module. The test passes.
3. Add `sh "node --test"` to the `test` task in `Rakefile`.
4. Add `results-log.js` to the `docs/` line in `CLAUDE.md`.

- [ ] Tests passing
- [ ] No regressions

---

### Stage 2: Payload builder

**Status:** Not Started
**What:** A function that turns quiz results into the form fields.
**Tests:**
- `buildLogPayload({ name, topic, results })` returns an object with the five `entry.*` keys.
- Correct and total are counts as strings.
- Missed is the ids of results where `got_it` is false, joined with commas.
- Missed is an empty string when nothing was missed.
**Steps:**

1. Write the four tests. Run them. They fail.
2. Implement `buildLogPayload` and export `FORM_URL`. The tests pass.

- [ ] Tests passing
- [ ] No regressions

---

### Stage 3: Local guard

**Status:** Not Started
**What:** A predicate that says whether the page should post.
**Tests:**
- `shouldLog({ hostname: 'localhost', protocol: 'http:' })` is false.
- `shouldLog` is false for `127.0.0.1`.
- `shouldLog` is false for protocol `file:`.
- `shouldLog` is true for `twentysidedstore.github.io` over `https:`.
**Steps:**

1. Write the four tests. Run them. They fail.
2. Implement `shouldLog`. The tests pass.

- [ ] Tests passing
- [ ] No regressions

---

### Stage 4: Name storage

**Status:** Not Started
**What:** Read and write the name with an 8-hour limit.
**Tests:** Use a plain object with `getItem` and `setItem` as the storage.
- `storedName(storage, now)` returns the name when `savedAt` is 7 hours before `now`.
- `storedName` returns `''` when `savedAt` is 9 hours before `now`.
- `storedName` returns `''` when the storage holds no value.
- `storedName` returns `''` when the storage holds bad JSON.
- `rememberName(storage, 'Alex', now)` writes JSON with `name` and `savedAt`.
**Steps:**

1. Write the five tests. Run them. They fail.
2. Implement `storedName`, `rememberName`, and export `NAME_TTL_MS`. The tests pass.

- [ ] Tests passing
- [ ] No regressions

---

### Stage 5: Wire the page

**Status:** Not Started
**What:** Connect the module to `index.html`.
**Tests:** Manual. Run the site on `localhost` and on the live site. Check the sheet.
**Steps:**

1. Change `<script>` to `<script type="module">`. Add `import { buildLogPayload, shouldLog, storedName, rememberName, FORM_URL } from './results-log.js';`.
2. Add a name input with id `staff-name` above the Start button in `view-select`. Use a Bulma `input`, `placeholder="Your name"`, `autocomplete="off"`.
3. In `renderSelect`, set the input value from `storedName(localStorage, Date.now())` inside `try`/`catch`. Disable Start when the trimmed value is blank. Add an `input` listener that updates the disabled state.
4. In `startQuiz`, call `rememberName(localStorage, name, Date.now())` inside `try`/`catch` and keep the name in `state.name`.
5. Add `postResults()`. It returns early when `shouldLog(location)` is false. Otherwise it calls `fetch(FORM_URL, { method: 'POST', mode: 'no-cors', body: new URLSearchParams(buildLogPayload(...)) })`.
6. Call `postResults()` in `judgeAnswer` before `renderScore()`. Do not call it inside `renderScore`.

- [ ] Manual checks passing
- [ ] No regressions

---

## Review Notes

_Updated by /review-feature. Don't delete — this is the audit trail._

| Issue | Severity | Resolution |
|-------|----------|------------|
| | | |
