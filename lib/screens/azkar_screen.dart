import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import '../models/azkar.dart';
import '../services/azkar_service.dart';
import '../utils/app_constants.dart';
import 'azkar_detail_screen.dart';

class AzkarScreenWidget extends StatefulWidget {
  const AzkarScreenWidget({super.key});

  @override
  State<AzkarScreenWidget> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreenWidget> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAzkar();
    _loadSettings();
  }

  Future<void> _initializeAzkar() async {
    try {
      print('🔄 AzkarScreen: Starting initialization...');
      
      // Check if AzkarService is already initialized
      if (AzkarService.instance.isInitialized) {
        print('✅ AzkarService already initialized');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Initialize with timeout
      await AzkarService.instance.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ AzkarService initialization timeout');
          setState(() {
            _isLoading = false;
          });
        },
      );
      
      print('✅ AzkarScreen: Initialization completed');
      print('📊 AzkarService categories count: ${AzkarService.instance.categories.length}');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error initializing AzkarService: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    // Font size settings removed - no longer needed
  }

  
  void _navigateToDetail(AzkarCategory category) {
    print('🔄 Navigating to AzkarDetailScreen for category: ${category.title}');
    print('📊 Category data: ${category.azkar.length} azkar');
    
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AzkarDetailScreen(category: category),
      ),
    );
  }

  
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'الأذكار',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [AppConstants.darkBackgroundColor, AppConstants.darkSurfaceColor]
                  : [AppConstants.backgroundColor, AppConstants.surfaceColor],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories,
                  size: 60,
                  color: AppConstants.primaryColor,
                ),
                SizedBox(height: 20),
                Text(
                  'جاري تحميل الأذكار...',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppConstants.primaryColor,
                  ),
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'الأذكار',
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
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'تصفير جميع الأذكار',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFFE0E0E0)
                          : null,
                    ),
                  ),
                  backgroundColor: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF2A2A2A)
                      : null,
                  content: Text(
                    'هل أنت متأكد من أنك تريد تصفير جميع عدادات الأذكار؟',
                    style: GoogleFonts.tajawal(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFFBDBDBD)
                          : null,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.tajawal(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF64B5F6)
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        AzkarService.instance.resetAllCounters();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E88E5)
                            : Theme.of(context).primaryColor,
                      ),
                      child: Text(
                        'تصفير',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'تصفير جميع الأذكار',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [AppConstants.darkBackgroundColor, AppConstants.darkSurfaceColor]
                : [AppConstants.backgroundColor, AppConstants.surfaceColor],
          ),
        ),
        child: SafeArea(
          child: _buildCategoriesGrid(),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    // Try StreamBuilder first, but fallback to direct data if needed
    return StreamBuilder<List<AzkarCategory>>(
      stream: AzkarService.instance.categoriesStream,
      builder: (context, snapshot) {
        print('🔄 AzkarScreen _buildCategoriesGrid StreamBuilder state: hasData=${snapshot.hasData}');
        
        // If Stream has data, use it
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final categories = snapshot.data!;
          print('✅ Using Stream data: ${categories.length} categories');
          
          return _buildCategoriesList(categories);
        }
        
        // Fallback to direct service data
        print('⚠️ StreamBuilder fallback: Using AzkarService.instance.categories directly');
        final categories = AzkarService.instance.categories;
        print('📊 Using fallback data: ${categories.length} categories');
        
        return _buildCategoriesList(categories);
      },
    );
  }
  
  Widget _buildCategoriesList(List<AzkarCategory> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 60,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد أذكار متاحة',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _initializeAzkar();
              },
              child: Text(
                'إعادة التحميل',
                style: GoogleFonts.tajawal(),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.0,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(AzkarCategory category) {
    return GestureDetector(
      onTap: () => _navigateToDetail(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: category.gradient,
          boxShadow: [
            BoxShadow(
              color: category.color.withOpacity(0.15),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: 10,
              sigmaY: 10,
            ),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Icon(
                      category.icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Title
                  Text(
                    category.title,
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Progress indicator
                  StreamBuilder<List<AzkarCategory>>(
                    stream: AzkarService.instance.categoriesStream,
                    builder: (context, snapshot) {
                      // Get current category from service data
                      AzkarCategory currentCategory;
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        currentCategory = snapshot.data!.firstWhere(
                          (cat) => cat.id == category.id,
                          orElse: () => category,
                        );
                      } else {
                        // Fallback to original category if stream has no data
                        currentCategory = category;
                      }
                      
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(
                            value: currentCategory.overallProgress,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 3,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${currentCategory.totalCompleted}/${currentCategory.totalCount}',
                            style: GoogleFonts.tajawal(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
