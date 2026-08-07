# Règles R8/ProGuard pour le build release.
#
# Contexte : le SDK Google Mobile Ads (play-services-ads) tire transitivement
# androidx.work (WorkManager) + androidx.room. Au démarrage, androidx.startup
# InitializationProvider initialise WorkManager, qui crée sa WorkDatabase (Room).
# R8 considère WorkDatabase_Impl / les Workers comme inutilisés (ils ne le sont
# qu'au runtime, par réflexion) et les supprime -> crash au lancement :
#   RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase
# Ces règles disent à R8 de ne pas y toucher.

# WorkManager : implémentation Room générée + tous les Workers instanciés par réflexion.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Room : les *_Impl générés et les entités/DAO sont résolus par réflexion au runtime.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**

# WorkManager (par sécurité, garde l'API publique utilisée par le provider de démarrage).
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
