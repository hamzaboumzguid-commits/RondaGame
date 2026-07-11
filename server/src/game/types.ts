/**
 * Modèle de données pur du jeu de Ronda marocaine.
 * Aucune dépendance à Colyseus ici : ce module doit rester testable en isolation.
 * Cf. GDD.md section 2 pour le règlement complet.
 */

export type Rank = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 10 | 11 | 12;
export type Suit = "oros" | "copas" | "espadas" | "bastos";

// Ordre naturel des valeurs, du plus faible au plus fort (GDD 2.1).
export const RANK_ORDER: Rank[] = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];

export function rankIndex(rank: Rank): number {
  return RANK_ORDER.indexOf(rank);
}

export interface Card {
  id: string; // identifiant stable unique, ex: "oros_7"
  rank: Rank;
  suit: Suit;
}

export type TeamId = "A" | "B";

export type PlayerSeat = 0 | 1 | 2 | 3; // sens horaire ; sièges 0/2 = équipe A, 1/3 = équipe B

export interface PlayerState {
  id: string; // session id (éphémère, pas de compte)
  nickname: string;
  seat: PlayerSeat;
  team: TeamId;
  hand: Card[];
}

export type DerbaTier = 0 | 1 | 2 | 3; // 0 = aucune, 1 = 1pt, 2 = 5pts (surenchère), 3 = 10pts (max)

export const DERBA_POINTS: Record<DerbaTier, number> = {
  0: 0,
  1: 1,
  2: 5,
  3: 10,
};

export interface CaptureEvent {
  byPlayerId: string;
  byTeam: TeamId;
  cardsCaptured: Card[]; // suite complète capturée, y compris la carte jouée si elle reste sur table
  playedCard: Card;
  isDerba: boolean;
  derbaTier: DerbaTier;
  isMissa: boolean; // table vidée par cette capture
}

export type AnnouncementKind = "ronda" | "tringa";

export interface Announcement {
  playerId: string;
  team: TeamId;
  kind: AnnouncementKind;
  rank: Rank; // valeur réelle, connue seulement du serveur tant que la petite manche n'est pas résolue
}

export interface SubRoundResult {
  rondaTringaPoints: Partial<Record<TeamId, number>>;
  revealedAnnouncements: Announcement[];
}

export interface DealResult {
  cardsPerPlayer: number; // 4 ou 3
  dealIndex: 0 | 1 | 2;
}

export interface RoundScoreBreakdown {
  team: TeamId;
  rondaTringa: number;
  derba: number;
  missa: number;
  butin: number;
  lastCaptureBonus: number; // +5 (roi) ou -0 (n'inclut pas le malus, il va à l'adverse)
  total: number;
}

export const TARGET_SCORE = 41;
export const CARDS_TOTAL = 40;
export const BUTIN_THRESHOLD = 20;
