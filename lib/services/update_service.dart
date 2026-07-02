import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final bool updateAvailable;
  final bool esObligatorio;
  final String apkUrl;
  final String versionAString;

  UpdateInfo({
    required this.updateAvailable,
    required this.esObligatorio,
    required this.apkUrl,
    required this.versionAString,
  });
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final doc = await _firestore.collection('config').doc('app_version').get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final serverVersionCode = data['version_code'] as int? ?? 0;
      final serverVersionName = data['version_name'] as String? ?? '';
      final apkUrl = data['apk_url'] as String? ?? '';
      final esObligatorio = data['es_obligatorio'] as bool? ?? false;

      final packageInfo = await PackageInfo.fromPlatform();
      final localVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (serverVersionCode > localVersionCode && apkUrl.isNotEmpty) {
        return UpdateInfo(
          updateAvailable: true,
          esObligatorio: esObligatorio,
          apkUrl: apkUrl,
          versionAString: serverVersionName,
        );
      }
      return null;
    } catch (e) {
      print('Error checking for updates: $e');
      return null;
    }
  }
}
