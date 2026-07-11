import { Card, PlayerState, TeamId, BUTIN_THRESHOLD, CARDS_TOTAL } from "./types.js";

/**
 * Comptage du butin en fin de manche complète, une fois les 40 cartes jouées (GDD 2.10).
 */
export function computeButin(capturedByTeam: Record<TeamId, Card[]>): Partial<Record<TeamId, number>> {
  const points: Partial<Record<TeamId, number>> = {};
  const countA = capturedByTeam.A.length;
  const countB = capturedByTeam.B.length;

  if (countA + countB !== CARDS_TOTAL) {
    throw new Error(`Butin invalide: total capturé ${countA + countB} !== ${CARDS_TOTAL}`);
  }

  if (countA > BUTIN_THRESHOLD) points.A = countA - BUTIN_THRESHOLD;
  if (countB > BUTIN_THRESHOLD) points.B = countB - BUTIN_THRESHOLD;
  return points;
}

/**
 * Bonus/malus de la toute dernière capture de la manche (GDD 2.11).
 * Roi (12) -> +5 à l'équipe qui capture. As (1) -> +5 à l'équipe adverse.
 */
export function computeLastCaptureBonus(
  lastCaptureCard: Card,
  lastCaptureTeam: TeamId,
): Partial<Record<TeamId, number>> {
  const points: Partial<Record<TeamId, number>> = {};
  const otherTeam: TeamId = lastCaptureTeam === "A" ? "B" : "A";

  if (lastCaptureCard.rank === 12) {
    points[lastCaptureTeam] = (points[lastCaptureTeam] ?? 0) + 5;
  } else if (lastCaptureCard.rank === 1) {
    points[otherTeam] = (points[otherTeam] ?? 0) + 5;
  }
  return points;
}

export function mergePoints(
  ...sources: Partial<Record<TeamId, number>>[]
): Record<TeamId, number> {
  const result: Record<TeamId, number> = { A: 0, B: 0 };
  for (const src of sources) {
    if (src.A) result.A += src.A;
    if (src.B) result.B += src.B;
  }
  return result;
}

export function nextLead(currentLeadSeat: PlayerState["seat"]): PlayerState["seat"] {
  // Le Lead passe au joueur à sa droite (GDD 2.2). Sièges 0->3->2->1->0 en "droite" si le jeu
  // tourne en sens horaire 0->1->2->3 (cf. GDD 2.4 : le jeu se déroule sens horaire à partir
  // du joueur à droite du Lead). La droite du siège N est donc (N + 3) % 4 = (N - 1) % 4.
  return (((currentLeadSeat + 3) % 4) as PlayerState["seat"]);
}

export function firstPlayerSeat(leadSeat: PlayerState["seat"]): PlayerState["seat"] {
  // Le jeu commence par le joueur à la droite du Lead (GDD 2.4), donc le siège opposé à nextLead.
  return (((leadSeat + 1) % 4) as PlayerState["seat"]);
}
