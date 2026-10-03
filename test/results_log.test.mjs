import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { buildLogPayload, shouldLog, storedName, rememberName, missedIdsFromSearch, questionsByIds, missedReviewUrl } from '../docs/results-log.js';

function result(id, gotIt) {
  return { question: { id }, got_it: gotIt };
}

describe('buildLogPayload', () => {
  const payload = buildLogPayload({
    name: 'Alex',
    topic: 'fundamentals',
    results: [result(7, true), result(8, false), result(9, false)]
  });

  test('maps name and topic to their entry ids', () => {
    assert.equal(payload['entry.1116517870'], 'Alex');
    assert.equal(payload['entry.1038066343'], 'fundamentals');
  });

  test('counts correct and total as strings', () => {
    assert.equal(payload['entry.738007954'], '1');
    assert.equal(payload['entry.375375561'], '3');
  });

  test('joins missed question ids with semicolons so Sheets keeps them as text', () => {
    assert.equal(payload['entry.784422944'], '8;9');
  });

  test('missed is empty when nothing was missed', () => {
    const perfect = buildLogPayload({ name: 'Alex', topic: 'fundamentals', results: [result(1, true)] });
    assert.equal(perfect['entry.784422944'], '');
  });
});

describe('shouldLog', () => {
  test('is false on localhost', () => {
    assert.equal(shouldLog({ hostname: 'localhost' }), false);
  });

  test('is false on 127.0.0.1', () => {
    assert.equal(shouldLog({ hostname: '127.0.0.1' }), false);
  });

  test('is true on the live site', () => {
    assert.equal(shouldLog({ hostname: 'twentysidedstore.github.io' }), true);
  });
});

const HOUR_MS = 60 * 60 * 1000;
const NOW = 1_727_000_000_000;

function storageHolding(value) {
  return { getItem: () => value, setItem: () => {} };
}

function savedHoursAgo(hours) {
  return storageHolding(JSON.stringify({ name: 'Alex', savedAt: NOW - hours * HOUR_MS }));
}

describe('storedName', () => {
  test('returns the name when saved 7 hours ago', () => {
    assert.equal(storedName(savedHoursAgo(7), NOW), 'Alex');
  });

  test('returns empty when saved 9 hours ago', () => {
    assert.equal(storedName(savedHoursAgo(9), NOW), '');
  });

  test('returns empty when saved exactly 8 hours ago', () => {
    assert.equal(storedName(savedHoursAgo(8), NOW), '');
  });

  test('returns empty when nothing is stored', () => {
    assert.equal(storedName(storageHolding(null), NOW), '');
  });

  test('returns empty when the stored string is null', () => {
    assert.equal(storedName(storageHolding('null'), NOW), '');
  });

  test('returns empty on bad JSON', () => {
    assert.equal(storedName(storageHolding('{not json'), NOW), '');
  });
});

describe('rememberName', () => {
  test('writes name and savedAt as JSON', () => {
    const written = {};
    const storage = { setItem: (key, value) => { written[key] = value; } };
    rememberName(storage, 'Alex', NOW);
    const [value] = Object.values(written);
    assert.deepEqual(JSON.parse(value), { name: 'Alex', savedAt: NOW });
  });
});

describe('missedIdsFromSearch', () => {
  test('parses comma separated ids', () => {
    assert.deepEqual(missedIdsFromSearch('?missed=388,347,577'), [388, 347, 577]);
  });

  test('parses semicolon separated ids', () => {
    assert.deepEqual(missedIdsFromSearch('?missed=388;347'), [388, 347]);
  });

  test('ignores blanks and non numbers', () => {
    assert.deepEqual(missedIdsFromSearch('?missed=388,,abc,12'), [388, 12]);
  });

  test('is empty without the parameter', () => {
    assert.deepEqual(missedIdsFromSearch(''), []);
  });
});

describe('questionsByIds', () => {
  const questions = [{ id: 1 }, { id: 2 }, { id: 3 }];

  test('returns questions in the requested order', () => {
    assert.deepEqual(questionsByIds(questions, [3, 1]), [{ id: 3 }, { id: 1 }]);
  });

  test('skips unknown ids', () => {
    assert.deepEqual(questionsByIds(questions, [2, 99]), [{ id: 2 }]);
  });
});

describe('missedReviewUrl', () => {
  const site = { origin: 'https://twentysidedstore.github.io', pathname: '/mtg-quiz/' };

  test('links to the site with missed ids', () => {
    const url = missedReviewUrl(site, [result(7, true), result(8, false), result(9, false)]);
    assert.equal(url, 'https://twentysidedstore.github.io/mtg-quiz/?missed=8,9');
  });

  test('is empty when nothing was missed', () => {
    assert.equal(missedReviewUrl(site, [result(1, true)]), '');
  });
});
