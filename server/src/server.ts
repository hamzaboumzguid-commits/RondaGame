import { createServer, Server as HttpServer } from "http";
import { WebSocketServer, WebSocket } from "ws";
import { randomUUID } from "crypto";
import { RoomManager } from "./net/RoomManager.js";
import { GameRoom } from "./net/GameRoom.js";
import { decode, encode, ServerMessage } from "./net/protocol.js";

export interface GameServer {
  httpServer: HttpServer;
  manager: RoomManager;
  close(): Promise<void>;
}

export function createGameServer(): GameServer {
  const manager = new RoomManager();

  const httpServer = createServer((req, res) => {
    if (req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ ok: true, rooms: manager.roomCount }));
      return;
    }
    res.writeHead(404);
    res.end();
  });

  const wss = new WebSocketServer({ server: httpServer });

  wss.on("connection", (socket: WebSocket) => {
    const playerId = randomUUID();
    let room: GameRoom | null = null;

    const conn = {
      send(msg: ServerMessage) {
        if (socket.readyState === WebSocket.OPEN) {
          socket.send(encode(msg));
        }
      },
    };

    socket.on("message", (raw) => {
      const msg = decode(raw.toString());
      if (!msg) {
        conn.send({ type: "error", code: "badMessage", message: "Message invalide" });
        return;
      }

      switch (msg.type) {
        case "create": {
          if (room) return;
          room = manager.createRoom();
          const res = room.join(playerId, msg.nickname, conn);
          if (res.ok) {
            conn.send({ type: "joined", roomCode: room.roomCode, playerId, state: room.publicState() });
          }
          break;
        }
        case "join": {
          if (room) return;
          const target = manager.getRoom(msg.roomCode);
          if (!target) {
            conn.send({ type: "error", code: "roomNotFound", message: "Aucune partie avec ce code" });
            return;
          }
          const res = target.join(playerId, msg.nickname, conn);
          if (!res.ok) {
            conn.send({ type: "error", code: "joinFailed", message: res.error });
            return;
          }
          room = target;
          conn.send({ type: "joined", roomCode: room.roomCode, playerId, state: room.publicState() });
          break;
        }
        case "joinTeam":
          room?.joinTeam(playerId, msg.team);
          break;
        case "start":
          room?.start(playerId);
          break;
        case "playCard":
          room?.playCard(playerId, msg.cardId, msg.capture);
          break;
      }
    });

    socket.on("close", () => {
      room?.leave(playerId);
      room = null;
    });
  });

  return {
    httpServer,
    manager,
    close: () =>
      new Promise<void>((resolve) => {
        wss.close();
        httpServer.close(() => resolve());
      }),
  };
}
