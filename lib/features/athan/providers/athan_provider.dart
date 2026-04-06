import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class Muezzin {
  final String id;
  final String name;
  final String normalAthanUrl;
  final String fajrAthanUrl;

  Muezzin({
    required this.id,
    required this.name,
    required this.normalAthanUrl,
    required this.fajrAthanUrl,
  });

  factory Muezzin.fromJson(Map<String, dynamic> json) {
    return Muezzin(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      normalAthanUrl: json['normalAthanUrl'] ?? '',
      fajrAthanUrl: json['fajrAthanUrl'] ?? '',
    );
  }
}

class AthanProvider with ChangeNotifier {
  // Storage keys
  static const String _prefEnabled = 'athan_enabled';
  static const String _prefUnified = 'athan_unified';
  static const String _prefNormalMuezzinId = 'selectedMuezzinId';
  static const String _prefFajrMuezzinId = 'selectedFajrMuezzinId';

  List<Muezzin> _muezzins = [];
  Muezzin? _selectedNormalMuezzin;
  Muezzin? _selectedFajrMuezzin;
  bool _isLoading = false;
  String? _localNormalPath;
  String? _localFajrPath;
  
  bool _isAthanEnabled = true; // Master Toggle
  bool _isUnifiedMuezzin = true; // One muezzin for all prayers vs specific

  List<Muezzin> get muezzins => _muezzins;
  Muezzin? get selectedNormalMuezzin => _selectedNormalMuezzin;
  Muezzin? get selectedFajrMuezzin => _selectedFajrMuezzin;
  bool get isLoading => _isLoading;
  String? get localNormalPath => _localNormalPath;
  String? get localFajrPath => _localFajrPath;
  
  bool get isAthanEnabled => _isAthanEnabled;
  bool get isUnifiedMuezzin => _isUnifiedMuezzin;

  final Dio _dio = Dio();

