import { Card, CaptureEvent, DerbaTier, PlayerState, RANK_ORDER, rankIndex } from "./types.js";

/**
 * État et règles de la table de jeu (GDD 2.6, 2.7, 2.8).
 * `pile` est la liste ordonnée des cartes actuellement sur la table, dernière posée en fin de tableau.
 */
export class Table {
  pile: Card[] = [];

  /**
   * Chaîne de Derba en cours (GDD 2.7) : rang concerné, palier atteint, et
   * cartes accumulées dans le paquet — le prochain surenchérisseur emporte tout.
   * Remise à null dès qu'un joueur fait autre chose que répondre avec la même valeur.
   */
  private derbaChain: { rank: Card["rank"]; derbaTier: DerbaTier; chainCards: Card[] } | null = null;

  /**
   * Valeur de la carte POSÉE au coup précédent (null si le coup précédent était
   * une capture). Une Derba capture « la carte que l'adversaire vient de poser »
   * (GDD 2.7) — capturer une carte plus ancienne n'est pas une Derba.
   */
  private justPosedRank: Card["rank"] | null = null;

  reset(): void {
    this.pile = [];
    this.derbaChain = null;
    this.justPosedRank = null;
  }

  /**
   * Joue une carte pour un joueur. Si une carte de même valeur est sur la table,
   * la capture est OBLIGATOIRE (GDD 2.6 — impossible de poser une carte à côté
   * de sa jumelle). Sinon la carte rejoint le tas commun — sauf si elle répond
   * immédiatement à une Derba avec la même valeur : c'est la surenchère (GDD 2.7),
   * le surenchérisseur emporte tout le paquet de la chaîne.
   * Conséquence de la capture obligatoire : la table ne contient jamais deux
   * cartes de même valeur.
   *
   * "Capture libre" (GDD 2.6) porte sur le choix de la carte jouée : le joueur
   * n'est jamais obligé de JOUER une carte capturante, mais s'il en joue une,
   * elle capture.
   */
  play(player: Pick<PlayerState, "id" | "team">, card: Card): CaptureEvent | null {
    const hasTwin = this.pile.some((c) => c.rank === card.rank);

    // Surenchère de Derba : réponse immédiate avec la même valeur alors que la
    // Derba précédente a déjà ramassé les cartes (la table n'a plus ce rang).
    if (!hasTwin && this.derbaChain !== null && this.derbaChain.rank === card.rank) {
      const tier: DerbaTier = this.derbaChain.derbaTier === 1 ? 2 : 3;
      const reclaimed = [...this.derbaChain.chainCards];
      const cardsCaptured = [...reclaimed, card];
      this.derbaChain = tier < 3 ? { rank: card.rank, derbaTier: tier, chainCards: cardsCaptured } : null;
      this.justPosedRank = null;
      return {
        byPlayerId: player.id,
        byTeam: player.team,
        cardsCaptured,
        playedCard: card,
        isDerba: true,
        derbaTier: tier,
        isMissa: false, // la table n'est pas touchée par la surenchère
        reclaimedCards: reclaimed,
      };
    }

    if (!hasTwin) {
      this.pile.push(card);
      this.derbaChain = null; // pose = rompt toute chaîne de Derba en cours
      this.justPosedRank = card.rank;
      return null;
    }

    // Derba = capture immédiate de la carte que le joueur précédent vient de POSER
    // (capturer une carte posée il y a plusieurs tours n'est pas une Derba).
    const isDerba = this.justPosedRank === card.rank;

    const captured = this.captureRun(card.rank);
    const cardsCaptured = [...captured, card];
    const isMissa = this.pile.length === 0;

    this.derbaChain = isDerba ? { rank: card.rank, derbaTier: 1, chainCards: cardsCaptured } : null;
    this.justPosedRank = null;

    return {
      byPlayerId: player.id,
      byTeam: player.team,
      cardsCaptured,
      playedCard: card,
      isDerba,
      derbaTier: isDerba ? 1 : 0,
      isMissa,
      reclaimedCards: [],
    };
  }

  /**
   * Capture la valeur cible puis toute la suite ascendante de valeurs PRÉSENTES
   * sur la table (GDD 2.6 — ex table 5-6-7, pose d'un 5 : tout part), quel que
   * soit l'ordre dans lequel les cartes ont été posées.
   * Retire les cartes de la pile et les retourne (sans la carte jouée elle-même).
   */
  private captureRun(rank: Card["rank"]): Card[] {
    const captured: Card[] = [];
    let nextIdx = rankIndex(rank);
    while (nextIdx < RANK_ORDER.length) {
      const pileIdx = this.pile.findIndex((c) => c.rank === RANK_ORDER[nextIdx]);
      if (pileIdx === -1) break;
      captured.push(...this.pile.splice(pileIdx, 1));
      nextIdx++;
    }
    return captured;
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
