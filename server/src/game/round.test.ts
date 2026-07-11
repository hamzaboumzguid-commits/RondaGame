import { describe, expect, it } from "vitest";
import { computeButin, computeLastCaptureBonus, firstPlayerSeat, nextLead } from "./round.js";
import { Card } from "./types.js";

function cards(n: number): Card[] {
  return Array.from({ length: n }, (_, i) => ({ id: `c${i}`, rank: 2, suit: "oros" as const }));
}

describe("computeButin", () => {
  it("équipe > 20 cartes marque le surplus", () => {
    const pts = computeButin({ A: cards(24), B: cards(16) });
    expect(pts).toEqual({ A: 4 });
  });

  it("20-20 : aucun point", () => {
    const pts = computeButin({ A: cards(20), B: cards(20) });
    expect(pts).toEqual({});
  });

  it("rejette un total différent de 40", () => {
    expect(() => computeButin({ A: cards(10), B: cards(10) })).toThrow();
  });
});

describe("computeLastCaptureBonus", () => {
  it("dernière capture avec un Roi (12) : +5 à l'équipe qui capture", () => {
    const pts = computeLastCaptureBonus({ id: "x", rank: 12, suit: "oros" }, "A");
    expect(pts).toEqual({ A: 5 });
  });

  it("dernière capture avec un As (1) : +5 à l'équipe adverse", () => {
    const pts = computeLastCaptureBonus({ id: "x", rank: 1, suit: "oros" }, "A");
    expect(pts).toEqual({ B: 5 });
  });

  it("dernière capture avec une autre carte : aucun bonus", () => {
    const pts = computeLastCaptureBonus({ id: "x", rank: 7, suit: "oros" }, "A");
    expect(pts).toEqual({});
  });
});

describe("rotation du Lead et premier joueur", () => {
  it("le Lead passe au joueur à sa droite (siège N -> N-1 mod 4)", () => {
    expect(nextLead(0)).toBe(3);
    expect(nextLead(3)).toBe(2);
    expect(nextLead(2)).toBe(1);
    expect(nextLead(1)).toBe(0);
  });

  it("le premier joueur à jouer est à la droite du Lead", () => {
    expect(firstPlayerSeat(0)).toBe(1);
    expect(firstPlayerSeat(1)).toBe(2);
  });
});
