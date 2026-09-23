/// Monetization hook (FUTURE).
///
/// The goal video shows a fullscreen ad after each game. Real ads arrive with
/// the `google_mobile_ads` integration (see docs/ADS_AND_ONLINE_ROADMAP.md).
/// Until then this is a deliberate no-op with a debug log, and the game-over
/// dialog shows a small "Ad placeholder" label.
library;

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';

class AdsService {
  /// Interstitial after a finished game.
  static Future<void> showGameEndAd() async {
    if (!AppConfig.adsEnabled) {
      debugPrint(
        '[Ads] game-end interstitial skipped (ADS_ENABLED=false).',
      );
      return;
    }
    // TODO(ads): load + show google_mobile_ads InterstitialAd here.
    debugPrint('[Ads] ADS_ENABLED=true but no ad units wired yet.');
  }

  /// Banner placeholder visibility (bottom of game screen in the video).
  static bool get showBannerPlaceholder =>
      !AppConfig.adsEnabled && kDebugMode;
}
