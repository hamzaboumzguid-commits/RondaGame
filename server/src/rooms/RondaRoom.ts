import { Room, Client } from "colyseus";
import { RondaRoomState, PlayerSchema, CardSchema, AnnouncementBadgeSchema, TeamScoreSchema } from "./schema.js";
import { createDeck, shuffle } from "../game/deck.js";
import { Table } from "../game/table.js";
import { resolveRondaTringa } from "../game/rondaTringa.js";
import { computeButin, computeLastCaptureBonus, firstPlayerSeat, mergePoints, nextLead } from "../game/round.js";
import {
  Announcement,
  Card,
  PlayerSeat,
  PlayerState,
  TARGET_SCORE,
  TeamId,
} from "../game/types.js";

const MAX_PLAYERS = 4;
const DEAL_SIZES = [4, 3, 3] as const;

interface InternalPlayer extends PlayerState {
  client: Client;
}

/**
 * Room Colyseus autoritaire pour une partie de Ronda marocaine.
 * Toute la logique de règles vit dans src/game/* (pure, testée) ; cette classe se contente
 * du câblage réseau : lobby, distribution, validation des coups, diffusion de l'état public,
 * et envoi de la main privée à chaque joueur.
 */
export class RondaRoom extends Room<{ state: RondaRoomState }> {
  maxClients = MAX_PLAYERS;

  private players = new Map<string, InternalPlayer>();
  private deck: Card[] = [];
  private table = new Table();
  private leadSeat: PlayerSeat = 0;
  private dealIndex: 0 | 1 | 2 = 0;
  private turnOrder: PlayerSeat[] = [];
  private turnIdx = 0;
  private announcementsThisSubRound: Announcement[] = [];
  private capturedByTeam: Record<TeamId, Card[]> = { A: [], B: [] };
  private lastCapture: { card: Card; team: TeamId } | null = null;

  onCreate(options: { roomCode: string }) {
    this.state = new RondaRoomState();
    this.state.roomCode = options.roomCode;
    this.state.teamScores.set("A", new TeamScoreSchema());
    this.state.teamScores.set("B", new TeamScoreSchema());

    this.onMessage("joinTeam", (client, message: { team: "A" | "B" }) => {
      this.handleJoinTeam(client, message.team);
    });

    this.onMessage("startGame", (client) => {
      this.handleStartGame(client);
    });

    this.onMessage("playCard", (client, message: { cardId: string; captureRank?: number }) => {
      this.handlePlayCard(client, message.cardId, message.captureRank);
    });
  }

  onJoin(client: Client, options: { nickname: string }) {
    if (this.players.size >= MAX_PLAYERS) {
      throw new Error("Room complète");
    }
    const seat = this.nextFreeSeat();
    const player: InternalPlayer = {
      id: client.sessionId,
      nickname: (options.nickname ?? "Joueur").slice(0, 20),
      seat,
      team: seat % 2 === 0 ? "A" : "B",
      hand: [],
      connected: true,
      client,
    };
    this.players.set(client.sessionId, player);

    const schema = new PlayerSchema();
    schema.id = player.id;
    schema.nickname = player.nickname;
    schema.seat = player.seat;
    schema.team = player.team;
    schema.connected = true;
    this.state.players.set(client.sessionId, schema);
  }

  onLeave(client: Client) {
    // GDD 3.1 : pas de reconnexion en v1, un départ en pleine manche annule la partie.
    if (this.state.phase !== "lobby") {
      this.broadcast("gameAbandoned", { reason: "playerLeft", playerId: client.sessionId });
      this.disconnect();
      return;
    }
    this.players.delete(client.sessionId);
    this.state.players.delete(client.sessionId);
  }

  private nextFreeSeat(): PlayerSeat {
    const taken = new Set([...this.players.values()].map((p) => p.seat));
    for (let s = 0; s < 4; s++) {
      if (!taken.has(s as PlayerSeat)) return s as PlayerSeat;
    }
    throw new Error("Aucun siège libre");
  }

