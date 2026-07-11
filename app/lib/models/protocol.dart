/// Miroirs Dart du protocole JSON défini côté serveur
/// (server/src/net/protocol.ts). Toute modification doit rester synchronisée.
library;

class GameCard {
  final String id;
  final int rank;
  final String suit; // oros | copas | espadas | bastos

  const GameCard({required this.id, required this.rank, required this.suit});

  factory GameCard.fromJson(Map<String, dynamic> json) => GameCard(
        id: json['id'] as String,
        rank: json['rank'] as int,
        suit: json['suit'] as String,
      );

  @override
  bool operator ==(Object other) => other is GameCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class PublicPlayer {
  final String id;
  final String nickname;
  final int seat;
  final String team;
  final int handCount;
  final bool hasAnnouncement;
  final bool isHost;

  const PublicPlayer({
    required this.id,
    required this.nickname,
    required this.seat,
    required this.team,
    required this.handCount,
    required this.hasAnnouncement,
    required this.isHost,
  });

  factory PublicPlayer.fromJson(Map<String, dynamic> json) => PublicPlayer(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        seat: json['seat'] as int,
        team: json['team'] as String,
        handCount: json['handCount'] as int,
        hasAnnouncement: json['hasAnnouncement'] as bool,
        isHost: json['isHost'] as bool,
      );
}

class PublicState {
  final String phase; // lobby | playing | reveal | roundEnd | gameOver
  final String roomCode;
  final List<PublicPlayer> players;
  final List<GameCard> tablePile;
  final String leadPlayerId;
  final String currentTurnPlayerId;
  final Map<String, int> scores; // {A: x, B: y}
  final String winningTeam;
  final int roundNumber;
  final int dealIndex;

  const PublicState({
    required this.phase,
    required this.roomCode,
    required this.players,
    required this.tablePile,
    required this.leadPlayerId,
    required this.currentTurnPlayerId,
    required this.scores,
    required this.winningTeam,
    required this.roundNumber,
    required this.dealIndex,
  });

  factory PublicState.fromJson(Map<String, dynamic> json) => PublicState(
        phase: json['phase'] as String,
        roomCode: json['roomCode'] as String,
        players: (json['players'] as List)
            .map((p) => PublicPlayer.fromJson(p as Map<String, dynamic>))
            .toList(),
        tablePile: (json['tablePile'] as List)
            .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        leadPlayerId: json['leadPlayerId'] as String,
        currentTurnPlayerId: json['currentTurnPlayerId'] as String,
        scores: (json['scores'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        winningTeam: json['winningTeam'] as String,
        roundNumber: json['roundNumber'] as int,
        dealIndex: json['dealIndex'] as int,
      );

  PublicPlayer? playerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }
}

class RevealedAnnouncement {
  final String playerId;
  final String team;
  final String kind; // ronda | tringa
  final int rank;

  const RevealedAnnouncement({
    required this.playerId,
    required this.team,
    required this.kind,
    required this.rank,
  });

  factory RevealedAnnouncement.fromJson(Map<String, dynamic> json) =>
      RevealedAnnouncement(
        playerId: json['playerId'] as String,
        team: json['team'] as String,
        kind: json['kind'] as String,
        rank: json['rank'] as int,
      );
}

/// Événements ponctuels du serveur qui déclenchent des animations ou des
/// transitions, par opposition à l'état continu (PublicState).
sealed class GameEvent {}

class CaptureEvent extends GameEvent {
  final String playerId;
  final String team;
  final String playedCardId;
  final List<String> capturedCardIds;
  final bool isDerba;
  final int derbaTier; // 0..3
  final bool isMissa;
  final int points;

  CaptureEvent.fromJson(Map<String, dynamic> json)
      : playerId = json['playerId'] as String,
        team = json['team'] as String,
        playedCardId = json['playedCardId'] as String,
        capturedCardIds =
            (json['capturedCardIds'] as List).cast<String>(),
        isDerba = json['isDerba'] as bool,
        derbaTier = json['derbaTier'] as int,
        isMissa = json['isMissa'] as bool,
        points = json['points'] as int;
}

class SubRoundRevealEvent extends GameEvent {
  final List<RevealedAnnouncement> announcements;
  final Map<String, int> points;

  SubRoundRevealEvent.fromJson(Map<String, dynamic> json)
      : announcements = (json['announcements'] as List)
            .map((a) => RevealedAnnouncement.fromJson(a as Map<String, dynamic>))
            .toList(),
        points = (json['points'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int));
}

class RoundEndEvent extends GameEvent {
  final Map<String, int> butinPoints;
  final Map<String, int> bonusPoints;
  final Map<String, int> cardCounts;

  RoundEndEvent.fromJson(Map<String, dynamic> json)
      : butinPoints = (json['butinPoints'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        bonusPoints = (json['bonusPoints'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        cardCounts = (json['cardCounts'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int));
}

class GameOverEvent extends GameEvent {
  final String winningTeam;
  GameOverEvent(this.winningTeam);
}

class GameAbandonedEvent extends GameEvent {
  final String reason;
  GameAbandonedEvent(this.reason);
}

class ErrorEvent extends GameEvent {
  final String code;
  final String message;
  ErrorEvent(this.code, this.message);
}

/// Libellés d'affichage des cartes.
String rankLabel(int rank) {
  switch (rank) {
    case 1:
      return 'As';
    case 10:
      return 'Valet';
    case 11:
      return 'Cavalier';
    case 12:
      return 'Roi';
    default:
      return '$rank';
  }
}

String suitLabel(String suit) {
  switch (suit) {
    case 'oros':
      return 'Deniers';
    case 'copas':
      return 'Coupes';
    case 'espadas':
      return 'Épées';
    case 'bastos':
      return 'Bâtons';
    default:
      return suit;
  }
}
