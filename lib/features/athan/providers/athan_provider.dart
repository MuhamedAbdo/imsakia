import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/prayer_times_service.dart';
import '../services/athan_manager.dart';

class Muezzin {
  final String id;
  final String name;
  final String path;
  final bool isFajr;

  Muezzin({
    required this.id,
    required this.name,
    required this.path,
    this.isFajr = false,
  });
}

class AthanProvider with ChangeNotifier {
  static const String _prefEnabled = 'athan_enabled';
  static const String _prefUnified = 'athan_unified';

  final List<Muezzin> _generalMuezzins = [
    Muezzin(id: "ab_egypt", name: "عبد الباسط - مصر", path: "assets/audio/athan_egypt_ab.mp3"),
    Muezzin(id: "saad_ghamdi", name: "سعد الغامدي", path: "assets/audio/athan_ghamdi.mp3"),
    Muezzin(id: "makkah", name: "أذان مكة", path: "assets/audio/athan_makkah.mp3"),
    Muezzin(id: "mishary", name: "مشاري العفاسي", path: "assets/audio/athan_mishari.mp3"),
    Muezzin(id: "rifaat", name: "محمد رفعت", path: "assets/audio/athan_rifaat.mp3"),
    Muezzin(id: "elbna", name: "محمود علي البنا", path: "assets/audio/elbna.mp3"),
    Muezzin(id: "aboelenin", name: "أبو العينين شعيشع", path: "assets/audio/aboelenin.mp3"),
  ];

  final List<Muezzin> _fajrMuezzins = [
    Muezzin(id: "ab_fajr", name: "عبد الباسط (فجر)", path: "assets/audio/fajr_abdulbaset.mp3", isFajr: true),
    Muezzin(id: "madinah_fajr", name: "أذان المدينة المنورة", path: "assets/audio/fajr_madinah.mp3", isFajr: true),
    Muezzin(id: "makkah_fajr", name: "أذان مكة (فجر)", path: "assets/audio/fajr_makkah.mp3", isFajr: true),
    Muezzin(id: "mishary_fajr", name: "مشاري العفاسي (فجر)", path: "assets/audio/fajr_mishari.mp3", isFajr: true),
  ];

  bool _isAthanEnabled = true;
  bool _isUnifiedMuezzin = true;
  bool _isBatteryOptimized = false;
  final Map<String, String> _prayerPaths = {};

  List<Muezzin> get generalMuezzins => _generalMuezzins;
  List<Muezzin> get fajrMuezzins => _fajrMuezzins;
  bool get isAthanEnabled => _isAthanEnabled;
  bool get isUnifiedMuezzin => _isUnifiedMuezzin;
  bool get isBatteryOptimized => _isBatteryOptimized;

  AthanProvider() {
    _loadSavedSettings();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      _isBatteryOptimized = !(await Permission.ignoreBatteryOptimizations.isGranted);
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    await _checkPermissions();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isAthanEnabled = prefs.getBool(_prefEnabled) ?? true;
    _isUnifiedMuezzin = prefs.getBool(_prefUnified) ?? true;
    
    _prayerPaths['fajr'] = prefs.getString('athan_path_fajr') ?? "assets/audio/fajr_makkah.mp3";
    _prayerPaths['dhuhr'] = prefs.getString('athan_path_dhuhr') ?? "assets/audio/athan_makkah.mp3";
    _prayerPaths['asr'] = prefs.getString('athan_path_asr') ?? "assets/audio/athan_makkah.mp3";
    _prayerPaths['maghrib'] = prefs.getString('athan_path_maghrib') ?? "assets/audio/athan_makkah.mp3";
    _prayerPaths['isha'] = prefs.getString('athan_path_isha') ?? "assets/audio/athan_makkah.mp3";

    notifyListeners();
  }

  String getPathForPrayer(String prayerKey) {
    if (prayerKey == 'fajr') {
      return _prayerPaths[prayerKey] ?? "assets/audio/fajr_makkah.mp3";
    }
    return _prayerPaths[prayerKey] ?? "assets/audio/athan_makkah.mp3";
  }

  Future<void> setAthanEnabled(bool value) async {
    if (value) {
      final hasPermission = await requestExactAlarmPermission();
      if (!hasPermission) {
        _isAthanEnabled = false;
        notifyListeners();
        return;
      }
    }

    _isAthanEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    
    if (value) {
      PrayerTimesService.instance.scheduleAllPrayers();
    } else {
      await AthanManager.cancelAllAlarms();
    }
    
    notifyListeners();
  }

  Future<void> setUnifiedMuezzin(bool value) async {
    _isUnifiedMuezzin = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUnified, value);
    
    if (value) {
      // ⚡ توحيد الصلوات الأربع العادية فقط - الفجر مستثنى تماماً ولا يتأثر
      final dhuhrPath = _prayerPaths['dhuhr'] ?? "assets/audio/athan_makkah.mp3";
      await setPrayerMuezzin('asr', dhuhrPath);
      await setPrayerMuezzin('maghrib', dhuhrPath);
      await setPrayerMuezzin('isha', dhuhrPath);
      // 🔒 الفجر محصّن: لا نلمسه هنا أبداً
    }
    
    notifyListeners();
  }

  Future<void> setPrayerMuezzin(String prayerKey, String path) async {
    _prayerPaths[prayerKey] = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('athan_path_$prayerKey', path);
    
    if (_isUnifiedMuezzin && prayerKey != 'fajr') {
       _prayerPaths['asr'] = path;
       _prayerPaths['maghrib'] = path;
       _prayerPaths['isha'] = path;
       await prefs.setString('athan_path_asr', path);
       await prefs.setString('athan_path_maghrib', path);
       await prefs.setString('athan_path_isha', path);
    }

    notifyListeners();
  }

  Future<bool> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied || status.isRestricted) {
        final result = await Permission.scheduleExactAlarm.request();
        if (result.isDenied || result.isPermanentlyDenied) {
          return false;
        }
      }
    }
    return true;
  }
}
