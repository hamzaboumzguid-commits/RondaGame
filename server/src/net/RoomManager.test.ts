import { describe, expect, it, vi } from "vitest";
import { RoomManager } from "./RoomManager.js";
import { PlayerConnection } from "./GameRoom.js";
import { ServerMessage } from "./protocol.js";
import * as roomCode from "./roomCode.js";

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

describe("RoomManager — codes de salon", () => {
  it("régénère le code en cas de collision jusqu'à en trouver un libre", () => {
    const manager = new RoomManager();
    const spy = vi
      .spyOn(roomCode, "generateRoomCode")
      .mockReturnValueOnce("AAAAA")
      .mockReturnValueOnce("AAAAA") // collision : déjà pris juste après
      .mockReturnValueOnce("BBBBB");

    const first = manager.createRoom();
    expect(first.roomCode).toBe("AAAAA");

    const second = manager.createRoom();
    expect(second.roomCode).toBe("BBBBB");
    expect(spy).toHaveBeenCalledTimes(3);

    spy.mockRestore();
  });

  it("getRoom est insensible à la casse du code", () => {
    const manager = new RoomManager();
    const room = manager.createRoom();
    expect(manager.getRoom(room.roomCode.toLowerCase())).toBe(room);
    expect(manager.getRoom(room.roomCode.toUpperCase())).toBe(room);
  });

  it("getRoom retourne undefined pour un code inconnu", () => {
    const manager = new RoomManager();
    expect(manager.getRoom("ZZZZZ")).toBeUndefined();
  });

  it("une room vidée dans le lobby est retirée du manager (onDispose)", () => {
    const manager = new RoomManager();
    const room = manager.createRoom();
    const p0 = new FakePlayer("p0");
    room.join("p0", "P0", p0);
    expect(manager.roomCount).toBe(1);

    room.leave("p0"); // dernier joueur du lobby quitte -> room vide -> dispose
    expect(manager.roomCount).toBe(0);
    expect(manager.getRoom(room.roomCode)).toBeUndefined();
  });

  it("une room abandonnée en cours de partie est retirée du manager", () => {
    const manager = new RoomManager();
    const room = manager.createRoom();
    const ids = ["p0", "p1", "p2", "p3"];
    for (const id of ids) room.join(id, id, new FakePlayer(id));
    room.start("p0");
    expect(manager.roomCount).toBe(1);

    room.leave("p2"); // départ en pleine partie -> gameAbandoned -> dispose
    expect(manager.roomCount).toBe(0);
    expect(manager.getRoom(room.roomCode)).toBeUndefined();
  });
});
