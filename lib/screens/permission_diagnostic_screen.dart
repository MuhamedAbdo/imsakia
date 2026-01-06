import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/permission_checker_service.dart';
import '../providers/theme_provider.dart';
import '../utils/logger.dart';

class PermissionDiagnosticScreen extends StatefulWidget {
  const PermissionDiagnosticScreen({super.key});

  @override
  State<PermissionDiagnosticScreen> createState() => _PermissionDiagnosticScreenState();
}

class _PermissionDiagnosticScreenState extends State<PermissionDiagnosticScreen> {
  final PermissionCheckerService _permissionChecker = PermissionCheckerService();
  Map<String, dynamic>? _permissionResults;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await _permissionChecker.checkAllPermissions();
      setState(() {
        _permissionResults = results;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Error checking permissions: $e');
      setState(() {
        _isLoading = false;
        _permissionResults = null;
      });
    }
  }

  Future<void> _requestPermission(String permissionType) async {
    // تم تصحيح الخطأ هنا: استدعاء الفحص وتخزين النتيجة في متغير منفصل قبل التحديث
    try {
      // نفتح إعدادات النظام بناءً على النوع
      switch (permissionType) {
        case 'exactAlarm':
          await _permissionChecker.requestExactAlarmPermission();
          break;
        case 'notifications':
          await _permissionChecker.requestNotificationPermission();
          break;
        case 'location':
          await _permissionChecker.requestLocationPermission();
          break;
      }
      
      // بعد العودة من الإعدادات، نعيد فحص الحالة لتحديث الواجهة
      await _checkPermissions();
    } catch (e) {
      Logger.error('Error requesting permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تشخيص الصلاحيات',
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF1e1e1e),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _permissionResults == null
              ? _buildErrorState(isDarkMode)
              : _buildPermissionList(isDarkMode),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkPermissions,
        tooltip: 'إعادة الفحص',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: isDarkMode ? Colors.white38 : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في فحص الصلاحيات',
            style: GoogleFonts.tajawal(fontSize: 16, color: isDarkMode ? Colors.white60 : Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _checkPermissions,
            child: Text('إعادة المحاولة', style: GoogleFonts.tajawal()),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionList(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_permissionResults!['androidInfo'] != null) ...[
            _buildInfoCard(isDarkMode),
            const SizedBox(height: 16),
          ],
          
          _buildPermissionCard(
            'الإشعارات',
            _permissionResults!['notifications'],
            isDarkMode,
            () => _requestPermission('notifications'),
          ),
          
          _buildPermissionCard(
            'المنبهات الدقيقة',
            _permissionResults!['exactAlarm'],
            isDarkMode,
            () => _requestPermission('exactAlarm'),
          ),
          
          _buildPermissionCard(
            'الموقع',
            _permissionResults!['location'],
            isDarkMode,
            () => _requestPermission('location'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDarkMode) {
    final info = _permissionResults!['androidInfo'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2d2d2d) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('معلومات النظام', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          Text('إصدار أندرويد: ${info['version']}', style: GoogleFonts.tajawal(fontSize: 13)),
          Text('مستوى SDK: ${info['sdkInt']}', style: GoogleFonts.tajawal(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(
    String title,
    Map<String, dynamic>? data,
    bool isDarkMode,
    VoidCallback onTap,
  ) {
    if (data == null) return const SizedBox();
    final bool isGranted = data['granted'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2d2d2d) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold))),
              Icon(isGranted ? Icons.check_circle : Icons.cancel, color: isGranted ? Colors.green : Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Text(data['description'] ?? '', style: GoogleFonts.tajawal(fontSize: 13, color: Colors.grey)),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: Text('إصلاح المشكلة', style: GoogleFonts.tajawal(color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}