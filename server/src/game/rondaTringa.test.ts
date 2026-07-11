import { describe, expect, it } from "vitest";
import { resolveRondaTringa } from "./rondaTringa.js";
import { Announcement } from "./types.js";

function ann(
  team: "A" | "B",
  kind: "ronda" | "tringa",
  rank: Announcement["rank"],
  playerId: string = team,
): Announcement {
  return { playerId, team, kind, rank };
}

describe("resolveRondaTringa", () => {
  it("une seule Ronda rapporte 1 point immédiatement", () => {
    const pts = resolveRondaTringa([ann("A", "ronda", 7)]);
    expect(pts).toEqual({ A: 1 });
  });

  it("2 Rondas : la plus forte gagne 2 points", () => {
    const pts = resolveRondaTringa([ann("A", "ronda", 5), ann("B", "ronda", 7)]);
    expect(pts).toEqual({ B: 2 });
  });

  it("3 Rondas : la plus forte gagne 3 points", () => {
    const pts = resolveRondaTringa([ann("A", "ronda", 5), ann("B", "ronda", 3), ann("A", "ronda", 7, "A2")]);
    expect(pts).toEqual({ A: 3 });
  });

  it("2 Rondas égales à la meilleure valeur -> annulation, personne ne marque", () => {
    const pts = resolveRondaTringa([ann("A", "ronda", 7), ann("B", "ronda", 7)]);
    expect(pts).toEqual({});
  });

  it("exemple GDD: 5-5 / 5-5 / 7-7 -> le 7 remporte 3 points", () => {
    const pts = resolveRondaTringa([
      ann("A", "ronda", 5, "p1"),
      ann("B", "ronda", 5, "p2"),
      ann("A", "ronda", 7, "p3"),
    ]);
    expect(pts).toEqual({ A: 3 });
  });

  it("4 Rondas : la plus petite gagne 4 points", () => {
    const pts = resolveRondaTringa([
      ann("A", "ronda", 5, "p1"),
      ann("B", "ronda", 7, "p2"),
      ann("A", "ronda", 3, "p3"),
      ann("B", "ronda", 12, "p4"),
    ]);
    expect(pts).toEqual({ A: 4 });
  });

  it("4 Rondas, plus petite partagée -> cascade vers la valeur suivante non partagée", () => {
    const pts = resolveRondaTringa([
      ann("A", "ronda", 2, "p1"),
      ann("B", "ronda", 2, "p2"),
      ann("A", "ronda", 5, "p3"),
      ann("B", "ronda", 12, "p4"),
    ]);
    expect(pts).toEqual({ A: 4 }); // 2 s'annule, 5 (A) unique et plus petite restante gagne
  });

  it("4 Rondas, aucun gagnant si tout s'annule en cascade", () => {
    const pts = resolveRondaTringa([
      ann("A", "ronda", 2, "p1"),
      ann("B", "ronda", 2, "p2"),
      ann("A", "ronda", 5, "p3"),
      ann("B", "ronda", 5, "p4"),
    ]);
    expect(pts).toEqual({});
  });

  it("Tringa bat toute Ronda, +1 bonus si elle bat une Ronda", () => {
    const pts = resolveRondaTringa([ann("A", "tringa", 2), ann("B", "ronda", 1)]);
    expect(pts).toEqual({ A: 6 });
  });

  it("Tringa seule sans Ronda concurrente : 5 points, pas de bonus", () => {
    const pts = resolveRondaTringa([ann("A", "tringa", 2)]);
    expect(pts).toEqual({ A: 5 });
  });

  it("plusieurs Tringas : la plus petite gagne, les autres ne rapportent rien", () => {
    const pts = resolveRondaTringa([ann("A", "tringa", 7), ann("B", "tringa", 2)]);
    expect(pts).toEqual({ B: 5 });
  });
});
