import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { fr, dj }

const _prefsKey = 'ronda_language';

const Map<String, String> _fr = {
  'home.nicknameLabel': 'TON PSEUDO',
  'home.nicknameHint': 'EX. HAMZA',
  'home.nicknameEmpty': 'Choisis un pseudo',
  'home.codeLength': 'Le code doit faire 5 caractères',
  'home.serverTimeout': 'Le serveur ne répond pas',
  'home.mode2v2': '2 VS 2',
  'home.mode1v1': '1 VS 1',
  'home.publicRoom': 'PARTIE PUBLIQUE (visible par tous)',
  'home.createRoom': 'CRÉER UNE PARTIE',
  'home.joinWithCode': 'REJOINDRE AVEC UN CODE',
  'home.codeHint': 'ABCDE',
  'home.join': 'REJOINDRE',
  'home.publicRoomsTitle': 'PARTIES PUBLIQUES',
  'home.noPublicRooms': 'Aucune partie publique ouverte pour le moment',
  'home.roomOf': 'Salon de {nickname}',
  'home.roomSubtitle': '{mode} · {count}/{max} joueurs',
  'home.settings': 'PARAMÈTRES',
  'lobby.codeCopied': 'CODE COPIÉ !',
  'lobby.headerBadge': '{mode} · {count}/{max} JOUEURS',
  'lobby.codeLabel': 'CODE DE LA PARTIE — TAPE POUR COPIER',
  'lobby.startGame': 'LANCER LA PARTIE',
  'lobby.waitingForPlayers': 'EN ATTENTE...',
  'lobby.waitingForHost': "EN ATTENTE DE L'HÔTE...",
  'lobby.teamHeader': 'ÉQUIPE {letter}',
  'lobby.joinTeam': 'REJOINDRE',
  'lobby.youSuffix': '(TOI)',
  'lobby.emptySlot': 'PLACE LIBRE',
  'victory.win': 'VICTOIRE !',
  'victory.loss': 'DÉFAITE',
  'victory.teamWins': "L'ÉQUIPE {team} REMPORTE LA PARTIE",
  'victory.playAgain': 'REJOUER',
  'game.roundBadge': 'TER7 {n}',
  'game.dealBadge': 'TFRI9A {n}/{total}',
  'game.emptyTable': 'TABLE VIDE',
  'game.pendingDerba': 'DERBA — SURENCHÈRE ?',
  'game.yourTurn': '✦ À TOI DE JOUER ✦',
  'game.playerTurn': 'AU TOUR DE {nickname}',
  'game.captureButton': 'CAPTURER !',
  'game.playButton': 'POSER',
  'game.quitTitle': 'QUITTER LA PARTIE ?',
  'game.quitBody': 'La partie sera annulée pour tous les joueurs.',
  'game.quitStay': 'RESTER',
  'game.quitConfirm': 'QUITTER',
  'game.announcementTringa': 'TRINGA !',
  'game.announcementRonda': 'RONDA !',
  'overlay.derbaTier1': 'DERBA !',
  'overlay.derbaTier2': '7BIYEL !',
  'overlay.derbaTier3': 'JOUJ 7BOULA !',
  'overlay.pointsEarned': '+{n} PTS · {nickname}',
  'overlay.missa': 'MISSA !',
  'overlay.revealNoAnnouncement': 'FIN DE LA TFRI9A',
  'overlay.revealAskAnnouncement': 'WACH KAYN CHI RWANED ?',
  'overlay.noAnnouncement': 'AUCUNE ANNONCE',
  'overlay.announcementRow': '{nickname} — {kind} DE {rank}',
  'overlay.teamHeader': 'ÉQUIPE {letter}',
  'overlay.pointsRow': '+{n} PTS',
  'overlay.tieNoPoints': 'ÉGALITÉ — AUCUN POINT',
  'overlay.roundEndTitle': 'FIN DU TER7',
  'overlay.cardsCollected': 'CARTES RAMASSÉES',
  'overlay.cardsCollectedValue': 'A {countA} — {countB} B',
  'overlay.butinTeam': 'BUTIN ÉQUIPE {letter}',
  'overlay.butinTie': 'BUTIN : ÉGALITÉ',
  'overlay.zeroPts': '0 PT',
  'overlay.lastCaptureKing': 'DERNIÈRE PRISE AU ROI',
  'overlay.lastCaptureAce': 'AS EN DERNIÈRE PRISE',
  'overlay.pointsTeamValue': '+{n} PTS ÉQ. {letter}',
  'overlay.dealBadge': 'TFRI9A {n}/{total}',
  'overlay.dealerDeals': '{nickname} DISTRIBUE',
  'overlay.tallyTitle': 'BUTIN DU TER7',
  'overlay.tallyTie': 'ÉGALITÉ 20-20',
  'overlay.tallyResult': '+{n} PTS · ÉQUIPE {letter}',
  'overlay.teamAbbrev': 'ÉQ. {letter}',
  'overlay.royalCapture': 'PRISE ROYALE !',
  'overlay.royalCaptureSub': 'LE ROI CONCLUT · +5 PTS ÉQUIPE {letter}',
  'overlay.aceOuch': "AÏE... L'AS !",
  'overlay.majebtich': 'MAJEBTICH 9A3TEK !',
  'overlay.aceSub': "DERNIÈRE PRISE À L'AS · +5 PTS POUR L'ADVERSAIRE",
  'overlay.majebtichSub': "LE LEAD N'A PAS FAIT LA DERNIÈRE PRISE...",
  'rank.as': 'As',
  'rank.valet': 'Valet',
  'rank.cavalier': 'Cavalier',
  'rank.roi': 'Roi',
  'suit.deniers': 'Deniers',
  'suit.coupes': 'Coupes',
  'suit.espadas': 'Épées',
  'suit.batons': 'Bâtons',
  'settings.title': 'PARAMÈTRES',
  'settings.language': 'LANGUE',
  'settings.languageFrench': 'Français',
  'settings.languageDarija': 'Darija',
  'settings.rules': 'RÈGLES DU JEU',
  'settings.back': 'RETOUR',
};

