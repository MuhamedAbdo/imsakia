import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/prayer_widget_service.dart';
import '../services/background_athan_service.dart';
import '../utils/logger.dart';

class WidgetSetupScreen extends StatefulWidget {
  const WidgetSetupScreen({Key? key}) : super(key: key);

  @override
  State<WidgetSetupScreen> createState() => _WidgetSetupScreenState();
}

class _WidgetSetupScreenState extends State<WidgetSetupScreen> {
  bool _isInitializing = false;
  bool _isWidgetEnabled = false;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notifications = await Permission.notification.isGranted;
    final location = await Permission.location.isGranted;
    final exactAlarms = await Permission.scheduleExactAlarm.isGranted;

    setState(() {
      _permissionsGranted = notifications && location && exactAlarms;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _isInitializing = true);

    try {
      // Request notification permissions
      await Permission.notification.request();
      
      // Request location permissions
      await Permission.location.request();
      
      // Request exact alarm permissions
      await Permission.scheduleExactAlarm.request();
      
      // Initialize background services
      await BackgroundAthanService.instance.requestPermissions();
      await BackgroundAthanService.instance.initialize();
      
      setState(() {
        _permissionsGranted = true;
        _isWidgetEnabled = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تفعيل الـ widget بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );

      Logger.success('Widget permissions and services initialized');
    } catch (e) {
      Logger.error('Failed to initialize widget: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تفعيل الـ widget: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات الـ Widget'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Widget Preview
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معاينة الـ Widget',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 320,
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.deepPurple[600]!,
                            Colors.deepPurple[800]!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.mosque,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'إمساكية',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الصلاة القادمة',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'الظهر',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.amber[300],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '2 ساعة 30 دقيقة',
                                        style: TextStyle(
                                          color: Colors.amber[300],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '15 رمضان 1445 هـ',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Permissions Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _permissionsGranted ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _permissionsGranted ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _permissionsGranted ? Icons.check_circle : Icons.error,
                    color: _permissionsGranted ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _permissionsGranted 
                          ? 'جميع الصلاحيات ممنوحة'
                          : 'بعض الصلاحيات مطلوبة',
                      style: TextStyle(
                        color: _permissionsGranted ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Setup Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isInitializing ? null : _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isInitializing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('جاري التفعيل...'),
                        ],
                      )
                    : Text(
                        _permissionsGranted ? 'إعادة تفعيل الـ Widget' : 'تفعيل الـ Widget',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'طريقة الاستخدام',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1. اضغط على زر "تفعيل الـ Widget"\n'
                    '2. اذهب إلى الشاشة الرئيسية\n'
                    '3. اضغط مطولاً على الشاشة\n'
                    '4. اختر "Widgets" أو "الودجت"\n'
                    '5. ابحث عن "إمساكية" واسحبه للشاشة\n'
                    '6. الـ widget سيتحدث تلقائياً كل 15 دقيقة',
                    style: TextStyle(
                      color: Colors.blue[800],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
