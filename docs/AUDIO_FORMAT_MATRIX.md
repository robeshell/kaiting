# Audio format matrix

This is the acceptance ledger for **SND-205**. A format is not called
cross-platform merely because a decoder package lists it: discovery, metadata,
native load, playback, seek, queue transition, local files, WebDAV headers and
device runtime are tracked separately.

The production player uses
[just_audio](https://github.com/ryanheise/just_audio/tree/minor/just_audio),
which delegates codecs to each operating system. Metadata uses
[audio_metadata_reader](https://github.com/ClementBeal/audio_metadata_reader).
Remote servers must provide the correct content type, content length and byte
range behavior; local files must retain the correct extension.

## Shared ingestion contract

| Format | Extension / MIME | Discovery and cache | Metadata policy |
| --- | --- | --- | --- |
| MP3 | `.mp3` / `audio/mpeg` | Local, Android SAF and WebDAV | ID3; recognisable MPEG frames may fall back to filename when non-essential tags are unreadable. Xing and Info frame counts correct long/VBR duration. |
| FLAC | `.flac` / `audio/flac` | Local, Android SAF and WebDAV | Vorbis comments, artwork and duration. |
| AAC in M4A | `.m4a` / `audio/mp4` | Local, Android SAF and WebDAV | MP4/iTunes atoms, artwork and duration. |
| ALAC in M4A | `.m4a` / `audio/mp4` | Local, Android SAF and WebDAV | Same M4A metadata path; codec is resolved by the native player. |
| Raw AAC / ADTS | `.aac` / `audio/aac` | Local, Android SAF and WebDAV | The metadata package has no raw AAC container parser. A valid ADTS header is required, then the track is imported by filename with unknown artist/album. |
| WAV | `.wav` / `audio/wav` | Local, Android SAF and WebDAV | RIFF metadata and duration. |
| Ogg Vorbis | `.ogg` / `audio/ogg` | Local, Android SAF and WebDAV | Vorbis comments and duration. |
| Opus | `.opus` / `audio/ogg` | Local, Android SAF and WebDAV | Vorbis comments and duration. This extends the original SND-205 minimum. |

WMA, APE and AIFF are not in the shared contract yet. Some libraries or
individual operating systems can handle them, but adding them before every
target has a tested ingestion and playback policy would create misleading
library entries.

## Native playback status

Legend: **Pass** = production playback engine loaded, played and sought a real
sample; **Build** = application builds but the format still needs runtime
device validation; **Pending** = target host/device is unavailable.

| Format | macOS (current host) | Android | iPhone / iPad | Windows |
| --- | --- | --- | --- | --- |
| MP3 | Pass (local + authenticated WebDAV; seek) | Build | Build | Pending |
| FLAC | Pass (local + authenticated/public WebDAV; seek/lyrics) | Build | Build | Pending |
| AAC in M4A | Pass (local + authenticated WebDAV; seek) | Build | Build | Pending |
| ALAC in M4A | Pass (local + authenticated WebDAV; seek) | Build | Build | Pending |
| Raw AAC / ADTS | Pass (local + authenticated WebDAV; seek) | Build | Build | Pending |
| WAV | Pass (local + authenticated WebDAV; seek) | Build | Build | Pending |
| Ogg Vorbis | Pass (local + authenticated WebDAV; seek) | Build | Build | Pending |
| Opus | Pass (local + authenticated WebDAV; seek) | Build | Build | Pending |

The macOS runs used `tool/validate_audio_formats.dart` through the same
`JustAudioPlaybackEngine` as production. Every sample passed both local-file and
authenticated WebDAV playback. Audio was muted, but each file reached playing
state, reported a positive native duration and confirmed a 500 ms seek. The
remote run also exercised authenticated byte-range responses for every format.

## Edge and recovery cases

| Case | Result |
| --- | --- |
| 60-minute MP3 with Info/VBR frame table | Corrected from an inaccurate 1,791,608 ms estimate to 3,600,039 ms. Bounded metadata probe dropped from about 24 seconds to under 1 second on the current Mac. |
| Raw AAC without a tag container | Valid ADTS bytes import by filename rather than disappearing from the library. |
| Truncated MP3 containing only a partial ID3 tag | Rejected because no MPEG audio frame is present. The scan continues and reports/skips the file. |
| One damaged file among valid local files | Valid tracks commit atomically; the damaged path is returned as a warning instead of aborting the source scan. |
| One damaged file among valid WebDAV files | The damaged file is counted as skipped; other tracks remain indexable. |
| Public WebDAV with split successful `propstat` blocks | Properties are merged, so size and modification fingerprints survive and the next scan performs no metadata reread. |

## Remaining acceptance work

- Run the same generated matrix through Android hardware/emulator storage and
  public WebDAV, including background controls and queue transitions.
- Run it on iPhone and iPad simulators, then hardware, including Files security
  scope restore, background playback and seek after interruption.
- Run it on a Windows host with `just_audio_windows`, including local files,
  authenticated WebDAV, cache extension preservation and remote range seek.
- Add natural transitions between mixed-format adjacent queue items and a real
  long VBR listening check; native duration/seek results remain authoritative.
