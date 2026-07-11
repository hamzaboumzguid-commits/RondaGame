import { Card, RANK_ORDER, Suit } from "./types.js";

const SUITS: Suit[] = ["oros", "copas", "espadas", "bastos"];

export function createDeck(): Card[] {
  const deck: Card[] = [];
  for (const suit of SUITS) {
    for (const rank of RANK_ORDER) {
      deck.push({ id: `${suit}_${rank}`, rank, suit });
    }
  }
  return deck;
}

/** Fisher-Yates, mutates and returns the same array. */
export function shuffle<T>(arr: T[], rng: () => number = Math.random): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}
