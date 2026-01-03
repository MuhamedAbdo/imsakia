import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

class QuranPagesService {
  static QuranPagesService? _instance;
  static QuranPagesService get instance => _instance ??= QuranPagesService._();

  QuranPagesService._();

  static const int totalPages = 604;
  
  // بيانات الأرباع الدقيقة - صفحة بداية كل ربع
  static const Map<int, String> quranQuarters = {
    1: 'الجزء 1 - الربع 1',
    4: 'الجزء 1 - الربع 2', 
    7: 'الجزء 1 - الربع 3',
    10: 'الجزء 1 - الربع 4',
    13: 'الجزء 1 - الربع 5',
    15: 'الجزء 1 - الربع 6',
    18: 'الجزء 1 - الربع 7',
    20: 'الجزء 1 - الربع 8',
    22: 'الجزء 2 - الربع 1',
    25: 'الجزء 2 - الربع 2',
    27: 'الجزء 2 - الربع 3',
    30: 'الجزء 2 - الربع 4',
    33: 'الجزء 2 - الربع 5',
    35: 'الجزء 2 - الربع 6',
    38: 'الجزء 2 - الربع 7',
    40: 'الجزء 2 - الربع 8',
    42: 'الجزء 3 - الربع 1',
    45: 'الجزء 3 - الربع 2',
    47: 'الجزء 3 - الربع 3',
    50: 'الجزء 3 - الربع 4',
    52: 'الجزء 3 - الربع 5',
    55: 'الجزء 3 - الربع 6',
    57: 'الجزء 3 - الربع 7',
    60: 'الجزء 3 - الربع 8',
    62: 'الجزء 4 - الربع 1',
    65: 'الجزء 4 - الربع 2',
    67: 'الجزء 4 - الربع 3',
    70: 'الجزء 4 - الربع 4',
    72: 'الجزء 4 - الربع 5',
    75: 'الجزء 4 - الربع 6',
    77: 'الجزء 4 - الربع 7',
    80: 'الجزء 4 - الربع 8',
    82: 'الجزء 5 - الربع 1',
    85: 'الجزء 5 - الربع 2',
    87: 'الجزء 5 - الربع 3',
    90: 'الجزء 5 - الربع 4',
    92: 'الجزء 5 - الربع 5',
    95: 'الجزء 5 - الربع 6',
    97: 'الجزء 5 - الربع 7',
    100: 'الجزء 5 - الربع 8',
    102: 'الجزء 6 - الربع 1',
    105: 'الجزء 6 - الربع 2',
    107: 'الجزء 6 - الربع 3',
    110: 'الجزء 6 - الربع 4',
    112: 'الجزء 6 - الربع 5',
    115: 'الجزء 6 - الربع 6',
    117: 'الجزء 6 - الربع 7',
    120: 'الجزء 6 - الربع 8',
    122: 'الجزء 7 - الربع 1',
    125: 'الجزء 7 - الربع 2',
    127: 'الجزء 7 - الربع 3',
    130: 'الجزء 7 - الربع 4',
    132: 'الجزء 7 - الربع 5',
    135: 'الجزء 7 - الربع 6',
    137: 'الجزء 7 - الربع 7',
    140: 'الجزء 7 - الربع 8',
    142: 'الجزء 8 - الربع 1',
    145: 'الجزء 8 - الربع 2',
    147: 'الجزء 8 - الربع 3',
    150: 'الجزء 8 - الربع 4',
    152: 'الجزء 8 - الربع 5',
    155: 'الجزء 8 - الربع 6',
    157: 'الجزء 8 - الربع 7',
    160: 'الجزء 8 - الربع 8',
    162: 'الجزء 9 - الربع 1',
    165: 'الجزء 9 - الربع 2',
    167: 'الجزء 9 - الربع 3',
    170: 'الجزء 9 - الربع 4',
    172: 'الجزء 9 - الربع 5',
    175: 'الجزء 9 - الربع 6',
    177: 'الجزء 9 - الربع 7',
    180: 'الجزء 9 - الربع 8',
    182: 'الجزء 10 - الربع 1',
    185: 'الجزء 10 - الربع 2',
    187: 'الجزء 10 - الربع 3',
    190: 'الجزء 10 - الربع 4',
    192: 'الجزء 10 - الربع 5',
    195: 'الجزء 10 - الربع 6',
    197: 'الجزء 10 - الربع 7',
    200: 'الجزء 10 - الربع 8',
    202: 'الجزء 11 - الربع 1',
    205: 'الجزء 11 - الربع 2',
    207: 'الجزء 11 - الربع 3',
    210: 'الجزء 11 - الربع 4',
    212: 'الجزء 11 - الربع 5',
    215: 'الجزء 11 - الربع 6',
    217: 'الجزء 11 - الربع 7',
    220: 'الجزء 11 - الربع 8',
    222: 'الجزء 12 - الربع 1',
    225: 'الجزء 12 - الربع 2',
    227: 'الجزء 12 - الربع 3',
    230: 'الجزء 12 - الربع 4',
    232: 'الجزء 12 - الربع 5',
    235: 'الجزء 12 - الربع 6',
    237: 'الجزء 12 - الربع 7',
    240: 'الجزء 12 - الربع 8',
    242: 'الجزء 13 - الربع 1',
    245: 'الجزء 13 - الربع 2',
    247: 'الجزء 13 - الربع 3',
    250: 'الجزء 13 - الربع 4',
    252: 'الجزء 13 - الربع 5',
    255: 'الجزء 13 - الربع 6',
    257: 'الجزء 13 - الربع 7',
    260: 'الجزء 13 - الربع 8',
    262: 'الجزء 14 - الربع 1',
    265: 'الجزء 14 - الربع 2',
    267: 'الجزء 14 - الربع 3',
    270: 'الجزء 14 - الربع 4',
    272: 'الجزء 14 - الربع 5',
    275: 'الجزء 14 - الربع 6',
    277: 'الجزء 14 - الربع 7',
    280: 'الجزء 14 - الربع 8',
    282: 'الجزء 15 - الربع 1',
    285: 'الجزء 15 - الربع 2',
    287: 'الجزء 15 - الربع 3',
    290: 'الجزء 15 - الربع 4',
    292: 'الجزء 15 - الربع 5',
    295: 'الجزء 15 - الربع 6',
    297: 'الجزء 15 - الربع 7',
    300: 'الجزء 15 - الربع 8',
    302: 'الجزء 16 - الربع 1',
    305: 'الجزء 16 - الربع 2',
    307: 'الجزء 16 - الربع 3',
    310: 'الجزء 16 - الربع 4',
    312: 'الجزء 16 - الربع 5',
    315: 'الجزء 16 - الربع 6',
    317: 'الجزء 16 - الربع 7',
    320: 'الجزء 16 - الربع 8',
    322: 'الجزء 17 - الربع 1',
    325: 'الجزء 17 - الربع 2',
    327: 'الجزء 17 - الربع 3',
    330: 'الجزء 17 - الربع 4',
    332: 'الجزء 17 - الربع 5',
    335: 'الجزء 17 - الربع 6',
    337: 'الجزء 17 - الربع 7',
    340: 'الجزء 17 - الربع 8',
    342: 'الجزء 18 - الربع 1',
    345: 'الجزء 18 - الربع 2',
    347: 'الجزء 18 - الربع 3',
    350: 'الجزء 18 - الربع 4',
    352: 'الجزء 18 - الربع 5',
    355: 'الجزء 18 - الربع 6',
    357: 'الجزء 18 - الربع 7',
    360: 'الجزء 18 - الربع 8',
    362: 'الجزء 19 - الربع 1',
    365: 'الجزء 19 - الربع 2',
    367: 'الجزء 19 - الربع 3',
    370: 'الجزء 19 - الربع 4',
    372: 'الجزء 19 - الربع 5',
    375: 'الجزء 19 - الربع 6',
    377: 'الجزء 19 - الربع 7',
    380: 'الجزء 19 - الربع 8',
    382: 'الجزء 20 - الربع 1',
    385: 'الجزء 20 - الربع 2',
    387: 'الجزء 20 - الربع 3',
    390: 'الجزء 20 - الربع 4',
    392: 'الجزء 20 - الربع 5',
    395: 'الجزء 20 - الربع 6',
    397: 'الجزء 20 - الربع 7',
    400: 'الجزء 20 - الربع 8',
    402: 'الجزء 21 - الربع 1',
    405: 'الجزء 21 - الربع 2',
    407: 'الجزء 21 - الربع 3',
    410: 'الجزء 21 - الربع 4',
    412: 'الجزء 21 - الربع 5',
    415: 'الجزء 21 - الربع 6',
    417: 'الجزء 21 - الربع 7',
    420: 'الجزء 21 - الربع 8',
    422: 'الجزء 22 - الربع 1',
    425: 'الجزء 22 - الربع 2',
    427: 'الجزء 22 - الربع 3',
    430: 'الجزء 22 - الربع 4',
    432: 'الجزء 22 - الربع 5',
    435: 'الجزء 22 - الربع 6',
    437: 'الجزء 22 - الربع 7',
    440: 'الجزء 22 - الربع 8',
    442: 'الجزء 23 - الربع 1',
    445: 'الجزء 23 - الربع 2',
    447: 'الجزء 23 - الربع 3',
    450: 'الجزء 23 - الربع 4',
    452: 'الجزء 23 - الربع 5',
    455: 'الجزء 23 - الربع 6',
    457: 'الجزء 23 - الربع 7',
    460: 'الجزء 23 - الربع 8',
    462: 'الجزء 24 - الربع 1',
    465: 'الجزء 24 - الربع 2',
    467: 'الجزء 24 - الربع 3',
    470: 'الجزء 24 - الربع 4',
    472: 'الجزء 24 - الربع 5',
    475: 'الجزء 24 - الربع 6',
    477: 'الجزء 24 - الربع 7',
    480: 'الجزء 24 - الربع 8',
    482: 'الجزء 25 - الربع 1',
    485: 'الجزء 25 - الربع 2',
    487: 'الجزء 25 - الربع 3',
    490: 'الجزء 25 - الربع 4',
    492: 'الجزء 25 - الربع 5',
    495: 'الجزء 25 - الربع 6',
    497: 'الجزء 25 - الربع 7',
    500: 'الجزء 25 - الربع 8',
    502: 'الجزء 26 - الربع 1',
    505: 'الجزء 26 - الربع 2',
    507: 'الجزء 26 - الربع 3',
    510: 'الجزء 26 - الربع 4',
    512: 'الجزء 26 - الربع 5',
    515: 'الجزء 26 - الربع 6',
    517: 'الجزء 26 - الربع 7',
    520: 'الجزء 26 - الربع 8',
    522: 'الجزء 27 - الربع 1',
    525: 'الجزء 27 - الربع 2',
    527: 'الجزء 27 - الربع 3',
    530: 'الجزء 27 - الربع 4',
    532: 'الجزء 27 - الربع 5',
    535: 'الجزء 27 - الربع 6',
    537: 'الجزء 27 - الربع 7',
    540: 'الجزء 27 - الربع 8',
    542: 'الجزء 28 - الربع 1',
    545: 'الجزء 28 - الربع 2',
    547: 'الجزء 28 - الربع 3',
    550: 'الجزء 28 - الربع 4',
    552: 'الجزء 28 - الربع 5',
    555: 'الجزء 28 - الربع 6',
    557: 'الجزء 28 - الربع 7',
    560: 'الجزء 28 - الربع 8',
    562: 'الجزء 29 - الربع 1',
    565: 'الجزء 29 - الربع 2',
    567: 'الجزء 29 - الربع 3',
    570: 'الجزء 29 - الربع 4',
    572: 'الجزء 29 - الربع 5',
    575: 'الجزء 29 - الربع 6',
    577: 'الجزء 29 - الربع 7',
    580: 'الجزء 29 - الربع 8',
    582: 'الجزء 30 - الربع 1',
    585: 'الجزء 30 - الربع 2',
    587: 'الجزء 30 - الربع 3',
    590: 'الجزء 30 - الربع 4',
    592: 'الجزء 30 - الربع 5',
    595: 'الجزء 30 - الربع 6',
    597: 'الجزء 30 - الربع 7',
    600: 'الجزء 30 - الربع 8',
  };

