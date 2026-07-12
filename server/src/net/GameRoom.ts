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
import { PublicRoomSummary, PublicState, ServerMessage, RevealedAnnouncement } from "./protocol.js";

/** Temps de réflexion par tour : passé ce délai, la carte la plus à gauche est jouée d'office. */
export const TURN_TIMEOUT_MS = 10_000;

export type GameMode = "2v2" | "1v1";

/** Donnes par manche : 4-3-3 à 4 joueurs, 5×4 en 1v1 (GDD 2.3 / 3.6). */
const DEAL_SIZES_BY_MODE: Record<GameMode, readonly number[]> = {
  "2v2": [4, 3, 3],
  "1v1": [4, 4, 4, 4, 4],
};

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
  readonly mode: GameMode;
  /** Visible dans la liste des salons publics de l'accueil tant que le lobby n'est pas plein/lancé. */
  readonly isPublic: boolean;
  phase: RoomPhase = "lobby";

  private players: RoomPlayer[] = [];
  private hostId: string | null = null;
  private deck: Card[] = [];
  private table = new Table();
  private leadSeat: PlayerSeat = 0;
  private roundNumber = 0;
  private dealIndex = 0;
  private turnOrder: PlayerSeat[] = [];
  private turnIdx = 0;
  private announcements: Announcement[] = [];
  private capturedByTeam: Record<TeamId, Card[]> = { A: [], B: [] };
  private lastCapture: { card: Card; team: TeamId; playerId: string } | null = null;
  /**
   * La TOUTE dernière carte jouée de la manche et si elle a capturé (GDD 2.11) :
   * le bonus Roi/As ne concerne QUE ce dernier coup, et seulement s'il capture.
   * Une simple pose en dernier coup ne déclenche aucun bonus.
   */
  private finalPlay: { card: Card; team: TeamId; playerId: string; captured: boolean } | null = null;
  private scores: Record<TeamId, number> = { A: 0, B: 0 };
  private winningTeam: TeamId | "" = "";
  private turnTimer: ReturnType<typeof setTimeout> | null = null;
  private turnEndsAt = 0;

  /** Appelé quand la room doit être détruite (partie finie ou abandonnée). */
  onDispose: () => void = () => {};

  constructor(roomCode: string, mode: GameMode = "2v2", isPublic: boolean = false) {
    this.roomCode = roomCode;
    this.mode = mode;
    this.isPublic = isPublic;
  }

  private get maxPlayers(): number {
    return this.mode === "1v1" ? 2 : 4;
  }

  private get dealSizes(): readonly number[] {
    return DEAL_SIZES_BY_MODE[this.mode];
  }

  // ---------- Lobby ----------

  join(id: string, nickname: string, conn: PlayerConnection): { ok: true } | { ok: false; error: string } {
    if (this.phase !== "lobby") return { ok: false, error: "La partie a déjà commencé" };
    if (this.players.length >= this.maxPlayers) return { ok: false, error: "Room complète" };

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
      this.clearTurnTimer();
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

    const teamSeats: PlayerSeat[] =
      this.mode === "1v1" ? (team === "A" ? [0] : [1]) : team === "A" ? [0, 2] : [1, 3];
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
    if (this.players.length !== this.maxPlayers) {
      this.sendTo(id, {
        type: "error",
        code: "notFull",
        message: `Il faut ${this.maxPlayers} joueurs pour commencer`,
      });
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
    this.finalPlay = null;
    this.dealIndex = 0;
    this.dealNext();
  }

  private dealNext(): void {
    const size = this.dealSizes[this.dealIndex];
    for (const player of this.playersBySeat()) {
      player.hand = this.deck.splice(0, size);
    }
    this.announcements = this.detectAnnouncements();

    this.turnOrder = this.rotationFrom(firstPlayerSeat(this.leadSeat, this.maxPlayers));
    this.turnIdx = 0;
    this.phase = "playing";
    this.armTurnTimer();

    this.broadcastState();
    for (const player of this.players) {
      player.conn.send({ type: "yourHand", cards: [...player.hand] });
    }
  }

  // ---------- Timer de tour (10 s, GDD 3.5) ----------

  private armTurnTimer(): void {
    this.clearTurnTimer();
    if (this.phase !== "playing") return;
    this.turnEndsAt = Date.now() + TURN_TIMEOUT_MS;
    this.turnTimer = setTimeout(() => this.autoPlayCurrentTurn(), TURN_TIMEOUT_MS);
  }

  private clearTurnTimer(): void {
    if (this.turnTimer) {
      clearTimeout(this.turnTimer);
      this.turnTimer = null;
    }
    this.turnEndsAt = 0;
  }

  /** Temps écoulé : la carte la plus à gauche du joueur courant est jouée d'office. */
  private autoPlayCurrentTurn(): void {
    if (this.phase !== "playing") return;
    const player = this.currentPlayer();
    if (!player || player.hand.length === 0) return;
    this.playCard(player.id, player.hand[0].id);
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

  playCard(id: string, cardId: string): void {
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

    const event = this.table.play(player, card);

    if (event) {
      // Surenchère de Derba : le paquet de la chaîne est repris à l'équipe adverse
      // (les cartes reprises sont déjà incluses dans cardsCaptured).
      if (event.reclaimedCards.length > 0) {
        const reclaimedIds = new Set(event.reclaimedCards.map((c) => c.id));
        const opposing = this.capturedByTeam[this.otherTeam(event.byTeam)];
        this.capturedByTeam[this.otherTeam(event.byTeam)] = opposing.filter((c) => !reclaimedIds.has(c.id));
      }
      this.capturedByTeam[event.byTeam].push(...event.cardsCaptured);
      this.lastCapture = { card: event.playedCard, team: event.byTeam, playerId: event.byPlayerId };
      this.finalPlay = { card: event.playedCard, team: event.byTeam, playerId: event.byPlayerId, captured: true };

      const points = DERBA_POINTS[event.derbaTier] + (event.isMissa ? 1 : 0);
      // Une nouvelle Derba en chaîne annule les points de la précédente (GDD 2.7) :
      // palier précédent + Missa éventuelle (elle voyage avec le paquet).
      if (event.isDerba && event.derbaTier > 1) {
        const prevTier = (event.derbaTier - 1) as 1 | 2;
        this.scores[this.otherTeam(event.byTeam)] -=
          DERBA_POINTS[prevTier] + (event.isMissa ? 1 : 0);
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
      // Simple pose : c'est le dernier coup potentiel, mais SANS capture ->
      // aucun bonus Roi/As si c'est le tout dernier coup de la manche (GDD 2.11).
      this.finalPlay = { card, team: player.team, playerId: id, captured: false };
      this.broadcast({ type: "cardPlaced", playerId: id, card });
    }

    // Resynchronise la main du joueur (indispensable pour l'auto-jeu du timer :
    // sans ça, la carte jouée d'office resterait affichée dans sa main).
    player.conn.send({ type: "yourHand", cards: [...player.hand] });

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
    this.armTurnTimer();
    this.broadcastState();
  }

  private endSubRound(): void {
    this.clearTurnTimer();
    const points = resolveRondaTringa(this.announcements, this.mode);
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

    if (this.dealIndex < this.dealSizes.length - 1) {
      this.dealIndex++;
      this.dealNext();
    } else {
      this.endRound();
    }
  }

  private endRound(): void {
    // GDD 2.10 vs 2.11 — deux notions de « dernier » distinctes, à ne PAS fusionner :
    //  • `lastCapture` = dernière capture RÉELLEMENT effectuée (peut être antérieure
    //    au tout dernier coup) -> à qui vont les cartes restantes sur la table.
    //  • `finalPlay`   = tout dernier coup joué de la manche -> bonus Roi/As, et
    //    seulement s'il capture. Les deux ne coïncident que si ce dernier coup capture.
    const remaining = this.table.sweepRemaining();
    if (remaining.length > 0 && this.lastCapture) {
      this.capturedByTeam[this.lastCapture.team].push(...remaining);
    }

    const butinPoints = computeButin(this.capturedByTeam);
    // Le bonus Roi/As ne concerne QUE le tout dernier coup, et seulement s'il
    // a capturé (GDD 2.11) — une pose finale ne donne aucun bonus.
    const bonusPoints =
      this.finalPlay && this.finalPlay.captured
        ? computeLastCaptureBonus(this.finalPlay.card, this.finalPlay.team)
        : {};

    // GDD 2.11 : le Lead est censé conclure. « S'il n'a pas réalisé la dernière
    // capture (dernier coup non capturant, OU capturé par un autre) » -> MAJEBTICH.
    // Un dernier coup non capturant du Lead lui-même compte donc bien comme raté.
    const leadId = this.players.find((p) => p.seat === this.leadSeat)?.id ?? "";
    const leadMissedLastCapture =
      this.finalPlay !== null &&
      !(this.finalPlay.captured && this.finalPlay.playerId === leadId);

    this.broadcast({
      type: "roundEnd",
      butinPoints,
      bonusPoints,
      cardCounts: { A: this.capturedByTeam.A.length, B: this.capturedByTeam.B.length },
      // Animations Roi (+5) / As (5 à l'adverse) : seulement si le dernier coup capture.
      lastCapture:
        this.finalPlay && this.finalPlay.captured
          ? { rank: this.finalPlay.card.rank, team: this.finalPlay.team }
          : null,
      leadMissedLastCapture,
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

    this.leadSeat = nextLead(this.leadSeat, this.maxPlayers);
    this.startRound();
  }

  private addPoints(team: TeamId, points: number): void {
    this.scores[team] += points;
  }

  private checkImmediateWin(): boolean {
    for (const team of ["A", "B"] as TeamId[]) {
      if (this.scores[team] >= TARGET_SCORE) {
        this.winningTeam = team;
        this.clearTurnTimer();
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
    for (let s = 0; s < this.maxPlayers; s++) {
      if (!this.players.some((p) => p.seat === s)) return s as PlayerSeat;
    }
    throw new Error("Room pleine");
  }

  private playersBySeat(): RoomPlayer[] {
    return [...this.players].sort((a, b) => a.seat - b.seat);
  }

  private rotationFrom(startSeat: PlayerSeat): PlayerSeat[] {
    const n = this.maxPlayers;
    return Array.from({ length: n }, (_, i) => ((startSeat + i) % n) as PlayerSeat);
  }

  publicState(): PublicState {
    // La pastille révèle le TYPE d'annonce (Ronda vs Tringa) mais jamais la
    // valeur (décision utilisateur 2026-07-12, GDD 2.5). Tringa prime.
    const kindByPlayer = new Map<string, "ronda" | "tringa">();
    for (const a of this.announcements) {
      if (a.kind === "tringa" || !kindByPlayer.has(a.playerId)) {
        kindByPlayer.set(a.playerId, a.kind);
      }
    }
    return {
      phase: this.phase,
      roomCode: this.roomCode,
      mode: this.mode,
      dealsPerRound: this.dealSizes.length,
      players: this.playersBySeat().map((p) => ({
        id: p.id,
        nickname: p.nickname,
        seat: p.seat,
        team: p.team,
        handCount: p.hand.length,
        announcementKind: this.phase === "playing" ? kindByPlayer.get(p.id) ?? "" : "",
        isHost: p.id === this.hostId,
      })),
      tablePile: [...this.table.pile],
      // Paquet de Derba en attente de surenchère, affiché sur la table (GDD 2.7).
      pendingDerba: this.phase === "playing" ? this.table.pendingChainCards : [],
      pendingDerbaRank:
        this.phase === "playing" ? this.table.pendingChainRank ?? 0 : 0,
      leadPlayerId: this.players.find((p) => p.seat === this.leadSeat)?.id ?? "",
      currentTurnPlayerId: this.phase === "playing" ? this.currentPlayer()?.id ?? "" : "",
      turnEndsAt: this.phase === "playing" ? this.turnEndsAt : 0,
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

  /** Résumé affiché dans la liste des salons publics — uniquement pertinent tant qu'on est en lobby. */
  summary(): PublicRoomSummary {
    return {
      roomCode: this.roomCode,
      mode: this.mode,
      playerCount: this.players.length,
      maxPlayers: this.maxPlayers,
      hostNickname: this.players.find((p) => p.id === this.hostId)?.nickname ?? "",
    };
  }
}
