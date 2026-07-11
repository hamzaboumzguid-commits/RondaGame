import { createDeck, shuffle } from "../game/deck.js";
import { Table } from "../game/table.js";
import { resolveRondaTringa } from "../game/rondaTringa.js";
import { computeButin, computeLastCaptureBonus, firstPlayerSeat, nextLead } from "../game/round.js";
import {
  Announcement,
  Card,
  DERBA_POINTS,
  PlayerSeat,
  TARGET_SCORE,
  TeamId,
} from "../game/types.js";
import { PublicState, ServerMessage, RevealedAnnouncement } from "./protocol.js";

const MAX_PLAYERS = 4;
const DEAL_SIZES = [4, 3, 3] as const;

/** Abstraction de la connexion sortante — une vraie socket ws en prod, un stub en test. */
export interface PlayerConnection {
  send(msg: ServerMessage): void;
}

interface RoomPlayer {
  id: string;
  nickname: string;
  seat: PlayerSeat;
  team: TeamId;
  hand: Card[];
  conn: PlayerConnection;
}

export type RoomPhase = "lobby" | "playing" | "reveal" | "roundEnd" | "gameOver";

/**
 * Une partie de Ronda : lobby -> 3 sous-manches par manche -> manche suivante,
 * jusqu'à 41 points. Fin de partie IMMÉDIATE dès qu'une équipe atteint 41,
 * même en plein milieu d'une manche (GDD 2.1) — vérifiée après chaque attribution.
 */
export class GameRoom {
  readonly roomCode: string;
  phase: RoomPhase = "lobby";

  private players: RoomPlayer[] = [];
  private hostId: string | null = null;
  private deck: Card[] = [];
  private table = new Table();
  private leadSeat: PlayerSeat = 0;
  private roundNumber = 0;
  private dealIndex: 0 | 1 | 2 = 0;
  private turnOrder: PlayerSeat[] = [];
  private turnIdx = 0;
  private announcements: Announcement[] = [];
  private capturedByTeam: Record<TeamId, Card[]> = { A: [], B: [] };
  private lastCapture: { card: Card; team: TeamId } | null = null;
  private scores: Record<TeamId, number> = { A: 0, B: 0 };
  private winningTeam: TeamId | "" = "";

  /** Appelé quand la room doit être détruite (partie finie ou abandonnée). */
  onDispose: () => void = () => {};

  constructor(roomCode: string) {
    this.roomCode = roomCode;
  }

  // ---------- Lobby ----------

  join(id: string, nickname: string, conn: PlayerConnection): { ok: true } | { ok: false; error: string } {
    if (this.phase !== "lobby") return { ok: false, error: "La partie a déjà commencé" };
    if (this.players.length >= MAX_PLAYERS) return { ok: false, error: "Room complète" };

    const seat = this.nextFreeSeat();
    const player: RoomPlayer = {
      id,
      nickname: nickname.trim().slice(0, 20) || "Joueur",
      seat,
      team: seat % 2 === 0 ? "A" : "B",
      hand: [],
      conn,
    };
    this.players.push(player);
    if (!this.hostId) this.hostId = id;

    this.broadcastState();
    return { ok: true };
  }

  leave(id: string): void {
    const idx = this.players.findIndex((p) => p.id === id);
    if (idx === -1) return;

    if (this.phase !== "lobby" && this.phase !== "gameOver") {
      // GDD 3.1 : pas de reconnexion en v1 — un départ en cours de partie annule tout.
      const leaver = this.players[idx];
      this.broadcast({ type: "gameAbandoned", reason: `${leaver.nickname} a quitté la partie` });
      this.phase = "gameOver";
      this.onDispose();
      return;
    }

    this.players.splice(idx, 1);
    if (this.hostId === id) this.hostId = this.players[0]?.id ?? null;
    if (this.players.length === 0) {
      this.onDispose();
      return;
    }
    this.broadcastState();
  }

  joinTeam(id: string, team: TeamId): void {
    if (this.phase !== "lobby") return;
    const player = this.players.find((p) => p.id === id);
    if (!player) return;
    if (player.team === team) return;

    const teamSeats: PlayerSeat[] = team === "A" ? [0, 2] : [1, 3];
    const freeSeat = teamSeats.find((s) => !this.players.some((p) => p.id !== id && p.seat === s));
    if (freeSeat === undefined) {
      this.sendTo(id, { type: "error", code: "teamFull", message: "Cette équipe est complète" });
      return;
    }

    player.seat = freeSeat;
    player.team = team;
    this.broadcastState();
  }

