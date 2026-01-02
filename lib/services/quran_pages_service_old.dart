// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import '../utils/logger.dart';

// class QuranPagesService {
//   static QuranPagesService? _instance;
//   static QuranPagesService get instance => _instance ??= QuranPagesService._();

//   QuranPagesService._();

//   static const int totalPages = 604;
  
//   final Map<int, double> _downloadProgress = {};
//   bool _isDownloading = false;
//   StreamController<Map<int, double>>? _progressController;

//   Map<int, double> get downloadProgress => Map.unmodifiable(_downloadProgress);
//   bool get isDownloading => _isDownloading;
//   Stream<Map<int, double>> get progressStream => 
//       (_progressController ??= StreamController<Map<int, double>>.broadcast()).stream;

//   Future<Directory> get _localQuranDir async {
//     final appDir = await getApplicationDocumentsDirectory();
//     final quranDir = Directory('${appDir.path}/quran_pages');
    
//     if (!await quranDir.exists()) {
//       await quranDir.create(recursive: true);
//     }
    
//     return quranDir;
//   }

//   Future<File> getLocalPageFile(int pageNumber) async {
//     final dir = await _localQuranDir;
//     return File('${dir.path}/page_$pageNumber.png');
//   }

//   Future<bool> isPageDownloaded(int pageNumber) async {
//     final file = await getLocalPageFile(pageNumber);
//     return await file.exists();
//   }

//   Future<int> getDownloadedPagesCount() async {
//     final dir = await _localQuranDir;
    
//     try {
//       final files = await dir.list().toList();
//       return files.whereType<File>().length;
//     } catch (e) {
//       Logger.error('Error getting downloaded pages count: $e');
//       return 0;
//     }
//   }

//   // Get local asset image path
//   String getLocalAssetPath(int pageNumber) {
//     // Check if page exists in assets/quran_image/
//     // Format: page_001.png, page_002.png, etc.
//     return 'assets/quran_image/page_${pageNumber.toString().padLeft(3, '0')}.png';
//   }

//   // Check if local asset exists
//   Future<bool> doesLocalAssetExist(int pageNumber) async {
//     try {
//       final assetPath = getLocalAssetPath(pageNumber);
//       await rootBundle.loadString(assetPath); // Try to load the asset
//       return true;
//     } catch (e) {
//       Logger.warning('Asset not found: $assetPath');
//       return false;
//     }
//   }

//   Future<void> downloadAllPages({
//     Function(int currentPage, int total, double progress)? onProgress,
//     Function()? onComplete,
//     Function(String error)? onError,
//   }) async {
//     if (_isDownloading) {
//       Logger.warning('Download already in progress');
//       return;
//     }

//     _isDownloading = true;
//     _downloadProgress.clear();
//     _progressController?.add(Map.from(_downloadProgress));

//     try {
//       Logger.info('Starting download of $totalPages Quran pages...');
      
//       for (int i = 1; i <= totalPages; i++) {
//         if (!_isDownloading) break; // Allow cancellation

//         try {
//           await _downloadPage(i);
//           _downloadProgress[i] = 1.0;
          
//           final overallProgress = i / totalPages;
//           onProgress?.call(i, totalPages, overallProgress);
//           _progressController?.add({i: 1.0});
          
//           Logger.info('Downloaded page $i/$totalPages (${(overallProgress * 100).toStringAsFixed(1)}%)');
          
//           // Small delay to prevent overwhelming the server
//           await Future.delayed(const Duration(milliseconds: 100));
          
//         } catch (e) {
//           Logger.error('Error downloading page $i: $e');
//           _downloadProgress[i] = 0.0;
//           _progressController?.add({i: 0.0});
//         }
//       }
      
//       if (_isDownloading) {
//         Logger.success('Quran pages download completed');
//         onComplete?.call();
//       }
      
