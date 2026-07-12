import { describe, expect, it } from "vitest";
import { RoomManager } from "./RoomManager.js";
import { PlayerConnection } from "./GameRoom.js";
import { ServerMessage } from "./protocol.js";

class FakePlayer implements PlayerConnection {
  received: ServerMessage[] = [];
  constructor(public id: string) {}
  send(msg: ServerMessage): void {
    this.received.push(msg);
  }
}

describe("RoomManager — salons publics", () => {
  it("liste uniquement les salons publics, en lobby, non pleins", () => {
    const manager = new RoomManager();

    const pub = manager.createRoom("2v2", true);
    const priv = manager.createRoom("2v2", false);
    const pubFull = manager.createRoom("1v1", true);

    pub.join("a", "Alice", new FakePlayer("a"));
    priv.join("b", "Bob", new FakePlayer("b"));
    pubFull.join("c", "Cid", new FakePlayer("c"));
    pubFull.join("d", "Dara", new FakePlayer("d")); // 1v1 complet -> plus rejoignable

    const list = manager.listPublicRooms();
    expect(list.map((r) => r.roomCode)).toEqual([pub.roomCode]);
    expect(list[0]).toMatchObject({
      mode: "2v2",
      playerCount: 1,
      maxPlayers: 4,
      hostNickname: "Alice",
    });
  });

  it("un salon public disparaît de la liste une fois la partie lancée", () => {
    const manager = new RoomManager();
    const room = manager.createRoom("2v2", true);
    const ids = ["p0", "p1", "p2"];
    for (const id of ids) room.join(id, id, new FakePlayer(id));
    expect(manager.listPublicRooms()).toHaveLength(1); // 3/4, encore rejoignable

    const last = new FakePlayer("p3");
    room.join("p3", "P3", last);
    expect(manager.listPublicRooms()).toHaveLength(0); // plein

    room.start("p0");
    expect(manager.listPublicRooms()).toHaveLength(0); // lancé
  });
});
