import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/athan_remote_datasource.dart';
import '../data/models/athan_model.dart';

/// حالات تحميل الملف
enum DownloadStatus { idle, downloading, done, error }

/// Provider لإدارة مكتبة الأذان (جلب البيانات، التشغيل، التحميل، الحفظ، ودعم وضع عدم الاتصال)
class AthanLibraryProvider with ChangeNotifier {
  // ─── مفاتيح SharedPreferences للصلوات ──────────────────────────────────────
  static String _keyIdFor(String prayerKey) => 'athan_library_id_$prayerKey';
  static String _keyNameFor(String prayerKey) => 'athan_library_name_$prayerKey';
  // Note: we save the absolute path directly to the key that Native Android uses.
  static String _keyPathFor(String prayerKey) => 'athan_path_$prayerKey';

  // ─── بادئة اسم الملف المحمَّل (ثابتة وفريدة لكل أذان) ────────────────────
  static const String _filePrefix = 'downloaded_athan_';

  // ─── الأصوات المدمجة في الـ Assets (جاهزة بدون إنترنت) ───────────────────
  static const List<AthanModel> assetNormalAthans = [
    AthanModel(
      id: "ab_egypt",
      name: "عبد الباسط - مصر",
      url: "",
      isFajr: false,
      assetPath: "assets/audio/athan_egypt_ab.mp3",
    ),
    AthanModel(
      id: "saad_ghamdi",
      name: "سعد الغامدي",
      url: "",
      isFajr: false,
      assetPath: "assets/audio/athan_ghamdi.mp3",
    ),
    AthanModel(
      id: "makkah",
      name: "أذان مكة",
      url: "",
      isFajr: false,
      assetPath: "assets/audio/athan_makkah.mp3",
    ),
    AthanModel(
      id: "mishary",
      name: "مشاري العفاسي",
      url: "",
      isFajr: false,
      assetPath: "assets/audio/athan_mishari.mp3",
    ),
    AthanModel(
      id: "rifaat",
      name: "محمد رفعت",
      url: "",
      isFajr: false,
      assetPath: "assets/audio/athan_rifaat.mp3",
    ),
    AthanModel(
      id: "elbna",
      name: "محمود علي البنا",
      url: "",
      isFajr: false,
      assetPath: "assets/audio/elbna.mp3",
    ),
    AthanModel(
      id: "aboelenin",
      name: "أبو العينين شعيشع",
      url: "",
      isFajr: false,
      assetPath: "assets/audio/aboelenin.mp3",
    ),
  ];

  static const List<AthanModel> assetFajrAthans = [
    AthanModel(
      id: "ab_fajr",
      name: "عبد الباسط (فجر)",
      url: "",
      isFajr: true,
      assetPath: "assets/audio/fajr_abdulbaset.mp3",
    ),
    AthanModel(
      id: "madinah_fajr",
      name: "أذان المدينة المنورة",
      url: "",
      isFajr: true,
      assetPath: "assets/audio/fajr_madinah.mp3",
    ),
    AthanModel(
      id: "makkah_fajr",
      name: "أذان مكة (فجر)",
      url: "",
      isFajr: true,
      assetPath: "assets/audio/fajr_makkah.mp3",
    ),
    AthanModel(
      id: "mishary_fajr",
      name: "مشاري العفاسي (فجر)",
      url: "",
      isFajr: true,
      assetPath: "assets/audio/fajr_mishari.mp3",
    ),
  ];

