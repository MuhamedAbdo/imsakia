import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../data/models/athan_model.dart';
import '../providers/athan_library_provider.dart';

/// شاشة مكتبة الأذان الكاملة
class AthanLibraryScreen extends StatefulWidget {
  const AthanLibraryScreen({super.key});

  @override
  State<AthanLibraryScreen> createState() => _AthanLibraryScreenState();
}

class _AthanLibraryScreenState extends State<AthanLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _player = AudioPlayer();
  // نحتفظ بمرجع Provider مبكراً لتجنب استخدام BuildContext عبر async gaps
  late AthanLibraryProvider _libraryProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _libraryProvider = context.read<AthanLibraryProvider>();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _libraryProvider.setPlayingId(null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _player.dispose();
    super.dispose();
  }

  // ─── Toggle preview playback ───────────────────────────────────────────────
  Future<void> _togglePreview(AthanModel athan) async {
    final provider = context.read<AthanLibraryProvider>();
    final isPlaying = provider.playingId == athan.id;

    if (isPlaying) {
      await _player.stop();
      provider.setPlayingId(null);
    } else {
      provider.setPlayingId(athan.id);
      try {
        await _player.stop();
        await _player.setUrl(athan.url);
        await _player.play();
      } catch (e) {
        provider.setPlayingId(null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذّر تشغيل الصوت: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  // ─── Download & Set ───────────────────────────────────────────────────────
  Future<void> _downloadAndSet(AthanModel athan) async {
    final provider = context.read<AthanLibraryProvider>();
    final result = await provider.downloadAndSet(athan);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم تعيين "${athan.name}" كأذان افتراضي ✓',
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('فشل التحميل، تحقق من الاتصال بالإنترنت'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryColor = const Color(0xFF1B5E20);
    final Color accentColor = const Color(0xFF4CAF50);
    final Color bgColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF5F8F5);
    final Color cardColor =
        isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color surfaceColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEAF2EA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : primaryColor,
        foregroundColor: Colors.white,
        title: const Text(
          'مكتبة الأذان',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: '🕌  الأذان العادي'),
            Tab(text: '🌙  أذان الفجر'),
          ],
        ),
      ),
      body: Consumer<AthanLibraryProvider>(
        builder: (context, provider, _) {
          // ─── حالة التحميل ────────────────────────────────────────────────
          if (provider.isLoading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جارٍ تحميل قائمة الأذانات...',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          // ─── حالة الخطأ ──────────────────────────────────────────────────
          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 64, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Tajawal'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: provider.fetchAthans,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة',
                          style: TextStyle(fontFamily: 'Tajawal')),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ─── القوائم ─────────────────────────────────────────────────────
          return TabBarView(
            controller: _tabController,
            children: [
              _AthanList(
                athans: provider.normalAthans,
                provider: provider,
                cardColor: cardColor,
                surfaceColor: surfaceColor,
                accentColor: accentColor,
                primaryColor: primaryColor,
                isDark: isDark,
                defaultId: provider.defaultAthanId,
                onPreview: _togglePreview,
                onDownload: _downloadAndSet,
              ),
              _AthanList(
                athans: provider.fajrAthans,
                provider: provider,
                cardColor: cardColor,
                surfaceColor: surfaceColor,
                accentColor: accentColor,
                primaryColor: primaryColor,
                isDark: isDark,
                defaultId: provider.defaultFajrId,
                onPreview: _togglePreview,
                onDownload: _downloadAndSet,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Widget قائمة الأذانات ──────────────────────────────────────────────────
class _AthanList extends StatelessWidget {
  final List<AthanModel> athans;
  final AthanLibraryProvider provider;
  final Color cardColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color primaryColor;
  final bool isDark;
  final String? defaultId;
  final Future<void> Function(AthanModel) onPreview;
  final Future<void> Function(AthanModel) onDownload;

  const _AthanList({
    required this.athans,
    required this.provider,
    required this.cardColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.primaryColor,
    required this.isDark,
    required this.defaultId,
    required this.onPreview,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (athans.isEmpty) {
      return const Center(
        child: Text('لا توجد أذانات',
            style: TextStyle(fontFamily: 'Tajawal')),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: athans.length,
      itemBuilder: (context, index) {
        final athan = athans[index];
        return _AthanCard(
          athan: athan,
          provider: provider,
          cardColor: cardColor,
          surfaceColor: surfaceColor,
          accentColor: accentColor,
          primaryColor: primaryColor,
          isDark: isDark,
          isDefault: defaultId == athan.id,
          onPreview: onPreview,
          onDownload: onDownload,
        );
      },
    );
  }
}

// ─── Widget بطاقة الأذان الواحد ─────────────────────────────────────────────
class _AthanCard extends StatelessWidget {
  final AthanModel athan;
  final AthanLibraryProvider provider;
  final Color cardColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color primaryColor;
  final bool isDark;
  final bool isDefault;
  final Future<void> Function(AthanModel) onPreview;
  final Future<void> Function(AthanModel) onDownload;

  const _AthanCard({
    required this.athan,
    required this.provider,
    required this.cardColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.primaryColor,
    required this.isDark,
    required this.isDefault,
    required this.onPreview,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaying = provider.playingId == athan.id;
    final status = provider.downloadStatusOf(athan.id);
    final progress = provider.downloadProgressOf(athan.id);
    final isDownloaded = provider.isDownloaded(athan.id);
    final isDownloading = status == DownloadStatus.downloading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDefault
            ? (isDark
                ? const Color(0xFF1B4D20)
                : const Color(0xFFE8F5E9))
            : cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDefault
            ? Border.all(color: accentColor, width: 1.5)
            : Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withAlpha(15),
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── صف المحتوى الرئيسي ───────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // أيقونة الأذان
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    athan.isFajr ? Icons.nightlight_round : Icons.mosque,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // اسم الأذان + شارة "الافتراضي"
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        athan.name,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✓ الأذان الافتراضي',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // زر التشغيل/الإيقاف
                _PlayButton(
                  isPlaying: isPlaying,
                  accentColor: accentColor,
                  onTap: () => onPreview(athan),
                ),
                const SizedBox(width: 8),

                // زر التحميل والتعيين
                _DownloadButton(
                  isDownloaded: isDownloaded,
                  isDownloading: isDownloading,
                  isDefault: isDefault,
                  accentColor: accentColor,
                  primaryColor: primaryColor,
                  onTap: isDownloading ? null : () => onDownload(athan),
                ),
              ],
            ),
          ),

          // ─── شريط التقدم أثناء التحميل ────────────────────────────────
          if (isDownloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? Colors.white12
                          : Colors.black12,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'جارٍ التحميل... ${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── زر التشغيل المنفصل ─────────────────────────────────────────────────────
class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final Color accentColor;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: IconButton(
        key: ValueKey(isPlaying),
        onPressed: onTap,
        tooltip: isPlaying ? 'إيقاف المعاينة' : 'معاينة الصوت',
        style: IconButton.styleFrom(
          backgroundColor:
              isPlaying ? accentColor : accentColor.withAlpha(30),
          foregroundColor: isPlaying ? Colors.white : accentColor,
          fixedSize: const Size(38, 38),
        ),
        icon: Icon(
          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 20,
        ),
      ),
    );
  }
}

// ─── زر التحميل والتعيين ────────────────────────────────────────────────────
class _DownloadButton extends StatelessWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final bool isDefault;
  final Color accentColor;
  final Color primaryColor;
  final VoidCallback? onTap;

  const _DownloadButton({
    required this.isDownloaded,
    required this.isDownloading,
    required this.isDefault,
    required this.accentColor,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return const SizedBox(
        width: 38,
        height: 38,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (isDefault) {
      return Tooltip(
        message: 'تم التعيين بالفعل',
        child: Icon(Icons.check_circle_rounded,
            color: accentColor, size: 34),
      );
    }

    return Tooltip(
      message: isDownloaded ? 'تعيين كافتراضي' : 'تحميل وتعيين',
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(
          isDownloaded ? Icons.check_rounded : Icons.download_rounded,
          size: 16,
        ),
        label: Text(
          isDownloaded ? 'تعيين' : 'تحميل',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
