import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reciter.dart';
import '../models/surah_audio.dart';
import '../providers/audio_player_provider.dart';
import '../providers/download_provider.dart';
import 'audio_bottom_sheet.dart';

class ReciterDetailScreen extends StatefulWidget {
  final Reciter reciter;

  const ReciterDetailScreen({super.key, required this.reciter});

  @override
  State<ReciterDetailScreen> createState() => _ReciterDetailScreenState();
}

class _ReciterDetailScreenState extends State<ReciterDetailScreen> {
  bool _isFavorite = false;

  final List<String> _surahNames = [
    'الفاتحة',
    'البقرة',
    'آل عمران',
    'النساء',
    'المائدة',
    'الأنعام',
    'الأعراف',
    'الأنفال',
    'التوبة',
    'يونس',
    'هود',
    'يوسف',
    'الرعد',
    'إبراهيم',
    'الحجر',
    'النحل',
    'الإسراء',
    'الكهف',
    'مريم',
    'طه',
    'الأنبياء',
    'الحج',
    'المؤمنون',
    'النور',
    'الفرقان',
    'الشعراء',
    'النمل',
    'القصص',
    'العنكبوت',
    'الروم',
    'لقمان',
    'السجدة',
    'الأحزاب',
    'سبأ',
    'فاطر',
    'يس',
    'الصافات',
    'ص',
    'الزمر',
    'غافر',
    'فصلت',
    'الشورى',
    'الزخرف',
    'الدخان',
    'الجاثية',
    'الأحقاف',
    'محمد',
    'الفتح',
    'الحجرات',
    'ق',
    'الذاريات',
    'الطور',
    'النجم',
    'القمر',
    'الرحمن',
    'الواقعة',
    'الحديد',
    'المجادلة',
    'الحشر',
    'الممتحنة',
    'الصف',
    'الجمعة',
    'المنافقون',
    'التغابن',
    'الطلاق',
    'التحريم',
    'الملك',
    'القلم',
    'الحاقة',
    'المعارج',
    'نوح',
    'الجن',
    'المزمل',
    'المدثر',
    'القيامة',
    'الإنسان',
    'المرسلات',
    'النبأ',
    'النازعات',
    'عبس',
    'التكوير',
    'الانفطار',
    'المطففين',
    'الانشقاق',
    'البروج',
    'الطارق',
    'الأعلى',
    'الغاشية',
    'الفجر',
    'البلد',
    'الشمس',
    'الليل',
    'الضحى',
    'الشرح',
    'التين',
    'العلق',
    'القدر',
    'البينة',
    'الزلزلة',
    'العاديات',
    'القارعة',
    'التكاثر',
    'العصر',
    'الهمزة',
    'الفيل',
    'قريش',
    'الماعون',
    'الكوثر',
    'الكافرون',
    'النصر',
    'المسد',
    'الإخلاص',
    'الفلق',
    'الناس',
  ];

  List<SurahAudio> _allSurahs = [];

  @override
  void initState() {
    super.initState();
    _initSurahs();
    _checkFavorite();
  }

  void _initSurahs() {
    _allSurahs = List.generate(114, (index) {
      final surahId = index + 1;
      final audioUrl = _formatUrl(widget.reciter.serverUrl, surahId);
      return SurahAudio(
        id: surahId,
        name: _surahNames[index],
        reciterId: widget.reciter.id,
        audioUrl: audioUrl,
      );
    });
  }

  Future<void> _checkFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorite_reciters') ?? [];
    if (mounted) {
      setState(() => _isFavorite = favs.contains(widget.reciter.id));
    }
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorite_reciters') ?? [];

    if (_isFavorite) {
      favs.remove(widget.reciter.id);
    } else {
      favs.add(widget.reciter.id);
    }

