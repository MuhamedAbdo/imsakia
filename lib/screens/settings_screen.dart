import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/prayer_times_service.dart';
import '../utils/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFirstTimeSetup;

  const SettingsScreen({super.key, this.isFirstTimeSetup = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsProvider _settingsProvider;

  final Map<String, String> _calculationMethods = {
    'egyptian': 'الهيئة المصرية العامة للمساحة',
    'karachi': 'جامعة العلوم الإسلامية بكراتشي',
    'umm_al_qura': 'جامعة أم القرى، مكة المكرمة',
    'muslim_world_league': 'رابطة العالم الإسلامي',
    'north_america': 'الجمعية الإسلامية لأمريكا الشمالية',
  };

  @override
  void initState() {
    super.initState();
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (!_settingsProvider.isInitialized) {
      _settingsProvider.initialize();
    }
  }

  Future<void> _saveSettings() async {
    try {
      if (widget.isFirstTimeSetup) {
        await _settingsProvider.setFirstLaunchComplete();
      }

      await PrayerTimesService.instance.getCurrentPrayerTimes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ الإعدادات بنجاح',
              style: GoogleFonts.tajawal(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (widget.isFirstTimeSetup) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/main', (route) => false);
            } else {
              Navigator.of(context).pop();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء حفظ الإعدادات',
              style: GoogleFonts.tajawal(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F9FA),
        appBar: widget.isFirstTimeSetup
            ? null
            : AppBar(
                title: Text(
                  'الإعدادات',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
              ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isFirstTimeSetup) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.settings_suggest_rounded,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'إعداد التطبيق',
                        style: GoogleFonts.tajawal(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يرجى ضبط الإعدادات الأساسية لضمان دقة مواقيت الصلاة',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],

              _buildSection(
                title: 'المظهر',
                icon: Icons.palette_outlined,
                children: [_buildThemeSelector(isDark)],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: 'الصلاة والتقويم',
                icon: Icons
                    .brightness_3_outlined, // تم تغيير الأيقونة هنا لحل الخطأ
                children: [
                  _buildCitySelector(isDark),
                  const SizedBox(height: 20),
                  _buildCalculationMethodSelector(isDark),
                  const SizedBox(height: 20),
                  _buildMadhabSelector(isDark),
                  const SizedBox(height: 10),
                  _buildDstToggle(),
                  const SizedBox(height: 10),
                  _buildHijriAdjustmentSelector(isDark),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    widget.isFirstTimeSetup
                        ? 'بدء استخدام التطبيق'
                        : 'حفظ التغييرات',
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- دوال المساعدة (Helper Widgets) لبناء واجهة منظمة ---

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldContainer({required String label, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 14,
            color: isDark ? Colors.amber[100] : Colors.blueGrey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildThemeSelector(bool isDark) {
    return Consumer2<SettingsProvider, ThemeProvider>(
      builder: (context, settings, themeProvider, child) {
        return Wrap(
          spacing: 10,
          children: AppThemeMode.values.map((mode) {
            bool isSelected = settings.themeMode == mode;
            return ChoiceChip(
              label: Text(
                _getThemeDisplayName(mode),
                style: GoogleFonts.tajawal(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              onSelected: (selected) {
                if (selected) {
                  settings.setThemeMode(mode);
                  themeProvider.syncWithSettingsProvider(mode);
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCitySelector(bool isDark) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return _buildFieldContainer(
          label: 'المدينة الحالية',
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: settings.selectedCity,
            dropdownColor: Theme.of(context).cardColor,
            decoration: const InputDecoration(border: InputBorder.none),
            items: AppConstants.cities.map((city) {
              return DropdownMenuItem<String>(
                value: city['id'] as String,
                child: Text(
                  '${city['name']} - ${city['country']}',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) async {
              if (value != null) {
                await settings.setCity(value);
                try {
                  await PrayerTimesService.instance.getCurrentPrayerTimes();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'حدث خطأ أثناء تحديث مواقيت الصلاة',
                          style: GoogleFonts.tajawal(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildCalculationMethodSelector(bool isDark) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return _buildFieldContainer(
          label: 'طريقة الحساب',
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: settings.selectedCalculationMethod,
            dropdownColor: Theme.of(context).cardColor,
            decoration: const InputDecoration(border: InputBorder.none),
            items: _calculationMethods.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) async {
              if (value != null) {
                await settings.setCalculationMethod(value);
                try {
                  await PrayerTimesService.instance.getCurrentPrayerTimes();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'حدث خطأ أثناء تحديث مواقيت الصلاة',
                          style: GoogleFonts.tajawal(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildMadhabSelector(bool isDark) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return _buildFieldContainer(
          label: 'المذهب (لصلاة العصر)',
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: settings.selectedMadhab,
            dropdownColor: Theme.of(context).cardColor,
            decoration: const InputDecoration(border: InputBorder.none),
            items: const [
              DropdownMenuItem(
                value: 'shafi',
                child: Text('الجمهور (شافعي، مالكي، حنبلي)'),
              ),
              DropdownMenuItem(value: 'hanafi', child: Text('الحنفي')),
            ],
            onChanged: (value) async {
              if (value != null) {
                await settings.setMadhab(value);
                try {
                  await PrayerTimesService.instance.getCurrentPrayerTimes();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'حدث خطأ أثناء تحديث مواقيت الصلاة',
                          style: GoogleFonts.tajawal(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDstToggle() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return SwitchListTile(
          title: Text(
            'تفعيل التوقيت الصيفي (+1 ساعة)',
            style: GoogleFonts.tajawal(fontSize: 15),
          ),
          value: settings.dstEnabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: (value) async {
            await settings.setDST(value);
            try {
              await PrayerTimesService.instance.getCurrentPrayerTimes();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'حدث خطأ أثناء تحديث مواقيت الصلاة',
                      style: GoogleFonts.tajawal(),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }

  Widget _buildHijriAdjustmentSelector(bool isDark) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return _buildFieldContainer(
          label: 'تعديل التقويم الهجري',
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: settings.hijriAdjustment,
            dropdownColor: Theme.of(context).cardColor,
            decoration: const InputDecoration(border: InputBorder.none),
            items: [-2, -1, 0, 1, 2].map((offset) {
              String label = offset == 0
                  ? "تاريخ اليوم (تلقائي)"
                  : (offset > 0 ? "تأخير +$offset يوم" : "تقديم $offset يوم");
              return DropdownMenuItem<int>(
                value: offset,
                child: Text(label, style: GoogleFonts.tajawal(fontSize: 15)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) settings.setHijriAdjustment(value);
            },
          ),
        );
      },
    );
  }

  String _getThemeDisplayName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'فاتح';
      case AppThemeMode.dark:
        return 'داكن';
      case AppThemeMode.system:
        return 'النظام';
    }
  }
}