  private handleJoinTeam(client: Client, team: "A" | "B") {
    if (this.state.phase !== "lobby") return;
    const player = this.players.get(client.sessionId);
    if (!player) return;

    const teamSeats: PlayerSeat[] = team === "A" ? [0, 2] : [1, 3];
    const occupied = [...this.players.values()].filter((p) => p.id !== player.id && teamSeats.includes(p.seat));
    if (occupied.length >= 2) return; // équipe déjà pleine

    const freeSeat = teamSeats.find(
      (s) => s === player.seat || !([...this.players.values()].some((p) => p.id !== player.id && p.seat === s)),
    );
    if (freeSeat === undefined) return;

    player.seat = freeSeat;
    player.team = team;
    const schema = this.state.players.get(client.sessionId)!;
    schema.seat = freeSeat;
    schema.team = team;
  }

  private handleStartGame(client: Client) {
    if (this.state.phase !== "lobby") return;
    if (this.players.size !== MAX_PLAYERS) return;

    this.leadSeat = 0;
    this.state.teamScores.get("A")!.score = 0;
    this.state.teamScores.get("B")!.score = 0;
    this.capturedByTeam = { A: [], B: [] };
    this.startRound();
  }

  private startRound() {
    this.deck = shuffle(createDeck());
    this.table.reset();
    this.capturedByTeam = { A: [], B: [] };
    this.dealIndex = 0;
    this.state.winningTeam = "";
    this.dealNext();
  }

  private dealNext() {
    const size = DEAL_SIZES[this.dealIndex];
    for (const player of this.playersBySeat()) {
      const cards = this.deck.splice(0, size);
      player.hand.push(...cards);
    }
    this.announcementsThisSubRound = this.detectAnnouncements();
    this.broadcastAnnouncementBadges();
    this.sendPrivateHands();

    this.turnOrder = this.rotationFrom(firstPlayerSeat(this.leadSeat));
    this.turnIdx = 0;
    this.state.phase = "playing";
    this.state.currentTurnPlayerId = this.playerAtSeat(this.turnOrder[0])!.id;
    this.state.leadPlayerId = this.playerAtSeat(this.leadSeat)!.id;
  }

  private detectAnnouncements(): Announcement[] {
    const anns: Announcement[] = [];
    for (const player of this.players.values()) {
      const counts = new Map<number, number>();
      for (const c of player.hand) counts.set(c.rank, (counts.get(c.rank) ?? 0) + 1);
      for (const [rank, count] of counts) {
        if (count === 2) anns.push({ playerId: player.id, team: player.team, kind: "ronda", rank: rank as Card["rank"] });
        if (count === 3) anns.push({ playerId: player.id, team: player.team, kind: "tringa", rank: rank as Card["rank"] });
      }
    }
    return anns;
  }

  private broadcastAnnouncementBadges() {
    this.state.announcements.clear();
    for (const ann of this.announcementsThisSubRound) {
      const badge = new AnnouncementBadgeSchema();
      badge.playerId = ann.playerId;
      this.state.announcements.push(badge);
    }
  }

  private sendPrivateHands() {
    for (const player of this.players.values()) {
      player.client.send("yourHand", {
        cards: player.hand.map((c) => ({ id: c.id, rank: c.rank, suit: c.suit })),
      });
    }
  }

