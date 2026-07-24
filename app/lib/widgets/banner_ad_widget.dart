import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_ids.dart';

/// Bannière AdMob adaptative ancrée. Se dimensionne à la largeur réellement
/// disponible (jamais la taille fixe 320px, qui déborderait sur un écran de
/// 320 dp avec le padding du lobby). Se rend invisible (SizedBox.shrink) tant
/// que l'annonce n'est pas chargée, et si le chargement échoue — jamais de
/// trou gris ni de rayures d'overflow dans la mise en page.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  // Largeur pour laquelle la bannière courante a été demandée : évite de
  // recharger à chaque rebuild du LayoutBuilder tant que la largeur ne change pas.
  int? _loadedForWidth;

  Future<void> _loadBanner(double availableWidth) async {
    final width = availableWidth.truncate();
    if (width <= 0 || width == _loadedForWidth) return;
    _loadedForWidth = width;

    // Taille adaptative ancrée = hauteur optimale pour la largeur donnée,
    // sans jamais dépasser cette largeur.
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
      Orientation.portrait,
      width,
    );
    if (size == null || !mounted) return;

    // Une largeur plus récente a été demandée entre-temps : on abandonne.
    if (width != _loadedForWidth) return;

    // Remplace toute bannière précédente (changement de largeur).
    _bannerAd?.dispose();
    _isLoaded = false;

    final banner = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd = banner;
    await banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // La largeur peut être infinie si le parent ne la borne pas : on
        // retombe alors sur la largeur de l'écran.
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        // Le chargement est asynchrone : déclenché après le frame courant.
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanner(width));

        final banner = _bannerAd;
        if (!_isLoaded || banner == null) return const SizedBox.shrink();
        return SizedBox(
          width: banner.size.width.toDouble(),
          height: banner.size.height.toDouble(),
          child: AdWidget(ad: banner),
        );
      },
    );
  }
}
