class_name NetChannels extends RefCounted
## Transfer channel numbers (ADR-0002 rule 3). Protocol constants, not tuning knobs: input and state
## are unreliable on separate channels so neither waits behind a lost reliable packet.
## SceneMultiplayer.peer_packet does not report the channel, so each side only decodes the one kind
## it can receive: the server input packets (var_to_bytes), a client snapshots (SnapshotCodec).

const INPUT := 1
const STATE := 2
## Reserved for reliable intents and events (ADR-0002); unused until the event stories.
const EVENT := 3
## create_server and create_client keep the default channel count (0 = ENet's maximum), which covers
## these. An explicit count of 4 made the client's ENet throttle limit fall to 1 of 32 under the
## test link, dropping about 97% of input (story 006, measured 2026-10-13; cause inside ENet not
## traced: inference). Do not pass a count without re-running prediction_reconcile_test.gd.
