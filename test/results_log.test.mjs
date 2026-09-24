import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { buildLogPayload, shouldLog } from '../docs/results-log.js';

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

  test('joins missed question ids with commas', () => {
    assert.equal(payload['entry.784422944'], '8,9');
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
