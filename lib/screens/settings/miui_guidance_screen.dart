import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/services/miui_service.dart';

class MiuiGuidanceScreen extends StatefulWidget {
  const MiuiGuidanceScreen({super.key});

  @override
  State<MiuiGuidanceScreen> createState() => _MiuiGuidanceScreenState();
}

class _MiuiGuidanceScreenState extends State<MiuiGuidanceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                FadeInDown(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 24),
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  child: const Text(
                    "تنبيه لمستخدمي أجهزة شاومي",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInDown(
                  delay: const Duration(milliseconds: 300),
                  child: const Text(
                    "لضمان عمل الأذان بشكل صحيح وتنبيهك في الوقت الدقيق، يرجى تفعيل الأذونات التالية من إعدادات النظام:",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                      color: Color(0xFF94A3B8),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildPermissionItem(
                          delay: 400,
                          icon: Icons.lock_open_rounded,
                          title: "العرض على شاشة القفل",
                          description: "يسمح بظهور شاشة الأذان حتى لو كان الهاتف مغلقاً.",
                          onTap: () => MiuiService.openOverlaySettings(),
                        ),
                        _buildPermissionItem(
                          delay: 500,
                          icon: Icons.picture_in_picture_alt_rounded,
                          title: "النوافذ المنبثقة",
                          description: "يسمح للتطبيق بفتح الأذان أثناء استخدام تطبيقات أخرى.",
                          onTap: () => MiuiService.openOverlaySettings(),
                        ),
                        _buildPermissionItem(
                          delay: 600,
                          icon: Icons.rocket_launch_rounded,
                          title: "التشغيل التلقائي",
                          description: "يضمن استمرار عمل التنبيهات حتى بعد إعادة تشغيل الهاتف.",
                          onTap: () => MiuiService.openAutostartSettings(),
                        ),
                        _buildPermissionItem(
                          delay: 700,
                          icon: Icons.battery_saver_rounded,
                          title: "توفير البطارية (لا توجد قيود)",
                          description: "يمنع النظام من إغلاق منبه الأذان لتوفير الطاقة.",
                          onTap: () => MiuiService.openBatteryOptimizationSettings(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        await MiuiService.markSetupCompleted();
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        "فهمت، لقد قمت بالتفعيل",
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "تخطي مؤقتاً",
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: Color(0xFF64748B),
                        fontSize: 16,
                      ),
                    ),
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

  Widget _buildPermissionItem({
    required int delay,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return FadeInRight(
      delay: Duration(milliseconds: delay),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF38BDF8), size: 28),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              description,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF475569), size: 16),
        ),
      ),
    );
  }
}
