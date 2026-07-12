import { createGameServer } from "./server.js";

const PORT = Number(process.env.PORT ?? 2567);
// 0.0.0.0 explicite : Fly.io (et la plupart des PaaS) exigent que le process
// écoute sur toutes les interfaces, pas seulement localhost/::1.
const HOST = process.env.HOST ?? "0.0.0.0";

const { httpServer } = createGameServer();

httpServer.listen(PORT, HOST, () => {
  console.log(`Ronda server (ws) listening on ${HOST}:${PORT}`);
});
