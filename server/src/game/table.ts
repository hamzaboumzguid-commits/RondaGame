import { Card, CaptureEvent, DerbaTier, PlayerState, TeamId } from "./types.js";

/**
 * État et règles de la table de jeu (GDD 2.6, 2.7, 2.8).
 * `pile` est la liste ordonnée des cartes actuellement sur la table, dernière posée en fin de tableau.
 */
export class Table {
  pile: Card[] = [];

  /** Dernière capture réalisée, utilisée pour détecter une chaîne de Derba (GDD 2.7). */
  private lastCapture: { rank: Card["rank"]; byPlayerId: string; derbaTier: DerbaTier } | null = null;

  reset(): void {
    this.pile = [];
    this.lastCapture = null;
  }

  /**
   * Joue une carte pour un joueur : capture si possible (choix du joueur si plusieurs cibles),
   * sinon la pose sur la table. Capture libre : jamais imposée (GDD 2.6).
   *
   * @param targetRank si fourni et présent sur la table, capture cette valeur (+ suite continue).
   *                   si omis ou absent de la table, la carte est simplement posée.
   */
  play(player: Pick<PlayerState, "id" | "team">, card: Card, opts: { capture: boolean }): CaptureEvent | null {
    if (!opts.capture || !this.pile.some((c) => c.rank === card.rank)) {
      this.pile.push(card);
      this.lastCapture = null; // pose = rompt toute chaîne de Derba en cours
      return null;
    }

    const isDerba = this.pile.length > 0 && this.pile[this.pile.length - 1].rank === card.rank;

    const captured = this.captureFrom(card.rank);
    const cardsCaptured = [...captured, card];

    let derbaTier: DerbaTier = 0;
    if (isDerba) {
      const chained = this.lastCapture !== null && this.lastCapture.rank === card.rank;
      if (chained) {
        derbaTier = this.lastCapture!.derbaTier === 1 ? 2 : this.lastCapture!.derbaTier === 2 ? 3 : 3;
      } else {
        derbaTier = 1;
      }
    }

    const isMissa = this.pile.length === 0;

    this.lastCapture = isDerba ? { rank: card.rank, byPlayerId: player.id, derbaTier } : null;

    return {
      byPlayerId: player.id,
      byTeam: player.team,
      cardsCaptured,
      playedCard: card,
      isDerba,
      derbaTier,
      isMissa,
    };
  }

  /**
   * Capture la valeur cible et toute suite continue attenante (GDD 2.6 — ex table 5-6-7, pose d'un 5).
   * Retire les cartes du pile et les retourne (sans la carte jouée elle-même).
   */
  private captureFrom(rank: Card["rank"]): Card[] {
    const idx = this.pile.findIndex((c) => c.rank === rank);
    if (idx === -1) return [];

    // La suite est capturée dans son intégralité contiguë à partir de la carte capturée,
    // en remontant tant que les valeurs de la pile forment une séquence de rangs consécutifs
    // dans l'ordre RANK_ORDER, comme décrit dans l'exemple du GDD (5-6-7 capturé par un 5).
    let start = idx;
    let end = idx;
    // La capture porte sur toute la table restante à partir du point de correspondance :
    // dans cette variante, une fois une valeur trouvée, toute la suite visible qui lui est
    // contiguë en rang est prise. On étend en avant tant que la suite continue.
    while (end + 1 < this.pile.length && this.isNextInSequence(this.pile[end].rank, this.pile[end + 1].rank)) {
      end++;
    }

    const captured = this.pile.slice(start, end + 1);
    this.pile.splice(start, end + 1 - start);
    return captured;
  }

  private isNextInSequence(a: Card["rank"], b: Card["rank"]): boolean {
    const RANK_ORDER = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];
    return RANK_ORDER.indexOf(b) === RANK_ORDER.indexOf(a) + 1;
  }

  isEmpty(): boolean {
    return this.pile.length === 0;
  }

  /** Cartes restantes non capturées en toute fin de manche (GDD 2.10). */
  sweepRemaining(): Card[] {
    const remaining = [...this.pile];
    this.pile = [];
    return remaining;
  }
}

export interface DerbaChainState {
  active: boolean;
  tier: DerbaTier;
}
