# Feature: Log Results

> **Branch:** `log-results`
> **Status:** In Progress (Stage 1/6)

## Problem

Staff have stopped taking the quizzes. The owner cannot see this. The site is static and keeps no record of completed quizzes. The owner needs to know who completes a quiz, on which topic, and with what score.

## Solution

When a quiz reaches the score screen, the page posts one row to a Google Form. Google writes the row to a linked sheet. The sheet is the log.

The page asks for a name on the topic-select screen. The Start button is disabled until the name is not blank. The page stores the name in `localStorage` with a timestamp. The page prefills the name when the stored name is less than 8 hours old. This limit exists because different staff use the same terminal on different days.

The post uses `fetch` with `mode: 'no-cors'`. The browser cannot read the response. The page does not report success or failure.

The page does not post when it runs on `localhost` or `127.0.0.1`. This keeps local testing out of the sheet. A `file:` URL needs no guard. The page already fails on `file:` URLs because browsers block `fetch` there.

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

Topic is the difficulty key, for example `fundamentals`. Missed is a comma-separated list of question ids. A result item is `{ question, got_it }`, so the id is at `question.id`.

The form is public, one page, and all five questions are Short answer with no required flag and no validation. Confirmed on 2026-09-24 with an anonymous GET that returned 200. A form that redirects to sign-in drops every anonymous post with no error.

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
- The Start button is disabled while the input is blank or the topic has no questions. Whitespace-only is blank. `updateTopicInfo` already disables Start for an empty topic. One predicate must own both conditions. Two writers of `disabled` would let a name enable Start on an empty topic and crash `renderQuiz`.
- `startQuiz` trims the name before it saves and posts.
- `storedName` returns `''` for any stored value that is not an object with a string `name` and a number `savedAt`. This includes `null`, a number, and bad JSON.
- The page saves the name when the quiz starts, not when the user types.
- "Try Again" posts a new row each time. This is correct. Each row is one completed quiz.

### Timing & Concurrency

- The post fires once per arrival at the score screen from `judgeAnswer`. "Back to Results" from the review screen also calls `renderScore`. The post must not fire there. Put the post call in `judgeAnswer`, next to the `renderScore` call, not inside `renderScore`.
- The post is asynchronous. The score screen does not wait for it. `keepalive: true` lets the request finish when the tab closes right after the last answer.

### Security & Access

- The form URL and entry ids are public. Anyone can post rows. This is accepted.
- The name is self-reported. This is accepted.
- The form does not require sign-in and does not collect email.

### Failure & Recovery

- `localStorage` can throw in private windows. Keep the `try`/`catch` in two small page functions, `readStoredName` and `saveName`, so the guard is in one place. A failure reads as no name and the input starts empty.
- The page prefills the name once, at init. It does not prefill in `renderSelect`. Topic tab clicks call `renderSelect`, and a prefill there would replace a name the user typed but did not save.
- The post can fail with no signal. The user sees nothing. The owner sees a missing row.
- Google can change the endpoint or the form. No local test can catch this. Check the sheet after the first deploy.
- A rejected `fetch`, for example from an ad blocker, logs an unhandled rejection in the console. This is accepted.
- GitHub Pages caches for about 10 minutes. After deploy a browser can briefly load a new `index.html` with an old or missing `results-log.js`. This is accepted.

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
- [ ] Switching topic keeps a typed name in the input.
- [ ] "Back to Results" adds no row.
- [ ] A topic with no questions keeps Start disabled when a name is entered.
- [ ] `curl -sI` on the form `viewform` URL returns 200, not 302.
- [ ] `rake test` runs the Ruby tests and the Node tests, and all pass.

---
## Open Questions
- N/A — all questions were answered in discovery.
---

## Implementation Stages

> TDD: Every stage writes tests first, then implementation. Complete each stage fully before starting the next.

### Stage 1: Test runner

**Status:** Complete
**What:** Make `rake test` run Node tests.
**Tests:** A placeholder test in `test/results_log.test.mjs` that imports `docs/results-log.js`.
**Steps:**

1. Write `test/results_log.test.mjs` with one test that imports `../docs/results-log.js`. Run `node --test`. It fails because the file is missing.
2. Create `docs/results-log.js` as an empty ES module. The test passes.
3. Add `sh "node --test"` at the top of the `test` task in `Rakefile`. The Ruby tests run at process exit. A Node failure stops the task before the Ruby tests load. This is accepted. `rake test` still fails.
4. Add `results-log.js` to the `docs/` line in `CLAUDE.md`. Leave `favicon.png` alone.

- [x] Tests passing
- [x] No regressions

---

### Stage 2: Payload builder

**Status:** Not Started
**What:** A function that turns quiz results into the form fields.
**Tests:**
Fixtures use the real result shape: `{ question: { id: 7 }, got_it: false }`.
- `buildLogPayload({ name, topic, results })` returns an object with the five `entry.*` keys.
- Correct and total are counts as strings.
- Missed is `question.id` of each result where `got_it` is false, joined with commas.
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
- `shouldLog({ hostname: 'localhost' })` is false.
- `shouldLog({ hostname: '127.0.0.1' })` is false.
- `shouldLog({ hostname: 'twentysidedstore.github.io' })` is true.
**Steps:**

