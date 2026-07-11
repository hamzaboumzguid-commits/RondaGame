# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Mobile game (iOS + Android) implementing the "Ronda marocaine — variante café" card game rules, 4 players in 2 teams of 2, online-only multiplayer via room codes (no accounts, ephemeral sessions — join flow modeled on Among Us: nickname + room code).

**The full ruleset, all product decisions, and rationale live in [GDD.md](GDD.md) — read it before touching any game logic.** It is the single source of truth for scoring, turn order, and every edge case (Derba chains, Ronda/Tringa resolution, last-capture bonus, etc.). Update it when a rule interpretation changes.

This is a monorepo with two independent projects:
- `server/` — authoritative Node.js/TypeScript backend: plain WebSocket (`ws`) + JSON protocol. Owns all game logic and rule enforcement. (Colyseus was tried and abandoned: no living Dart client exists — see GDD.md section 4.)
- `app/` — Flutter (Dart) cross-platform client. Renders server-authoritative state; never re-implements scoring rules.

## Commands

### Server (`server/`)
```
npm run dev          # tsx watch, runs src/index.ts with hot reload on :2567
npm run build         # tsc compile to dist/ (ESM output)
npm start             # run compiled dist/index.js
npm test               # vitest run — full suite (rule engine + room orchestration + socket E2E)
npx vitest run src/game/table.test.ts   # run a single test file
npx tsc --noEmit       # typecheck only
```
No lint script is configured.

### App (`app/`)
Flutter SDK lives at `C:\dev\flutter` (cloned from the stable channel, added to user PATH). If `flutter` is not found in a fresh shell, use `C:\dev\flutter\bin\flutter` directly.
```
flutter pub get
flutter analyze        # must be clean before considering a change done
flutter test            # widget/unit tests (the e2e-tagged test self-skips if the server is down)
flutter test --tags e2e test/game_client_e2e_test.dart   # full-game E2E vs live local server (start server first)
flutter run              # launch on connected device/emulator
```
The client connects to `ws://localhost:2567` by default; override at build time with `--dart-define=RONDA_SERVER=ws://host:port` (Android emulator needs `ws://10.0.2.2:2567`).

## Architecture

### Server: rule engine is separated from network plumbing

`server/src/game/` is **pure logic with no network dependency** — it must stay independently testable:
- `types.ts` — card/player/team/announcement domain types, `RANK_ORDER` (As < 2 < ... < Roi), point constants (`TARGET_SCORE` 41, `BUTIN_THRESHOLD` 20, `DERBA_POINTS` 1/5/10).
- `deck.ts` — 40-card Spanish deck + Fisher-Yates shuffle.
- `table.ts` — the `Table` class: capture resolution (capturing a rank also sweeps the whole contiguous ascending sequence — stricter than it first looks, it takes unrelated contiguous cards too; see GDD 2.6), Derba detection with chain-tier escalation (capped at tier 3 since only 4 copies of each rank exist), Missa detection. A non-capture play breaks any Derba chain.
- `rondaTringa.ts` — end-of-sub-round resolution: single Ronda, 2/3-Ronda highest-wins-with-tie-cancels, 4-Ronda lowest-wins-with-cascading-tiebreak, Tringa-always-beats-Ronda +1 bonus. Trickiest piece of the ruleset — re-read GDD 2.9 before modifying.
- `round.ts` — butin counting, last-capture bonus/malus (Roi +5 / As gives 5 to opponent), lead rotation ("to the right" = seat (N+3)%4, seats numbered clockwise 0-3).

`server/src/net/` wires this to the network:
- `protocol.ts` — the complete JSON message contract (ClientMessage / ServerMessage / PublicState). **`app/lib/models/protocol.dart` mirrors these shapes by hand — any change here must be replicated there.**
- `GameRoom.ts` — one game: lobby (host starts, explicit team choice), 3 sub-round deals (4-3-3) per round, turn validation, scoring. Takes a `PlayerConnection` interface (just `send()`), so tests drive it with fakes. Key rule detail implemented here: a chained Derba *cancels the previous tier's points* (which always belong to the opposing team since turns alternate A/B/A/B) before adding its own; and the win check runs after *every* point application, because reaching 41 ends the game immediately mid-round (GDD 2.1).
- `RoomManager.ts` / `roomCode.ts` — code → room map; 5-char codes from a no-ambiguity alphabet (no 0/O/1/I/L).
- `server.ts` exports `createGameServer()` (used by tests); `index.ts` is the thin entry point.

Hands are **never** in the broadcast public state — each player gets a private `yourHand` message. Announcements are exposed pre-reveal only as a boolean badge (`hasAnnouncement`), never value or kind (GDD 2.5).

No reconnection in v1 (GDD 3.1): any disconnect/leave outside the lobby broadcasts `gameAbandoned` and kills the room.

**Module system**: server is ESM (`"type": "module"`, tsconfig `module: node16`). **Every relative import needs an explicit `.js` extension** even in `.ts` source, or the compiled `dist/` breaks under Node's ESM loader. Don't switch to `bundler` resolution to avoid the extensions — tsc doesn't rewrite import paths.

### App: thin client over the server state

- `lib/models/protocol.dart` — hand-written Dart mirrors of the server protocol (see sync warning above). `GameEvent` is a **sealed class** — you can't subclass it outside that file; game_screen models sub-phases (e.g. Derba-then-Missa on one capture) with local state flags instead.
- `lib/net/game_client.dart` — `GameClient extends ChangeNotifier`, provided once at app root. Holds connection, `PublicState state`, private `hand`, and a broadcast `Stream<GameEvent> events` for one-shot events (captures, reveals, game over). Continuous state → `notifyListeners`; punctual events → the stream. `playCard` removes the card locally right away for responsiveness; server re-sends the full hand at each deal.
- `lib/screens/` — home (nickname + create/join) → lobby (team columns, tap-to-copy code) → game → victory. Lobby navigates to game when phase flips to `playing`; game navigates to victory when the `GameOverEvent` finishes its overlay queue.
- `lib/screens/game_screen.dart` — seats drawn relative to the local player (me bottom, teammate top, next clockwise player right). Server events are queued and played **one at a time as short blocking overlays** (input ignored while one is showing — GDD 3.4: 1-2s pauses for impact). Ordinary captures (no Derba/Missa) don't block.
- `lib/widgets/event_overlays.dart` — the Derba tier-1/2/3 escalation, Missa ripple, reveal and round-end panels, with all durations as top-level constants.
- `lib/widgets/playing_card.dart` + `lib/theme.dart` — cards, suit symbols, zellige background are all drawn procedurally with CustomPainter; **there are no image assets in the project**.

## Working with the ruleset

When a rule question comes up that GDD.md doesn't unambiguously answer, don't guess — the traditional/oral nature of this game variant means corner cases were explicitly interviewed and resolved with the user (see GDD.md "Historique des décisions"). Treat GDD.md as authoritative over intuition about similar card games (Scopa, Belote) — several rules here deliberately diverge (e.g. capture is never forced, even when possible).
