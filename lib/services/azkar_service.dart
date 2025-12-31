import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/azkar.dart';
import '../utils/app_constants.dart';

class AzkarService {
  static AzkarService? _instance;
  static AzkarService get instance => _instance ??= AzkarService._();

  AzkarService._();

  List<AzkarCategory> _categories = [];
  StreamController<List<AzkarCategory>>? _categoriesController;
  Timer? _saveTimer;
  bool _isInitialized = false;

  Stream<List<AzkarCategory>> get categoriesStream => 
      (_categoriesController ??= StreamController<List<AzkarCategory>>.broadcast()).stream;

  List<AzkarCategory> get categories => List.unmodifiable(_categories);

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ AzkarService already initialized');
      return;
    }

    try {
      // Use fallback data directly for now to avoid JSON loading issues
      print('🔄 Using hardcoded fallback Azkar...');
      _loadFallbackData();
      await _loadSavedProgress();
      _isInitialized = true;
      print('✅ AzkarService initialized successfully');
    } catch (e) {
      print('❌ Error initializing AzkarService: $e');
      // Load fallback data if JSON loading fails
      _loadFallbackData();
      _isInitialized = true;
    }
  }

  Future<void> _loadAzkarData() async {
    try {
      print('🔄 Loading azkar from assets/data/azkar.json...');
      
      final String azkarString = await rootBundle.loadString('assets/data/azkar.json')
          .timeout(const Duration(seconds: 3), onTimeout: () {
        throw TimeoutException('Timeout loading azkar.json', const Duration(seconds: 3));
      });

      final dynamic azkarJson = json.decode(azkarString);

      if (azkarJson is! List) {
        throw FormatException('azkar.json is not a valid array');
      }

      final List<dynamic> azkarList = azkarJson;

      if (azkarList.isEmpty) {
        throw Exception('azkar.json is empty');
      }

      _categories = azkarList.map((data) {
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid azkar data format');
        }
        return AzkarCategory.fromJson(data);
      }).toList();

      print('✅ Loaded ${_categories.length} Azkar categories from JSON');
    } catch (e) {
      throw Exception('Failed to load azkar.json: $e');
    }
  }

  void _loadFallbackData() {
    print('🔄 Loading hardcoded fallback Azkar...');
    
    _categories = [
      AzkarCategory(
        id: 'morning',
        title: 'أذكار الصباح',
        description: 'الأذكار المستحبة في الصباح',
        icon: Icons.wb_sunny,
        color: Color(0xFFFFD700),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        azkar: [
          Azkar(
            id: 'morning_1',
            category: 'morning',
            text: 'أَصْبَحْنَا وَأَصْبَحْ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ، وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، يُحْيِي وَيُمِيتُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            target: 1,
          ),
          Azkar(
            id: 'morning_2',
            category: 'morning',
            text: 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا وَنَمُوتُنَا، وَإِلَيْكَ النُُّسُورُ',
            target: 1,
          ),
          Azkar(
            id: 'morning_3',
            category: 'morning',
            text: 'اللَّهُمَّ إِنِّي أَصْبَحْتُ أَشْهَدُكَ وَأَشْهَدُ حَمَلَةَ عَرْشِكَ، وَمَلائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ، لا إِلَهَ إِلَّا أَنْتَ، وَحْدَكَ لا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
            target: 1,
          ),
          Azkar(
            id: 'morning_4',
            category: 'morning',
            text: 'اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ فَمِنْكَ وَحْدَكَ لا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ',
            target: 3,
          ),
          Azkar(
            id: 'morning_5',
            category: 'morning',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لا إِلَهَ إِلَّا أَنْتَ',
            target: 3,
          ),
          Azkar(
            id: 'morning_6',
            category: 'morning',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ عَذَابِ جَهَنَّمَ، وَمِنْ عَذَابِ الْقَبْرِ، وَمِنْ فِتْنَةِ الْمَحْيَا وَالْمَمَاتِ',
            target: 3,
          ),
          Azkar(
            id: 'morning_7',
            category: 'morning',
            text: 'حَسْبِيَ اللَّهُ لا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُُّ الْعَرْشِ الْعَظِيمِ',
            target: 3,
          ),
          Azkar(
            id: 'morning_8',
            category: 'morning',
            text: 'بِسْمِ اللَّهِ الَّذِي لا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ',
            target: 3,
          ),
          Azkar(
            id: 'morning_9',
            category: 'morning',
            text: 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالإِسْلامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
            target: 1,
          ),
          Azkar(
            id: 'morning_10',
            category: 'morning',
            text: 'اللَّهُمَّ أَنْتَ رَبِّي، لا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ، وَوَعْدِكَ مَا اسْتَطَعْتُ',
            target: 3,
          ),
          Azkar(
            id: 'morning_11',
            category: 'morning',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ هَمَزِ الشَّيْطَانِ، وَأَعُوذُ بِكَ رَبِّي أَنْ يَحْضُرُونِ',
            target: 3,
          ),
          Azkar(
            id: 'morning_12',
            category: 'morning',
            text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَعَمَلاً مُبَارَكًا، وَرِزْقًا طَيِّبًا، وَشِفَاءً مِنْ كُلِّ دَاءٍ',
            target: 1,
          ),
          Azkar(
            id: 'morning_13',
            category: 'morning',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْعُجْزِ، وَأَعُوذُ بِكَ مِنَ الْبُخْلِ، وَأَعُوذُ بِكَ مِنَ الْكَسْلِ',
            target: 3,
          ),
          Azkar(
            id: 'morning_14',
            category: 'morning',
            text: 'اللَّهُمَّ بَارِكْ لِي فِي دِينِي، وَبَارِكْ لِي فِي مَالِي، وَبَارِكْ لِي فِي أَهْلِي، وَبَارِكْ لِي فِي صَنِيعَتِي',
            target: 1,
          ),
          Azkar(
            id: 'morning_15',
            category: 'morning',
            text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
            target: 33,
          ),
        ],
      ),
      AzkarCategory(
        id: 'evening',
        title: 'أذكار المساء',
        description: 'الأذكار المستحبة في المساء',
        icon: Icons.nightlight_round,
        color: Color(0xFF1E3A8A),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        azkar: [
          Azkar(
            id: 'evening_1',
            category: 'evening',
            text: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ، وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، يُحْيِي وَيُمِيتُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            target: 1,
          ),
          Azkar(
            id: 'evening_2',
            category: 'evening',
            text: 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا وَنَمُوتُنَا، وَإِلَيْكَ النُُّسُورُ',
            target: 1,
          ),
          Azkar(
            id: 'evening_3',
            category: 'evening',
            text: 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أَشْهَدُكَ وَأَشْهَدُ حَمَلَةَ عَرْشِكَ، وَمَلائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ، لا إِلَهَ إِلَّا أَنْتَ، وَحْدَكَ لا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
            target: 1,
          ),
          Azkar(
            id: 'evening_4',
            category: 'evening',
            text: 'اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ فَمِنْكَ وَحْدَكَ لا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ',
            target: 3,
          ),
          Azkar(
            id: 'evening_5',
            category: 'evening',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لا إِلَهَ إِلَّا أَنْتَ',
            target: 3,
          ),
          Azkar(
            id: 'evening_6',
            category: 'evening',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ عَذَابِ جَهَنَّمَ، وَمِنْ عَذَابِ الْقَبْرِ، وَمِنْ فِتْنَةِ الْمَحْيَا وَالْمَمَاتِ',
            target: 3,
          ),
          Azkar(
            id: 'evening_7',
            category: 'evening',
            text: 'حَسْبِيَ اللَّهُ لا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُُّ الْعَرْشِ الْعَظِيمِ',
            target: 3,
          ),
          Azkar(
            id: 'evening_8',
            category: 'evening',
            text: 'بِسْمِ اللَّهِ الَّذِي لا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ',
            target: 3,
          ),
          Azkar(
            id: 'evening_9',
            category: 'evening',
            text: 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالإِسْلامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
            target: 1,
          ),
          Azkar(
            id: 'evening_10',
            category: 'evening',
            text: 'اللَّهُمَّ أَنْتَ رَبِّي، لا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ، وَوَعْدِكَ مَا اسْتَطَعْتُ',
            target: 3,
          ),
          Azkar(
            id: 'evening_11',
            category: 'evening',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ هَمَزِ الشَّيْطَانِ، وَأَعُوذُ بِكَ رَبِّي أَنْ يَحْضُرُونِ',
            target: 3,
          ),
          Azkar(
            id: 'evening_12',
            category: 'evening',
            text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَعَمَلاً مُبَارَكًا، وَرِزْقًا طَيِّبًا، وَشِفَاءً مِنْ كُلِّ دَاءٍ',
            target: 1,
          ),
          Azkar(
            id: 'evening_13',
            category: 'evening',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْعُجْزِ، وَأَعُوذُ بِكَ مِنَ الْبُخْلِ، وَأَعُوذُ بِكَ مِنَ الْكَسْلِ',
            target: 3,
          ),
          Azkar(
            id: 'evening_14',
            category: 'evening',
            text: 'اللَّهُمَّ بَارِكْ لِي فِي دِينِي، وَبَارِكْ لِي فِي مَالِي، وَبَارِكْ لِي فِي أَهْلِي، وَبَارِكْ لِي فِي صَنِيعَتِي',
            target: 1,
          ),
          Azkar(
            id: 'evening_15',
            category: 'evening',
            text: 'قُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
            target: 1,
          ),
          Azkar(
            id: 'evening_16',
            category: 'evening',
            text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
            target: 33,
          ),
        ],
      ),
      AzkarCategory(
        id: 'prayer',
        title: 'أذكار الصلاة',
        description: 'الأذكار بعد الصلاة المكتوبة',
        icon: Icons.mosque,
        color: Color(0xFF10B981),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        azkar: [
          Azkar(
            id: 'prayer_1',
            category: 'prayer',
            text: 'سُبْحَانَ اللَّهِ',
            target: 33,
          ),
          Azkar(
            id: 'prayer_2',
            category: 'prayer',
            text: 'الْحَمْدُ لِلَّهِ',
            target: 33,
          ),
          Azkar(
            id: 'prayer_3',
            category: 'prayer',
            text: 'اللَّهُ أَكْبَر',
            target: 33,
          ),
          Azkar(
            id: 'prayer_4',
            category: 'prayer',
            text: 'لا إِلَهَ إِلَّا اللَّهُ',
            target: 33,
          ),
          Azkar(
            id: 'prayer_5',
            category: 'prayer',
            text: 'أَسْتَغْفِرُ اللَّهَ',
            target: 33,
          ),
          Azkar(
            id: 'prayer_6',
            category: 'prayer',
            text: 'اللَّهُمَّ أَنْتَ السَّلامُ وَمِنْكَ السَّلامُ، تَبَارَكْتَ يَا ذَا الْجَلالَ وَالإِكْرَامُ',
            target: 1,
          ),
          Azkar(
            id: 'prayer_7',
            category: 'prayer',
            text: 'اللَّهُمَّ أَجْعَلْ فِي قَلْبِي نُورًا، وَفِي لِسَانِي نُورًا، وَفِي سَمْعِي وَبَصَرِي نُورًا، وَأَمَامِي وَخَلْفِي نُورًا',
            target: 1,
          ),
          Azkar(
            id: 'prayer_8',
            category: 'prayer',
            text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَأَعُوذُ بِكَ مِنَ الْعُجْزِ وَالْبُخْلِ، وَأَعُوذُ بِكَ مِنَ الْكَسْلِ وَالشِّقَاقِ',
            target: 1,
          ),
          Azkar(
            id: 'prayer_9',
            category: 'prayer',
            text: 'اللَّهُمَّ اغْفِرْ لِي ذُنُوبِي الَّتِي قَدَّمْتُهَا وَأَخْرَأَهَا، وَمَا أَخْفَأْتُهَا بَعْدَ قُدْرَتِي، وَمَا أَسْرَرْتُهَا بِعْلَمِكَ',
            target: 1,
          ),
          Azkar(
            id: 'prayer_10',
            category: 'prayer',
            text: 'اللَّهُمَّ اهْدِنِي لِمَا تُحِبُّ، وَبَصِّرْنِي عَمَّا تَكْرَهُ، وَوَفِّقْنِي بَيْنَهُ وَبَيْنَ الْحَقِّ',
            target: 1,
          ),
          Azkar(
            id: 'prayer_11',
            category: 'prayer',
            text: 'لا إِلَهَ إِلَّا أَنْتَ سُبْحَانُ، بِكَ أَحْمَدُ، وَأَنْتَ أَهْلُ الْغَنَاءِ وَالْفَضْلِ، بِيَدِكَ أَسْتَغْفِرُ وَأَتُوبُ إِلَيْكَ',
            target: 1,
          ),
          Azkar(
            id: 'prayer_12',
            category: 'prayer',
            text: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ',
            target: 1,
          ),
        ],
      ),
      AzkarCategory(
        id: 'sleep',
        title: 'أذكار النوم',
        description: 'الأذكار المستحبة قبل النوم',
        icon: Icons.bedtime,
        color: Color(0xFF6B46C1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B46C1), Color(0xFF9333EA)],
        ),
        azkar: [
          Azkar(
            id: 'sleep_1',
            category: 'sleep',
            text: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
            target: 1,
          ),
          Azkar(
            id: 'sleep_2',
            category: 'sleep',
            text: 'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ',
            target: 3,
          ),
          Azkar(
            id: 'sleep_3',
            category: 'sleep',
            text: 'اللَّهُمَّ بِاسْمِكَ أَمُوتُ وَبِاسْمِكَ أَحْيَا',
            target: 1,
          ),
          Azkar(
            id: 'sleep_4',
            category: 'sleep',
            text: 'سُبْحَانَ اللَّهِ (33 مرة)، الْحَمْدُ لِلَّهِ (33 مرة)، اللَّهُ أَكْبَر (34 مرة)',
            target: 1,
          ),
          Azkar(
            id: 'sleep_5',
            category: 'sleep',
            text: 'آمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ، كُلٌّ آمَنَ بِاللَّهِ وَمَلائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ، لا نُفَرِّقُ بَيْنَ أَحَدٍ مِنْ رُسُلِهِ، وَقَالُوا سَمِعْنَا وَأَطَعْنَا، غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ',
            target: 1,
          ),
        ],
      ),
      AzkarCategory(
        id: 'wakeup',
        title: 'أذكار الاستيقاظ',
        description: 'الأذكار المستحبة عند الاستيقاظ من النوم',
        icon: Icons.wb_sunny_outlined,
        color: Color(0xFFF59E0B),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFFF9500)],
        ),
        azkar: [
          Azkar(
            id: 'wakeup_1',
            category: 'wakeup',
            text: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
            target: 1,
          ),
          Azkar(
            id: 'wakeup_2',
            category: 'wakeup',
            text: 'اللَّهُمَّ لَكَ الْحَمْدُ أَنْتَ قَيِّمُ السَّمَاوَاتِ وَالأَرْضِ وَمَنْ فِيهِنَّ، وَلَكَ الْحَمْدُ لَكَ مُلْكُ السَّمَاوَاتِ وَالأَرْضِ وَمَنْ فِيهِنَّ',
            target: 1,
          ),
          Azkar(
            id: 'wakeup_3',
            category: 'wakeup',
            text: 'اللَّهُمَّ أَنْتَ رَبِّي لا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ',
            target: 1,
          ),
        ],
      ),
      AzkarCategory(
        id: 'food',
        title: 'أذكار الطعام',
        description: 'الأذكار المستحبة قبل وبعد الأكل',
        icon: Icons.restaurant,
        color: Color(0xFFDC2626),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
        ),
        azkar: [
          Azkar(
            id: 'food_1',
            category: 'food',
            text: 'بِسْمِ اللَّهِ وَبَرَكَاتِ اللَّهِ (قبل الأكل)',
            target: 1,
          ),
          Azkar(
            id: 'food_2',
            category: 'food',
            text: 'اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا وَقِنَا عَذَابَ النَّارِ (بعد الأكل)',
            target: 1,
          ),
          Azkar(
            id: 'food_3',
            category: 'food',
            text: 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ (بعد الأكل)',
            target: 1,
          ),
        ],
      ),
      AzkarCategory(
        id: 'home',
        title: 'أذكار الدخول والخروج',
        description: 'الأذكار المستحبة عند الدخول والخروج من المنزل',
        icon: Icons.home,
        color: Color(0xFF059669),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF10B981)],
        ),
        azkar: [
          Azkar(
            id: 'home_1',
            category: 'home',
            text: 'بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا (عند الدخول)',
            target: 1,
          ),
          Azkar(
            id: 'home_2',
            category: 'home',
            text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ الْمَوْلَجِ وَخَيْرَ الْمَخْرَجِ (عند الدخول)',
            target: 1,
          ),
          Azkar(
            id: 'home_3',
            category: 'home',
            text: 'بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ، لا حَوْلَ وَلا قُوَّةَ إِلَّا بِاللَّهِ (عند الخروج)',
            target: 1,
          ),
        ],
      ),
      AzkarCategory(
        id: 'clothes',
        title: 'أذكار اللباس',
        description: 'الأذكار المستحبة عند لبس الثياب',
        icon: Icons.checkroom,
        color: Color(0xFF7C3AED),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
        ),
        azkar: [
          Azkar(
            id: 'clothes_1',
            category: 'clothes',
            text: 'الْحَمْدُ لِلَّهِ الَّذِي كَسَانِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلا قُوَّةٍ',
            target: 1,
          ),
          Azkar(
            id: 'clothes_2',
            category: 'clothes',
            text: 'الْحَمْدُ لِلَّهِ الَّذِي كَسَانِي هَذَا الثَّوْبَ وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلا قُوَّةٍ',
            target: 1,
          ),
        ],
      ),
];

