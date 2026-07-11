import { createGameServer } from "./server.js";

const PORT = Number(process.env.PORT ?? 2567);

const { httpServer } = createGameServer();

httpServer.listen(PORT, () => {
  console.log(`Ronda server (ws) listening on :${PORT}`);
});
