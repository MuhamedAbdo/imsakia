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

  void _setupListeners() {
    audioHandler?.player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => isPlaying = state.playing);
      }
    });
  }

  Future<void> _fetchRadios() async {
    try {
      final response = await Dio().get('https://mp3quran.net/api/v3/radios?language=ar');
      if (response.data != null) {
        setState(() {
          allRadios = response.data['radios'];
          filteredRadios = allRadios;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterRadios(String query) {
    setState(() {
      filteredRadios = allRadios
          .where((radio) => radio['name'].toString().contains(query))
          .toList();
    });
  }

  void _playRadio(int index, dynamic radioData) async {
    try {
      final radioUrl = radioData['url'];
      
      if (currentIndex == index && isPlaying) {
        await audioHandler?.pause();
      } else {
        await audioHandler?.stop();
        
        audioHandler?.setMediaItem(
          id: 'radio_${radioData['id']}',
          title: radioData['name'],
          artist: 'إذاعة القرآن الكريم',
          artUri: Uri.parse('https://raw.githubusercontent.com/ryanheise/audio_service/master/example/web/media/art.jpg'),
          album: 'الراديو المباشر',
        );

        await audioHandler?.playRadio(radioUrl);
        
        setState(() => currentIndex = index);
        _showMessage('جاري تشغيل: ${radioData['name']}', Colors.green);
      }
    } catch (e) {
      _showError('خطأ في تشغيل الإذاعة: $e');
    }
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  void _showMessage(String message, Color color) {
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
    // We don't dispose audioHandler?.player here as it's global
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xffd4a574);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
                onChanged: _filterRadios,
              )
            : const Text(
                "إذاعات القرآن الكريم",
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
          )
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: filteredRadios.length,
                        itemBuilder: (context, index) {
                          final radio = filteredRadios[index];
                          bool isThisPlaying = currentIndex == index && isPlaying;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Icon(
                                isThisPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: accentColor,
                                size: 40,
                              ),
                              title: Text(radio['name'], style: const TextStyle(fontFamily: 'Tajawal')),
                              onTap: () => _playRadio(index, radio),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          
          // Floating widget at bottom
          if (currentIndex != -1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xff2196F3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Radio info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'الإذاعة الحالية',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              filteredRadios[currentIndex]['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Play/Pause button
                      GestureDetector(
                        onTap: () {
                          if (currentIndex != -1) {
                            _playRadio(currentIndex, filteredRadios[currentIndex]);
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 10),
                      
                      // Stop button
                      GestureDetector(
                        onTap: () async {
                          await audioHandler?.stop();
                          setState(() {
                            currentIndex = -1;
                            isPlaying = false;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}