import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { AddressInfo } from "net";
import WebSocket from "ws";
import { createGameServer, GameServer } from "./server.js";
import { ClientMessage, ServerMessage } from "./net/protocol.js";

/**
 * E2E sur vraies sockets : 4 clients WebSocket rejoignent une room via le flux
 * create -> code -> join, choisissent leurs équipes et lancent la partie.
 */

class TestClient {
  ws!: WebSocket;
  received: ServerMessage[] = [];
  private waiters: { predicate: (m: ServerMessage) => boolean; resolve: (m: ServerMessage) => void }[] = [];

  async connect(port: number): Promise<void> {
    this.ws = new WebSocket(`ws://127.0.0.1:${port}`);
    this.ws.on("message", (raw) => {
      const msg = JSON.parse(raw.toString()) as ServerMessage;
      this.received.push(msg);
      const idx = this.waiters.findIndex((w) => w.predicate(msg));
      if (idx !== -1) {
        const [waiter] = this.waiters.splice(idx, 1);
        waiter.resolve(msg);
      }
    });
    await new Promise<void>((resolve, reject) => {
      this.ws.once("open", resolve);
      this.ws.once("error", reject);
    });
  }

  send(msg: ClientMessage): void {
    this.ws.send(JSON.stringify(msg));
  }

  /** Attend le premier message du type donné (déjà reçu ou à venir). */
  waitFor<T extends ServerMessage["type"]>(type: T, timeoutMs = 3000): Promise<Extract<ServerMessage, { type: T }>> {
    return this.waitForMatch((m) => m.type === type, `type "${type}"`, timeoutMs) as Promise<
      Extract<ServerMessage, { type: T }>
    >;
  }

  /** Attend un message satisfaisant le prédicat (déjà reçu ou à venir). */
  waitForMatch(
    predicate: (m: ServerMessage) => boolean,
    label = "prédicat",
    timeoutMs = 3000,
  ): Promise<ServerMessage> {
    const already = this.received.find(predicate);
    if (already) return Promise.resolve(already);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Timeout en attente de ${label}`)), timeoutMs);
      this.waiters.push({
        predicate,
        resolve: (m) => {
          clearTimeout(timer);
          resolve(m);
        },
      });
    });
  }

  close(): void {
    this.ws.close();
  }
}

describe("E2E websocket", () => {
  let server: GameServer;
  let port: number;

  beforeAll(async () => {
    server = createGameServer();
    await new Promise<void>((resolve) => server.httpServer.listen(0, resolve));
    port = (server.httpServer.address() as AddressInfo).port;
  });

  afterAll(async () => {
    await server.close();
  });

  it("flux complet : créer, rejoindre par code, équipes, démarrage, première donne", async () => {
    const host = new TestClient();
    await host.connect(port);
    host.send({ type: "create", nickname: "Hamza" });
    const joined = await host.waitFor("joined");
    const code = joined.roomCode;
    expect(code).toMatch(/^[A-Z2-9]{5}$/);

    const guests = [new TestClient(), new TestClient(), new TestClient()];
    for (const [i, guest] of guests.entries()) {
      await guest.connect(port);
      guest.send({ type: "join", roomCode: code, nickname: `Invité${i + 1}` });
      await guest.waitFor("joined");
    }

    // Un mauvais code est rejeté.
    const lost = new TestClient();
    await lost.connect(port);
    lost.send({ type: "join", roomCode: "ZZZZZ", nickname: "Perdu" });
    const err = await lost.waitFor("error");
    expect(err.code).toBe("roomNotFound");
    lost.close();

    // Lancement : chaque joueur reçoit sa main de 4 cartes en privé.
    host.send({ type: "start" });
    const all = [host, ...guests];
    for (const client of all) {
      const hand = await client.waitFor("yourHand");
      expect(hand.cards).toHaveLength(4);
    }

    // L'état public ne contient jamais les mains, seulement les compteurs.
    const playing = (await host.waitForMatch(
      (m) => m.type === "state" && m.state.phase === "playing",
      "état playing",
    )) as Extract<ServerMessage, { type: "state" }>;
    const state = playing.state;
    for (const p of state.players) {
      expect(p).not.toHaveProperty("hand");
      expect(p.handCount).toBe(4);
    }

    for (const c of all) c.close();
  });

  it("liste des salons publics : visible si isPublic, invisible sinon ou une fois plein", async () => {
    const host = new TestClient();
    await host.connect(port);
    host.send({ type: "create", nickname: "HostPublic", mode: "1v1", isPublic: true });
    const joined = await host.waitFor("joined");

    const privateHost = new TestClient();
    await privateHost.connect(port);
    privateHost.send({ type: "create", nickname: "HostPrive", mode: "1v1" });
    await privateHost.waitFor("joined");

    const viewer = new TestClient();
    await viewer.connect(port);
    viewer.send({ type: "listPublicRooms" });
    const list1 = await viewer.waitFor("publicRooms");
    expect(list1.rooms.some((r) => r.roomCode === joined.roomCode)).toBe(true);
    expect(list1.rooms.some((r) => r.hostNickname === "HostPrive")).toBe(false);

    // La room publique se remplit (1v1) -> disparaît de la liste.
    const guest = new TestClient();
    await guest.connect(port);
    guest.send({ type: "join", roomCode: joined.roomCode, nickname: "Invité" });
    await guest.waitFor("joined");

    viewer.send({ type: "listPublicRooms" });
    const list2 = await viewer.waitForMatch(
      (m) => m.type === "publicRooms" && !m.rooms.some((r) => r.roomCode === joined.roomCode),
      "liste sans la room pleine",
    );
    expect((list2 as Extract<ServerMessage, { type: "publicRooms" }>).rooms).toHaveLength(0);

    for (const c of [host, privateHost, viewer, guest]) c.close();
  });
});