  /// البحث عن صوت مدمج بالـ id
  static AthanModel? findAssetById(String id) {
    for (final a in assetNormalAthans) {
      if (a.id == id) return a;
    }
    for (final a in assetFajrAthans) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// البحث عن صوت مدمج بمسار الـ asset
  static AthanModel? findAssetByPath(String path) {
    for (final a in assetNormalAthans) {
      if (a.assetPath == path) return a;
    }
    for (final a in assetFajrAthans) {
      if (a.assetPath == path) return a;
    }
    return null;
  }

  /// هل الـ id يتبع صوتاً مدمجاً في الـ assets
  static bool isAssetId(String id) => findAssetById(id) != null;

  // ─── Data source ──────────────────────────────────────────────────────────
  final AthanRemoteDataSource _remoteDataSource;

  AthanLibraryProvider({AthanRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? AthanRemoteDataSourceImpl() {
    _init();
  }

  // ─── State ────────────────────────────────────────────────────────────────
  List<AthanModel> _allAthans = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String? _errorMessage;

  /// الأذان الذي يُعاد تشغيله حاليًا (null = لا يوجد)
  String? _playingId;

  /// حالة تحميل كل أذان (key = id)
  final Map<String, DownloadStatus> _downloadStatus = {};

  /// نسبة التحميل (0.0 → 1.0) لكل أذان
  final Map<String, double> _downloadProgress = {};

  /// الأذانات المحفوظة محلياً (key = id, value = مسار الملف على القرص)
  final Map<String, String> _localPaths = {};

  /// المعرفات المحفوظة لكل صلاة (key: prayerKey, value: id)
  final Map<String, String> _assignedIds = {};

  /// الأسماء المحفوظة لكل صلاة (key: prayerKey, value: name)
  final Map<String, String> _assignedNames = {};

  // ─── Getters ──────────────────────────────────────────────────────────────
  /// قائمة الأذان العادي من السيرفر (في وضع عدم الاتصال تُعرض فقط الأصوات المحمّلة محلياً، ومستبعد منها التكبيرات)
  List<AthanModel> get normalAthans {
    final list = _allAthans
        .where((a) => !a.isFajr && !a.name.contains('تكبيرات'));
    if (_isOffline) {
      return list.where((a) => isDownloaded(a.id)).toList();
    }
    return list.toList();
  }

  /// قائمة أذان الفجر من السيرفر (في وضع عدم الاتصال تُعرض فقط الأصوات المحمّلة محلياً، ومستبعد منها التكبيرات)
  List<AthanModel> get fajrAthans {
    final list = _allAthans
        .where((a) => a.isFajr && !a.name.contains('تكبيرات'));
    if (_isOffline) {
      return list.where((a) => isDownloaded(a.id)).toList();
    }
    return list.toList();
  }

  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;
  String? get playingId => _playingId;

  /// هل تتوفر أي أصوات محملة محلياً على الجهاز من السيرفر
  bool get hasOfflineAthans => _allAthans
      .where((a) => !a.name.contains('تكبيرات'))
      .any((a) => isDownloaded(a.id));

  /// إرجاع اسم الأذان المعين لصلاة معينة
  String getAssignedNameFor(String prayerKey) {
    final name = _assignedNames[prayerKey];
    if (name != null && name.isNotEmpty) return name;
    return prayerKey == 'fajr' ? 'أذان مكة (فجر)' : 'أذان مكة';
  }

  /// إرجاع ID الأذان المعين لصلاة معينة
  String getAssignedIdFor(String prayerKey) {
    final id = _assignedIds[prayerKey];
    if (id != null && id.isNotEmpty) return id;
    return prayerKey == 'fajr' ? 'makkah_fajr' : 'makkah';
  }

  /// هل الصلاة المعينة لها أذان سحابي؟
  bool hasCloudAthanFor(String prayerKey) {
    final id = _assignedIds[prayerKey];
    if (id == null) return false;
    return !isAssetId(id);
  }

  /// هل هذا الأذان معين لأي صلاة؟
  bool isAssigned(String id) => _assignedIds.containsValue(id);

  /// إرجاع قائمة بالصلوات التي تم تعيين هذا الأذان لها
  List<String> getPrayersAssignedTo(String id) {
    return _assignedIds.entries
        .where((entry) => entry.value == id)
        .map((entry) => entry.key)
        .toList();
  }

  DownloadStatus downloadStatusOf(String id) {
    if (isAssetId(id)) return DownloadStatus.done;
    return _downloadStatus[id] ?? DownloadStatus.idle;
  }

  double downloadProgressOf(String id) {
    if (isAssetId(id)) return 1.0;
    return _downloadProgress[id] ?? 0.0;
  }

  /// هل الملف موجود وجاهز للاستخدام؟ الأصوات المدمجة دائماً true
  bool isDownloaded(String id) {
    if (isAssetId(id)) return true;
    if (_downloadStatus[id] == DownloadStatus.done &&
        _localPaths.containsKey(id)) {
      final p = _localPaths[id]!;
      if (File(p).existsSync()) return true;
    }
    final cachedPath = _localPaths[id];
    if (cachedPath != null && File(cachedPath).existsSync()) {
      return true;
    }
    return false;
  }

  /// مسار الملف المحلي أو الـ asset للأذان
  String? localPathOf(String id) {
    final asset = findAssetById(id);
    if (asset != null) return asset.assetPath;
    return _localPaths[id];
  }

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    await _loadSavedDefaults();
    await _scanLocalFiles(); // استعادة الملفات المحمّلة مسبقاً عند إعادة التشغيل
    await fetchAthans();
  }

  /// يفحص مجلد Documents ويستعيد أي ملفات سبق تحميلها بالبادئة الثابتة
  Future<void> _scanLocalFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.path.split('/').last.split('\\').last;
          if (fileName.startsWith(_filePrefix) && fileName.endsWith('.mp3')) {
            // استخراج الـ id من اسم الملف: downloaded_athan_{id}.mp3
            final id = fileName
                .replaceFirst(_filePrefix, '')
                .replaceFirst('.mp3', '');
            if (id.isNotEmpty && await entity.exists()) {
              _localPaths[id] = entity.path;
              _downloadStatus[id] = DownloadStatus.done;
              _downloadProgress[id] = 1.0;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AthanLibrary] _scanLocalFiles error: $e');
    }
  }

  Future<void> _loadSavedDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (var p in prayers) {
      final id = prefs.getString(_keyIdFor(p));
      final name = prefs.getString(_keyNameFor(p));
      final path = prefs.getString(_keyPathFor(p));

      if (id != null && id.isNotEmpty) {
        _assignedIds[p] = id;
      } else if (path != null && path.isNotEmpty) {
        final asset = findAssetByPath(path);
        _assignedIds[p] = asset?.id ?? (p == 'fajr' ? 'makkah_fajr' : 'makkah');
      } else {
        _assignedIds[p] = (p == 'fajr' ? 'makkah_fajr' : 'makkah');
      }

      if (name != null && name.isNotEmpty) {
        _assignedNames[p] = name;
      } else if (path != null && path.isNotEmpty) {
        final asset = findAssetByPath(path);
        _assignedNames[p] = asset?.name ?? (p == 'fajr' ? 'أذان مكة (فجر)' : 'أذان مكة');
      } else {
        _assignedNames[p] = (p == 'fajr' ? 'أذان مكة (فجر)' : 'أذان مكة');
      }
    }
    notifyListeners();
  }

