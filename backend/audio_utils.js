'use strict';

const REQUIRED_SAMPLE_RATE = 16000;
const REQUIRED_CHANNELS = 1;
const REQUIRED_BITS_PER_SAMPLE = 16;
const MIN_AUDIO_DURATION_SECONDS = 1.2;
const MAX_AUDIO_DURATION_SECONDS = 10;

function errorResult(errorCode, message, extra = {}) {
  return {
    success: false,
    text: '',
    reply: '',
    audio: '',
    emotion: 'calm',
    errorCode,
    message,
    logId: '',
    ...extra
  };
}

function decodeBase64Strict(value) {
  if (typeof value !== 'string' || value.length === 0 || value.length % 4 !== 0) {
    return null;
  }
  const base64Pattern = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;
  if (!base64Pattern.test(value)) {
    return null;
  }
  const decoded = Buffer.from(value, 'base64');
  return decoded.toString('base64') === value ? decoded : null;
}

function analyzePcmS16le(buffer) {
  const sampleCount = Math.floor(buffer.length / 2);
  let sumSquares = 0;
  let peak = 0;
  let silentSamples = 0;
  for (let offset = 0; offset < sampleCount * 2; offset += 2) {
    const sample = buffer.readInt16LE(offset);
    const absolute = Math.abs(sample);
    sumSquares += sample * sample;
    peak = Math.max(peak, absolute);
    if (absolute < 100) silentSamples++;
  }
  return {
    durationSeconds: sampleCount / REQUIRED_SAMPLE_RATE,
    rms: sampleCount > 0 ? Math.sqrt(sumSquares / sampleCount) : 0,
    peak,
    silenceRatio: sampleCount > 0 ? silentSamples / sampleCount : 1
  };
}

function validatePcmRequest(body) {
  const format = body.format || 'pcm_s16le';
  const sampleRate = Number(body.sample_rate || REQUIRED_SAMPLE_RATE);
  const channels = Number(body.channels || REQUIRED_CHANNELS);
  const bitsPerSample = Number(body.bits_per_sample || REQUIRED_BITS_PER_SAMPLE);

  if (!['pcm', 'pcm_s16le'].includes(format) || sampleRate !== REQUIRED_SAMPLE_RATE ||
      channels !== REQUIRED_CHANNELS || bitsPerSample !== REQUIRED_BITS_PER_SAMPLE) {
    return {
      error: errorResult('INVALID_PCM', 'PCM must be mono 16kHz signed 16-bit little-endian.')
    };
  }

  const pcmBuffer = decodeBase64Strict(body.audio);
  if (!pcmBuffer || pcmBuffer.length === 0 || pcmBuffer.length % 2 !== 0) {
    return {
      error: errorResult('INVALID_PCM', 'PCM payload is malformed or has an odd byte length.')
    };
  }

  const quality = analyzePcmS16le(pcmBuffer);
  if (quality.durationSeconds < MIN_AUDIO_DURATION_SECONDS) {
    return {
      error: errorResult('AUDIO_TOO_SHORT', 'Audio must be at least 1.2 seconds.', { quality })
    };
  }

  const maxBytes = REQUIRED_SAMPLE_RATE * (REQUIRED_BITS_PER_SAMPLE / 8) * MAX_AUDIO_DURATION_SECONDS;
  return {
    pcmBuffer: pcmBuffer.length > maxBytes ? pcmBuffer.subarray(0, maxBytes) : pcmBuffer,
    quality,
    trimmed: pcmBuffer.length > maxBytes
  };
}

module.exports = {
  MIN_AUDIO_DURATION_SECONDS,
  REQUIRED_SAMPLE_RATE,
  analyzePcmS16le,
  decodeBase64Strict,
  errorResult,
  validatePcmRequest
};