  start(id: string): void {
    if (this.phase !== "lobby") return;
    if (id !== this.hostId) {
      this.sendTo(id, { type: "error", code: "notHost", message: "Seul l'hôte peut lancer la partie" });
      return;
    }
    if (this.players.length !== MAX_PLAYERS) {
      this.sendTo(id, { type: "error", code: "notFull", message: "Il faut 4 joueurs pour commencer" });
      return;
    }

    this.scores = { A: 0, B: 0 };
    this.leadSeat = 0;
    this.roundNumber = 0;
    this.startRound();
  }

  // ---------- Déroulement d'une manche ----------

  private startRound(): void {
    this.roundNumber++;
    this.deck = shuffle(createDeck());
    this.table.reset();
    this.capturedByTeam = { A: [], B: [] };
    this.lastCapture = null;
    this.dealIndex = 0;
    this.dealNext();
  }

  private dealNext(): void {
    const size = DEAL_SIZES[this.dealIndex];
    for (const player of this.playersBySeat()) {
      player.hand = this.deck.splice(0, size);
    }
    this.announcements = this.detectAnnouncements();

    this.turnOrder = this.rotationFrom(firstPlayerSeat(this.leadSeat));
    this.turnIdx = 0;
    this.phase = "playing";

    this.broadcastState();
    for (const player of this.players) {
      player.conn.send({ type: "yourHand", cards: [...player.hand] });
    }
  }

  private detectAnnouncements(): Announcement[] {
    const anns: Announcement[] = [];
    for (const player of this.players) {
      const counts = new Map<Card["rank"], number>();
      for (const c of player.hand) counts.set(c.rank, (counts.get(c.rank) ?? 0) + 1);
      for (const [rank, count] of counts) {
        if (count === 2) anns.push({ playerId: player.id, team: player.team, kind: "ronda", rank });
        if (count >= 3) anns.push({ playerId: player.id, team: player.team, kind: "tringa", rank });
      }
    }
    return anns;
  }

  playCard(id: string, cardId: string, capture: boolean): void {
    if (this.phase !== "playing") return;
    const player = this.players.find((p) => p.id === id);
    if (!player) return;
    if (this.currentPlayer()?.id !== id) {
      this.sendTo(id, { type: "error", code: "notYourTurn", message: "Ce n'est pas ton tour" });
      return;
    }

    const cardIdx = player.hand.findIndex((c) => c.id === cardId);
    if (cardIdx === -1) {
      this.sendTo(id, { type: "error", code: "cardNotInHand", message: "Cette carte n'est pas dans ta main" });
      return;
    }
    const [card] = player.hand.splice(cardIdx, 1);

    const event = this.table.play(player, card, { capture });

    if (event) {
      this.capturedByTeam[event.byTeam].push(...event.cardsCaptured);
      this.lastCapture = { card: event.playedCard, team: event.byTeam };

      const points = DERBA_POINTS[event.derbaTier] + (event.isMissa ? 1 : 0);
      // Une nouvelle Derba en chaîne annule les points de la précédente (GDD 2.7) :
      // on retire les points du palier précédent avant d'ajouter le nouveau.
      if (event.isDerba && event.derbaTier > 1) {
        const prevTier = (event.derbaTier - 1) as 1 | 2;
        this.scores[this.otherTeam(event.byTeam)] -= DERBA_POINTS[prevTier];
      }
      if (points > 0) {
        this.addPoints(event.byTeam, points);
      }

      this.broadcast({
        type: "captureEvent",
        playerId: event.byPlayerId,
        team: event.byTeam,
        playedCardId: event.playedCard.id,
        capturedCardIds: event.cardsCaptured.map((c) => c.id),
        isDerba: event.isDerba,
        derbaTier: event.derbaTier,
        isMissa: event.isMissa,
        points,
      });

      if (this.checkImmediateWin()) return;
    } else {
      this.broadcast({ type: "cardPlaced", playerId: id, card });
    }

    this.advanceTurn();
  }

  private advanceTurn(): void {
    const allEmpty = this.players.every((p) => p.hand.length === 0);
    if (allEmpty) {
      this.endSubRound();
      return;
    }
    // Passe au prochain joueur qui a encore des cartes (tous en ont autant, mais soyons robustes).
    do {
      this.turnIdx = (this.turnIdx + 1) % this.turnOrder.length;
    } while (this.currentPlayer()!.hand.length === 0);
    this.broadcastState();
  }

