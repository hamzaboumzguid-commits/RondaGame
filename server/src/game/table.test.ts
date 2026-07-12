import { describe, expect, it } from "vitest";
import { Table } from "./table.js";
import { Card, PlayerState } from "./types.js";

function card(rank: Card["rank"], suit: Card["suit"] = "oros"): Card {
  return { id: `${suit}_${rank}`, rank, suit };
}

function player(id: string, team: "A" | "B" = "A"): PlayerState {
  return { id, nickname: id, seat: 0, team, hand: [] };
}

describe("Table.play — capture obligatoire et suites", () => {
  it("pose la carte si aucune jumelle sur la table", () => {
    const t = new Table();
    const ev = t.play(player("p1"), card(5));
    expect(ev).toBeNull();
    expect(t.pile).toHaveLength(1);
  });

  it("capture OBLIGATOIRE dès qu'une jumelle est sur la table (GDD 2.6)", () => {
    const t = new Table();
    t.pile = [card(6)];
    const ev = t.play(player("p1"), card(6, "copas"));
    expect(ev).not.toBeNull();
    expect(ev!.cardsCaptured.map((c) => c.rank)).toEqual([6, 6]);
    expect(t.isEmpty()).toBe(true);
  });

  it("capture une suite continue (5-6-7 capturé par un 5)", () => {
    const t = new Table();
    t.pile = [card(5), card(6), card(7)];
    const ev = t.play(player("p1"), card(5, "copas"));
    expect(ev!.cardsCaptured.map((c) => c.rank)).toEqual([5, 6, 7, 5]);
    expect(t.isEmpty()).toBe(true);
    expect(ev!.isDerba).toBe(false); // suite != Derba (GDD 2.6)
  });

  it("la suite se lit sur les VALEURS présentes, pas l'ordre de pose (4 capture 4-5-6 éparpillés)", () => {
    const t = new Table();
    t.pile = [card(6), card(2), card(4), card(5)]; // ordre de pose quelconque
    const ev = t.play(player("p1"), card(4, "copas"));
    expect(ev!.cardsCaptured.map((c) => c.rank).sort((a, b) => a - b)).toEqual([4, 4, 5, 6]);
    expect(t.pile.map((c) => c.rank)).toEqual([2]); // le 2 n'est pas dans la suite ascendante
  });

  it("la suite est ascendante uniquement (4 ne prend pas le 3)", () => {
    const t = new Table();
    t.pile = [card(3), card(4), card(5)];
    const ev = t.play(player("p1"), card(4, "copas"));
    expect(ev!.cardsCaptured.map((c) => c.rank).sort((a, b) => a - b)).toEqual([4, 4, 5]);
    expect(t.pile.map((c) => c.rank)).toEqual([3]);
  });

  it("la suite traverse le saut 7 -> Valet(10) de l'ordre des rangs", () => {
    const t = new Table();
    t.pile = [card(7), card(10), card(2)];
    const ev = t.play(player("p1"), card(7, "copas"));
    expect(ev!.cardsCaptured.map((c) => c.rank).sort((a, b) => a - b)).toEqual([7, 7, 10]);
    expect(t.pile.map((c) => c.rank)).toEqual([2]);
  });

  it("Missa quand la table est entièrement vidée", () => {
    const t = new Table();
    t.pile = [card(3)];
    const ev = t.play(player("p1"), card(3, "copas"));
    expect(ev!.isMissa).toBe(true);
  });

  it("pas de Missa si une carte non-consécutive reste sur la table après capture", () => {
    const t = new Table();
    t.pile = [card(3), card(7)]; // 7 n'est pas consécutif à 3 dans l'ordre des rangs
    const ev = t.play(player("p1"), card(3, "copas"));
    expect(ev!.isMissa).toBe(false);
    expect(t.pile.map((c) => c.rank)).toEqual([7]);
  });
});

