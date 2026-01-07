import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

class TafsirService {
  static final TafsirService _instance = TafsirService._internal();
  factory TafsirService() => _instance;
  TafsirService._internal();

  final Map<String, String> _tafsirCache = {};
  bool _isLoaded = false;

  Future<void> loadTafsirData() async {
    if (_isLoaded) return;
    
    try {
      // Load the XML file
      String tafsirXml = await rootBundle.loadString('assets/data/tafsir.json.xml');
      final document = XmlDocument.parse(tafsirXml);
      
      // Parse the XML structure
      final quranElement = document.getElement('quran');
      if (quranElement != null) {
        final surahs = quranElement.findElements('sura');
        
        for (final surah in surahs) {
          final surahIndex = surah.getAttribute('index');
          if (surahIndex != null) {
            final ayahs = surah.findElements('aya');
            
            for (final ayah in ayahs) {
              final ayahIndex = ayah.getAttribute('index');
              final ayahText = ayah.getAttribute('text');
              
              if (ayahIndex != null && ayahText != null) {
                // Create key in format "surah:ayah"
                String key = '$surahIndex:$ayahIndex';
                _tafsirCache[key] = ayahText;
              }
            }
          }
        }
      }
      
      _isLoaded = true;
      print('Tafsir data loaded successfully. Total verses: ${_tafsirCache.length}');
    } catch (e) {
      print('Error loading Tafsir data: $e');
    }
  }

  String? getTafsir(int surahNumber, int ayahNumber) {
    String key = '$surahNumber:$ayahNumber';
    return _tafsirCache[key];
  }

  bool get isLoaded => _isLoaded;
  
  // Get all available surahs in the tafsir
  List<int> getAvailableSurahs() {
    Set<int> surahs = {};
    for (String key in _tafsirCache.keys) {
      final parts = key.split(':');
      if (parts.length == 2) {
        surahs.add(int.parse(parts[0]));
      }
    }
    return surahs.toList()..sort();
  }
  
  // Get all available ayahs for a specific surah
  List<int> getAvailableAyahs(int surahNumber) {
    List<int> ayahs = [];
    String prefix = '$surahNumber:';
    for (String key in _tafsirCache.keys) {
      if (key.startsWith(prefix)) {
        final parts = key.split(':');
        if (parts.length == 2) {
          ayahs.add(int.parse(parts[1]));
        }
      }
    }
    return ayahs..sort();
  }
}