  // الحصول على الربع الحالي بناءً على الصفحة
  static String getCurrentQuarter(int pageNumber) {
    final entry = quranQuarters.entries.lastWhere(
      (entry) => pageNumber >= entry.key,
      orElse: () => MapEntry(1, 'الجزء 1 - الربع 1'),
    );
    return entry.value;
  }

  // التحقق إذا كانت الصفحة هي بداية ربع
  static bool isQuarterStart(int pageNumber) {
    return quranQuarters.containsKey(pageNumber);
  }
  
  final Map<int, double> _downloadProgress = {};
  bool _isDownloading = false;
  StreamController<Map<int, double>>? _progressController;

  Map<int, double> get downloadProgress => Map.unmodifiable(_downloadProgress);
  bool get isDownloading => _isDownloading;
  Stream<Map<int, double>> get progressStream => 
      (_progressController ??= StreamController<Map<int, double>>.broadcast()).stream;

  Future<Directory> get _localQuranDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final quranDir = Directory('${appDir.path}/quran_pages');
    
    if (!await quranDir.exists()) {
      await quranDir.create(recursive: true);
    }
    
    return quranDir;
  }

  Future<File> getLocalPageFile(int pageNumber) async {
    final dir = await _localQuranDir;
    return File('${dir.path}/page_$pageNumber.png');
  }

  Future<bool> isPageDownloaded(int pageNumber) async {
    final file = await getLocalPageFile(pageNumber);
    return await file.exists();
  }

  Future<int> getDownloadedPagesCount() async {
    final dir = await _localQuranDir;
    
    try {
      final files = await dir.list().toList();
      return files.whereType<File>().length;
    } catch (e) {
      Logger.error('Error getting downloaded pages count: $e');
      return 0;
    }
  }

  // Get local asset image path
  String getLocalAssetPath(int pageNumber) {
    return 'assets/quran_image/$pageNumber.png';
  }

  // Check if local asset exists
  Future<bool> doesLocalAssetExist(int pageNumber) async {
    final localAssetPath = getLocalAssetPath(pageNumber);
    try {
      // Try to load the asset as binary data (for images)
      await rootBundle.load(localAssetPath);
      return true;
    } catch (e) {
      Logger.warning('Asset not found: $localAssetPath');
      return false;
    }
  }

  // Preload page into cache
  Future<bool> preloadPage(int pageNumber) async {
    try {
      // Check if the asset exists to preload it
      final exists = await doesLocalAssetExist(pageNumber);
      if (exists) {
        Logger.debug('Page $pageNumber asset exists and can be loaded');
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('Error preloading page $pageNumber: $e');
      return false;
    }
  }

  // Get page image URL (for fallback to network if local fails)
  String getPageImageUrl(int pageNumber) {
    // Fallback to network if local asset doesn't exist
    return 'https://cdn.islamic.network/quran/images/${pageNumber.toString().padLeft(3, '0')}.png';
  }

  Future<void> _downloadPage(int pageNumber) async {
    final file = await getLocalPageFile(pageNumber);
    
    // Skip if already downloaded
    if (await file.exists()) {
      return;
    }

    try {
      // Load the asset and save it to local storage
      final assetPath = getLocalAssetPath(pageNumber);
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      
      await file.writeAsBytes(bytes);
      Logger.debug('Successfully copied page $pageNumber from assets');
    } catch (e) {
      Logger.error('Failed to copy page $pageNumber from assets: $e');
      rethrow;
    }
  }

  // Download all Quran pages (for offline use)
  Future<void> downloadAllPages({
    Function(int currentPage, int total, double progress)? onProgress,
    Function()? onComplete,
    Function(String error)? onError,
  }) async {
    if (_isDownloading) {
      Logger.warning('Download already in progress');
      return;
    }

    _isDownloading = true;
    _downloadProgress.clear();
    _progressController?.add(Map.from(_downloadProgress));

    try {
      Logger.info('Starting download of $totalPages Quran pages...');
      
      for (int i = 1; i <= totalPages; i++) {
        if (!_isDownloading) break; // Allow cancellation

        try {
          await _downloadPage(i);
          _downloadProgress[i] = 1.0;
          
          final overallProgress = i / totalPages;
          onProgress?.call(i, totalPages, overallProgress);
          _progressController?.add({i: 1.0});
          
          Logger.info('Downloaded page $i/$totalPages (${(overallProgress * 100).toStringAsFixed(1)}%)');
          
          // Small delay to prevent overwhelming the server
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          Logger.error('Error downloading page $i: $e');
          _downloadProgress[i] = 0.0;
          _progressController?.add({i: 0.0});
        }
      }
      
      if (_isDownloading) {
        Logger.success('Quran pages download completed');
        onComplete?.call();
      }
      
    } catch (e) {
      Logger.error('Error during Quran pages download: $e');
      onError?.call(e.toString());
    } finally {
      _isDownloading = false;
    }
  }

  // Cancel download
  void cancelDownload() {
    _isDownloading = false;
    Logger.info('Quran pages download cancelled');
  }

  Future<void> downloadPage(int pageNumber) async {
    try {
      await _downloadPage(pageNumber);
      _downloadProgress[pageNumber] = 1.0;
      _progressController?.add({pageNumber: 1.0});
    } catch (e) {
      Logger.error('Error downloading page $pageNumber: $e');
      _downloadProgress[pageNumber] = 0.0;
      _progressController?.add({pageNumber: 0.0});
      rethrow;
    }
  }

  Future<void> clearAllPages() async {
    try {
      final dir = await _localQuranDir;
      
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        Logger.info('Cleared all downloaded Quran pages');
      }
      
      _downloadProgress.clear();
      _progressController?.add(Map.from(_downloadProgress));
      
    } catch (e) {
      Logger.error('Error clearing Quran pages: $e');
    }
  }

  Future<double> getTotalDownloadSize() async {
    final dir = await _localQuranDir;
    
    if (!await dir.exists()) return 0.0;
    
    try {
      final files = await dir.list().toList();
      int totalSize = 0;
      
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize / (1024 * 1024); // Convert to MB
    } catch (e) {
      Logger.error('Error calculating download size: $e');
      return 0.0;
    }
  }

  Future<void> preloadAdjacentPages(int currentPage) async {
    final startPage = (currentPage - 2).clamp(1, totalPages);
    final endPage = (currentPage + 2).clamp(1, totalPages);
    
    Logger.info('Preloading pages $startPage to $endPage');
    
    final futures = <Future<bool>>[];
    
    for (int i = startPage; i <= endPage; i++) {
      if (i != currentPage) {
        futures.add(preloadPage(i));
      }
    }
    
    await Future.wait(futures);
  }

  void dispose() {
    _progressController?.close();
    _progressController = null;
  }
}
