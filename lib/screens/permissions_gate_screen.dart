import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/permissions_service.dart';
import '../features/athan/providers/athan_provider.dart';

class PermissionsGateScreen extends StatefulWidget {
  const PermissionsGateScreen({super.key});

  @override
  State<PermissionsGateScreen> createState() => _PermissionsGateScreenState();
}

class _PermissionsGateScreenState extends State<PermissionsGateScreen> with WidgetsBindingObserver {
  Map<String, bool> _permissions = {
    'notifications': false,
    'exact_alarm': false,
    'battery_optimization': false,
    'system_alert': false,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final perms = await PermissionsService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _permissions = perms;
        _isLoading = false;
      });
    }
  }

  bool get _canProceed {
    // Mandatory: Notifications & Exact Alarms
    return (_permissions['notifications'] ?? false) && 
           (_permissions['exact_alarm'] ?? false);
  }

  Future<void> _proceed() async {
    if (!_canProceed) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_canProceed) {
          // If critical permissions are missing, close the app on back press
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
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    children: [
                      // App Logo / Symbol
                      const Icon(Icons.security_rounded, size: 80, color: Colors.white),
                      const SizedBox(height: 24),
                      Text(
                        "أذونات ضرورية لعمل التطبيق",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "يحتاج تطبيق زاد إلى الأذونات التالية ليعمل الأذان في الخلفية بدقة",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Permission List
                      _buildPermissionItem(
                        icon: Icons.notifications_active_rounded,
                        title: "الإشعارات",
                        subtitle: "لعرض تنبيهات الصلاة",
                        isGranted: _permissions['notifications'] ?? false,
                        isMandatory: true,
                        onTap: () => openAppSettings(),
                      ),
                      const SizedBox(height: 16),
                      _buildPermissionItem(
                        icon: Icons.alarm_on_rounded,
                        title: "التنبيهات الدقيقة",
                        subtitle: "لضمان دقة مواعيد الأذان",
                        isGranted: _permissions['exact_alarm'] ?? false,
                        isMandatory: true,
                        onTap: () => openAppSettings(),
                      ),
                      const SizedBox(height: 16),
                      _buildPermissionItem(
                        icon: Icons.battery_saver_rounded,
                        title: "إلغاء قيود البطارية",
                        subtitle: "لمنع النظام من إيقاف الأذان (موصى به)",
                        isGranted: _permissions['battery_optimization'] ?? false,
                        isMandatory: false,
                        onTap: () {
                          final provider = Provider.of<AthanProvider>(context, listen: false);
                          provider.openBatteryOptimizationSettings();
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPermissionItem(
                        icon: Icons.rocket_launch_rounded,
                        title: "التشغيل التلقائي",
                        subtitle: "ليعمل الأذان بعد إعادة تشغيل الهاتف",
                        isGranted: _permissions['system_alert'] ?? false,
                        isMandatory: false,
                        onTap: () {
                          final provider = Provider.of<AthanProvider>(context, listen: false);
                          provider.openComprehensivePermissions();
                        },
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Proceed Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _canProceed ? _proceed : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            disabledBackgroundColor: Colors.white24,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            "منح الأذونات والمتابعة",
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _canProceed ? Colors.white : Colors.white38,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "بدون هذه الأذونات، لن يصلك الأذان في وقته",
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          color: Colors.white60,
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

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required bool isMandatory,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted 
              ? Colors.green.withValues(alpha: 0.5) 
              : Colors.orange.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isGranted ? Colors.green : Colors.orange).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isGranted ? Colors.green : Colors.orange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (isGranted)
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28)
            else
              Text(
                isMandatory ? "مطلوب" : "تفعيل",
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
