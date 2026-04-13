import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../features/audio/services/audio_handler.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  bool isPlaying = false;
  List<dynamic> allRadios = [];
  List<dynamic> filteredRadios = [];
  bool isLoading = true;
  int currentIndex = -1;
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _fetchRadios();
  }

  // ✅ تم توحيد المستمعات لتعمل مع النظام السيادي الجديد
  void _setupListeners() {
    audioHandler?.playbackState.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state.playing;
        });
      }
    });
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

  void playRadio(int index, dynamic radioData) async {
    try {
      final radioUrl = radioData['url'];

      // إذا كانت نفس الإذاعة تعمل، نقوم بإيقافها
      if (currentIndex == index && isPlaying) {
        await audioHandler?.pause();
      } else {
        // إعداد بيانات الإذاعة للنظام
        audioHandler?.setMediaItem(
          id: 'radio_${radioData['id']}',
          title: radioData['name'],
          artist: 'إذاعة القرآن الكريم',
          artUri: Uri.parse(
            'https://raw.githubusercontent.com/ryanheise/audio_service/master/example/web/media/art.jpg',
          ),
        );

        // تشغيل الرابط المباشر
        await audioHandler?.playRadio(radioUrl);

        setState(() {
          currentIndex = index;
        });

        showMessage('جاري تشغيل: ${radioData['name']}', Colors.green);
      }
    } catch (e) {
      showError('خطأ في تشغيل الإذاعة: $e');
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
              : ListView.builder(
                  itemCount: filteredRadios.length,
                  padding: const EdgeInsets.only(
                    bottom: 80,
                  ), // مساحة للبار السفلي
                  itemBuilder: (context, index) {
                    final radio = filteredRadios[index];
                    bool isThisPlaying = currentIndex == index && isPlaying;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isThisPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: accentColor,
                          size: 40,
                        ),
                        title: Text(
                          radio['name'],
                          style: const TextStyle(fontFamily: 'Tajawal'),
                        ),
                        onTap: () => playRadio(index, radio),
                      ),
                    );
                  },
                ),

          if (currentIndex != -1)
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
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, -2),
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
                    filteredRadios[currentIndex]['name'],
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
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 35,
              ),
              onPressed: () =>
                  playRadio(currentIndex, filteredRadios[currentIndex]),
            ),
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.white, size: 30),
              onPressed: () async {
                await audioHandler?.stop();
                setState(() => currentIndex = -1);
              },
            ),
          ],
        ),
      ),
    );
  }
}