const Map<String, String> _dj = {
  'home.nicknameLabel': 'SMIYTEK',
  'home.nicknameHint': 'EX : HAMZA',
  'home.nicknameEmpty': 'KHTAR SMIYA',
  'home.codeLength': 'CODE KHASS YKOUN FIH 5 DL7OROF',
  'home.serverTimeout': 'SERVER TAYE7',
  'home.mode2v2': '2 DED 2',
  'home.mode1v1': '1 DED 1',
  'home.publicRoom': 'TL3EB DED NASS FL3ALAM ?',
  'home.createRoom': 'SEYEB TER7',
  'home.joinWithCode': 'DKHOL B CODE',
  'home.codeHint': 'ABCDE',
  'home.join': 'DKHOL',
  'home.publicRoomsTitle': 'TRO7A ME7LOULINE',
  'home.noPublicRooms': 'TA CHI TER7 MAME7LOUL',
  'home.roomOf': 'Ter7 dyal {nickname}',
  'home.roomSubtitle': '{mode} · {count}/{max} LE3AB',
  'home.settings': 'PARAMÈTRES',
  'lobby.codeCopied': 'CODE TCOPIA !',
  'lobby.headerBadge': '{mode} · {count}/{max} LE3AB',
  'lobby.codeLabel': 'CODE DYAL TER7 — WERREK BACH TCOLIH',
  'lobby.startGame': 'BDA TER7',
  'lobby.waitingForPlayers': 'TSENNA CHWIA...',
  'lobby.waitingForHost': 'TSENNA MOUL TER7...',
  'lobby.teamHeader': 'FRI9A {letter}',
  'lobby.joinTeam': 'DKHOL',
  'lobby.youSuffix': '(NTA)',
  'lobby.emptySlot': 'BLASSA KHAWYA',
  'victory.win': 'RBE7NA !',
  'victory.loss': 'KHSSERNA',
  'victory.teamWins': 'FRI9A {team} REBHAT TER7',
  'victory.playAgain': '3AWED L3EB',
  'game.roundBadge': 'TER7 {n}',
  'game.dealBadge': 'TFRI9A {n}/{total}',
  'game.emptyTable': 'TABLA KHAWYA',
  'game.pendingDerba': 'DERBA — 7BIYEL ?',
  'game.yourTurn': '✦ NOUBTEK ✦',
  'game.playerTurn': 'NOUBA DYAL {nickname}',
  'game.captureButton': 'HBET !',
  'game.playButton': '7OT',
  'game.quitTitle': 'BGHITI TKHREJ ?',
  'game.quitBody': 'Ter7 ghadi tlgha l koulchi.',
  'game.quitStay': 'B9A',
  'game.quitConfirm': 'KHREJ',
  'game.announcementTringa': 'TRINGA !',
  'game.announcementRonda': 'RONDA !',
  'overlay.derbaTier1': 'DERBA !',
  'overlay.derbaTier2': '7BIYEL !',
  'overlay.derbaTier3': 'JOUJ 7BOULA !',
  'overlay.pointsEarned': '+{n} PTS · {nickname}',
  'overlay.missa': 'MISSA !',
  'overlay.revealNoAnnouncement': 'AKHIR TFRI9A',
  'overlay.revealAskAnnouncement': 'WACH KAYN CHI RWANED ?',
  'overlay.noAnnouncement': 'MAKAYN HTA RONDA',
  'overlay.announcementRow': '{nickname} — {kind} DYAL {rank}',
  'overlay.teamHeader': 'FRI9A {letter}',
  'overlay.pointsRow': '+{n} PTS',
  'overlay.tieNoPoints': 'TA3ADOL — WALO POINT',
  'overlay.roundEndTitle': 'LEKHER DYAL TER7',
  'overlay.cardsCollected': "L9ESS",
  'overlay.cardsCollectedValue': 'A {countA} — {countB} B',
  'overlay.butinTeam': 'L7SSAB DIAL FRI9A {letter}',
  'overlay.butinTie': 'L7SSAB : TA3ADOL',
  'overlay.zeroPts': '0 PT',
  'overlay.lastCaptureKing': 'JEBTI 9A3TEK B TNACH',
  'overlay.lastCaptureAce': 'JEBTI 9A3TEK B AS',
  'overlay.pointsTeamValue': '+{n} PTS FRI9A {letter}',
  'overlay.dealBadge': 'TFRI9A {n}/{total}',
  'overlay.dealerDeals': '{nickname} KAYFAR9',
  'overlay.tallyTitle': 'L7SSAB DYAL TER7',
  'overlay.tallyTie': 'TA3ADOL 20-20',
  'overlay.tallyResult': '+{n} PTS · FRI9A {letter}',
  'overlay.teamAbbrev': 'FRI9A {letter}',
  'overlay.royalCapture': 'L9A3A B 12 !',
  'overlay.royalCaptureSub': 'L9A3A B 12 · +5 PTS FRI9A {letter}',
  'overlay.aceOuch': "AH... L'AS !",
  'overlay.majebtich': 'MAJEBTICH 9A3TEK !',
  'overlay.aceSub': 'AKHER HABTA B AS · +5 PTS L KHASM',
  'overlay.majebtichSub': 'MOUL L9A3A MAJABCH 9A3TOU',
  'rank.as': 'As',
  'rank.valet': 'Sota',
  'rank.cavalier': 'Cabal',
  'rank.roi': 'Tnach',
  'suit.deniers': 'Flouss',
  'suit.coupes': 'Guebbass',
  'suit.espadas': 'Syouf',
  'suit.batons': 'Zrawet',
  'settings.title': 'PARAMÈTRES',
  'settings.language': 'LOGHA',
  'settings.languageFrench': 'Français',
  'settings.languageDarija': 'Darija',
  'settings.rules': '9WANINE LO3BA',
  'settings.back': 'RJE3',
};

/// Provider de langue (GDD 3.x) : bascule Français / Darija, persistée entre
/// les lancements. Les termes de jeu (DERBA, MISSA, TER7, TFRI9A, RONDA,
/// TRINGA, 7BIYEL, JOUJ 7BOULA, MAJEBTICH 9A3TEK) sont volontairement
/// identiques dans les deux langues : ce sont les noms propres des règles.
class AppStrings extends ChangeNotifier {
  AppLanguage _language = AppLanguage.fr;
  AppLanguage get language => _language;

  AppStrings() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'dj') {
      _language = AppLanguage.dj;
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang == AppLanguage.dj ? 'dj' : 'fr');
  }

  /// Traduit une clé, avec substitution optionnelle de `{placeholder}`.
  String t(String key, [Map<String, Object>? args]) {
    final table = _language == AppLanguage.dj ? _dj : _fr;
    var value = table[key] ?? _fr[key] ?? key;
    if (args != null) {
      for (final entry in args.entries) {
        value = value.replaceAll('{${entry.key}}', '${entry.value}');
      }
    }
    return value;
  }
}