print('✅ Loaded ${_categories.length} fallback Azkar categories');
_categoriesController?.add(_categories);
  }

  Future<void> _loadSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      for (int i = 0; i < _categories.length; i++) {
        final category = _categories[i];
        final savedProgress = prefs.getString('azkar_progress_${category.id}');
        
        if (savedProgress != null) {
          final Map<String, dynamic> progress = json.decode(savedProgress);
          final updatedAzkar = category.azkar.map((azkar) {
            final azkarProgress = progress[azkar.id];
            if (azkarProgress != null) {
              return azkar.copyWith(
                currentCount: azkarProgress['currentCount'] as int? ?? 0,
                isCompleted: azkarProgress['isCompleted'] as bool? ?? false,
              );
            }
            return azkar;
          }).toList();
          
          _categories[i] = category.copyWith(azkar: updatedAzkar);
        }
      }
      
      _notifyCategoriesChanged();
      print('✅ Loaded saved Azkar progress');
    } catch (e) {
      print('❌ Error loading saved Azkar progress: $e');
    }
  }

  Future<void> incrementAzkarCount(String categoryId, String azkarId) async {
    try {
      final categoryIndex = _categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex == -1) return;

      final category = _categories[categoryIndex];
      final azkarIndex = category.azkar.indexWhere((azkar) => azkar.id == azkarId);
      if (azkarIndex == -1) return;

      final azkar = category.azkar[azkarIndex];
      if (azkar.isCompleted) return; // Don't increment if already completed

      final updatedAzkar = azkar.incrementCount();
      final updatedAzkarList = List<Azkar>.from(category.azkar);
      updatedAzkarList[azkarIndex] = updatedAzkar;

      _categories[categoryIndex] = category.copyWith(azkar: updatedAzkarList);
      
      _notifyCategoriesChanged();
      _scheduleSave();
      
      print('📈 Incremented azkar count: $azkarId (${updatedAzkar.currentCount}/${updatedAzkar.target})');
    } catch (e) {
      print('❌ Error incrementing azkar count: $e');
    }
  }

  Future<void> resetCategoryCounters(String categoryId) async {
    try {
      final categoryIndex = _categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex == -1) return;

      _categories[categoryIndex] = _categories[categoryIndex].resetAllCounters();
      
      _notifyCategoriesChanged();
      _scheduleSave();
      
      print('🔄 Reset counters for category: $categoryId');
    } catch (e) {
      print('❌ Error resetting category counters: $e');
    }
  }

  Future<void> resetAllCounters() async {
    try {
      _categories = _categories.map((category) => category.resetAllCounters()).toList();
      
      _notifyCategoriesChanged();
      _scheduleSave();
      
      print('🔄 Reset all Azkar counters');
    } catch (e) {
      print('❌ Error resetting all counters: $e');
    }
  }

  AzkarCategory? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((category) => category.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  void _notifyCategoriesChanged() {
    _categoriesController?.add(_categories);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      for (final category in _categories) {
        final Map<String, dynamic> progress = {};
        for (final azkar in category.azkar) {
          progress[azkar.id] = {
            'currentCount': azkar.currentCount,
            'isCompleted': azkar.isCompleted,
          };
        }
        
        await prefs.setString('azkar_progress_${category.id}', json.encode(progress));
      }
      
      print('💾 Saved Azkar progress');
    } catch (e) {
      print('❌ Error saving Azkar progress: $e');
    }
  }

  void dispose() {
    _saveTimer?.cancel();
    _categoriesController?.close();
    _categoriesController = null;
  }
}
