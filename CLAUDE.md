# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Mobile game (iOS + Android) implementing the "Ronda marocaine — variante café" card game rules, 4 players in 2 teams of 2, online-only multiplayer via room codes (no accounts, ephemeral sessions — join flow modeled on Among Us: nickname + room code).

**The full ruleset, all product decisions, and rationale live in [GDD.md](GDD.md) — read it before touching any game logic.** It is the single source of truth for scoring, turn order, and every edge case (Derba chains, Ronda/Tringa resolution, last-capture bonus, etc.). Update it when a rule interpretation changes.

This is a monorepo with two independent projects:
- `server/` — authoritative Colyseus (Node.js/TypeScript) backend. Owns all game logic and rule enforcement.
- `app/` — Flutter (Dart) cross-platform client. Renders server-authoritative state; never re-implements scoring rules.

## Commands

### Server (`server/`)
```
npm run dev          # tsx watch, runs src/index.ts with hot reload
npm run build         # tsc compile to dist/ (ESM output)
npm start             # run compiled dist/index.js
npm test               # vitest run — run the full game-logic test suite once
npm run test:watch    # vitest in watch mode
npx vitest run src/game/table.test.ts   # run a single test file
npx tsc --noEmit       # typecheck only, no output
```
No lint script is configured yet.

### App (`app/`)
Flutter SDK lives at `C:\dev\flutter` (cloned from the stable channel, not installed via a package manager — added to user PATH). If `flutter` is not found in a fresh shell, use `C:\dev\flutter\bin\flutter` directly or re-source PATH.
```
flutter pub get
flutter analyze        # static analysis — must be clean before considering a change done
flutter test            # widget/unit tests
flutter test test/some_test.dart   # run a single test file
flutter run              # launch on connected device/emulator
```

## Architecture

### Server: rule engine is separated from network plumbing

`server/src/game/` is **pure logic with no Colyseus dependency** — it must stay independently testable:
- `types.ts` — card/player/team/announcement domain types, `RANK_ORDER` (the game's value ordering, As < 2 < ... < Roi), point constants (`TARGET_SCORE`, `BUTIN_THRESHOLD`, `CARDS_TOTAL`).
- `deck.ts` — 40-card Spanish deck construction and Fisher-Yates shuffle.
- `table.ts` — the `Table` class: capture resolution (including the "capture a rank pulls the whole contiguous ascending sequence" rule — see GDD 2.6, this is stricter than it first looks, it will sweep unrelated contiguous cards too), Derba detection and chain-tier escalation (1→5→10, capped at 3 in a row since only 4 copies of each rank exist), Missa detection.
- `rondaTringa.ts` — end-of-sub-round resolution for announced Rondas/Tringas: single Ronda, 2/3-Ronda highest-wins-with-tie-cancels, 4-Ronda lowest-wins-with-cascading-tiebreak, Tringa-always-beats-Ronda with the +1 bonus. This function is the trickiest piece of the ruleset — re-read GDD 2.9 before modifying it.
- `round.ts` — butin (loot) counting, last-capture bonus/malus (Roi +5 / As -5-to-opponent), lead-seat rotation ("to the right" = seat N → (N+3)%4 given seats are numbered clockwise 0→1→2→3).

`server/src/rooms/RondaRoom.ts` is the only place that wires this logic to the network: it holds per-connection `Client` references, deals cards, broadcasts the public Colyseus schema state, and sends each player their own hand via a private message (`yourHand`) — hands are deliberately **not** part of the synced `RondaRoomState` so opponents' cards are never serialized to a client that shouldn't see them. Ronda/Tringa announcements are similarly exposed only as an anonymous badge (`AnnouncementBadgeSchema`, just a `playerId`) until the sub-round resolves — the server holds the real `Announcement[]` values privately and only broadcasts the reveal at sub-round end.

The server is authoritative by design (no accounts to ban cheaters, so the client cannot be trusted): all capture/Derba/scoring decisions happen in `RondaRoom`/`game/*`, the client only sends intents (`playCard`, `joinTeam`, `startGame`) and receives resulting state.

**Module system note**: the server is ESM (`"type": "module"` in package.json) because Colyseus 0.17 ships pure ESM. `tsconfig.json` uses `module`/`moduleResolution: node16`, which means **every relative import must include an explicit `.js` extension** even though the source files are `.ts` (e.g. `import { Table } from "./table.js"`) — this is required for the compiled output to resolve correctly under Node's ESM loader. Don't switch this to `bundler` resolution to avoid writing extensions; that would silently break `dist/` at runtime since `tsc` doesn't rewrite import paths.

No reconnection handling in v1 (deliberate scope cut, see GDD 3.1): any disconnect or leave mid-round aborts the whole game for all players (`onLeave` broadcasts `gameAbandoned` and disconnects everyone once `phase !== "lobby"`).

### Room lifecycle (`RondaRoom`)
`lobby → dealing/playing → reveal → roundEnd → (loop back to dealing, or → gameOver)`. Each round is 3 sub-rounds (4-3-3 card deals). `dealNext()` re-detects announcements and re-sends private hands after every deal. `endSubRound()` resolves Ronda/Tringa and either deals the next sub-round or calls `endRound()`, which sweeps remaining table cards to the last capturing team, computes butin + last-capture bonus, and either loops into a new round or ends the game at `TARGET_SCORE` (41).

Room codes are 5 characters from a disambiguated alphabet (no 0/O/1/I/L, see `rooms/roomCode.ts`), created via `POST /rooms` before the client opens the Colyseus websocket connection with that code.

### App: not yet implemented beyond `flutter create` scaffold

`app/lib/main.dart` is still the default Flutter counter template. No game screens, no Colyseus client wiring, no state management choice made yet. Per GDD.md section 4, UI/animation implementation (lobby, table, Derba/Missa animations, Moroccan-themed visual design) is planned to be built with Fable 5 rather than in a Sonnet session — check with the user before writing substantial `app/` UI code in a non-Fable session.

## Working with the ruleset

When a rule question comes up that GDD.md doesn't unambiguously answer, don't guess — the traditional/oral nature of this game variant means several corner cases were explicitly interviewed and resolved with the user (see GDD.md section "Historique des décisions"). Treat GDD.md as authoritative over intuition about how similar card games (Scopa, Belote) usually work — several rules here deliberately diverge (e.g. capture is never forced, even when possible).
