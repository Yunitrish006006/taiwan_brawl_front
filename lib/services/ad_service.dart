import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_configuration.dart';

/// 廣告 Unit ID — 上線前請替換為 AdMob 後台的正式 ID
class _AdUnitIds {
  static String banner(AppConfiguration configuration) => Platform.isAndroid
      ? configuration.androidBannerAdUnitId
      : configuration.iosBannerAdUnitId;

  static String interstitial(AppConfiguration configuration) =>
      Platform.isAndroid
      ? configuration.androidInterstitialAdUnitId
      : configuration.iosInterstitialAdUnitId;
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
    AppConfiguration? configuration,
  }) {
    late final BannerAd ad;
    final future = Future<BannerAd>(() async {
      await Future.microtask(() {});
      return ad;
    });

    ad = BannerAd(
      adUnitId: _AdUnitIds.banner(
        configuration ?? AppConfiguration.environment,
      ),
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
    AppConfiguration? configuration,
  }) {
    InterstitialAd.load(
      adUnitId: _AdUnitIds.interstitial(
        configuration ?? AppConfiguration.environment,
      ),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (err) => onFailed?.call(err),
      ),
    );
  }
}
