import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/quran_pages_service.dart';
import '../utils/logger.dart';

class QuranPagesViewerScreen extends StatefulWidget {
  final int initialPage;
  final String surahName;

  const QuranPagesViewerScreen({
    super.key,
    this.initialPage = 1,
    this.surahName = '',
  });

  @override
  State<QuranPagesViewerScreen> createState() => _QuranPagesViewerScreenState();
}

class _QuranPagesViewerScreenState extends State<QuranPagesViewerScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    
    // Preload adjacent pages
    QuranPagesService.instance.preloadAdjacentPages(_currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _hideControlsTimer?.cancel();
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page + 1;
    });

    // Preload adjacent pages
    QuranPagesService.instance.preloadAdjacentPages(_currentPage);
    
    Logger.debug('Changed to Quran page $_currentPage');
  }

  void _goToPage() {
    final controller = TextEditingController(text: _currentPage.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'الذهاب إلى صفحة',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'رقم الصفحة (1-604)',
            border: OutlineInputBorder(),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.tajawal()),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= 604) {
                _pageController.animateToPage(
                  page - 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                Navigator.pop(context);
              }
            },
            child: Text('ذهاب', style: GoogleFonts.tajawal()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Quran pages
          GestureDetector(
            onTap: _toggleControls,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: QuranPagesService.totalPages,
              reverse: true, // RTL reading direction
              itemBuilder: (context, index) {
                final pageNumber = QuranPagesService.totalPages - index;
                return _buildQuranPage(pageNumber);
              },
            ),
          ),
          
          // Controls overlay
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Top controls
                  _buildTopControls(),
                  const Spacer(),
                  // Bottom controls
                  _buildBottomControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            
            const Spacer(),
            
            if (widget.surahName.isNotEmpty)
              Expanded(
                flex: 2,
                child: Text(
                  widget.surahName,
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            const Spacer(),
            
            IconButton(
              onPressed: _goToPage,
              icon: const Icon(Icons.bookmark_border, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous page button
            IconButton(
              onPressed: _currentPage > 1
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              icon: const Icon(Icons.skip_previous, color: Colors.white),
            ),
            
            const SizedBox(width: 20),
            
            // Page number
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'صفحة $_currentPage / ${QuranPagesService.totalPages}',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(width: 20),
            
            // Next page button
            IconButton(
              onPressed: _currentPage < QuranPagesService.totalPages
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              icon: const Icon(Icons.skip_next, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuranPage(int pageNumber) {
    return FutureBuilder<bool>(
      future: QuranPagesService.instance.isPageDownloaded(pageNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final isDownloaded = snapshot.data ?? false;
        
        if (isDownloaded) {
          return _buildLocalPage(pageNumber);
        } else {
          return _buildNetworkPage(pageNumber);
        }
      },
    );
  }

  Widget _buildLocalPage(int pageNumber) {
    return FutureBuilder<File>(
      future: QuranPagesService.instance.getLocalPageFile(pageNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final file = snapshot.data!;
        
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            Logger.error('Error loading local page $pageNumber: $error');
            return _buildNetworkPage(pageNumber);
          },
        );
      },
    );
  }

  Widget _buildNetworkPage(int pageNumber) {
    final imageUrl = QuranPagesService.instance.getPageImageUrl(pageNumber);
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (context, url, error) {
        Logger.error('Error loading network page $pageNumber: $error');
        return _buildErrorWidget(pageNumber);
      },
      memCacheWidth: 1024,
      memCacheHeight: 1448,
    );
  }

  Widget _buildErrorWidget(int pageNumber) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل الصفحة $pageNumber',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Retry loading
            },
            child: Text(
              'إعادة المحاولة',
              style: GoogleFonts.tajawal(),
            ),
          ),
        ],
      ),
    );
  }
}
