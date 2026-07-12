import { GameMode, GameRoom } from "./GameRoom.js";
import { generateRoomCode } from "./roomCode.js";

export class RoomManager {
  private rooms = new Map<string, GameRoom>();

  createRoom(mode: GameMode = "2v2"): GameRoom {
    let code = generateRoomCode();
    while (this.rooms.has(code)) code = generateRoomCode();

    const room = new GameRoom(code, mode);
    room.onDispose = () => this.rooms.delete(code);
    this.rooms.set(code, room);
    return room;
  }

  getRoom(code: string): GameRoom | undefined {
    return this.rooms.get(code.toUpperCase());
  }

  get roomCount(): number {
    return this.rooms.size;
  }
}