  AthanProvider() {
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isAthanEnabled = prefs.getBool(_prefEnabled) ?? true;
    _isUnifiedMuezzin = prefs.getBool(_prefUnified) ?? true;
    
    _localNormalPath = prefs.getString('localNormalAthanPath');
    _localFajrPath = prefs.getString('localFajrAthanPath');
    
    final normalId = prefs.getString(_prefNormalMuezzinId);
    final fajrId = prefs.getString(_prefFajrMuezzinId);
    if (_muezzins.isNotEmpty) {
      if (normalId != null) {
        try {
          _selectedNormalMuezzin = _muezzins.firstWhere((m) => m.id == normalId);
        } catch (_) {}
      }
      if (fajrId != null) {
        try {
          _selectedFajrMuezzin = _muezzins.firstWhere((m) => m.id == fajrId);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<void> fetchMuezzins() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Placeholder for your actual JSON API. 
      // Replace with:
      // final response = await _dio.get('https://your-api.com/muezzins.json');
      // _muezzins = (response.data as List).map((e) => Muezzin.fromJson(e)).toList();

      await Future.delayed(const Duration(milliseconds: 500));
      // استخدمنا روابط حقيقية مؤقتة تعمل لتجنب خطأ 404
      _muezzins = [
         Muezzin(
           id: "1", 
           name: "عبد الباسط عبد الصمد", 
           normalAthanUrl: "https://www.ayouby.com/multimedia/Call_of_Prayer/Athan_AB.mp3", 
           fajrAthanUrl: "https://www.ayouby.com/multimedia/Call_of_Prayer/Athan_AB.mp3"
         ),
         Muezzin(
           id: "2", 
           name: "أذان الحرم المكي", 
           normalAthanUrl: "https://download.tvquran.com/download/selections/380/6088219.mp3", 
           fajrAthanUrl: "https://download.tvquran.com/download/selections/380/6088219.mp3"
         ),
         Muezzin(
           id: "3", 
           name: "أذان المدينة المنورة", 
           normalAthanUrl: "https://raw.githubusercontent.com/AalianKhan/adhans/main/adhan.mp3", 
           fajrAthanUrl: "https://raw.githubusercontent.com/AalianKhan/adhans/main/adhan_fajr.mp3"
         ),
         Muezzin(
           id: "4", 
           name: "مشاري العفاسي", 
           normalAthanUrl: "https://tvquran.com/uploads/adhan/Mishary.mp3", 
           fajrAthanUrl: "https://tvquran.com/uploads/adhan/Mishary.mp3"
         ),
         Muezzin(
           id: "5", 
           name: "أذان الأقصى", 
           normalAthanUrl: "https://tvquran.com/uploads/adhan/Alaqsa.mp3", 
           fajrAthanUrl: "https://tvquran.com/uploads/adhan/Alaqsa.mp3"
         ),
         Muezzin(
           id: "6", 
           name: "أذان الفجر (مخصص)", 
           normalAthanUrl: "https://raw.githubusercontent.com/AalianKhan/adhans/main/adhan_fajr.mp3", 
           fajrAthanUrl: "https://raw.githubusercontent.com/AalianKhan/adhans/main/adhan_fajr.mp3"
         ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final normalId = prefs.getString(_prefNormalMuezzinId);
      final fajrId = prefs.getString(_prefFajrMuezzinId);
      
      if (normalId != null) {
        try {
          _selectedNormalMuezzin = _muezzins.firstWhere((m) => m.id == normalId);
        } catch (_) {}
      }
      
      if (fajrId != null) {
        try {
           _selectedFajrMuezzin = _muezzins.firstWhere((m) => m.id == fajrId);
        } catch (_) {}
      } else if (_selectedNormalMuezzin != null && _isUnifiedMuezzin) {
         _selectedFajrMuezzin = _selectedNormalMuezzin;
      }

    } catch (e) {
      debugPrint("Error fetching muezzins: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAthanEnabled(bool value) async {
    if (value) {
      // User wants to enable Athan, we must check for exact alarm permission on Android 14+
      final hasPermission = await requestExactAlarmPermission();
      if (!hasPermission) {
        // Permission denied, do not enable
        _isAthanEnabled = false;
        notifyListeners();
        return;
      }
    }

    _isAthanEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    notifyListeners();
  }

  Future<bool> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied || status.isRestricted) {
        final result = await Permission.scheduleExactAlarm.request();
        if (result.isDenied || result.isPermanentlyDenied) {
          debugPrint("Exact alarm permission denied by user");
          return false;
        }
      }
    }
    return true;
  }

  Future<void> setUnifiedMuezzin(bool value) async {
    _isUnifiedMuezzin = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUnified, value);
    
    // If we turned ON unified, we update Fajr muezzin to match normal
    if (value && _selectedNormalMuezzin != null) {
      await selectMuezzinForFajr(_selectedNormalMuezzin!);
    }
    
    notifyListeners();
  }

  Future<void> selectMuezzinForNormal(Muezzin muezzin) async {
    _selectedNormalMuezzin = muezzin;
    _isLoading = true;
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final normalPath = '${dir.path}/athan_${muezzin.id}_normal.mp3';
      final prefs = await SharedPreferences.getInstance();

      if (!File(normalPath).existsSync()) {
         await _dio.download(muezzin.normalAthanUrl, normalPath);
      }

      _localNormalPath = normalPath;
      await prefs.setString('localNormalAthanPath', normalPath);
      await prefs.setString(_prefNormalMuezzinId, muezzin.id);
      
      // If unified, also select for Fajr implicitly
      if (_isUnifiedMuezzin) {
        await selectMuezzinForFajr(muezzin);
      }

    } catch (e) {
      debugPrint("Error downloading normal athan files: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectMuezzinForFajr(Muezzin muezzin) async {
    _selectedFajrMuezzin = muezzin;
    if (!_isUnifiedMuezzin) {
      _isLoading = true;
      notifyListeners();
    } // Skip loading if called from unified

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fajrPath = '${dir.path}/athan_${muezzin.id}_fajr.mp3';
      final prefs = await SharedPreferences.getInstance();

      if (!File(fajrPath).existsSync()) {
         await _dio.download(muezzin.fajrAthanUrl, fajrPath);
      }

      _localFajrPath = fajrPath;
      await prefs.setString('localFajrAthanPath', fajrPath);
      await prefs.setString(_prefFajrMuezzinId, muezzin.id);

    } catch (e) {
      debugPrint("Error downloading fajr athan files: $e");
    } finally {
      if (!_isUnifiedMuezzin || _isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Opens the system battery optimization settings for this app.
  /// Crucial for Xiaomi users to select "No Restrictions".
  Future<void> openBatteryOptimizationSettings() async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('imsakia/notifications');
        await channel.invokeMethod('openBatteryOptimizationSettings');
      } catch (e) {
        debugPrint("Error opening battery settings: $e");
      }
    }
  }
}
