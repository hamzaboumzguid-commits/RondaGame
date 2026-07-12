import { Card, DerbaTier, TeamId } from "../game/types.js";

/**
 * Protocole JSON échangé sur WebSocket entre le client Flutter et le serveur.
 * Le serveur est autoritaire : le client n'envoie que des intentions, le serveur
 * renvoie l'état public complet après chaque changement (l'état est minuscule,
 * pas besoin de sync différentielle pour un jeu tour-par-tour à 4 joueurs).
 */

// ---- Client -> Serveur ----

export type ClientMessage =
  | { type: "create"; nickname: string; mode?: "2v2" | "1v1"; isPublic?: boolean }
  | { type: "join"; roomCode: string; nickname: string }
  | { type: "joinTeam"; team: TeamId }
  | { type: "start" }
  // La capture n'est pas un choix : le serveur capture d'office si la valeur
  // jouée est présente sur la table (GDD 2.6, capture obligatoire sur jumelle).
  | { type: "playCard"; cardId: string }
  // Salons publics : liste des parties en lobby, non pleines, ouvertes à
  // tous — alternative au code privé tant que la base de joueurs est petite.
  | { type: "listPublicRooms" };

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
  mode: "2v2" | "1v1";
  /** 3 tfri9at (4-3-3) en 2v2, 5 tfri9at de 4 en 1v1. */
  dealsPerRound: number;
  players: PublicPlayer[];
  tablePile: Card[];
  /** Paquet de Derba en attente de surenchère, encore affiché sur la table. */
  pendingDerba: Card[];
  /**
   * Rang qui surenchérit la Derba en attente (0 si aucune) : SEULE cette valeur
   * capture le paquet ; un rang qui figure DANS le paquet ne capture pas (GDD 2.7).
   */
  pendingDerbaRank: number;
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

/** Résumé d'un salon public affiché dans la liste de l'accueil. */
export interface PublicRoomSummary {
  roomCode: string;
  mode: "2v2" | "1v1";
  playerCount: number;
  maxPlayers: number;
  hostNickname: string;
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
      /** Le Lead n'a pas fait la dernière prise -> animation MAJEBTICH 9A3TEK. */
      leadMissedLastCapture: boolean;
    }
  | { type: "gameOver"; winningTeam: TeamId }
  | { type: "gameAbandoned"; reason: string }
  | { type: "error"; code: string; message: string }
  | { type: "publicRooms"; rooms: PublicRoomSummary[] };

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