  private endSubRound(): void {
    const points = resolveRondaTringa(this.announcements);
    for (const team of ["A", "B"] as TeamId[]) {
      if (points[team]) this.addPoints(team, points[team]!);
    }

    this.phase = "reveal";
    const revealed: RevealedAnnouncement[] = this.announcements.map((a) => ({
      playerId: a.playerId,
      team: a.team,
      kind: a.kind,
      rank: a.rank,
    }));
    this.broadcast({ type: "subRoundReveal", announcements: revealed, points });
    this.broadcastState();

    if (this.checkImmediateWin()) return;

    if (this.dealIndex < 2) {
      this.dealIndex = (this.dealIndex + 1) as 1 | 2;
      this.dealNext();
    } else {
      this.endRound();
    }
  }

  private endRound(): void {
    // Les cartes restantes vont à l'équipe du dernier joueur ayant capturé (GDD 2.10).
    const remaining = this.table.sweepRemaining();
    if (remaining.length > 0 && this.lastCapture) {
      this.capturedByTeam[this.lastCapture.team].push(...remaining);
    }

    const butinPoints = computeButin(this.capturedByTeam);
    const bonusPoints = this.lastCapture
      ? computeLastCaptureBonus(this.lastCapture.card, this.lastCapture.team)
      : {};

    this.broadcast({
      type: "roundEnd",
      butinPoints,
      bonusPoints,
      cardCounts: { A: this.capturedByTeam.A.length, B: this.capturedByTeam.B.length },
    });

    // Butin appliqué avant le bonus de dernière capture ; le premier à franchir 41 gagne.
    for (const source of [butinPoints, bonusPoints]) {
      for (const team of ["A", "B"] as TeamId[]) {
        if (source[team]) {
          this.addPoints(team, source[team]!);
          if (this.checkImmediateWin()) return;
        }
      }
    }

    this.phase = "roundEnd";
    this.broadcastState();

    this.leadSeat = nextLead(this.leadSeat);
    this.startRound();
  }

  private addPoints(team: TeamId, points: number): void {
    this.scores[team] += points;
  }

  private checkImmediateWin(): boolean {
    for (const team of ["A", "B"] as TeamId[]) {
      if (this.scores[team] >= TARGET_SCORE) {
        this.winningTeam = team;
        this.phase = "gameOver";
        this.broadcast({ type: "gameOver", winningTeam: team });
        this.broadcastState();
        return true;
      }
    }
    return false;
  }

  // ---------- Helpers ----------

  private otherTeam(team: TeamId): TeamId {
    return team === "A" ? "B" : "A";
  }

  private currentPlayer(): RoomPlayer | undefined {
    return this.players.find((p) => p.seat === this.turnOrder[this.turnIdx]);
  }

  private nextFreeSeat(): PlayerSeat {
    for (let s = 0; s < 4; s++) {
      if (!this.players.some((p) => p.seat === s)) return s as PlayerSeat;
    }
    throw new Error("Room pleine");
  }

  private playersBySeat(): RoomPlayer[] {
    return [...this.players].sort((a, b) => a.seat - b.seat);
  }

  private rotationFrom(startSeat: PlayerSeat): PlayerSeat[] {
    return [0, 1, 2, 3].map((i) => ((startSeat + i) % 4) as PlayerSeat);
  }

  publicState(): PublicState {
    const announcedIds = new Set(this.announcements.map((a) => a.playerId));
    return {
      phase: this.phase,
      roomCode: this.roomCode,
      players: this.playersBySeat().map((p) => ({
        id: p.id,
        nickname: p.nickname,
        seat: p.seat,
        team: p.team,
        handCount: p.hand.length,
        hasAnnouncement: this.phase === "playing" && announcedIds.has(p.id),
        isHost: p.id === this.hostId,
      })),
      tablePile: [...this.table.pile],
      leadPlayerId: this.players.find((p) => p.seat === this.leadSeat)?.id ?? "",
      currentTurnPlayerId: this.phase === "playing" ? this.currentPlayer()?.id ?? "" : "",
      scores: { ...this.scores },
      winningTeam: this.winningTeam,
      roundNumber: this.roundNumber,
      dealIndex: this.dealIndex,
    };
  }

  private broadcastState(): void {
    this.broadcast({ type: "state", state: this.publicState() });
  }

  private broadcast(msg: ServerMessage): void {
    for (const player of this.players) {
      player.conn.send(msg);
    }
  }

  private sendTo(id: string, msg: ServerMessage): void {
    this.players.find((p) => p.id === id)?.conn.send(msg);
  }

  get playerCount(): number {
    return this.players.length;
  }
}
