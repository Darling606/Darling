# Voice testing

The app records 48 kHz mono S16LE PCM, converts it to 16 kHz mono S16LE,
then sends the buffered recording to the backend. The click-to-record UI uses
Doubao `push_to_talk` mode: audio is sent as 640-byte chunks paced at 20 ms,
followed by an `EndASR` event.

## Local validation

Run validation and Base64 regression tests without network access:

```powershell
npm test
```

## Realtime speech fixture

To test the full Doubao ASR, chat, and TTS path independently of an emulator
microphone, provide a 2-3 second Chinese speech fixture:

```powershell
npm run test:realtime -- D:\path\speech.wav
```

Accepted fixture formats:

- Headerless `.pcm`: mono, 16000 Hz, signed 16-bit little-endian.
- `.wav`: PCM format 1, mono, 16000 Hz, signed 16-bit.

Set `VOLC_APPID`, `VOLC_TOKEN`, and optionally `VOLC_MODEL=1.2.1.1` in `.env`.
Do not commit credentials or speech recordings containing private information.
