import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/azkar.dart';
import '../utils/logger.dart';

class AzkarService {
  static AzkarService? _instance;
  static AzkarService get instance => _instance ??= AzkarService._();

  AzkarService._();

  List<AzkarCategory> _categories = [];
  StreamController<List<AzkarCategory>>? _categoriesController;
  Timer? _saveTimer;
  bool _isInitialized = false;

  Stream<List<AzkarCategory>> get categoriesStream =>
      (_categoriesController ??=
              StreamController<List<AzkarCategory>>.broadcast())
          .stream;

  List<AzkarCategory> get categories => List.unmodifiable(_categories);

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.debug('AzkarService already initialized');
      return;
    }

    try {
      // Use fallback data directly for now to avoid JSON loading issues
      Logger.info('Using hardcoded fallback Azkar...');
      _loadFallbackData();
      await _loadSavedProgress();
      _isInitialized = true;
      Logger.success('AzkarService initialized successfully');
    } catch (e) {
      Logger.error('Error initializing AzkarService: $e');
      // Load fallback data if JSON loading fails
      _loadFallbackData();
      _isInitialized = true;
    }
  }

  void _loadFallbackData() {
    Logger.info('Loading hardcoded fallback Azkar...');

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
          // أذكار الصباح المحدثة من Islambook
          Azkar(
            id: 'morning_1',
            category: 'morning',
            text: '''
أَعُوذُ بِاللهِ مِنْ الشَّيْطَانِ الرَّجِيمِ
{اللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلاَ يُحيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلاَّ بِمَا شَاء وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ وَلاَ يَؤُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ}''',
            target: 1,
          ),
          Azkar(
            id: 'morning_2',
            category: 'morning',
            text: '''
بِسْمِ اللهِ الرَّحْمنِ الرَّحِيمِ
{قُلْ هُوَ اللَّهُ أَحَدٌ * اللَّهُ الصَّمَدُ * لَمْ يَلِدْ وَلَمْ يُولَدْ * وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ}''',
            target: 3,
          ),
          Azkar(
            id: 'morning_3',
            category: 'morning',
            text: '''
بِسْمِ اللهِ الرَّحْمنِ الرَّحِيمِ
{قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ * مِن شَرِّ مَا خَلَقَ * وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ * وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ * وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ}''',
            target: 3,
          ),
          Azkar(
            id: 'morning_4',
            category: 'morning',
            text: '''
بِسْمِ اللهِ الرَّحْمنِ الرَّحِيمِ
{قُلْ أَعُوذُ بِرَبِّ النَّاسِ * مَلِكِ النَّاسِ * إِلَهِ النَّاسِ * مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ * الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ * مِنَ الْجِنَّةِ وَ النَّاسِ}''',
            target: 3,
          ),
          Azkar(
            id: 'morning_5',
            category: 'morning',
            text: '''
أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ، وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ''',
            target: 1,
          ),
          Azkar(
            id: 'morning_6',
            category: 'morning',
            text:
                'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
            target: 1,
          ),
          Azkar(
            id: 'morning_7',
            category: 'morning',
            text: '''
اللّهُمَّ أَنْتَ رَبِّي لا إِلَهَ إِلا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لا يَغْفِرُ الذُّنُوبَ إِلا أَنْتَ''',
            target: 1,
          ),
          Azkar(
            id: 'morning_8',
            category: 'morning',
            text: '''
اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لا إِلَهَ إِلا أَنْتَ وَحْدَكَ لا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ''',
            target: 4,
          ),
          Azkar(
            id: 'morning_9',
            category: 'morning',
            text:
                'اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ',
            target: 1,
          ),
          Azkar(
            id: 'morning_10',
            category: 'morning',
            text:
                'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لا إِلَهَ إِلا أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ، وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لا إِلَهَ إِلا أَنْتَ',
            target: 3,
          ),
          Azkar(
            id: 'morning_11',
            category: 'morning',
            text:
                'حَسْبِيَ اللَّهُ لا إِلَهَ إِلا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
            target: 7,
          ),
          Azkar(
            id: 'morning_12',
            category: 'morning',
            text:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي',
            target: 1,
          ),
          Azkar(
            id: 'morning_13',
            category: 'morning',
            text:
                'اللَّهُمَّ عَالِمَ الغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لا إِلَهَ إِلا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَى نَفْسِي سُوءًا، أَوْ أَجُرَّهُ إِلَى مُسْلِمٍ',
            target: 1,
          ),
          Azkar(
            id: 'morning_14',
            category: 'morning',
            text:
                'بِسْمِ اللَّهِ الَّذِي لا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
            target: 3,
          ),
          Azkar(
            id: 'morning_15',
            category: 'morning',
            text:
                'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
            target: 3,
          ),
          Azkar(
            id: 'morning_16',
            category: 'morning',
            text:
                'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ أَصْلِحْ لِي شأْنِي كُلَّهُ وَلا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
            target: 1,
          ),
          Azkar(
            id: 'morning_17',
            category: 'morning',
            text:
                'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذَا الْيَوْمِ: فَتْحَهُ، وَنَصْرَهُ، وَنُورَهُ، وَبَرَكَاتِهِ، وَهُدَاهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهِ وَشَرِّ مَا بَعْدَهُ',
            target: 1,
          ),
          Azkar(
            id: 'morning_18',
            category: 'morning',
            text:
                'أَصْبَحْنَا عَلَى فِطْرَةِ الإِسْلَامِ وَعَلَى كَلِمَةِ الإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
            target: 1,
          ),
          Azkar(
            id: 'morning_19',
            category: 'morning',
            text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
            target: 100,
          ),
          Azkar(
            id: 'morning_20',
            category: 'morning',
            text:
                'لا إِلَهَ إِلا اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            target:
                10, // أو 100 حسب الرغبة، والموقع ذكر 10 كحد أدنى أو 100 لزيادة الأجر
          ),
          Azkar(
            id: 'morning_21',
            category: 'morning',
            text:
                'سُبْحَانَ اللهِ وَبِحَمْدِهِ: عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
            target: 3,
          ),
          Azkar(
            id: 'morning_22',
            category: 'morning',
            text:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا',
            target: 1,
          ),
          Azkar(
            id: 'morning_23',
            category: 'morning',
            text: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
            target: 100,
          ),
          Azkar(
            id: 'morning_24',
            category: 'morning',
            text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
            target: 10,
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
          // أذكار المساء المحدثة من Islambook
          Azkar(
            id: 'evening_1',
            category: 'evening',
            text: '''
أَعُوذُ بِاللهِ مِنْ الشَّيْطَانِ الرَّجِيمِ
{اللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلاَ يُحيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلاَّ بِمَا شَاء وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ وَلاَ يَؤُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ}''',
            target: 1,
          ),
          Azkar(
            id: 'evening_2',
            category: 'evening',
            text: '''
بِسْمِ اللهِ الرَّحْمنِ الرَّحِيمِ
{قُلْ هُوَ اللَّهُ أَحَدٌ * اللَّهُ الصَّمَدُ * لَمْ يَلِدْ وَلَمْ يُولَدْ * وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ}''',
            target: 3,
          ),
          Azkar(
            id: 'evening_3',
            category: 'evening',
            text: '''
بِسْمِ اللهِ الرَّحْمنِ الرَّحِيمِ
{قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ * مِن شَرِّ مَا خَلَقَ * وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ * وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ * وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ}''',
            target: 3,
          ),
          Azkar(
            id: 'evening_4',
            category: 'evening',
            text: '''
بِسْمِ اللهِ الرَّحْمنِ الرَّحِيمِ
{قُلْ أَعُوذُ بِرَبِّ النَّاسِ * مَلِكِ النَّاسِ * إِلَهِ النَّاسِ * مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ * الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ * مِنَ الْجِنَّةِ وَ النَّاسِ}''',
            target: 3,
          ),
          Azkar(
            id: 'evening_5',
            category: 'evening',
            text: '''
أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ، وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ''',
            target: 1,
          ),
          Azkar(
            id: 'evening_6',
            category: 'evening',
            text:
                'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ',
            target: 1,
          ),
          Azkar(
            id: 'evening_7',
            category: 'evening',
            text: '''
اللّهُمَّ أَنْتَ رَبِّي لا إِلَهَ إِلا أَنْتَ، خَلقتَني وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لا يَغْفِرُ الذُّنُوبَ إِلا أَنْتَ''',
            target: 1,
          ),
          Azkar(
            id: 'evening_8',
            category: 'evening',
            text: '''
اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لا إِلَهَ إِلا أَنْتَ وَحْدَكَ لا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ''',
            target: 4,
          ),
          Azkar(
            id: 'evening_9',
            category: 'evening',
            text:
                'اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ',
            target: 1,
          ),
          Azkar(
            id: 'evening_10',
            category: 'evening',
            text:
                'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لا إِلَهَ إِلا أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ، وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لا إِلَهَ إِلا أَنْتَ',
            target: 3,
          ),
          Azkar(
            id: 'evening_11',
            category: 'evening',
            text:
                'حَسْبِيَ اللَّهُ لا إِلَهَ إِلا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
            target: 7,
          ),
          Azkar(
            id: 'evening_12',
            category: 'evening',
            text:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالآخِرَةِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي وَمَالِي، اللَّهُمَّ اسْتُرْ عَوْرَاتِي وَآمِنْ رَوْعَاتِي، اللَّهُمَّ احْفَظْنِي مِنْ بَيْنِ يَدَيَّ وَمِنْ خَلْفِي وَعَنْ يَمِينِي وَعَنْ شِمَالِي وَمِنْ فَوْقِي وَأَعُوذُ بِعَظَمَتِكَ أَنْ أُغْتَالَ مِنْ تَحْتِي',
            target: 1,
          ),
          Azkar(
            id: 'evening_13',
            category: 'evening',
            text:
                'اللَّهُمَّ عَالِمَ الغَيْبِ وَالشَّهَادَةِ فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لا إِلَهَ إِلا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَى نَفْسِي سُوءًا، أَوْ أَجُرَّهُ إِلَى مُسْلِمٍ',
            target: 1,
          ),
          Azkar(
            id: 'evening_14',
            category: 'evening',
            text:
                'بِسْمِ اللَّهِ الَّذِي لا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الأَرْضِ وَلا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
            target: 3,
          ),
          Azkar(
            id: 'evening_15',
            category: 'evening',
            text:
                'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
            target: 3,
          ),
          Azkar(
            id: 'evening_16',
            category: 'evening',
            text:
                'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ أَصْلِحْ لِي شأْنِي كُلَّهُ وَلا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
            target: 1,
          ),
          Azkar(
            id: 'evening_17',
            category: 'evening',
            text:
                'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ: فَتْحَهَا، وَنَصْرَهَا، وَنُورَهَا، وَبَرَكَتَهَا، وَهُدَاهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهَا وَشَرِّ مَا بَعْدَهَا',
            target: 1,
          ),
          Azkar(
            id: 'evening_18',
            category: 'evening',
            text:
                'أَمْسَيْنَا عَلَى فِطْرَةِ الإِسْلَامِ وَعَلَى كَلِمَةِ الإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
            target: 1,
          ),
          Azkar(
            id: 'evening_19',
            category: 'evening',
            text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
            target: 100,
          ),
          Azkar(
            id: 'evening_20',
            category: 'evening',
            text:
                'لا إِلَهَ إِلا اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
            target: 10,
          ),
          Azkar(
            id: 'evening_21',
            category: 'evening',
            text:
                'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
            target: 3,
          ),
          Azkar(
            id: 'evening_22',
            category: 'evening',
            text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
            target: 10,
          ),
          Azkar(
            id: 'evening_23',
            category: 'evening',
            text: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
            target: 100,
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
          // أذكار بعد السلام من الصلاة المفروضة
          // المصدر: Islambook
          Azkar(
            id: 'prayer_1',
            category: 'prayer',
            text: '''
أَسْـتَغْفِرُ الله، أَسْـتَغْفِرُ الله، أَسْـتَغْفِرُ الله.
اللّهُـمَّ أَنْـتَ السَّلامُ ، وَمِـنْكَ السَّلام ، تَبارَكْتَ يا ذا الجَـلالِ وَالإِكْـرام .''',
            target: 1,
          ),
          Azkar(
            id: 'prayer_2',
            category: 'prayer',
            text:
                'لا إلهَ إلاّ اللّهُ وحدَهُ لا شريكَ لهُ، لهُ المُـلْكُ ولهُ الحَمْد، وهوَ على كلّ شَيءٍ قَدير، اللّهُـمَّ لا مانِعَ لِما أَعْطَـيْت، وَلا مُعْطِـيَ لِما مَنَـعْت، وَلا يَنْفَـعُ ذا الجَـدِّ مِنْـكَ الجَـد.',
            target: 1,
          ),
          Azkar(
            id: 'prayer_3',
            category: 'prayer',
            text:
                'لا إلهَ إلاّ اللّه, وحدَهُ لا شريكَ لهُ، لهُ الملكُ ولهُ الحَمد، وهوَ على كلّ شيءٍ قدير، لا حَـوْلَ وَلا قـوَّةَ إِلاّ بِاللهِ، لا إلهَ إلاّ اللّـه، وَلا نَعْـبُـدُ إِلاّ إيّـاه, لَهُ النِّعْـمَةُ وَلَهُ الفَضْل وَلَهُ الثَّـناءُ الحَـسَن، لا إلهَ إلاّ اللّهُ مخْلِصـينَ لَـهُ الدِّينَ وَلَوْ كَـرِهَ الكـافِرون.',
            target: 1,
          ),
          Azkar(
            id: 'prayer_4',
            category: 'prayer',
            text: 'سُـبْحانَ اللهِ، والحَمْـدُ لله ، واللهُ أكْـبَر.',
            target: 33,
          ),
          Azkar(
            id: 'prayer_5',
            category: 'prayer',
            text:
                'لا إلهَ إلاّ اللّهُ وَحْـدَهُ لا شريكَ لهُ، لهُ الملكُ ولهُ الحَمْد، وهُوَ على كُلّ شَيءٍ قَـدير.',
            target: 1,
          ),
          Azkar(
            id: 'prayer_6',
            category: 'prayer',
            text: '''
بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم
{قُلْ هُوَ ٱللَّهُ أَحَدٌ، ٱللَّهُ ٱلصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ.}
  
_________________

بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم
{قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِى ٱلْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ.}
  
_________________

بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم
{قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ، مَلِكِ ٱلنَّاسِ، إِلَٰهِ ٱلنَّاسِ، مِن شَرِّ ٱلْوَسْوَاسِ ٱلْخَنَّاسِ، ٱلَّذِى يُوَسْوِسُ فِى صُدُورِ ٱلنَّاسِ، مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ.}''',
            target:
                3, // ملاحظة: تقال 3 مرات بعد الفجر والمغرب، ومرة بعد باقي الصلوات
          ),
          Azkar(
            id: 'prayer_7',
            category: 'prayer',
            text:
                'أَعُوذُ بِاللهِ مِنْ الشَّيْطَانِ الرَّجِيمِ\n{اللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلاَ يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلاَّ بِمَا شَاء وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ وَلاَ يَؤُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ.}',
            target: 1,
          ),
          Azkar(
            id: 'prayer_8',
            category: 'prayer',
            text:
                'لا إلهَ إلاّ اللّهُ وحْـدَهُ لا شريكَ لهُ، لهُ المُلكُ ولهُ الحَمْد، يُحيـي وَيُمـيتُ وهُوَ على كُلّ شيءٍ قدير.',
            target: 10, // بعد المغرب والصبح
          ),
          Azkar(
            id: 'prayer_9',
            category: 'prayer',
            text:
                'اللّهُـمَّ إِنِّـي أَسْأَلُـكَ عِلْمـاً نافِعـاً وَرِزْقـاً طَيِّـباً ، وَعَمَـلاً مُتَقَـبَّلاً.',
            target: 1, // بعد صلاة الفجر
          ),
          Azkar(
            id: 'prayer_10',
            category: 'prayer',
            text: 'اللَّهُمَّ أَجِرْنِي مِنْ النَّار.',
            target: 7, // بعد الصبح والمغرب كما هو مأثور
          ),
          Azkar(
            id: 'prayer_11',
            category: 'prayer',
            text:
                'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ.',
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
            text:
                'سُبْحَانَ اللَّهِ (33 مرة)، الْحَمْدُ لِلَّهِ (33 مرة)، اللَّهُ أَكْبَر (34 مرة)',
            target: 1,
          ),
          Azkar(
            id: 'sleep_5',
            category: 'sleep',
            text:
                'آمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ، كُلٌّ آمَنَ بِاللَّهِ وَمَلائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ، لا نُفَرِّقُ بَيْنَ أَحَدٍ مِنْ رُسُلِهِ، وَقَالُوا سَمِعْنَا وَأَطَعْنَا، غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ',
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
            text:
                'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
            target: 1,
          ),
          Azkar(
            id: 'wakeup_2',
            category: 'wakeup',
            text:
                'اللَّهُمَّ لَكَ الْحَمْدُ أَنْتَ قَيِّمُ السَّمَاوَاتِ وَالأَرْضِ وَمَنْ فِيهِنَّ، وَلَكَ الْحَمْدُ لَكَ مُلْكُ السَّمَاوَاتِ وَالأَرْضِ وَمَنْ فِيهِنَّ',
            target: 1,
          ),
          Azkar(
            id: 'wakeup_3',
            category: 'wakeup',
            text:
                'اللَّهُمَّ أَنْتَ رَبِّي لا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ',
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
            text:
                'اللَّهُمَّ بَارِكْ لَنَا فِيمَا رَزَقْتَنَا وَقِنَا عَذَابَ النَّارِ (بعد الأكل)',
            target: 1,
          ),
          Azkar(
            id: 'food_3',
            category: 'food',
            text:
                'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ (بعد الأكل)',
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
            text:
                'بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا (عند الدخول)',
            target: 1,
          ),
          Azkar(
            id: 'home_2',
            category: 'home',
            text:
                'اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ الْمَوْلَجِ وَخَيْرَ الْمَخْرَجِ (عند الدخول)',
            target: 1,
          ),
          Azkar(
            id: 'home_3',
            category: 'home',
            text:
                'بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ، لا حَوْلَ وَلا قُوَّةَ إِلَّا بِاللَّهِ (عند الخروج)',
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
            text:
                'الْحَمْدُ لِلَّهِ الَّذِي كَسَانِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلا قُوَّةٍ',
            target: 1,
          ),
          Azkar(
            id: 'clothes_2',
            category: 'clothes',
            text:
                'الْحَمْدُ لِلَّهِ الَّذِي كَسَانِي هَذَا الثَّوْبَ وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلا قُوَّةٍ',
            target: 1,
          ),
        ],
      ),
    ];

    Logger.success('Loaded ${_categories.length} fallback Azkar categories');
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
      Logger.success('Loaded saved Azkar progress');
    } catch (e) {
      Logger.error('Error loading saved Azkar progress: $e');
    }
  }

  Future<void> incrementAzkarCount(String categoryId, String azkarId) async {
    try {
      final categoryIndex = _categories.indexWhere(
        (cat) => cat.id == categoryId,
      );
      if (categoryIndex == -1) return;

      final category = _categories[categoryIndex];
      final azkarIndex = category.azkar.indexWhere(
        (azkar) => azkar.id == azkarId,
      );
      if (azkarIndex == -1) return;

      final azkar = category.azkar[azkarIndex];
      if (azkar.isCompleted) return; // Don't increment if already completed

      final updatedAzkar = azkar.incrementCount();
      final updatedAzkarList = List<Azkar>.from(category.azkar);
      updatedAzkarList[azkarIndex] = updatedAzkar;

      _categories[categoryIndex] = category.copyWith(azkar: updatedAzkarList);

      _notifyCategoriesChanged();
      _scheduleSave();

      Logger.info(
        'Incremented azkar count: $azkarId (${updatedAzkar.currentCount}/${updatedAzkar.target})',
      );
    } catch (e) {
      Logger.error('Error incrementing azkar count: $e');
    }
  }

  Future<void> resetCategoryCounters(String categoryId) async {
    try {
      final categoryIndex = _categories.indexWhere(
        (cat) => cat.id == categoryId,
      );
      if (categoryIndex == -1) return;

      _categories[categoryIndex] = _categories[categoryIndex]
          .resetAllCounters();

      _notifyCategoriesChanged();
      _scheduleSave();

      Logger.info('Reset counters for category: $categoryId');
    } catch (e) {
      Logger.error('Error resetting category counters: $e');
    }
  }

  Future<void> resetAllCounters() async {
    try {
      _categories = _categories
          .map((category) => category.resetAllCounters())
          .toList();

      _notifyCategoriesChanged();
      _scheduleSave();

      Logger.info('Reset all Azkar counters');
    } catch (e) {
      Logger.error('Error resetting all counters: $e');
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

        await prefs.setString(
          'azkar_progress_${category.id}',
          json.encode(progress),
        );
      }

      Logger.info('Saved Azkar progress');
    } catch (e) {
      Logger.error('Error saving Azkar progress: $e');
    }
  }

  void dispose() {
    _saveTimer?.cancel();
    _categoriesController?.close();
    _categoriesController = null;
  }
}
