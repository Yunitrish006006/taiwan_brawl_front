import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../constants/app_constants.dart';

class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  Future<String> _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getVersion(),
      builder: (context, snapshot) {
        final version = snapshot.data ?? '';
        return Text(
          '${AppConstants.appName}${version.isNotEmpty ? ' v$version' : ''}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