1. Write the three tests. Run them. They fail.
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
- `storedName` returns `''` when `savedAt` is exactly 8 hours before `now`.
- `storedName` returns `''` when the storage holds no value (`getItem` returns `null`).
- `storedName` returns `''` when the storage holds the string `null`.
- `storedName` returns `''` when the storage holds bad JSON.
- `rememberName(storage, 'Alex', now)` writes JSON with `name` and `savedAt`.
**Steps:**

1. Write the seven tests. Run them. They fail.
2. Implement `storedName`, `rememberName`, and export `NAME_TTL_MS`. `storedName` catches the `JSON.parse` error and checks the parsed shape. The tests pass.

- [ ] Tests passing
- [ ] No regressions

---

### Stage 5: Name input

**Status:** Not Started
**What:** Add the name input to the page and connect it to storage.
**Tests:** Manual. Serve the site with `ruby -run -e httpd docs -p 8000` and open `http://localhost:8000/`. Check prefill, the disabled Start button, a topic switch keeping a typed name, and an empty topic keeping Start disabled with a name entered.
**Steps:**

1. Change `<script>` to `<script type="module">`. Add `import { buildLogPayload, shouldLog, storedName, rememberName, FORM_URL } from './results-log.js';`.
2. Add a name input with id `staff-name` above the Start button in `view-select`. Use a Bulma `input`, `placeholder="Your name"`, `autocomplete="off"`.
3. Add `readStoredName()` and `saveName(name)`. Each wraps one `localStorage` call in `try`/`catch` and calls `storedName` or `rememberName` with `Date.now()`.
4. In the init `.then`, after `renderSelect()`, set the input value from `readStoredName()`. Do not do this in `renderSelect`.
5. Add `startDisabled()`. It is true when the topic has no questions or the trimmed input is blank. Make `updateTopicInfo` the only writer of `btn-start.disabled`, using `startDisabled()`. Add an `input` listener on the name field that calls `updateTopicInfo`.
6. In `startQuiz`, set `state.name` to the trimmed input value and call `saveName(state.name)`. The two "Try Again" buttons also call `startQuiz`. The input still holds the name, so no separate path is needed.

- [ ] Manual checks passing
- [ ] No regressions

---

### Stage 6: Post results

**Status:** Not Started
**What:** Post one row to the form when a quiz completes.
**Tests:** Manual. Serve the site as in Stage 5. Complete a quiz on `localhost` and check that no row appears. Complete one on the live site and check the sheet. Use "Back to Results" and check that no second row appears.
**Steps:**

1. Add `postResults()`. It returns early when `shouldLog(location)` is false. Otherwise it calls:
   ```js
   fetch(FORM_URL, {
     method: 'POST',
     mode: 'no-cors',
     keepalive: true,
     body: new URLSearchParams(buildLogPayload({ name: state.name, topic: state.topic, results: state.results }))
   });
   ```
2. Call `postResults()` in `judgeAnswer` before `renderScore()`. Do not call it inside `renderScore`.

- [ ] Manual checks passing
- [ ] No regressions

---

## Review Notes

_Updated by /review-feature. Don't delete — this is the audit trail._

| Issue | Severity | Resolution |
|-------|----------|------------|
| M1. Prefill in `renderSelect` replaces a typed name on topic switch. | Medium | Prefill once at init. Stage 5 updated. |
| M2. A Node test failure stops `rake test` before the Ruby tests load. | Medium | Accepted. `rake test` still fails. Noted in Stage 1. |
| L1. The `file:` guard is dead. Browsers block `fetch` on `file:` URLs, so the page never runs there. | Low | Removed from Solution and Stage 3. |
| L2. `try`/`catch` on `localStorage` conflicts with the no-overguard rule. | Low | Kept. Limited to `readStoredName` and `saveName`. |
| R1. The form required sign-in. Anonymous posts would drop silently. | Critical | Owner fixed the form settings. Confirmed 200 on the viewform URL. Check added to Done When. |
| R2. `updateStartButton` and `updateTopicInfo` both write `disabled`. A name could enable Start on an empty topic. | High | One predicate `startDisabled()`. `updateTopicInfo` is the only writer. |
| R3. Missed id path unstated. `r.id` is undefined. | Medium | Plan states `question.id`. Fixtures use the real shape. |
| R4. Blank or mismatched answers can reject the response. | Medium | Confirmed all fields are Short answer, none required, one page. |
| R5. `storedName` throws on `null` or non-object values. | Medium | Returns `''` for any bad shape. Tests added. |
| R6. Trim and 8-hour boundary unspecified. | Low | `startQuiz` trims. Boundary test added. |
| R7. Manual tests need a local server. | Low | `ruby -run -e httpd docs -p 8000` added to Stages 5 and 6. |
| R8. `postResults` call elided. | Low | Written out with `keepalive: true`. |
| R9. Stages 5 and 6 have manual tests only. | Low | Accepted. No DOM test tooling. |
