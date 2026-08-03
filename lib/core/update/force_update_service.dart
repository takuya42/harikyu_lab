import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const minimumVersionKey = 'minimum_version';

final forceUpdateServiceProvider = Provider<ForceUpdateService>(
  (ref) => ForceUpdateService(FirebaseRemoteConfig.instance),
);

class ForceUpdateService {
  const ForceUpdateService(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  Future<bool> isUpdateRequired() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ),
    );
    await _remoteConfig.setDefaults(const {minimumVersionKey: ''});
    await _remoteConfig.fetchAndActivate();

    final minimumVersion = _remoteConfig.getString(minimumVersionKey).trim();
    if (minimumVersion.isEmpty) return false;
    final packageInfo = await PackageInfo.fromPlatform();
    return compareVersions(packageInfo.version, minimumVersion) < 0;
  }

  Future<void> openStore() async {
    final Uri uri;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      uri = Uri.parse('itms-apps://itunes.apple.com/search?term=はりきゅうラボ');
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      uri = Uri.parse(
        'market://details?id=com.harikyu_lab.harikyu_lab',
      );
    } else {
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('アプリストアを開けませんでした。');
    }
  }
}

/// Compares dotted numeric versions without treating 1.10 as a decimal.
int compareVersions(String current, String minimum) {
  List<int> parts(String value) => value
      .split('+').first
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9].*'), '')) ?? 0)
      .toList();

  final left = parts(current);
  final right = parts(minimum);
  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final leftPart = index < left.length ? left[index] : 0;
    final rightPart = index < right.length ? right[index] : 0;
    if (leftPart != rightPart) return leftPart.compareTo(rightPart);
  }
  return 0;
}
