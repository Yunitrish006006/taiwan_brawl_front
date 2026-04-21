import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 廣告 Unit ID — 上線前請替換為 AdMob 後台的正式 ID
class _AdUnitIds {
  // ── Banner ──────────────────────────────────────────────
  static const String _androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBanner = 'ca-app-pub-3940256099942544/2934735716';

  // ── Interstitial ────────────────────────────────────────
  static const String _androidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  static String get banner =>
      Platform.isAndroid ? _androidBanner : _iosBanner;

  static String get interstitial =>
      Platform.isAndroid ? _androidInterstitial : _iosInterstitial;
}

class AdService {
  AdService._();

  static bool _initialized = false;

  /// 在 main() 中呼叫一次，僅在 iOS / Android 執行
  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // ── Banner ──────────────────────────────────────────────

  /// 建立並載入一個 Banner 廣告，回傳已載入的 [BannerAd]。
  /// 呼叫方負責在 widget dispose 時呼叫 [BannerAd.dispose]。
  static Future<BannerAd> loadBanner({
    AdSize size = AdSize.banner,
    void Function(Ad, LoadAdError)? onFailed,
  }) {
    final completer = Future<BannerAd>.value;
    late final BannerAd ad;
    final future = Future<BannerAd>(() async {
      await Future.microtask(() {});
      return ad;
    });

    ad = BannerAd(
      adUnitId: _AdUnitIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (a, err) => onFailed?.call(a, err),
      ),
    )..load();

    return future;
  }

  // ── Interstitial ────────────────────────────────────────

  /// 載入一個全版廣告；載入完成後透過 [onLoaded] 回傳。
  static void loadInterstitial({
    required void Function(InterstitialAd ad) onLoaded,
    void Function(LoadAdError)? onFailed,
  }) {
    InterstitialAd.load(
      adUnitId: _AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (err) => onFailed?.call(err),
      ),
    );
  }
}
