import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/permissions_service.dart';

enum PermissionType {
  notifications,
  exactAlarm,
  batteryOptimization,
  autoStart,
  xiaomiOtherPermissions,
}

class PermissionConfig {
  final PermissionType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isCritical;
  final String whyNeeded;

  PermissionConfig({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.isCritical = true,
    required this.whyNeeded,
  });
}

class SequentialPermissionsScreen extends StatefulWidget {
  const SequentialPermissionsScreen({super.key});

  @override
  State<SequentialPermissionsScreen> createState() =>
      _SequentialPermissionsScreenState();
}

class _SequentialPermissionsScreenState
    extends State<SequentialPermissionsScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isAwaitingPermissionReturn = false;
  bool _isLoading = true;
  bool _isProcessingTransition = false;

  List<PermissionConfig> _queue = [];

  void _initializeQueue(bool isXiaomi) {
    _queue = [
      PermissionConfig(
        type: PermissionType.notifications,
        title: 'تفعيل الإشعارات',
        description: 'ضروري لعرض تنبيهات أوقات الصلاة والآذان في وقتها.',
        icon: Icons.notifications_active_rounded,
        isCritical: true,
        whyNeeded: 'نحتاج هذا لإرسال تنبيهات الأذان في الخلفية.',
      ),
      PermissionConfig(
        type: PermissionType.exactAlarm,
        title: 'المنبهات الدقيقة',
        description:
            'لضمان انطلاق الأذان في الثانية الصحيحة دون تأخير من النظام.',
        icon: Icons.access_time_filled_rounded,
        isCritical: true,
        whyNeeded: 'يضمن دقة المواعيد بنسبة 100% على أندرويد 12+.',
      ),
      PermissionConfig(
        type: PermissionType.batteryOptimization,
        title: 'تحسين البطارية',
        description: 'منع النظام من إيقاف التطبيق أو الأذان لتوفير الطاقة.',
        icon: Icons.battery_saver_rounded,
        isCritical: false,
        whyNeeded: 'يمنع "قتل" التطبيق بواسطة النظام في وضع السكون.',
      ),
      PermissionConfig(
        type: PermissionType.autoStart,
        title: 'التشغيل التلقائي',
        description: 'ليعمل الأذان مباشرة بعد إعادة تشغيل الهاتف.',
        icon: Icons.power_settings_new_rounded,
        isCritical: false,
        whyNeeded: 'يضمن استعادة مواقيت الأذان فور فتح الهاتف.',
      ),
    ];

    if (isXiaomi) {
      _queue.add(
        PermissionConfig(
          type: PermissionType.xiaomiOtherPermissions,
          title: 'صلاحيات شاومي الخاصة',
          description: 'لتفعيل ميزة "العرض على شاشة القفل" و "نوافذ منبثقة".',
          icon: Icons.security_rounded,
          isCritical: true,
          whyNeeded: 'ضروري جداً لضمان ظهور الأذان فوق شاشة القفل.',
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Find where to start
    _setupScreen();
  }

  Future<void> _setupScreen() async {
    final isXiaomi = await PermissionsService.isXiaomiDevice();
    if (mounted) {
      setState(() {
        _initializeQueue(isXiaomi);
      });
      _checkCurrentStatusAndProceed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ✅ تحقق مجمع عند العودة للتطبيق لضمان المزامنة
      _handleReturnFromSettings();
    }
  }

  Future<void> _checkCurrentStatusAndProceed() async {
    if (mounted) setState(() => _isLoading = true);
    for (int i = 0; i < _queue.length; i++) {
      final isGranted = await _isGranted(_queue[i].type);
      if (!isGranted) {
        if (mounted) {
          setState(() {
            _currentIndex = i;
            _isLoading = false;
          });
          // Automatically show dialog for the first missing permission
          Future.delayed(
            const Duration(milliseconds: 500),
            () => _showPermissionDialog(_queue[i]),
          );
        }
        return;
      }
    }
    // All granted
    if (mounted) await _completeOnboarding();
  }

  Future<bool> _isGranted(PermissionType type) async {
    switch (type) {
      case PermissionType.notifications:
        return await PermissionsService.isNotificationGranted();
      case PermissionType.exactAlarm:
        // ✅ هذا هو السطر السحري: تحقق أصلي 100%
        return await PermissionsService.isExactAlarmGranted();
      case PermissionType.batteryOptimization:
        return await PermissionsService.isBatteryOptimizationGranted();
      case PermissionType.autoStart:
        return await PermissionsService.isAutoStartGranted();
      case PermissionType.xiaomiOtherPermissions:
        // 👍 "الخداع البرمجي": لا يمكننا التحقق منها برمجياً، لذا نعتبرها غير ممنوحة بالبداية 
        // حتى يضغط المستخدم على "تفعيل"
        return false;
    }
  }

  Future<void> _handleReturnFromSettings() async {
    if (_isProcessingTransition || !mounted) return;
    _isProcessingTransition = true;
  
    try {
      // 🔥 1. تحقق شامل من كل الأذونات أولاً
      final statuses = await PermissionsService.checkAllPermissions();
      bool allGranted = statuses.values.every((v) => v);
  
      if (allGranted && mounted) {
        // ✅ كل الرخص ممنوحة! انتقال فوري لصفحة المدينة
        await _completeOnboarding();
        return;
      }
  
      // 🔥 2. إذا نسي المستخدم إذناً معيناً، نتحقق من الخطوة الحالية
      final current = _queue[_currentIndex];
      bool granted = await _isGranted(current.type);
  
      // محاولات إضافية في حالة عدم الرصد الفوري (محاولتان بفاصل 300 ملي ثانية)
      if (!granted) {
        for (int i = 0; i < 2; i++) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          granted = await _isGranted(current.type);
          if (granted) break;
        }
      }
  
      if (granted && mounted) {
        // ✅ انتقال للخطوة التالية
        await _proceedToNext();
      } else if (mounted) {
        // 🔥 تحسين شاومي: بمجرد العودة من إعدادات شاومي، نعتبرها نجحت لتشجيع المستخدم
        if (current.type == PermissionType.autoStart || 
            current.type == PermissionType.xiaomiOtherPermissions) {
           debugPrint('Aggressive success for Xiaomi logic: ${current.type}');
           await _proceedToNext();
           return;
        }
  
        // إذا لم يتم المنح بعد كل المحاولات، نظهر الحوار للأذونات الحرجة فقط
        if (current.isCritical && _isAwaitingPermissionReturn) {
          _showPermissionDialog(current);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAwaitingPermissionReturn = false;
          _isProcessingTransition = false;
        });
      }
    }
  }

  Future<void> _proceedToNext() async {
    if (_currentIndex < _queue.length - 1) {
      if (mounted) {
        setState(() {
          _currentIndex++;
        });
      }
      // ✅ ومضة بسيطة للانتقال للخطوة التالية
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        _showPermissionDialog(_queue[_currentIndex]);
      }
    } else {
      // ✅ كسر الحلقة: تم الوصول للنهاية
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_completed', true);
      if (mounted) await _completeOnboarding();
    }
  }

  Future<void> _showPermissionDialog(PermissionConfig config) async {
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !config.isCritical,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(config.icon, color: Colors.green, size: 40),
        ),
        title: Text(
          config.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              config.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لماذا نحتاج هذا؟ ${config.whyNeeded}',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!config.isCritical)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'لاحقاً',
                style: GoogleFonts.tajawal(color: Colors.grey),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              // إخفاء الـ Dialog والبدء في انتظار العودة
              if (mounted) {
                setState(() => _isAwaitingPermissionReturn = true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'تفعيل الآن',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      // ✅ كسر الحلقة: بمجرد الضغط على بدء التفعيل
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_completed', true);
      _triggerPermission(config.type);
    } else if (result == false && !config.isCritical) {
      // ✅ كسر الحلقة: بمجرد التخطي
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_completed', true);
      if (mounted) await _proceedToNext();
    }
  }

  Future<void> _triggerPermission(PermissionType type) async {
    _isAwaitingPermissionReturn = true;

    switch (type) {
      case PermissionType.notifications:
        await Permission.notification.request();
        break;
      case PermissionType.exactAlarm:
        await Permission.scheduleExactAlarm.request();
        break;
      case PermissionType.batteryOptimization:
        // ✅ استخدم الخدمة المستقلة مباشرة
        await PermissionsService.openBatteryOptimizationSettings();
        break;
      case PermissionType.autoStart:
        // ✅ استخدم الخدمة المستقلة مباشرة
        await PermissionsService.openComprehensivePermissions();
        break;
      case PermissionType.xiaomiOtherPermissions:
        // ✅ توجيه حصري لصفحة الصلاحيات الأخرى في شاومي
        await PermissionsService.openXiaomiOtherPermissions();
        break;
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted', true);
    await prefs.setBool('setup_completed', true);

    if (mounted) {
      await Navigator.of(context).pushReplacementNamed('/city-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _queue.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final current = _queue[_currentIndex];
    final progress = (_currentIndex + 1) / _queue.length;

    // 🔥 توحيد الثيم للخطوات والحوارات ليكون Light دائماً ومستقلاً عن النظام
    return Theme(
      data: ThemeData.light(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && current.isCritical) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.green,
                    ),
                    minHeight: 6,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.mosque_rounded,
                            size: 100,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 40),
                          Text(
                            'تجهيز تطبيق زاد',
                            style: GoogleFonts.tajawal(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'نتبع خطوات بسيطة لضمان عمل الأذان بدقة 100% على هاتفك الشخصي',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 60),

                          // Current step display
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  current.icon,
                                  size: 50,
                                  color: Colors.greenAccent,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  current.title,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  current.description,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () => _showPermissionDialog(current),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0D47A1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'بدء التفعيل',
                                style: GoogleFonts.tajawal(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          if (!current.isCritical) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => _proceedToNext(),
                              child: Text(
                                'تخطي هذه الخطوة مؤقتاً',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'الخطوة ${_currentIndex + 1} من ${_queue.length}',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
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
