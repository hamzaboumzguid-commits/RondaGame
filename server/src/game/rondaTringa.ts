import { Announcement, Rank, RANK_ORDER, TeamId, rankIndex } from "./types.js";

/**
 * Résolution des Rondas/Tringas en fin de petite manche (GDD 2.5, 2.9).
 * Reçoit toutes les annonces de la petite manche (une par joueur ayant une paire/brelan en main),
 * retourne les points par équipe.
 */
export function resolveRondaTringa(announcements: Announcement[]): Partial<Record<TeamId, number>> {
  const points: Partial<Record<TeamId, number>> = {};
  if (announcements.length === 0) return points;

  const tringas = announcements.filter((a) => a.kind === "tringa");
  const rondas = announcements.filter((a) => a.kind === "ronda");

  if (tringas.length > 0) {
    // La plus petite Tringa gagne toujours, bat toute Ronda (GDD 2.9).
    const winner = pickLowest(tringas);
    let total = 5;
    if (rondas.length > 0) {
      total += 1; // bonus "Tringa contre une Ronda"
    }
    points[winner.team] = (points[winner.team] ?? 0) + total;
    return points;
  }

  if (rondas.length === 1) {
    const only = rondas[0];
    points[only.team] = (points[only.team] ?? 0) + 1;
    return points;
  }

  if (rondas.length === 2 || rondas.length === 3) {
    const winner = pickHighestUnique(rondas);
    if (winner) {
      points[winner.team] = (points[winner.team] ?? 0) + rondas.length;
    }
    // égalité entre les meilleures -> annulation, personne ne marque
    return points;
  }

  if (rondas.length === 4) {
    const winner = pickLowestUniqueCascading(rondas);
    if (winner) {
      points[winner.team] = (points[winner.team] ?? 0) + 4;
    }
    return points;
  }

  return points;
}

function pickLowest(list: Announcement[]): Announcement {
  return list.reduce((best, cur) => (rankIndex(cur.rank) < rankIndex(best.rank) ? cur : best));
}

/** Retourne le gagnant si la valeur la plus haute est unique, sinon null (égalité -> annulation). */
function pickHighestUnique(list: Announcement[]): Announcement | null {
  const maxIdx = Math.max(...list.map((a) => rankIndex(a.rank)));
  const atMax = list.filter((a) => rankIndex(a.rank) === maxIdx);
  return atMax.length === 1 ? atMax[0] : null;
}

/**
 * Règle des 4 Rondas (GDD 2.9) : la plus petite gagne. Si elle est partagée par plusieurs joueurs,
 * ces Rondas s'annulent et on regarde la valeur suivante, jusqu'à trouver une valeur non partagée
 * ou épuiser les annonces (aucun gagnant).
 */
function pickLowestUniqueCascading(list: Announcement[]): Announcement | null {
  const byRankAsc = [...list].sort((a, b) => rankIndex(a.rank) - rankIndex(b.rank));
  let i = 0;
  while (i < byRankAsc.length) {
    const idx = rankIndex(byRankAsc[i].rank);
    const group = byRankAsc.filter((a) => rankIndex(a.rank) === idx);
    if (group.length === 1) {
      return group[0];
    }
    i += group.length;
  }
  return null;
}
