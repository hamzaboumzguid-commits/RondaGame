import { Card, DerbaTier, TeamId } from "../game/types.js";

/**
 * Protocole JSON échangé sur WebSocket entre le client Flutter et le serveur.
 * Le serveur est autoritaire : le client n'envoie que des intentions, le serveur
 * renvoie l'état public complet après chaque changement (l'état est minuscule,
 * pas besoin de sync différentielle pour un jeu tour-par-tour à 4 joueurs).
 */

// ---- Client -> Serveur ----

export type ClientMessage =
  | { type: "create"; nickname: string }
  | { type: "join"; roomCode: string; nickname: string }
  | { type: "joinTeam"; team: TeamId }
  | { type: "start" }
  // La capture n'est pas un choix : le serveur capture d'office si la valeur
  // jouée est présente sur la table (GDD 2.6, capture obligatoire sur jumelle).
  | { type: "playCard"; cardId: string };

// ---- Serveur -> Client ----

export interface PublicPlayer {
  id: string;
  nickname: string;
  seat: number;
  team: TeamId;
  handCount: number;
  // Pastille d'annonce : révèle le TYPE (ronda/tringa) mais jamais la valeur (GDD 2.5).
  announcementKind: "" | "ronda" | "tringa";
  isHost: boolean;
}

export interface PublicState {
  phase: "lobby" | "playing" | "reveal" | "roundEnd" | "gameOver";
  roomCode: string;
  players: PublicPlayer[];
  tablePile: Card[];
  leadPlayerId: string;
  currentTurnPlayerId: string;
  /** Échéance (epoch ms) du tour courant — timer de 10 s, 0 hors phase de jeu. */
  turnEndsAt: number;
  scores: Record<TeamId, number>;
  winningTeam: TeamId | "";
  roundNumber: number;
  dealIndex: number;
}

export interface RevealedAnnouncement {
  playerId: string;
  team: TeamId;
  kind: "ronda" | "tringa";
  rank: number;
}

export type ServerMessage =
  | { type: "joined"; roomCode: string; playerId: string; state: PublicState }
  | { type: "state"; state: PublicState }
  | { type: "yourHand"; cards: Card[] }
  | {
      type: "captureEvent";
      playerId: string;
      team: TeamId;
      playedCardId: string;
      capturedCardIds: string[];
      isDerba: boolean;
      derbaTier: DerbaTier;
      isMissa: boolean;
      points: number;
    }
  | { type: "cardPlaced"; playerId: string; card: Card }
  | {
      type: "subRoundReveal";
      announcements: RevealedAnnouncement[];
      points: Partial<Record<TeamId, number>>;
    }
  | {
      type: "roundEnd";
      butinPoints: Partial<Record<TeamId, number>>;
      bonusPoints: Partial<Record<TeamId, number>>;
      cardCounts: Record<TeamId, number>;
      lastCapture: { rank: number; team: TeamId } | null;
    }
  | { type: "gameOver"; winningTeam: TeamId }
  | { type: "gameAbandoned"; reason: string }
  | { type: "error"; code: string; message: string };

export function encode(msg: ServerMessage): string {
  return JSON.stringify(msg);
}

export function decode(raw: string): ClientMessage | null {
  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed?.type !== "string") return null;
    return parsed as ClientMessage;
  } catch {
    return null;
  }
}