describe("Table.play — Derba et surenchère", () => {
  it("première Derba vaut palier 1 (1 point)", () => {
    const t = new Table();
    t.play(player("A"), card(4)); // A pose un 4
    const ev = t.play(player("B", "B"), card(4, "copas")); // B mange immédiatement
    expect(ev!.isDerba).toBe(true);
    expect(ev!.derbaTier).toBe(1);
    expect(ev!.reclaimedCards).toHaveLength(0);
  });

  it("surenchère : réponse immédiate avec la même valeur = palier 2, et reprend tout le paquet", () => {
    const t = new Table();
    t.play(player("A"), card(4, "oros")); // A pose
    t.play(player("B", "B"), card(4, "copas")); // B : Derba palier 1, ramasse la paire
    const ev = t.play(player("C"), card(4, "espadas")); // C surenchérit sur table vide
    expect(ev!.isDerba).toBe(true);
    expect(ev!.derbaTier).toBe(2);
    // C emporte le paquet : les 2 cartes de B + la sienne.
    expect(ev!.cardsCaptured.map((c) => c.id).sort()).toEqual(["copas_4", "espadas_4", "oros_4"]);
    expect(ev!.reclaimedCards.map((c) => c.id).sort()).toEqual(["copas_4", "oros_4"]);
    expect(ev!.isMissa).toBe(false); // la surenchère ne vide pas la table
  });

  it("surenchère max : palier 3 avec les 4 exemplaires, tout le paquet au dernier", () => {
    const t = new Table();
    t.play(player("A"), card(4, "oros"));
    t.play(player("B", "B"), card(4, "copas")); // palier 1
    t.play(player("C"), card(4, "espadas")); // palier 2
    const ev = t.play(player("D", "B"), card(4, "bastos")); // palier 3 (max)
    expect(ev!.derbaTier).toBe(3);
    expect(ev!.cardsCaptured).toHaveLength(4);
    expect(ev!.reclaimedCards).toHaveLength(3);
  });

  it("le paquet de la surenchère inclut la suite capturée par la Derba initiale", () => {
    const t = new Table();
    t.pile = [card(5, "bastos")];
    t.play(player("A"), card(4, "oros")); // A pose un 4 (pas de jumelle, le 5 reste)
    t.play(player("B", "B"), card(4, "copas")); // Derba + suite : ramasse 4,4,5
    const ev = t.play(player("C"), card(4, "espadas")); // surenchère
    expect(ev!.derbaTier).toBe(2);
    expect(ev!.cardsCaptured).toHaveLength(4); // 4,4,5 repris + son 4
    expect(ev!.reclaimedCards).toHaveLength(3);
  });

  it("une pose (non-capture) rompt la chaîne de Derba", () => {
    const t = new Table();
    t.play(player("A"), card(4));
    t.play(player("B", "B"), card(4, "copas")); // Derba palier 1, table vide
    t.play(player("C"), card(7)); // pose simple : chaîne rompue
    const ev = t.play(player("D", "B"), card(4, "espadas")); // trop tard : simple pose
    expect(ev).toBeNull();
    expect(t.pile.map((c) => c.rank)).toEqual([7, 4]);
  });

  it("capturer une carte ancienne (pas juste posée) n'est PAS une Derba", () => {
    const t = new Table();
    t.play(player("A"), card(7)); // A pose un 7
    t.play(player("B", "B"), card(2)); // B pose un 2 — le 7 n'est plus « juste posé »
    const ev = t.play(player("C"), card(7, "copas")); // C capture le vieux 7
    expect(ev).not.toBeNull();
    expect(ev!.isDerba).toBe(false);
  });

  it("une capture d'une autre valeur rompt aussi la chaîne", () => {
    const t = new Table();
    t.pile = [card(7, "bastos")];
    t.play(player("A"), card(4));
    t.play(player("B", "B"), card(4, "copas")); // Derba (le 7 reste sur table)
    t.play(player("C"), card(7, "copas")); // capture du 7 : chaîne rompue
    const ev = t.play(player("D", "B"), card(4, "espadas")); // simple pose
    expect(ev).toBeNull();
  });
});
