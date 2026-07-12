import { GameMode, GameRoom } from "./GameRoom.js";
import { generateRoomCode } from "./roomCode.js";
import { PublicRoomSummary } from "./protocol.js";

export class RoomManager {
  private rooms = new Map<string, GameRoom>();

  createRoom(mode: GameMode = "2v2", isPublic: boolean = false): GameRoom {
    let code = generateRoomCode();
    while (this.rooms.has(code)) code = generateRoomCode();

    const room = new GameRoom(code, mode, isPublic);
    room.onDispose = () => this.rooms.delete(code);
    this.rooms.set(code, room);
    return room;
  }

  getRoom(code: string): GameRoom | undefined {
    return this.rooms.get(code.toUpperCase());
  }

  /** Salons publics encore rejoignables (lobby, pas plein) — pour la liste de l'accueil. */
  listPublicRooms(): PublicRoomSummary[] {
    const result: PublicRoomSummary[] = [];
    for (const room of this.rooms.values()) {
      if (!room.isPublic || room.phase !== "lobby") continue;
      const summary = room.summary();
      if (summary.playerCount >= summary.maxPlayers) continue;
      result.push(summary);
    }
    return result;
  }

  get roomCount(): number {
    return this.rooms.size;
  }
}
