import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../data/models/athan_model.dart';
import '../providers/athan_library_provider.dart';
import '../../athan/providers/athan_provider.dart';

/// شاشة مكتبة الأذان الكاملة: تجمع الأصوات المدمجة في assets وأصوات السيرفر السحابية
class AthanLibraryScreen extends StatefulWidget {
  const AthanLibraryScreen({super.key});

  @override
  State<AthanLibraryScreen> createState() => _AthanLibraryScreenState();
}

class _AthanLibraryScreenState extends State<AthanLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _player = AudioPlayer();
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

  // ─── معاينة الصوت ────────────────────────────────────────────────────────
  static const int _previewMaxAttempts = 2;

  Future<void> _togglePreview(AthanModel athan) async {
    final provider = context.read<AthanLibraryProvider>();
    final isPlaying = provider.playingId == athan.id;

    if (isPlaying) {
      await _player.stop();
      provider.setPlayingId(null);
      return;
    }

    provider.setPlayingId(athan.id);

    final String? localPath = provider.isDownloaded(athan.id)
        ? provider.localPathOf(athan.id)
        : null;

    for (var attempt = 1; attempt <= _previewMaxAttempts; attempt++) {
      if (!mounted || provider.playingId != athan.id) return;
      try {
        if (athan.isAsset && athan.assetPath != null) {
          await _player.setAsset(athan.assetPath!);
        } else if (localPath != null) {
          await _player.setFilePath(localPath);
        } else {
          await _player.setUrl(athan.url);
        }
        await _player.play();
        return;
      } on PlayerInterruptedException {
        return;
      } catch (e) {
        if (!mounted || provider.playingId != athan.id) return;

        final bool transient = !athan.isAsset && localPath == null && _isTransientSourceError(e);
        if (transient && attempt < _previewMaxAttempts) {
          await Future.delayed(const Duration(milliseconds: 700));
          continue;
        }

        provider.setPlayingId(null);
        if (mounted) {
          final String message = transient
              ? 'الخادم لم يستجب الآن، حاول مجددًا بعد قليل'
              : 'تعذّر تشغيل الصوت، يرجى المحاولة مرة أخرى';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message,
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return;
      }
    }
  }

  bool _isTransientSourceError(Object e) {
    if (e is PlayerException) {
      if (e.code != 1) return false;
      final m = (e.message ?? '').toLowerCase();
      return m.contains('response code: 5') ||
          m.contains('source error') ||
          m.contains('httpdatasource') ||
          m.contains('unable to connect') ||
          m.contains('connection') ||
          m.contains('timeout') ||
          m.contains('timed out');
    }
    return false;
  }

  // ─── التحميل والتعيين ───────────────────────────────────────────────────
  Future<void> _downloadAndSet(AthanModel athan, {required String prayerKey}) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AthanLibraryProvider>();
    final athanProvider = context.read<AthanProvider>();

    final result = await provider.downloadAndSet(athan, prayerKey: prayerKey);
    if (!mounted) return;

    if (result != null) {
      // مزامنة AthanProvider فورياً
      await athanProvider.syncFromPrefs();
      if (!mounted) return;

      final String successMessage;
      if (prayerKey == 'all') {
        successMessage = 'تم تعيين "${athan.name}" كأذان موحد لجميع الصلوات ✓';
      } else {
        final prayerNamesAr = {
          'fajr': 'الفجر',
          'dhuhr': 'الظهر',
          'asr': 'العصر',
          'maghrib': 'المغرب',
          'isha': 'العشاء',
        };
        successMessage =
            'تم تعيين "${athan.name}" لصلاة ${prayerNamesAr[prayerKey]} ✓';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  successMessage,
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
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'فشل التحميل، تحقق من الاتصال بالإنترنت',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  void _onSetAthanPressed(AthanModel athan) {
    if (athan.isFajr) {
      _downloadAndSet(athan, prayerKey: 'fajr');
    } else {
      final athanProvider = Provider.of<AthanProvider>(context, listen: false);
      if (athanProvider.isUnifiedMuezzin) {
        _downloadAndSet(athan, prayerKey: 'all');
      } else {
        _showAssignmentDialog(athan);
      }
    }
  }

  void _showAssignmentDialog(AthanModel athan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'تخصيص "${athan.name}"',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Color(0xFF1B5E20)),
                title: const Text('تعيين كأذان موحد لجميع الصلوات العادية',
                    style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAndSet(athan, prayerKey: 'all');
                },
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny, color: Colors.orange),
                title: const Text('صلاة الظهر فقط',
                    style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAndSet(athan, prayerKey: 'dhuhr');
                },
              ),
              ListTile(
                leading: const Icon(Icons.wb_twilight, color: Colors.deepOrange),
                title: const Text('صلاة العصر فقط',
                    style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAndSet(athan, prayerKey: 'asr');
                },
              ),
              ListTile(
                leading: const Icon(Icons.nights_stay, color: Colors.indigo),
                title: const Text('صلاة المغرب فقط',
                    style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAndSet(athan, prayerKey: 'maghrib');
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.deepPurple),
                title: const Text('صلاة العشاء فقط',
                    style: TextStyle(fontFamily: 'Tajawal')),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAndSet(athan, prayerKey: 'isha');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const Color primaryColor = Color(0xFF1B5E20);
    const Color accentColor = Color(0xFF4CAF50);
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
          'مكتبة أصوات الأذان',
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
          return Column(
            children: [
              // شريط التنبيه عند عدم توفر الإنترنت (الأصوات المدمجة تعمل دائماً)
              if (provider.isOffline)
                _OfflineBanner(
                  isDark: isDark,
                  onRetry: provider.fetchAthans,
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AthanList(
                      assetAthans: AthanLibraryProvider.assetNormalAthans,
                      serverAthans: provider.normalAthans,
                      provider: provider,
                      isFajr: false,
                      cardColor: cardColor,
                      surfaceColor: surfaceColor,
                      accentColor: accentColor,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      onPreview: _togglePreview,
                      onSetPressed: _onSetAthanPressed,
                    ),
                    _AthanList(
                      assetAthans: AthanLibraryProvider.assetFajrAthans,
                      serverAthans: provider.fajrAthans,
                      provider: provider,
                      isFajr: true,
                      cardColor: cardColor,
                      surfaceColor: surfaceColor,
                      accentColor: accentColor,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      onPreview: _togglePreview,
                      onSetPressed: _onSetAthanPressed,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── شريط التنبيه لوضع عدم الاتصال ───────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const _OfflineBanner({
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2416) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF6B5320) : const Color(0xFFFFE082),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 20,
            color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFE65100),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'لا يوجد اتصال بالإنترنت — تظهر الأصوات المدمجة والمحمّلة، ويمكنك تحميل المزيد عند الاتصال',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFFFECB3)
                    : const Color(0xFF5D4037),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF4A3B18)
                    : const Color(0xFFFFECB3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: isDark
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFFE65100),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'تحديث',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── قائمة الأصوات مع تقسيم المدمجة والسيرفر ──────────────────────────────────
class _AthanList extends StatelessWidget {
  final List<AthanModel> assetAthans;
  final List<AthanModel> serverAthans;
  final AthanLibraryProvider provider;
  final bool isFajr;
  final Color cardColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color primaryColor;
  final bool isDark;
  final Future<void> Function(AthanModel) onPreview;
  final void Function(AthanModel) onSetPressed;

  const _AthanList({
    required this.assetAthans,
    required this.serverAthans,
    required this.provider,
    required this.isFajr,
    required this.cardColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.primaryColor,
    required this.isDark,
    required this.onPreview,
    required this.onSetPressed,
  });

  @override
  Widget build(BuildContext context) {
    // ترتيب أصوات السيرفر: المحمّلة تظهر أولاً
    final sortedServerAthans = List<AthanModel>.from(serverAthans)..sort((a, b) {
      final aDownloaded = provider.isDownloaded(a.id);
      final bDownloaded = provider.isDownloaded(b.id);
      if (aDownloaded && !bDownloaded) return -1;
      if (!aDownloaded && bDownloaded) return 1;
      return 0;
    });

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      children: [
        // ─── القسم 1: الأصوات المدمجة في assets ──────────────────────────────
        _buildSectionHeader(
          title: isFajr ? 'أصوات أذان الفجر المدمجة' : 'أصوات الأذان المدمجة',
          subtitle: 'جاهزة للاستخدام الفوري بدون إنترنت',
          icon: Icons.offline_pin_rounded,
          count: assetAthans.length,
          iconColor: Colors.teal,
        ),
        const SizedBox(height: 8),
        ...assetAthans.map((athan) => _AthanCard(
              athan: athan,
              provider: provider,
              cardColor: cardColor,
              surfaceColor: surfaceColor,
              accentColor: accentColor,
              primaryColor: primaryColor,
              isDark: isDark,
              onPreview: onPreview,
              onSetPressed: onSetPressed,
            )),

        const SizedBox(height: 16),

        // ─── القسم 2: أصوات السيرفر السحابية ─────────────────────────────────
        _buildSectionHeader(
          title: isFajr ? 'أصوات الفجر الإضافية (السيرفر)' : 'أصوات إضافية من السيرفر',
          subtitle: 'أصوات منوعة يمكنك الاستماع إليها وتحميلها',
          icon: Icons.cloud_download_rounded,
          count: serverAthans.length,
          iconColor: Colors.blueAccent,
        ),
        const SizedBox(height: 8),

        if (provider.isLoading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'جارٍ فحص أصوات السيرفر...',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (sortedServerAthans.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  provider.isOffline
                      ? Icons.wifi_off_rounded
                      : Icons.music_off_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.isOffline
                        ? 'لا تتوفر أصوات سيرفر محمّلة حالياً، اتصل بالإنترنت لعرض وتحميل المزيد.'
                        : 'لا توجد أصوات إضافية في هذا القسم حالياً.',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...sortedServerAthans.map((athan) => _AthanCard(
                athan: athan,
                provider: provider,
                cardColor: cardColor,
                surfaceColor: surfaceColor,
                accentColor: accentColor,
                primaryColor: primaryColor,
                isDark: isDark,
                onPreview: onPreview,
                onSetPressed: onSetPressed,
              )),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required int count,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black45,
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

// ─── بطاقة الأذان الواحد ───────────────────────────────────────────────────
class _AthanCard extends StatelessWidget {
  final AthanModel athan;
  final AthanLibraryProvider provider;
  final Color cardColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color primaryColor;
  final bool isDark;
  final Future<void> Function(AthanModel) onPreview;
  final void Function(AthanModel) onSetPressed;

  const _AthanCard({
    required this.athan,
    required this.provider,
    required this.cardColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.primaryColor,
    required this.isDark,
    required this.onPreview,
    required this.onSetPressed,
  });

  @override
  Widget build(BuildContext context) {
    final athanProvider = Provider.of<AthanProvider>(context, listen: true);
    final isPlaying = provider.playingId == athan.id;
    final status = provider.downloadStatusOf(athan.id);
    final progress = provider.downloadProgressOf(athan.id);
    final isDownloaded = provider.isDownloaded(athan.id);
    final isDownloading = status == DownloadStatus.downloading;

    // فحص الصلوات المعين لها هذا الأذان
    final assignedPrayers = provider.getPrayersAssignedTo(athan.id);
    String badgeText = '';
    if (assignedPrayers.isNotEmpty) {
      if (athanProvider.isUnifiedMuezzin && !athan.isFajr) {
        if (assignedPrayers.contains('dhuhr')) {
          badgeText = '✓ الأذان الموحد';
        }
      } else if (athan.isFajr) {
        badgeText = '✓ معين لصلاة الفجر';
      } else {
        final Map<String, String> prayerNames = {
          'fajr': 'الفجر',
          'dhuhr': 'الظهر',
          'asr': 'العصر',
          'maghrib': 'المغرب',
          'isha': 'العشاء'
        };
        final names =
            assignedPrayers.map((p) => prayerNames[p] ?? p).join('، ');
        badgeText = '✓ معين: $names';
      }
    }
    final bool isAssigned = badgeText.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isAssigned
            ? (isDark
                ? const Color(0xFF1B4D20)
                : const Color(0xFFE8F5E9))
            : cardColor,
        borderRadius: BorderRadius.circular(14),
        border: isAssigned
            ? Border.all(color: accentColor, width: 1.6)
            : Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withAlpha(15),
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // النقر على البطاقة يتيح اختيار وتعيين الصوت مباشرة
          onTap: isDownloading ? null : () => onSetPressed(athan),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // أيقونة الفجر أو المسجد
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isAssigned
                            ? accentColor.withAlpha(35)
                            : surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        athan.isFajr ? Icons.nightlight_round : Icons.mosque,
                        color: isAssigned ? Colors.white : accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // اسم الأذان + الشارات
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  athan.name,
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (athan.isAsset) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withAlpha(isDark ? 50 : 25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.teal.withAlpha(80), width: 0.8),
                                  ),
                                  child: const Text(
                                    'مدمج',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                              ] else if (isDownloaded) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(isDark ? 50 : 25),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.withAlpha(80), width: 0.8),
                                  ),
                                  child: const Text(
                                    'محمّل',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (isAssigned) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                badgeText,
                                style: const TextStyle(
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

                    // زر الاستماع / المعاينة
                    _PlayButton(
                      isPlaying: isPlaying,
                      accentColor: accentColor,
                      onTap: () => onPreview(athan),
                    ),
                    const SizedBox(width: 8),

                    // زر التعيين / التحميل
                    _ActionButton(
                      isAsset: athan.isAsset,
                      isDownloaded: isDownloaded,
                      isDownloading: isDownloading,
                      isAssigned: isAssigned,
                      accentColor: accentColor,
                      primaryColor: primaryColor,
                      onTap: isDownloading ? null : () => onSetPressed(athan),
                    ),
                  ],
                ),
              ),

              // شريط تقدم التحميل
              if (isDownloading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress > 0 ? progress : null,
                          minHeight: 4,
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
                          fontSize: 10.5,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── زر الاستماع / المعاينة ────────────────────────────────────────────────
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
      duration: const Duration(milliseconds: 200),
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
          fixedSize: const Size(36, 36),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(
          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 20,
        ),
      ),
    );
  }
}

// ─── زر التعيين والتحميل ───────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final bool isAsset;
  final bool isDownloaded;
  final bool isDownloading;
  final bool isAssigned;
  final Color accentColor;
  final Color primaryColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.isAsset,
    required this.isDownloaded,
    required this.isDownloading,
    required this.isAssigned,
    required this.accentColor,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isAssigned) {
      return Tooltip(
        message: 'محدد حالياً كصوت للأذان',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withAlpha(35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: accentColor, size: 16),
              const SizedBox(width: 4),
              Text(
                'محدد',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool isReady = isAsset || isDownloaded;

    return Tooltip(
      message: isReady ? 'تعيين كصوت للأذان' : 'تحميل وتعيين كصوت للأذان',
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: isReady ? primaryColor : const Color(0xFF2E7D32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: Icon(
          isReady ? Icons.check_rounded : Icons.download_rounded,
          size: 15,
        ),
        label: Text(
          isReady ? 'تعيين' : 'تحميل',
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
