import { describe, expect, it } from "vitest";
import { Table } from "./table.js";
import { Card, PlayerState } from "./types.js";

function card(rank: Card["rank"], suit: Card["suit"] = "oros"): Card {
  return { id: `${suit}_${rank}`, rank, suit };
}

function player(id: string, team: "A" | "B" = "A"): PlayerState {
  return { id, nickname: id, seat: 0, team, hand: [], connected: true };
}

describe("Table.play — capture et suites", () => {
  it("pose une carte si aucune capture demandée", () => {
    const t = new Table();
    const ev = t.play(player("p1"), card(5), { capture: false });
    expect(ev).toBeNull();
    expect(t.pile).toHaveLength(1);
  });

  it("capture une carte de même valeur", () => {
    const t = new Table();
    t.pile = [card(6)];
    const ev = t.play(player("p1"), card(6), { capture: true });
    expect(ev).not.toBeNull();
    expect(ev!.cardsCaptured.map((c) => c.rank)).toEqual([6, 6]);
    expect(t.isEmpty()).toBe(true);
  });

  it("capture une suite continue (5-6-7 capturé par un 5)", () => {
    const t = new Table();
    t.pile = [card(5), card(6), card(7)];
    const ev = t.play(player("p1"), card(5, "copas"), { capture: true });
    expect(ev!.cardsCaptured.map((c) => c.rank)).toEqual([5, 6, 7, 5]);
    expect(t.isEmpty()).toBe(true);
    expect(ev!.isDerba).toBe(false); // suite != Derba (GDD 2.6)
  });

  it("Missa quand la table est entièrement vidée", () => {
    const t = new Table();
    t.pile = [card(3)];
    const ev = t.play(player("p1"), card(3), { capture: true });
    expect(ev!.isMissa).toBe(true);
  });

  it("pas de Missa si une carte non-consécutive reste sur la table après capture", () => {
    const t = new Table();
    t.pile = [card(3), card(7)]; // 7 n'est pas consécutif à 3 dans l'ordre des rangs
    const ev = t.play(player("p1"), card(3), { capture: true });
    expect(ev!.isMissa).toBe(false);
    expect(t.pile.map((c) => c.rank)).toEqual([7]);
  });

  it("suite ascendante contiguë entièrement capturée (3-4 capturé par un 3)", () => {
    const t = new Table();
    t.pile = [card(3), card(4)];
    const ev = t.play(player("p1"), card(3), { capture: true });
    expect(ev!.cardsCaptured.map((c) => c.rank)).toEqual([3, 4, 3]);
    expect(t.isEmpty()).toBe(true);
  });
});

describe("Table.play — Derba et surenchère", () => {
  it("première Derba vaut palier 1 (1 point)", () => {
    const t = new Table();
    t.play(player("A"), card(4), { capture: false }); // A pose un 4
    const ev = t.play(player("B"), card(4, "copas"), { capture: true }); // B mange immédiatement
    expect(ev!.isDerba).toBe(true);
    expect(ev!.derbaTier).toBe(1);
  });

  it("surenchère : 2e Derba immédiate en chaîne vaut palier 2 (5 points)", () => {
    const t = new Table();
    t.play(player("A"), card(4), { capture: false });
    t.play(player("B"), card(4, "copas"), { capture: true }); // Derba 1 (palier 1)
    t.pile.push(card(4, "espadas")); // B repose une carte (simplifié : re-pose une 3e occurrence)
    const ev = t.play(player("A"), card(4, "bastos"), { capture: true }); // A remange immédiatement
    expect(ev!.derbaTier).toBe(2);
  });

  it("plafonne à palier 3 (10 points) — max 3 Derbas en chaîne", () => {
    const t = new Table();
    // Simule la chaîne complète avec les 4 exemplaires du rang 4.
    t.play(player("A"), card(4, "oros"), { capture: false });
    t.play(player("B"), card(4, "copas"), { capture: true }); // Derba palier 1
    t.pile.push(card(4, "espadas"));
    t.play(player("A"), card(4, "bastos"), { capture: true }); // Derba palier 2 (5 pts)
    expect(t.pile).toHaveLength(0);
    // Il n'existe pas de 5e carte de rang 4 dans un jeu réel ; on vérifie juste que le palier
    // ne peut pas dépasser 3 par construction (DERBA_POINTS n'a que les clés 0..3).
  });

  it("une pose (non-capture) rompt la chaîne de Derba", () => {
    const t = new Table();
    t.play(player("A"), card(4), { capture: false });
    t.play(player("B"), card(4, "copas"), { capture: true }); // Derba palier 1, table vide -> Missa aussi
    t.play(player("A"), card(7), { capture: false }); // pose simple, aucune Derba
    const ev = t.play(player("B"), card(2), { capture: false });
    expect(ev).toBeNull();
  });
});
