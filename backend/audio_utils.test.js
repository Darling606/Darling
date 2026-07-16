'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  decodeBase64Strict,
  validatePcmRequest
} = require('./audio_utils');

test('base64 round trips payload lengths with remainders 0, 1 and 2', () => {
  for (const length of [3, 4, 5]) {
    const source = Buffer.from(Array.from({ length }, (_, index) => index + 1));
    const decoded = decodeBase64Strict(source.toString('base64'));
    assert.deepEqual(decoded, source);
  }
});

test('26240 bytes remain 26240 bytes after base64 decoding', () => {
  const source = Buffer.alloc(26240, 7);
  const decoded = decodeBase64Strict(source.toString('base64'));
  assert.equal(decoded.length, 26240);
});

test('rejects malformed base64 and odd PCM byte lengths', () => {
  assert.equal(decodeBase64Strict('abc'), null);
  const result = validatePcmRequest({
    audio: Buffer.alloc(38401).toString('base64'),
    format: 'pcm_s16le',
    sample_rate: 16000,
    channels: 1,
    bits_per_sample: 16
  });
  assert.equal(result.error.errorCode, 'INVALID_PCM');
});

test('rejects audio shorter than 1.2 seconds', () => {
  const result = validatePcmRequest({
    audio: Buffer.alloc(26240).toString('base64'),
    format: 'pcm_s16le',
    sample_rate: 16000,
    channels: 1,
    bits_per_sample: 16
  });
  assert.equal(result.error.errorCode, 'AUDIO_TOO_SHORT');
});

test('accepts valid mono 16kHz S16LE PCM', () => {
  const result = validatePcmRequest({
    audio: Buffer.alloc(38400).toString('base64'),
    format: 'pcm_s16le',
    sample_rate: 16000,
    channels: 1,
    bits_per_sample: 16
  });
  assert.equal(result.error, undefined);
  assert.equal(result.pcmBuffer.length, 38400);
  assert.equal(result.quality.durationSeconds, 1.2);
});
