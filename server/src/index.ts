import { createServer } from "http";
import express from "express";
import cors from "cors";
import { Server, matchMaker } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { RondaRoom } from "./rooms/RondaRoom.js";
import { generateRoomCode } from "./rooms/roomCode.js";

const PORT = Number(process.env.PORT ?? 2567);

const app = express();
app.use(cors());
app.use(express.json());

const httpServer = createServer(app);
const gameServer = new Server({
  transport: new WebSocketTransport({ server: httpServer }),
});

gameServer.define("ronda", RondaRoom);

// Endpoint HTTP pour créer une room et obtenir son code, avant que le client ne se connecte
// en websocket avec ce code (flux façon Among Us : créer -> obtenir code -> partager -> rejoindre).
app.post("/rooms", async (_req, res) => {
  let roomCode = generateRoomCode();
  // Évite (improbable) collision avec une room active existante.
  const existing = await matchMaker.query({ name: "ronda" });
  const codes = new Set(existing.map((r) => (r.metadata as { roomCode?: string })?.roomCode));
  while (codes.has(roomCode)) roomCode = generateRoomCode();

  await matchMaker.createRoom("ronda", { roomCode });
  res.json({ roomCode });
});

app.get("/health", (_req, res) => res.json({ ok: true }));

httpServer.listen(PORT, () => {
  console.log(`Ronda server listening on :${PORT}`);
});
