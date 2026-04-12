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
  bool _isLoading = false;

  final List<PermissionConfig> _queue = [
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
      isCritical: false, // Recommended
      whyNeeded: 'يمنع "قتل" التطبيق بواسطة النظام في وضع السكون.',
    ),
    PermissionConfig(
      type: PermissionType.autoStart,
      title: 'التشغيل التلقائي',
      description: 'ليعمل الأذان مباشرة بعد إعادة تشغيل الهاتف.',
      icon: Icons.power_settings_new_rounded,
      isCritical: false, // Recommended
      whyNeeded: 'يضمن استعادة مواقيت الأذان فور فتح الهاتف.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Find where to start
    _checkCurrentStatusAndProceed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAwaitingPermissionReturn) {
      _isAwaitingPermissionReturn = false;
      _handleReturnFromSettings();
    }
  }

  Future<void> _checkCurrentStatusAndProceed() async {
    setState(() => _isLoading = true);
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
    _completeOnboarding();
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
    }
  }

  Future<void> _handleReturnFromSettings() async {
    final current = _queue[_currentIndex];
    final granted = await _isGranted(current.type);

    if (granted) {
      _proceedToNext();
    } else {
      // Still not granted, maybe show a snackbar or just re-show dialog
      if (current.isCritical) {
        _showPermissionDialog(current);
      } else {
        // It was elective, let the screen show the manual button again
      }
    }
  }

  Future<void> _proceedToNext() async {
    if (_currentIndex < _queue.length - 1) {
      setState(() {
        _currentIndex++;
      });
      await Future.delayed(const Duration(milliseconds: 600));
      _showPermissionDialog(_queue[_currentIndex]);
    } else {
      _completeOnboarding();
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
            onPressed: () => Navigator.pop(context, true),
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
      _triggerPermission(config.type);
    } else if (result == false && !config.isCritical) {
      _proceedToNext();
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
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/city-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final current = _queue[_currentIndex];
    final progress = (_currentIndex + 1) / _queue.length;

    return PopScope(
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
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
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
                              style: GoogleFonts.tajawal(color: Colors.white54),
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
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
