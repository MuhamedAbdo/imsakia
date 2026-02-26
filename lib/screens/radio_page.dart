import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initRadioPlayer();
    _fetchRadios();
  }

  void _initRadioPlayer() {
    debugPrint("Initializing AudioPlayer for radio...");
    
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint("Playback state changed: $state");
      if (mounted) {
        setState(() => isPlaying = state == PlayerState.playing);
      }
    });
  }

  Future<void> _fetchRadios() async {
    try {
      debugPrint("Fetching radios from API...");
      final response = await Dio().get('https://mp3quran.net/api/v3/radios?language=ar');
      if (response.data != null) {
        debugPrint("API Response received");
        debugPrint("Number of radios: ${response.data['radios']?.length ?? 0}");
        
        // Log first radio details for debugging
        if (response.data['radios']?.isNotEmpty == true) {
          final firstRadio = response.data['radios'][0];
          debugPrint("First radio: ${firstRadio['name']} -> ${firstRadio['url']}");
        }
        
        setState(() {
          allRadios = response.data['radios'];
          filteredRadios = allRadios;
          isLoading = false;
        });
        debugPrint("Radios loaded successfully");
      }
    } catch (e) {
      debugPrint("Error fetching radios: $e");
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
      debugPrint("=== Radio Debug ===");
      debugPrint("Name: ${radioData['name']}");
      debugPrint("URL: ${radioData['url']}");
      debugPrint("Current index: $currentIndex, Selected index: $index");
      debugPrint("Is playing: $isPlaying");
      
      final radioUrl = radioData['url'];
      
      if (currentIndex == index && isPlaying) {
        debugPrint("Pausing radio...");
        await _audioPlayer.pause();
      } else {
        debugPrint("Setting new station...");
        
        // Stop current playback
        await _audioPlayer.stop();
        
        // Set volume to maximum
        await _audioPlayer.setVolume(1.0);
        
        // Play the radio stream URL
        await _audioPlayer.play(UrlSource(radioUrl));
        
        setState(() => currentIndex = index);
        debugPrint("Playback started for index: $index");
        
        // Show success message
        _showMessage('جاري تشغيل: ${radioData['name']}', Colors.green);
      }
    } catch (e) {
      debugPrint("Radio Error: $e");
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
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xffd4a574);

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              AppBar(
                backgroundColor: const Color(0xff2196F3),
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
                    : const Text("إذاعات القرآن الكريم", style: TextStyle(fontFamily: 'Tajawal')),
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
                      color: Colors.black.withOpacity(0.3),
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
                                color: Colors.white.withOpacity(0.8),
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
                            color: Colors.white.withOpacity(0.2),
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
                          await _audioPlayer.stop();
                          setState(() {
                            currentIndex = -1;
                            isPlaying = false;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
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