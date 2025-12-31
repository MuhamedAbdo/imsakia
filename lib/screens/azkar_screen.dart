import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

class AzkarScreen extends StatefulWidget {
  const AzkarScreen({super.key});

  @override
  State<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreen>
    with TickerProviderStateMixin {
  double _fontSize = 18.0;
  int _currentCategoryIndex = 0;
  int _currentZikrIndex = 0;
  Map<String, Map<String, int>> _zikrCounters = {};
  Map<String, Map<String, int>> _zikrTargets = {};
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;
  
  // Sample Azkar data (will be expanded or loaded from JSON)
  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'morning',
      'title': 'أذكار الصباح',
      'icon': Icons.wb_sunny,
      'color': Color(0xFFFFD700),
      'gradient': [Color(0xFFFFD700), Color(0xFFFFA500)],
      'azkar': [
        {'text': 'أصبحنا وأصبح الملك لله', 'target': 3},
        {'text': 'اللهم إني أصبحت أشهدك وأشهد حملت عرشك وأشهد ملائكتك وكتبك وجبريل وميكائيل وإسرافيل وعزرائيل أعلم أنك الله ربي وربي ورب محمد عبدك ورسولك', 'target': 1},
        {'text': 'اللهم ما أصبح بي من نعمة فمنك وحدك فشكرك', 'target': 3},
        {'text': 'اللهم إني أعوذ بك من الكفر والفقر ومن عذاب القبر', 'target': 3},
        {'text': 'حسبي الله لا إله إلا هو عليه توكلت وإليه أناب', 'target': 3},
      ]
    },
    {
      'id': 'evening',
      'title': 'أذكار المساء',
      'icon': Icons.nightlight_round,
      'color': Color(0xFF1E3A8A),
      'gradient': [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      'azkar': [
        {'text': 'أمسينا وأمسى الملك لله', 'target': 3},
        {'text': 'اللهم إني أمسيت أشهدك وأشهد حملت عرشك وأشهد ملائكتك وكتبك وجبريل وميكائيل وإسرافيل وعزرائيل أعلم أنك الله ربي وربي ورب محمد عبدك ورسولك', 'target': 1},
        {'text': 'اللهم ما أمسى بي من نعمة فمنك وحدك فشكرك', 'target': 3},
        {'text': 'اللهم إني أعوذ بك من الكفر والفقر ومن عذاب القبر', 'target': 3},
        {'text': 'حسبي الله لا إله إلا هو عليه توكلت وإليه أناب', 'target': 3},
      ]
    },
    {
      'id': 'sleep',
      'title': 'أذكار النوم',
      'icon': Icons.bedtime,
      'color': Color(0xFF6B46C1),
      'gradient': [Color(0xFF6B46C1), Color(0xFF9333EA)],
      'azkar': [
        {'text': 'باسمك ربي وضعت جنبي وبك أرفعه وبك أعتضي فإذا أنت أخذت نفسي أرحمها', 'target': 1},
        {'text': 'اللهم قني عذابك يوم تبعثني أو تبعثني', 'target': 3},
        {'text': 'اللهم إني أسألك العافية في الدنيا والآخرة', 'target': 3},
        {'text': 'اللهم إني أعوذ بك من هم الحزن وعجز الدعن وغلبة الدين وغلبة الرجال', 'target': 3},
      ]
    },
    {
      'id': 'prayer',
      'title': 'أذكار الصلاة',
      'icon': Icons.mosque,
      'color': Color(0xFF10B981),
      'gradient': [Color(0xFF10B981), Color(0xFF059669)],
      'azkar': [
        {'text': 'سبحان الله', 'target': 33},
        {'text': 'الحمد لله', 'target': 33},
        {'text': 'لا إله إلا الله', 'target': 33},
        {'text': 'الله أكبر', 'target': 33},
        {'text': 'أستغفر الله', 'target': 33},
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeCounters();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _fontSize = prefs.getDouble('azkar_font_size') ?? 18.0;
      });
    } catch (e) {
      print('❌ Error loading Azkar settings: $e');
    }
  }
  
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('azkar_font_size', _fontSize);
    } catch (e) {
      print('❌ Error saving Azkar settings: $e');
    }
  }
  
  void _initializeCounters() {
    for (var category in _categories) {
      final categoryId = category['id'] as String;
      _zikrCounters[categoryId] = {};
      _zikrTargets[categoryId] = {};
      
      for (int i = 0; i < (category['azkar'] as List).length; i++) {
        _zikrCounters[categoryId]![i.toString()] = 0;
        _zikrTargets[categoryId]![i.toString()] = (category['azkar'] as List)[i]['target'] as int;
      }
    }
  }
  
  void _incrementZikr() {
    final categoryId = _categories[_currentCategoryIndex]['id'] as String;
    final zikrKey = _currentZikrIndex.toString();
    
    HapticFeedback.lightImpact();
    
    setState(() {
      _zikrCounters[categoryId]![zikrKey] = (_zikrCounters[categoryId]![zikrKey] ?? 0) + 1;
    });
    
    _saveProgress();
    
    // Check if target reached and auto-move
    if (_zikrCounters[categoryId]![zikrKey]! >= _zikrTargets[categoryId]![zikrKey]!) {
      HapticFeedback.heavyImpact();
      _moveToNextZikr();
    }
    
    // Animate progress
    _progressController.forward().then((_) {
      _progressController.reverse();
    });
  }
  
  void _moveToNextZikr() {
    final currentCategory = _categories[_currentCategoryIndex];
    final azkarList = currentCategory['azkar'] as List;
    
    if (_currentZikrIndex < azkarList.length - 1) {
      setState(() {
        _currentZikrIndex++;
      });
      _slideController.forward().then((_) {
        _slideController.reverse();
      });
    }
  }
  
  void _moveToPreviousZikr() {
    if (_currentZikrIndex > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentZikrIndex--;
      });
      _slideController.forward().then((_) {
        _slideController.reverse();
      });
    }
  }
  
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoryId = _categories[_currentCategoryIndex]['id'] as String;
      await prefs.setString('azkar_progress_$categoryId', json.encode(_zikrCounters[categoryId]));
    } catch (e) {
      print('❌ Error saving Azkar progress: $e');
    }
  }
  
  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoryId = _categories[_currentCategoryIndex]['id'] as String;
      final saved = prefs.getString('azkar_progress_$categoryId');
      
      if (saved != null) {
        final Map<String, dynamic> progress = json.decode(saved);
        setState(() {
          _zikrCounters[categoryId] = progress.map((key, value) => MapEntry(key, value as int));
        });
      }
    } catch (e) {
      print('❌ Error loading Azkar progress: $e');
    }
  }
  
  void _copyZikr(String text) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الذكر',
          style: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _shareZikr(String text) {
    HapticFeedback.selectionClick();
    // Share functionality can be implemented with share package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم مشاركة الذكر',
          style: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حجم الخط',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_fontSize.toInt()}',
                  style: GoogleFonts.tajawal(fontSize: 24),
                ),
                const SizedBox(height: 20),
                Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 28.0,
                  divisions: 16,
                  activeColor: Theme.of(context).primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _saveSettings();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: Text(
              'حفظ',
              style: GoogleFonts.tajawal(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryId = _categories[_currentCategoryIndex]['id'] as String;
    final hasLoadedProgress = _zikrCounters[categoryId]?.isNotEmpty ?? false;
    
    if (_currentCategoryIndex == 0 && !hasLoadedProgress) {
      _loadProgress();
    }
    
    final currentCategory = _categories[_currentCategoryIndex];
    final azkarList = currentCategory['azkar'] as List;
    final currentZikr = azkarList[_currentZikrIndex];
    final currentCount = _zikrCounters[categoryId]?[_currentZikrIndex.toString()] ?? 0;
    final targetCount = _zikrTargets[categoryId]?[_currentZikrIndex.toString()] ?? 33;
    final progress = currentCount / targetCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          currentCategory['title'] as String,
          style: GoogleFonts.tajawal(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showFontSizeDialog,
            icon: const Icon(Icons.text_fields),
            tooltip: 'حجم الخط',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: _currentCategoryIndex == 0
              ? _buildCategoriesGrid()
              : _buildZikrDetail(currentZikr, currentCount, targetCount, progress),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.2,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final colors = category['gradient'] as List<Color>;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _currentCategoryIndex = index;
                _currentZikrIndex = 0;
              });
              _loadProgress();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (category['color'] as Color).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category['title'] as String,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildZikrDetail(Map<String, dynamic> zikr, int currentCount, int targetCount, double progress) {
    return Column(
      children: [
        // Progress indicator
        Container(
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'التقدم',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$currentCount / $targetCount',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
                minHeight: 8,
              ),
            ],
          ),
        ),
        
        // Zikr card with glassmorphism
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return SlideTransition(
                  position: _slideAnimation,
                  child: GestureDetector(
                    onTap: _incrementZikr,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: 10,
                            sigmaY: 10,
                          ),
                          child: Container(
                            color: Colors.white.withOpacity(0.05),
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Zikr text
                                Text(
                                  zikr['text'] as String,
                                  style: GoogleFonts.amiri(
                                    fontSize: _fontSize,
                                    height: 1.8,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.headlineLarge?.color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                const SizedBox(height: 30),
                                
                                // Counter button
                                GestureDetector(
                                  onTap: _incrementZikr,
                                  child: AnimatedBuilder(
                                    animation: _progressAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: 1.0 + (_progressAnimation.value * 0.1),
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context).primaryColor.withOpacity(0.8),
                                                Theme.of(context).primaryColor.withOpacity(0.6),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Theme.of(context).primaryColor.withOpacity(0.4),
                                                blurRadius: 15,
                                                spreadRadius: 3,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$currentCount',
                                              style: GoogleFonts.tajawal(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Action buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      onPressed: _moveToPreviousZikr,
                                      icon: const Icon(Icons.arrow_back),
                                      tooltip: 'السابق',
                                    ),
                                    IconButton(
                                      onPressed: () => _copyZikr(zikr['text'] as String),
                                      icon: const Icon(Icons.copy),
                                      tooltip: 'نسخ',
                                    ),
                                    IconButton(
                                      onPressed: () => _shareZikr(zikr['text'] as String),
                                      icon: const Icon(Icons.share),
                                      tooltip: 'مشاركة',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
