import { Schema, type, MapSchema, ArraySchema } from "@colyseus/schema";

/**
 * État synchronisé Colyseus (visible côté client). Représente la vue publique de la partie.
 * Les mains adverses ne sont volontairement pas exposées ici : chaque client ne reçoit sa propre
 * main via un message privé dédié (cf. rooms/RondaRoom.ts), pour garder le serveur autoritaire
 * et éviter toute triche côté client.
 */

export class CardSchema extends Schema {
  @type("string") id: string = "";
  @type("number") rank: number = 0;
  @type("string") suit: string = "";
}

export class PlayerSchema extends Schema {
  @type("string") id: string = "";
  @type("string") nickname: string = "";
  @type("number") seat: number = 0;
  @type("string") team: string = "";
  @type("boolean") connected: boolean = true;
  @type("number") handCount: number = 0;
}

export class AnnouncementBadgeSchema extends Schema {
  @type("string") playerId: string = "";
  // Aucune valeur ni type (ronda/tringa) exposée avant résolution — cf. GDD 2.5.
}

export class TeamScoreSchema extends Schema {
  @type("number") score: number = 0;
}

export class RondaRoomState extends Schema {
  @type("string") phase: string = "lobby"; // lobby | dealing | playing | reveal | roundEnd | gameOver
  @type("string") roomCode: string = "";
  @type({ map: PlayerSchema }) players = new MapSchema<PlayerSchema>();
  @type([CardSchema]) tablePile = new ArraySchema<CardSchema>();
  @type([AnnouncementBadgeSchema]) announcements = new ArraySchema<AnnouncementBadgeSchema>();
  @type("string") leadPlayerId: string = "";
  @type("string") currentTurnPlayerId: string = "";
  @type({ map: TeamScoreSchema }) teamScores = new MapSchema<TeamScoreSchema>();
  @type("string") winningTeam: string = "";
}
