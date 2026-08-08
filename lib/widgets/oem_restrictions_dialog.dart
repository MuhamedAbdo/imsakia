import 'package:flutter/material.dart';
import '../utils/device_restrictions_handler.dart';

class OemRestrictionsDialog {
  /// يتحقق ويعرض الواجهة إذا كان الجهاز من شاومي ولم يتم عرضها من قبل
  static Future<void> checkAndShow(BuildContext context) async {
    final hasShown = await DeviceRestrictionsHandler.hasShownOemDialog();
    if (hasShown) return;

    final isXiaomi = await DeviceRestrictionsHandler.isXiaomiDevice();
    if (!isXiaomi) return;

    if (context.mounted) {
      await _showBottomSheet(context);
      await DeviceRestrictionsHandler.setHasShownOemDialog(true);
    }
  }

  static Future<void> _showBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _OemRestrictionsWidget(),
    );
  }
}

class _OemRestrictionsWidget extends StatelessWidget {
  const _OemRestrictionsWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'إعدادات هامة لهواتف شاومي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'لضمان عمل الأذان بدقة وفي وقته، يجب تفعيل الإعدادات التالية (هذه الخطوة إلزامية لمنع النظام من إغلاق التطبيق):',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            _buildFeatureRow(
              icon: Icons.autorenew,
              title: 'تفعيل "التشغيل التلقائي" (AutoStart)',
              subtitle: 'للسماح للتطبيق بالعمل في الخلفية',
            ),
            const SizedBox(height: 16),
            _buildFeatureRow(
              icon: Icons.battery_charging_full,
              title: 'إلغاء قيود البطارية',
              subtitle: 'اختيار "لا توجد قيود" لضمان دقة المؤقت',
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                // 1. طلب استثناء البطارية
                await DeviceRestrictionsHandler.requestDisableBatteryOptimizations();
                // 2. توجيه لصفحة التشغيل التلقائي
                await DeviceRestrictionsHandler.openXiaomiAutoStartSettings();

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'تفعيل الإعدادات الآن',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'تخطي مؤقتاً (لا يُنصح به)',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.6,
                  ),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.blueAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