  private handlePlayCard(client: Client, cardId: string, captureRank?: number) {
    const player = this.players.get(client.sessionId);
    if (!player) return;
    if (this.state.phase !== "playing") return;
    if (this.state.currentTurnPlayerId !== player.id) return;

    const cardIdx = player.hand.findIndex((c) => c.id === cardId);
    if (cardIdx === -1) return;
    const [card] = player.hand.splice(cardIdx, 1);

    const wantsCapture = captureRank !== undefined && captureRank === card.rank;
    const event = this.table.play(player, card, { capture: wantsCapture });

    this.syncTablePile();

    if (event) {
      this.capturedByTeam[event.byTeam].push(...event.cardsCaptured);
      this.lastCapture = { card: event.playedCard, team: event.byTeam };

      if (event.isDerba || event.isMissa) {
        this.broadcast("captureEvent", {
          playerId: event.byPlayerId,
          team: event.byTeam,
          isDerba: event.isDerba,
          derbaTier: event.derbaTier,
          isMissa: event.isMissa,
          cardsCaptured: event.cardsCaptured.map((c) => c.id),
        });
      }
    }

    this.advanceTurn();
  }

  private advanceTurn() {
    const allHandsEmpty = [...this.players.values()].every((p) => p.hand.length === 0);
    if (allHandsEmpty) {
      this.endSubRound();
      return;
    }
    this.turnIdx = (this.turnIdx + 1) % this.turnOrder.length;
    this.state.currentTurnPlayerId = this.playerAtSeat(this.turnOrder[this.turnIdx])!.id;
  }

  private endSubRound() {
    const rondaTringaPoints = resolveRondaTringa(this.announcementsThisSubRound);
    this.applyPoints(rondaTringaPoints);
    this.state.phase = "reveal";
    this.broadcast("subRoundReveal", {
      announcements: this.announcementsThisSubRound,
      points: rondaTringaPoints,
    });

    if (this.dealIndex < 2) {
      this.dealIndex = (this.dealIndex + 1) as 0 | 1 | 2;
      this.dealNext();
    } else {
      this.endRound();
    }
  }

  private endRound() {
    // Cartes restantes non capturées vont au dernier joueur ayant capturé (GDD 2.10).
    const remaining = this.table.sweepRemaining();
    if (remaining.length > 0 && this.lastCapture) {
      this.capturedByTeam[this.lastCapture.team].push(...remaining);
    }

    const butinPoints = computeButin(this.capturedByTeam);
    const bonusPoints = this.lastCapture
      ? computeLastCaptureBonus(this.lastCapture.card, this.lastCapture.team)
      : {};

    const merged = mergePoints(butinPoints, bonusPoints);
    this.applyPoints(merged);

    this.state.phase = "roundEnd";
    this.broadcast("roundEnd", { butinPoints, bonusPoints });

    const scoreA = this.state.teamScores.get("A")!.score;
    const scoreB = this.state.teamScores.get("B")!.score;

    if (scoreA >= TARGET_SCORE || scoreB >= TARGET_SCORE) {
      this.state.winningTeam = scoreA > scoreB ? "A" : "B";
      this.state.phase = "gameOver";
      return;
    }

    this.leadSeat = nextLead(this.leadSeat);
    this.startRound();
  }

  private applyPoints(points: Partial<Record<TeamId, number>>) {
    if (points.A) this.state.teamScores.get("A")!.score += points.A;
    if (points.B) this.state.teamScores.get("B")!.score += points.B;
  }

  private syncTablePile() {
    this.state.tablePile.clear();
    for (const c of this.table.pile) {
      const cs = new CardSchema();
      cs.id = c.id;
      cs.rank = c.rank;
      cs.suit = c.suit;
      this.state.tablePile.push(cs);
    }
  }

  private playersBySeat(): InternalPlayer[] {
    return [...this.players.values()].sort((a, b) => a.seat - b.seat);
  }

  private playerAtSeat(seat: PlayerSeat): InternalPlayer | undefined {
    return [...this.players.values()].find((p) => p.seat === seat);
  }

  private rotationFrom(startSeat: PlayerSeat): PlayerSeat[] {
    const order: PlayerSeat[] = [];
    for (let i = 0; i < 4; i++) {
      order.push(((startSeat + i) % 4) as PlayerSeat);
    }
    return order;
  }
}
