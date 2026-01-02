import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/quran_pages_service.dart';

class DownloadProgressDialog extends StatefulWidget {
  final VoidCallback onCancel;

  const DownloadProgressDialog({
    super.key,
    required this.onCancel,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  int _currentPage = 0;
  int _totalPages = QuranPagesService.totalPages;
  double _progress = 0.0;
  bool _isDownloading = false;
  bool _isCompleted = false;
  String _statusMessage = 'جاري الإعداد...';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'جاري تحميل المصحف...';
    });

    QuranPagesService.instance.downloadAllPages(
      onProgress: (currentPage, total, progress) {
        if (mounted) {
          setState(() {
            _currentPage = currentPage;
            _totalPages = total;
            _progress = progress;
            _statusMessage = 'تم تحميل $_currentPage من $_totalPages صفحة';
          });
        }
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isCompleted = true;
            _statusMessage = 'اكتمل تحميل المصحف بنجاح!';
            _progress = 1.0;
          });
          
          // Auto-close after 2 seconds
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _statusMessage = 'حدث خطأ: $error';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                'تحميل المصحف الشريف',
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineSmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Progress indicator
              if (_isDownloading || _isCompleted) ...[
                // Circular progress
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isCompleted ? Colors.green : Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_progress * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.tajawal(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.headlineSmall?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_currentPage/$_totalPages',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Linear progress bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: _progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _isCompleted ? Colors.green : Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Status message
                Text(
                  _statusMessage,
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              if (!_isDownloading && !_isCompleted) ...[
                // Initial state
                Icon(
                  Icons.download_for_offline,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'سيتم تحميل 604 صفحة من المصحف الشريف\nللقراءة بدون اتصال بالإنترنت',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_isDownloading)
                    ElevatedButton.icon(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.cancel),
                      label: Text(
                        'إلغاء',
                        style: GoogleFonts.tajawal(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  
                  if (_isCompleted)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: Text(
                        'تم',
                        style: GoogleFonts.tajawal(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  
                  if (!_isDownloading && !_isCompleted)
                    ElevatedButton.icon(
                      onPressed: _startDownload,
                      icon: const Icon(Icons.download),
                      label: Text(
                        'بدء التحميل',
                        style: GoogleFonts.tajawal(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