  /// يُعيد تحميل الإعدادات من SharedPreferences — يُستدعى بعد العودة من شاشة المكتبة
  Future<void> syncFromPrefs() async {
    await _loadSavedDefaults();
  }

  /// مسح الأذان والعودة لأذان مكة الافتراضي
  Future<void> clearDefault({required String prayerKey}) async {
    final prefs = await SharedPreferences.getInstance();

    if (prayerKey == 'all') {
      final normalPrayers = ['dhuhr', 'asr', 'maghrib', 'isha'];
      for (var p in normalPrayers) {
        _assignedIds[p] = 'makkah';
        _assignedNames[p] = 'أذان مكة';
        await prefs.setString(_keyIdFor(p), 'makkah');
        await prefs.setString(_keyNameFor(p), 'أذان مكة');
        await prefs.setString(_keyPathFor(p), "assets/audio/athan_makkah.mp3");
      }
    } else {
      final defaultId = prayerKey == 'fajr' ? 'makkah_fajr' : 'makkah';
      final defaultName = prayerKey == 'fajr' ? 'أذان مكة (فجر)' : 'أذان مكة';
      final fallbackPath = prayerKey == 'fajr'
          ? "assets/audio/fajr_makkah.mp3"
          : "assets/audio/athan_makkah.mp3";

      _assignedIds[prayerKey] = defaultId;
      _assignedNames[prayerKey] = defaultName;
      await prefs.setString(_keyIdFor(prayerKey), defaultId);
      await prefs.setString(_keyNameFor(prayerKey), defaultName);
      await prefs.setString(_keyPathFor(prayerKey), fallbackPath);
    }

    notifyListeners();
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────
  Future<void> fetchAthans() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _remoteDataSource.fetchAthans();
      _allAthans = fetched.where((a) => !a.name.contains('تكبيرات')).toList();
      _isOffline = false;
      _errorMessage = null;
    } catch (e) {
      debugPrint(
          '[AthanLibrary] Network fetch failed: $e. Checking offline cache...');
      _isOffline = true;

      // تحديث قائمة الملفات المحلية المحفوظة على القرص
      await _scanLocalFiles();

      // استرجاع القائمة المخزنة مؤقتاً
      final cachedAthans = await _remoteDataSource.getCachedAthans();
      if (cachedAthans.isNotEmpty) {
        _allAthans =
            cachedAthans.where((a) => !a.name.contains('تكبيرات')).toList();
      }
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Preview playback ─────────────────────────────────────────────────────
  void setPlayingId(String? id) {
    _playingId = id;
    notifyListeners();
  }

  // ─── Download & Set ───────────────────────────────────────────────────────
  /// تعيين الأذان مباشرة (إذا كان مدمجاً أو محملاً) أو تحميله ثم تعيينه
  Future<String?> downloadAndSet(AthanModel athan,
      {required String prayerKey}) async {
    // إذا كان صوتاً مدمجاً في الـ assets
    if (athan.isAsset) {
      await _saveAsDefault(athan, prayerKey: prayerKey, localPath: athan.assetPath!);
      return athan.assetPath;
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = '$_filePrefix${athan.id}.mp3';
    final filePath = '${dir.path}/$fileName';

    // ─── تحقق 1: هل الملف موجود في الذاكرة (نفس الجلسة)؟ ─────────────────
    if (_localPaths.containsKey(athan.id)) {
      debugPrint(
          '[AthanLibrary] ✅ Cache hit for ${athan.id}, setting as default for $prayerKey');
      await _saveAsDefault(athan,
          prayerKey: prayerKey, localPath: _localPaths[athan.id]!);
      return _localPaths[athan.id];
    }

    // ─── تحقق 2: هل الملف موجود على القرص (جلسة سابقة)؟ ──────────────────
    final file = File(filePath);
    if (await file.exists()) {
      debugPrint(
          '[AthanLibrary] 💾 Disk hit for ${athan.id}, skipping download');
      _localPaths[athan.id] = filePath;
      _downloadStatus[athan.id] = DownloadStatus.done;
      _downloadProgress[athan.id] = 1.0;
      await _saveAsDefault(athan, prayerKey: prayerKey, localPath: filePath);
      notifyListeners();
      return filePath;
    }

    // ─── لا يوجد: تحميل من الإنترنت ────────────────────────────────────────
    debugPrint('[AthanLibrary] ⬇️ Downloading ${athan.name} (${athan.id})...');
    _downloadStatus[athan.id] = DownloadStatus.downloading;
    _downloadProgress[athan.id] = 0.0;
    notifyListeners();

    try {
      final request = http.Request('GET', Uri.parse(athan.url));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          _downloadProgress[athan.id] = received / contentLength;
          notifyListeners();
        }
      }
      await sink.close();

      _localPaths[athan.id] = filePath;
      _downloadStatus[athan.id] = DownloadStatus.done;
      _downloadProgress[athan.id] = 1.0;
      await _saveAsDefault(athan, prayerKey: prayerKey, localPath: filePath);
      debugPrint('[AthanLibrary] ✅ Downloaded: $filePath');
      notifyListeners();
      return filePath;
    } catch (e) {
      _downloadStatus[athan.id] = DownloadStatus.error;
      notifyListeners();
      debugPrint('[AthanLibrary] ❌ Download error: $e');
      return null;
    }
  }

  Future<void> _saveAsDefault(AthanModel athan,
      {required String prayerKey, String? localPath}) async {
    final prefs = await SharedPreferences.getInstance();
    final path = localPath ?? (athan.isAsset ? athan.assetPath! : (_localPaths[athan.id] ?? ''));

    if (prayerKey == 'all') {
      final normalPrayers = ['dhuhr', 'asr', 'maghrib', 'isha'];
      for (var p in normalPrayers) {
        _assignedIds[p] = athan.id;
        _assignedNames[p] = athan.name;
        await prefs.setString(_keyIdFor(p), athan.id);
        await prefs.setString(_keyNameFor(p), athan.name);
        if (path.isNotEmpty) await prefs.setString(_keyPathFor(p), path);
      }
    } else {
      _assignedIds[prayerKey] = athan.id;
      _assignedNames[prayerKey] = athan.name;
      await prefs.setString(_keyIdFor(prayerKey), athan.id);
      await prefs.setString(_keyNameFor(prayerKey), athan.name);
      if (path.isNotEmpty) await prefs.setString(_keyPathFor(prayerKey), path);
    }

    notifyListeners();
  }
}
