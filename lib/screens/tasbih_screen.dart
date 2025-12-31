import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen>
    with TickerProviderStateMixin {
  int _currentCount = 0;
  int _totalCount = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  
  @override
  void initState() {
    super.initState();
    _loadCounts();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = 'tasbih_${today.year}_${today.month}_${today.day}';
      
      setState(() {
        _currentCount = prefs.getInt('tasbih_current') ?? 0;
        _totalCount = prefs.getInt(todayKey) ?? 0;
      });
    } catch (e) {
      print('❌ Error loading tasbih counts: $e');
    }
  }
  
  Future<void> _saveCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = 'tasbih_${today.year}_${today.month}_${today.day}';
      
      await prefs.setInt('tasbih_current', _currentCount);
      await prefs.setInt(todayKey, _totalCount);
    } catch (e) {
      print('❌ Error saving tasbih counts: $e');
    }
  }
  
  void _incrementCount() {
    HapticFeedback.lightImpact();
    
    setState(() {
      _currentCount++;
      _totalCount++;
    });
    
    _saveCounts();
    
    // Trigger animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }
  
  void _resetCount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'إعادة تعيين العداد',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'هل تريد إعادة تعيين العداد إلى الصفر؟',
            style: GoogleFonts.tajawal(),
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
                setState(() {
                  _currentCount = 0;
                });
                _saveCounts();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Text(
                'نعم',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: _incrementCount,
        child: Container(
          width: double.infinity,
          height: double.infinity,
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
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المسبحة',
                        style: GoogleFonts.tajawal(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.headlineLarge?.color,
                        ),
                      ),
                      // Reset button
                      FloatingActionButton(
                        mini: true,
                        onPressed: _resetCount,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                        elevation: 0,
                        child: Icon(
                          Icons.refresh,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Main counter area
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Ripple effect
                              if (_animationController.isAnimating)
                                Container(
                                  width: 250,
                                  height: 250,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).primaryColor.withOpacity(
                                        0.3 * _rippleAnimation.value,
                                      ),
                                      width: 3,
                                    ),
                                  ),
                                ),
                              
                              // Main circular counter
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).primaryColor.withOpacity(0.9),
                                      Theme.of(context).primaryColor.withOpacity(0.7),
                                      Theme.of(context).primaryColor.withOpacity(0.5),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(110),
                                    splashColor: Colors.white.withOpacity(0.3),
                                    highlightColor: Colors.white.withOpacity(0.1),
                                    onTap: _incrementCount,
                                    child: Center(
                                      child: Text(
                                        '$_currentCount',
                                        style: GoogleFonts.tajawal(
                                          fontSize: 72,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                // Daily total section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  margin: const EdgeInsets.all(16.0),
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
                      Text(
                        'إجمالي التسبيح اليوم',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_totalCount',
                        style: GoogleFonts.tajawal(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
