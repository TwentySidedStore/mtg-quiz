import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as log from '../docs/results-log.js';

test('module loads', () => {
  assert.ok(log);
});
