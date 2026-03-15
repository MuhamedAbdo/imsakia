import 'package:flutter/foundation.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';

class QiblaProvider extends ChangeNotifier {
  Stream<QiblahDirection>? _qiblahStream;
  bool _supported = false;
  bool _initialized = false;

  Stream<QiblahDirection>? get qiblahStream => _qiblahStream;
  bool get isSupported => _supported;
  bool get isInitialized => _initialized;

  Future<void> initialize({double? lat, double? lon}) async {
    _supported = await FlutterQiblah.androidDeviceSensorSupport() ?? false;
    
    // Check for sensors AND valid coordinates to avoid "spinning"
    if (_supported && lat != null && lon != null) {
      _qiblahStream = FlutterQiblah.qiblahStream;
    } else {
      _qiblahStream = null;
    }
    
    _initialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    FlutterQiblah().dispose();
    super.dispose();
  }
}
