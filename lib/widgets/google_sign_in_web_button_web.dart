import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildGoogleSignInWebButton({
  required bool loading,
  required double frameWidth,
  required bool useDarkTheme,
}) {
  final googleButtonTheme = useDarkTheme
      ? google_web.GSIButtonTheme.filledBlack
      : google_web.GSIButtonTheme.outline;

  return IgnorePointer(
    ignoring: loading,
    child: Opacity(
      opacity: loading ? 0.7 : 1,
      child: SizedBox(
        height: 56,
        child: Center(
          child: google_web.renderButton(
            configuration: google_web.GSIButtonConfiguration(
              theme: googleButtonTheme,
              text: google_web.GSIButtonText.signinWith,
              size: google_web.GSIButtonSize.large,
              shape: google_web.GSIButtonShape.rectangular,
              minimumWidth: frameWidth,
            ),
          ),
        ),
      ),
    ),
  );
}