    await prefs.setStringList('favorite_reciters', favs);
    setState(() => _isFavorite = !_isFavorite);
  }

  String _formatUrl(String server, int surahId) {
    // Zero-pad to 3 digits
    final paddedId = surahId.toString().padLeft(3, '0');
    // Prevent double slashes
    final cleanServer = server.endsWith('/')
        ? server.substring(0, server.length - 1)
        : server;
    return '$cleanServer/$paddedId.mp3';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.black : Colors.blue,
          title: Text(
            widget.reciter.name,
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Consumer<DownloadProvider>(
              builder: (context, downloadProvider, child) {
                final isDownloadingAll = downloadProvider.isDownloadingAll;
                return IconButton(
                  icon: Icon(
                    isDownloadingAll ? Icons.stop_circle_outlined : Icons.download_for_offline,
                    color: isDownloadingAll ? Colors.orange : Colors.white,
                  ),
                  tooltip: isDownloadingAll ? "إيقاف التحميل" : "تحميل الكل",
                  onPressed: () {
                    if (isDownloadingAll) {
                      downloadProvider.cancelAllDownloads(widget.reciter.id);
                      _showMessage(context, "تم إيقاف التحميل", Colors.orange);
                    } else {
                      downloadProvider.downloadAll(
                        widget.reciter,
                        _allSurahs,
                        onStatus: (msg) {
                          // Prevent spamming snackbars too fast, or just show them
                          _showMessage(context, msg, Colors.blue);
                        },
                        onComplete: () {
                          _showMessage(context, "اكتمل تحميل جميع السور المحددة", Colors.green);
                        },
                      );
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.only(
                bottom: 100,
              ), // padding for global bottom sheet UI
              itemCount: 114,
              itemBuilder: (context, index) {
                return _buildSurahRow(context, _allSurahs[index], isDarkMode);
              },
            ),
            const AudioBottomSheet(),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahRow(
    BuildContext context,
    SurahAudio surah,
    bool isDarkMode,
  ) {
    return Consumer2<AudioPlayerProvider, DownloadProvider>(
      builder: (context, audioProvider, downloadProvider, child) {
        final isPlayingHere =
            audioProvider.currentSurah?.id == surah.id &&
            audioProvider.currentReciter?.id == widget.reciter.id;
        final isAudioPlaying = isPlayingHere && audioProvider.isPlaying;

        final isDownloading = downloadProvider.isDownloading(
          widget.reciter.id,
          surah.id,
        );
        final progress = downloadProvider.getProgress(
          widget.reciter.id,
          surah.id,
        );

        final localPath = downloadProvider.getLocalPath(
          widget.reciter.id,
          surah.id,
        );
        final isDownloaded = localPath != null && localPath.isNotEmpty;

        surah.localPath = localPath; // inject resolving downloaded scope

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isPlayingHere
                ? Border.all(color: Colors.blue, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPlayingHere
                  ? Colors.blue
                  : (isDarkMode ? Colors.grey[800] : Colors.blue[50]),
              child: Text(
                '${surah.id}',
                style: GoogleFonts.tajawal(
                  color: isPlayingHere
                      ? Colors.white
                      : (isDarkMode ? Colors.white70 : Colors.blue),
                ),
              ),
            ),
            title: Text(
              'سورة ${surah.name}',
              style: GoogleFonts.tajawal(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isPlayingHere
                    ? Colors.blue
                    : (isDarkMode ? Colors.white : Colors.black87),
              ),
            ),
            subtitle: isDownloaded
                ? Text(
                    "تم التحميل",
                    style: GoogleFonts.tajawal(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Download Status or Button
                if (isDownloading)
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          color: Colors.blue,
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => downloadProvider.cancelDownload(
                            widget.reciter.id,
                            surah.id,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isDownloaded)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () =>
                        _showDeleteDialog(context, downloadProvider, surah),
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.download,
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                    onPressed: () {
                      downloadProvider.downloadSurah(
                        surah,
                        onStart: () => _showMessage(
                          context,
                          "يبدأ التحميل...",
                          Colors.blue,
                        ),
                        onSuccess: () => _showMessage(
                          context,
                          "اكتمل تحميل ${surah.name}",
                          Colors.green,
                        ),
                        onError: (msg) =>
                            _showMessage(context, msg, Colors.red),
                      );
                    },
                  ),

                const SizedBox(width: 8),

                // Play / Pause Button
                IconButton(
                  icon: Icon(
                    isAudioPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: isAudioPlaying
                        ? Colors.blue
                        : (isDarkMode ? Colors.white : Colors.blue[800]),
                    size: 34,
                  ),
                  onPressed: () async {
                    if (isPlayingHere) {
                      audioProvider.togglePlayPause();
                    } else {
                      // Offline Guard
                      if (!isDownloaded) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        var connectivityResult = await (Connectivity().checkConnectivity());
                        if (connectivityResult.contains(ConnectivityResult.none)) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text("يرجى الاتصال بالإنترنت لتشغيل هذه السورة"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }
                      }
                      
                      // Ensure playlist is set up
                      if (audioProvider.currentPlaylist != _allSurahs) {
                         audioProvider.setPlaylist(_allSurahs);
                      }
                      
                      audioProvider.playSurah(surah, widget.reciter);
                    }
                  },
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    DownloadProvider downloadProvider,
    SurahAudio surah,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            "حذف السورة",
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "هل تريد بالتأكيد حذف سورة ${surah.name} من الذاكرة؟",
            style: GoogleFonts.tajawal(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("إلغاء", style: GoogleFonts.tajawal()),
            ),
            TextButton(
              onPressed: () {
                downloadProvider.deleteDownloadedSurah(
                  widget.reciter.id,
                  surah.id,
                );
                Navigator.pop(ctx);
              },
              child: Text("حذف", style: GoogleFonts.tajawal(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.tajawal()),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Doesn't overlap bottom sheet
        ),
      );
    }
  }
}
