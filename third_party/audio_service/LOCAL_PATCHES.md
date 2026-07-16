# Local patches

This directory vendors `audio_service` 0.18.19.

On an active Android audio service, notification transport intents are
delivered directly to the existing media session. This avoids an unnecessary
`MediaBrowserCompat` reconnect for every notification tap. Play and pause are
also routed directly because the upstream Android implementation represents
those two notification actions with private bypass key codes.

If the service is not alive, the upstream receiver path is retained so Android
can start and reconnect to it normally.
