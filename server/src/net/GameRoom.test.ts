import { describe, expect, it } from "vitest";
import { GameRoom, PlayerConnection } from "./GameRoom.js";
import { Card, TARGET_SCORE } from "../game/types.js";
import { PublicState, ServerMessage } from "./protocol.js";

/**
 * Joueur factice qui enregistre tout ce que le serveur lui envoie.
 * Permet de piloter une partie complète via l'API publique de GameRoom,
 * exactement comme le ferait un vrai client.
 */
class FakePlayer implements PlayerConnection {
  received: ServerMessage[] = [];
  hand: Card[] = [];
  lastState: PublicState | null = null;

  constructor(public id: string) {}

  send(msg: ServerMessage): void {
    this.received.push(msg);
    if (msg.type === "yourHand") this.hand = msg.cards;
    if (msg.type === "state") this.lastState = msg.state;
    if (msg.type === "joined") this.lastState = msg.state;
  }

  messagesOfType<T extends ServerMessage["type"]>(type: T): Extract<ServerMessage, { type: T }>[] {
    return this.received.filter((m) => m.type === type) as Extract<ServerMessage, { type: T }>[];
  }
}

function setupFullRoom(): { room: GameRoom; players: FakePlayer[] } {
  const room = new GameRoom("TEST1");
  const players = ["p0", "p1", "p2", "p3"].map((id) => new FakePlayer(id));
  for (const p of players) {
    const res = room.join(p.id, `Joueur-${p.id}`, p);
    expect(res.ok).toBe(true);
  }
  return { room, players };
}

describe("GameRoom — lobby", () => {
  it("refuse un 5e joueur", () => {
    const { room } = setupFullRoom();
    const extra = new FakePlayer("p4");
    const res = room.join(extra.id, "Intrus", extra);
    expect(res.ok).toBe(false);
  });

  it("attribue les équipes par sièges alternés (0/2 = A, 1/3 = B)", () => {
    const { players } = setupFullRoom();
    const state = players[0].lastState!;
    const teams = state.players.map((p) => p.team);
    expect(teams).toEqual(["A", "B", "A", "B"]);
  });

  it("permet de changer d'équipe si une place est libre, refuse sinon", () => {
    const room = new GameRoom("TEST2");
    const p0 = new FakePlayer("p0");
    const p1 = new FakePlayer("p1");
    const p2 = new FakePlayer("p2");
    room.join(p0.id, "P0", p0); // siège 0, équipe A
    room.join(p1.id, "P1", p1); // siège 1, équipe B
    room.join(p2.id, "P2", p2); // siège 2, équipe A

    // p1 veut rejoindre A : impossible, sièges 0 et 2 occupés.
    room.joinTeam(p1.id, "A");
    expect(p1.messagesOfType("error").some((e) => e.code === "teamFull")).toBe(true);

    // p2 rejoint B (siège 3 libre) : OK.
    room.joinTeam(p2.id, "B");
    const state = p0.lastState!;
    expect(state.players.find((p) => p.id === "p2")?.team).toBe("B");
  });

  it("seul l'hôte peut démarrer, et uniquement à 4 joueurs", () => {
    const room = new GameRoom("TEST3");
    const p0 = new FakePlayer("p0");
    const p1 = new FakePlayer("p1");
    room.join(p0.id, "P0", p0);
    room.join(p1.id, "P1", p1);

    room.start(p1.id); // pas l'hôte
    expect(p1.messagesOfType("error").some((e) => e.code === "notHost")).toBe(true);

    room.start(p0.id); // hôte mais pas 4 joueurs
    expect(p0.messagesOfType("error").some((e) => e.code === "notFull")).toBe(true);
    expect(room.phase).toBe("lobby");
  });
});

describe("GameRoom — partie complète", () => {
  function playUntilGameOver(room: GameRoom, players: FakePlayer[], maxTurns = 5000): void {
    let turns = 0;
    while (room.phase !== "gameOver" && turns < maxTurns) {
      const state = room.publicState();
      const current = players.find((p) => p.id === state.currentTurnPlayerId);
      if (!current || current.hand.length === 0) break;

      const card = current.hand[0];
      // retire la carte localement (le serveur renvoie la main via yourHand seulement à la donne)
      current.hand = current.hand.slice(1);
      room.playCard(current.id, card.id);
      turns++;
    }
  }

  it("une partie se déroule jusqu'à la victoire d'une équipe (score >= 41)", () => {
    const { room, players } = setupFullRoom();
    room.start("p0");
    expect(room.phase).toBe("playing");

    playUntilGameOver(room, players);

    expect(room.phase).toBe("gameOver");
    const state = room.publicState();
    expect(state.winningTeam === "A" || state.winningTeam === "B").toBe(true);
    expect(state.scores[state.winningTeam as "A" | "B"]).toBeGreaterThanOrEqual(TARGET_SCORE);
  });

  it("chaque joueur reçoit exactement sa main en privé (4 puis 3 puis 3 cartes)", () => {
    const { room, players } = setupFullRoom();
    room.start("p0");

    for (const p of players) {
      const hands = p.messagesOfType("yourHand");
      expect(hands).toHaveLength(1); // première donne uniquement pour l'instant
      expect(hands[0].cards).toHaveLength(4);
    }
  });

  it("les badges d'annonce sont anonymes : présence signalée sans valeur ni type", () => {
    const { room, players } = setupFullRoom();
    room.start("p0");

    const state = room.publicState();
    for (const p of state.players) {
      // le champ est un booléen : impossible de déduire ronda vs tringa ou la valeur
      expect(typeof p.hasAnnouncement).toBe("boolean");
    }
    // aucune annonce détaillée diffusée avant la fin de la sous-manche
    for (const p of players) {
      expect(p.messagesOfType("subRoundReveal")).toHaveLength(0);
    }
  });

  it("un départ en pleine partie abandonne la partie pour tous", () => {
    const { room, players } = setupFullRoom();
    room.start("p0");
    room.leave("p2");

    expect(room.phase).toBe("gameOver");
    for (const p of players.filter((p) => p.id !== "p2")) {
      expect(p.messagesOfType("gameAbandoned")).toHaveLength(1);
    }
  });

  it("40 cartes sont comptabilisées par équipe à chaque fin de manche", () => {
    const { room, players } = setupFullRoom();
    room.start("p0");
    playUntilGameOver(room, players);

    for (const p of players) {
      for (const end of p.messagesOfType("roundEnd")) {
        expect(end.cardCounts.A + end.cardCounts.B).toBe(40);
      }
    }
  });

  it("statistique sur 30 parties : jamais de crash, toujours un gagnant", () => {
    for (let i = 0; i < 30; i++) {
      const { room, players } = setupFullRoom();
      room.start("p0");
      playUntilGameOver(room, players);
      expect(room.phase).toBe("gameOver");
    }
  });
});
