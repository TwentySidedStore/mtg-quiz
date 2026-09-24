# Implementation: Log Results

> **Date:** 2026-09-24
> **Branch:** `log-results`
> **Plan:** `planning/log-results.md` (removed after implementation, see git history)

## Summary

The quiz page asks for a name on the topic-select screen. When a quiz reaches the score screen, the page posts one row to a Google Form: name, topic, correct, total, and missed question ids. The linked Google Sheet is the log of completed quizzes.

## What Changed

- `docs/results-log.js` — new ES module. `buildLogPayload` maps results to form entry ids. `shouldLog` is false on `localhost` and `127.0.0.1`. `storedName` and `rememberName` keep the name in storage with an 8-hour limit. `FORM_URL` is the post endpoint.
- `docs/index.html` — the inline script is now `type="module"` and imports the file above. A name input sits above Start. `startDisabled` owns the Start button state. `startQuiz` saves the trimmed name. `judgeAnswer` calls `postResults` before `renderScore`.
- `test/results_log.test.mjs` — 14 Node tests for the module. Run with `node --test`.
- `Rakefile` — `rake test` runs `node --test` before the Ruby tests.
- `CLAUDE.md` — `results-log.js` added to the `docs/` layout line.

## Deviations from Plan

None in the code. The plan called for manual browser checks in Stages 5 and 6. Browser automation was not available in the session. Headless Chrome confirmed the module loads, the input renders, and Start is disabled with a blank name. These checks are still open:

- The name is prefilled when the stored name is less than 8 hours old.
- Switching topic keeps a typed name in the input.
- A topic with no questions keeps Start disabled when a name is entered.
- Completing a quiz on `localhost` adds no row to the sheet.
- Completing a quiz on the live site adds one row.
- "Back to Results" adds no second row.

Serve locally with `ruby -run -e httpd docs -p 8000` and open `http://localhost:8000/`.

## Surprises & Lessons

- The Google Form required sign-in when first created. An anonymous request to the form URL redirected to a login page. A post from the page would have been dropped with no error. The form settings were fixed before implementation. Check this first when rows stop arriving.
- Browsers block `fetch` on `file:` URLs, so the page never ran from a file URL. No `file:` guard was needed.
- `JSON.parse(null)` returns `null` without throwing. `storedName` checks the parsed shape, not only the parse.

## Watch List

- **Empty sheet.** Run `curl -sI` on the form `viewform` URL. A 302 means the form requires sign-in again. Then check that the five entry ids in `results-log.js` still match the form. Get them from "Get pre-filled link".
- **No success signal.** The post uses `mode: 'no-cors'`. The browser cannot read the response. A failed post is invisible to the user. A rejected `fetch`, for example from an ad blocker, only logs to the console.
- **Public endpoint.** Anyone with the URL can post rows. Names are self-reported.
- **Node test failure hides Ruby tests.** `rake test` runs Node first. A Node failure stops the task before the Ruby tests load. `rake test` still fails.
- **Deploy cache.** GitHub Pages caches for about 10 minutes. A browser can briefly load a new `index.html` with an old or missing `results-log.js`.
