import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import '../features/audio/providers/audio_player_provider.dart';
import '../features/audio/services/audio_handler.dart';
import '../providers/quran_audio_provider.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  // Static player instance to preserve playback across tab navigation on Windows
  static AudioPlayer? _windowsRadioPlayer;
  AudioPlayer get _player =>
      audioHandler?.player ?? (_windowsRadioPlayer ??= AudioPlayer());

  StreamSubscription? _audioHandlerSubscription;
  StreamSubscription? _playerSubscription;

  bool isPlaying = false;
  bool isBuffering = false;
  List<dynamic> allRadios = [];
  List<dynamic> filteredRadios = [];
  bool isLoading = true;
  int currentIndex = -1;
  String? currentRadioUrl;
  dynamic currentRadioData;
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _fetchRadios();
  }

  void _setupListeners() {
    if (audioHandler != null) {
      _audioHandlerSubscription = audioHandler!.playbackState.listen((state) {
        if (mounted) {
          setState(() {
            isPlaying = state.playing;
            isBuffering =
                state.processingState == AudioProcessingState.buffering;
          });
        }
      });
    } else {
      _playerSubscription = _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            isPlaying = state.playing &&
                state.processingState != ProcessingState.completed;
            isBuffering =
                state.processingState == ProcessingState.buffering ||
                state.processingState == ProcessingState.loading;
          });
        }
      });
    }
  }

  Future<void> _fetchRadios() async {
    try {
      final response = await Dio().get(
        'https://mp3quran.net/api/v3/radios?language=ar',
      );
      if (response.data != null && mounted) {
        setState(() {
          allRadios = response.data['radios'];
          filteredRadios = allRadios;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        showError('تعذر تحميل الإذاعات: $e');
      }
    }
  }

  void filterRadios(String query) {
    setState(() {
      filteredRadios = allRadios
          .where((radio) => radio['name'].toString().contains(query))
          .toList();
    });
  }

  Future<void> playRadio(int index, dynamic radioData) async {
    try {
      final radioUrl = radioData['url']?.toString();
      if (radioUrl == null || radioUrl.isEmpty) {
        showError('رابط الإذاعة غير متوفر');
        return;
      }

      // إذا كانت نفس الإذاعة تعمل، نقوم بإيقافها مؤقتاً
      final isSameRadio = currentRadioUrl == radioUrl;
      if (isSameRadio && isPlaying) {
        if (audioHandler != null) {
          await audioHandler!.pause();
        } else {
          await _player.pause();
        }
        if (mounted) {
          setState(() {
            isPlaying = false;
            isBuffering = false;
          });
        }
      } else {
        // إيقاف أي تلاوة قرآنية تعمل حالياً لتجنب تداخل الأصوات
        try {
          final quranAudio =
              Provider.of<QuranAudioProvider>(context, listen: false);
          final audioPlayerProv =
              Provider.of<AudioPlayerProvider>(context, listen: false);

          if (quranAudio.player.playing) {
            await quranAudio.pause();
          }
          if (audioPlayerProv.isPlaying) {
            await audioPlayerProv.pause();
          }
        } catch (_) {}

        if (!mounted) return;

        setState(() {
          currentIndex = index;
          currentRadioUrl = radioUrl;
          currentRadioData = radioData;
          isBuffering = true;
        });

        showMessage('جاري تشغيل: ${radioData['name']}', Colors.green);

        if (audioHandler != null) {
          // نظام أندرويد عبر خدمة الخلفية
          audioHandler!.setMediaItem(
            id: 'radio_${radioData['id']}',
            title: radioData['name'],
            artist: 'إذاعة القرآن الكريم',
            artUri: Uri.parse(
              'https://raw.githubusercontent.com/ryanheise/audio_service/master/example/web/media/art.jpg',
            ),
          );

          await audioHandler!.playRadio(radioUrl);
        } else {
          // نظام ويندوز / سطح المكتب
          if (_player.playing) {
            await _player.pause();
          }
          await _player.setVolume(1.0);
          final source = AudioSource.uri(
            Uri.parse(radioUrl),
            headers: {'User-Agent': 'ZadApp/1.0'},
          );
          await _player.setAudioSource(source);
          await _player.play();

          // حماية ويندوز للتأكد من انخراط المشغل وبدء البث
          if (!kIsWeb && Platform.isWindows && !_player.playing) {
            for (int retry = 0; retry < 3; retry++) {
              await Future.delayed(const Duration(milliseconds: 250));
              if (_player.playing) break;
              await _player.play();
            }
          }
        }

        if (mounted) {
          setState(() {
            isPlaying = _player.playing;
            isBuffering = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isBuffering = false);
        showError('خطأ في تشغيل الإذاعة: $e');
      }
    }
  }

  Future<void> _stopRadio() async {
    try {
      if (audioHandler != null) {
        await audioHandler!.stop();
      } else {
        await _player.stop();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        currentIndex = -1;
        currentRadioUrl = null;
        currentRadioData = null;
        isPlaying = false;
        isBuffering = false;
      });
    }
  }

  void showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioHandlerSubscription?.cancel();
    _playerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xffd4a574);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "بحث عن إذاعة...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: filterRadios,
              )
            : const Text(
                "إذاعات القرآن الكريم",
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  filteredRadios = allRadios;
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: ListView.builder(
                      itemCount: filteredRadios.length,
                      padding: EdgeInsets.only(
                        bottom: currentRadioData != null ? 85 : 20,
                      ),
                      itemBuilder: (context, index) {
                        final radio = filteredRadios[index];
                        final bool isThisSelected =
                            currentRadioUrl == radio['url']?.toString();
                        final bool isThisPlaying = isThisSelected && isPlaying;
                        final bool isThisBuffering =
                            isThisSelected && isBuffering;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: isThisBuffering
                                ? SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                  )
                                : Icon(
                                    isThisPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    color: accentColor,
                                    size: 40,
                                  ),
                            title: Text(
                              radio['name'] ?? '',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: isThisSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isThisSelected ? accentColor : null,
                              ),
                            ),
                            onTap: () => playRadio(index, radio),
                          ),
                        );
                      },
                    ),
                  ),
                ),

          if (currentRadioData != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomPlayer(),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPlayer() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xff2196F3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'الإذاعة الحالية',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    currentRadioData?['name']?.toString() ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isBuffering)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 35,
                ),
                onPressed: () {
                  if (currentRadioData != null) {
                    playRadio(currentIndex, currentRadioData);
                  }
                },
              ),
            IconButton(
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: Colors.white,
                size: 30,
              ),
              onPressed: _stopRadio,
            ),
          ],
        ),
      ),
    );
  }
}