//     } catch (e) {
//       Logger.error('Error during Quran pages download: $e');
//       onError?.call(e.toString());
//     } finally {
//       _isDownloading = false;
//     }
//   }

//   Future<void> _downloadPage(int pageNumber) async {
//     final url = getPageImageUrl(pageNumber);
//     final file = await getLocalPageFile(pageNumber);
    
//     // Skip if already downloaded
//     if (await file.exists()) {
//       return;
//     }

//     try {
//       final response = await _dio.get(
//         url,
//         options: Options(
//           responseType: ResponseType.bytes,
//           receiveTimeout: const Duration(seconds: 30),
//           sendTimeout: const Duration(seconds: 30),
//         ),
//         onReceiveProgress: (received, total) {
//           if (total > 0) {
//             final progress = received / total;
//             _downloadProgress[pageNumber] = progress;
//             _progressController?.add({pageNumber: progress});
//           }
//         },
//       );

//       if (response.statusCode == 200) {
//         await file.writeAsBytes(response.data);
//         Logger.debug('Successfully downloaded page $pageNumber');
//       } else {
//         throw DioException(
//           requestOptions: response.requestOptions,
//           response: response,
//         );
//       }
//     } catch (e) {
//       Logger.error('Failed to download page $pageNumber: $e');
//       rethrow;
//     }
//   }

//   Future<void> downloadPage(int pageNumber) async {
//     try {
//       await _downloadPage(pageNumber);
//       _downloadProgress[pageNumber] = 1.0;
//       _progressController?.add({pageNumber: 1.0});
//     } catch (e) {
//       Logger.error('Error downloading page $pageNumber: $e');
//       _downloadProgress[pageNumber] = 0.0;
//       _progressController?.add({pageNumber: 0.0});
//       rethrow;
//     }
//   }

//   void cancelDownload() {
//     _isDownloading = false;
//     Logger.info('Quran pages download cancelled');
//   }

//   Future<void> clearAllPages() async {
//     try {
//       final dir = await _localQuranDir;
      
//       if (await dir.exists()) {
//         await dir.delete(recursive: true);
//         Logger.info('Cleared all downloaded Quran pages');
//       }
      
//       _downloadProgress.clear();
//       _progressController?.add(Map.from(_downloadProgress));
      
//     } catch (e) {
//       Logger.error('Error clearing Quran pages: $e');
//     }
//   }

//   Future<double> getTotalDownloadSize() async {
//     final dir = await _localQuranDir;
    
//     if (!await dir.exists()) return 0.0;
    
//     try {
//       final files = await dir.list().toList();
//       int totalSize = 0;
      
//       for (final file in files) {
//         if (file is File) {
//           totalSize += await file.length();
//         }
//       }
      
//       return totalSize / (1024 * 1024); // Convert to MB
//     } catch (e) {
//       Logger.error('Error calculating download size: $e');
//       return 0.0;
//     }
//   }

//   Future<bool> preloadPage(int pageNumber) async {
//     try {
//       final url = getPageImageUrl(pageNumber);
      
//       // Simple preload by creating the image provider
//       CachedNetworkImageProvider(url);
      
//       Logger.debug('Preloaded page $pageNumber into cache');
//       return true;
//     } catch (e) {
//       Logger.error('Error preloading page $pageNumber: $e');
//       return false;
//     }
//   }

//   Future<void> preloadAdjacentPages(int currentPage) async {
//     final startPage = (currentPage - 2).clamp(1, totalPages);
//     final endPage = (currentPage + 2).clamp(1, totalPages);
    
//     Logger.info('Preloading pages $startPage to $endPage');
    
//     final futures = <Future<bool>>[];
    
//     for (int i = startPage; i <= endPage; i++) {
//       if (i != currentPage) {
//         futures.add(preloadPage(i));
//       }
//     }
    
//     await Future.wait(futures);
//   }

//   void dispose() {
//     _progressController?.close();
//     _progressController = null;
//   }
// }
