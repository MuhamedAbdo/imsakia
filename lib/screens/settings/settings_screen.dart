import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:developer' as developer;
import '../../core/theme/app_colors.dart';
import '../../core/models/settings_model.dart';
import '../../core/models/city_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/prayer_times_provider.dart';
import '../../providers/hijri_calendar_provider.dart';
import '../../core/services/athan_audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// ── Available Athan Sounds ────────────────────────────────────────────────────
// NOTE: Add the corresponding mp3 files to assets/audio/ with these names.
const List<Map<String, String>> _availableAthanSounds = [
  {
    'name': 'عبد الباسط (مصر)',
    'nameEn': 'Abdul Baset (Egypt)',
    'path': 'assets/audio/athan_egypt_ab.mp3',
  },
  {
    'name': 'الحرم المكي',
    'nameEn': 'Makkah Haram',
    'path': 'assets/audio/athan_makkah.mp3',
  },
  {
    'name': 'مشاري راشد العفاسي',
    'nameEn': 'Mishary Rashid Al-Afasy',
    'path': 'assets/audio/athan_mishari.mp3',
  },
  {
    'name': 'محمد رفعت',
    'nameEn': 'Muhammad Rifaat',
    'path': 'assets/audio/athan_rifaat.mp3',
  },
  {
    'name': 'سعد الغامدي',
    'nameEn': 'Saad Al-Ghamdi',
    'path': 'assets/audio/athan_ghamdi.mp3',
  },
];

// Fajr sounds include a wider selection with dedicated Fajr recordings
const List<Map<String, String>> _availableFajrSounds = [
  {
    'name': 'أذان الفجر (المدينة المنورة)',
    'nameEn': 'Fajr Athan (Madinah)',
    'path': 'assets/audio/fajr_madinah.mp3',
  },
  {
    'name': 'أذان الفجر (الحرم المكي)',
    'nameEn': 'Fajr Athan (Makkah Haram)',
    'path': 'assets/audio/fajr_makkah.mp3',
  },
  {
    'name': 'أذان الفجر (مشاري العفاسي)',
    'nameEn': 'Fajr Athan (Mishary Al-Afasy)',
    'path': 'assets/audio/fajr_mishari.mp3',
  },
];

class _SettingsScreenState extends State<SettingsScreen> {
  List<CityModel> _cities = [];
  List<CityModel> _filteredCities = [];
  final _searchController = TextEditingController();
  bool _citiesLoaded = false;

  /// Name of the currently selected city shown in the search field.
  /// When null the field is in search mode; when set it shows the city name.
  String? _selectedCityDisplay;

  /// Path of the currently playing audio preview.
  String? _playingPath;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── City helpers ──────────────────────────────────────────────────────────

  Future<void> _loadCities() async {
    if (_citiesLoaded) return;
    final raw = await rootBundle.loadString('assets/data/cities.json');
    final list = jsonDecode(raw) as List;
    _cities =
        list.map((e) => CityModel.fromJson(e as Map<String, dynamic>)).toList();
    _filteredCities = _cities;
    _citiesLoaded = true;
  }

  void _filterCities(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredCities = _cities
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.nameAr.contains(q) ||
              c.country.toLowerCase().contains(q) ||
              c.countryCode.toLowerCase().contains(q))
          .toList();
    });
  }

  /// Called when user taps the ✕ icon to clear city selection and re-enter
  /// search mode.
  void _clearCitySelection() {
    setState(() {
      _selectedCityDisplay = null;
      _searchController.clear();
      _filteredCities = _cities;
    });
  }

  // ── Audio Preview Helpers ──────────────────────────────────────────────────

  Future<void> _handlePlayToggle(String path) async {
    try {
      if (_playingPath == path) {
        // Same file is playing -> stop it
        await AthanAudioService().stop();
        if (mounted) {
          setState(() {
            _playingPath = null;
          });
        }
      } else {
        // Different file or nothing playing -> stop old and play new
        await AthanAudioService().stop();
        if (mounted) {
          setState(() {
            _playingPath = path;
          });
        }
        
        developer.log('[SettingsScreen] Explicitly triggering: $path', name: 'SettingsScreen');
        await AthanAudioService().play(path);

        // Listen for natural completion to reset UI
        // Note: AthanAudioService handles natural completion via _disposePlayer.
        // We could poll isPlaying or use a stream if available.
        // For now, simple state tracking is enough.
      }
    } catch (e) {
      developer.log('[SettingsScreen] ERROR playing $path: $e', name: 'SettingsScreen', error: e);
      if (mounted) {
        setState(() {
          _playingPath = null;
        });
      }
    }
  }

  void _resetPlayingState() {
     if (_playingPath != null) {
       AthanAudioService().stop();
       setState(() {
         _playingPath = null;
       });
     }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final textColor = isDark ? Colors.white : AppColors.darkNavy;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppColors.darkNavy, AppColors.darkBg]
                  : [AppColors.lightBg, AppColors.lightBeige],
            ),
          ),
        ),
        SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: FadeInDown(
                    child: Text(
                      'الإعدادات',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.gold,
                              ),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  // ── Location Section ─────────────────────────────
                  _SectionHeader(
                      title: 'الموقع',
                      isDark: isDark),

                  _SettingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SegmentedSetting(
                          label: 'طريقة تحديد الموقع',
                          options: [
                            _Option(
                              icon: Icons.gps_fixed,
                              label: 'GPS',
                              value: LocationMode.gps,
                            ),
                            _Option(
                              icon: Icons.search,
                              label: 'يدوي',
                              value: LocationMode.manual,
                            ),
                          ],
                          selected: settings.locationMode,
                          onChanged: (v) async {
                            final locationProvider = context.read<LocationProvider>();
                            final settingsProvider = context.read<SettingsProvider>();
                            final prayerProv = context.read<PrayerTimesProvider>();
                            await settingsProvider.setLocationMode(v);
                            if (!context.mounted) return;
                            if (v == LocationMode.gps) {
                              await locationProvider.fetchGpsLocation(
                                locale: 'ar',
                                onLocationChanged: (loc) => prayerProv.calculate(
                                  loc,
                                  settingsProvider.calculationMethod,
                                ),
                              );
                            }
                          },
                        ),
                        if (settings.locationMode == LocationMode.manual) ...[
                          const Divider(height: 24),
                          _CitySearch(
                            isDark: isDark,
                            onLoad: _loadCities,
                            onSearch: _filterCities,
                            filteredCities: _filteredCities,
                            searchController: _searchController,
                            selectedCityDisplay: _selectedCityDisplay,
                            onClearSelection: _clearCitySelection,
                            onSelect: (city) async {
                              // FIX 1: Show city name in textbox immediately
                              final displayName = city.nameAr;
                              setState(() {
                                _selectedCityDisplay = displayName;
                                _searchController.text = displayName;
                                _filteredCities = [];
                              });
                               final locationProvider = context.read<LocationProvider>();
                               final prayerProv = context.read<PrayerTimesProvider>();
                               final settingsProvider = context.read<SettingsProvider>();

                               await locationProvider.setManualLocation(
                                 city,
                                 onLocationChanged: (loc) => prayerProv.calculate(
                                   loc,
                                   settingsProvider.calculationMethod,
                                 ),
                               );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Calculation Method ──────────────────────────
                  _SectionHeader(
                      title: 'طريقة الحساب',
                      isDark: isDark),

                  _SettingCard(
                    child: _DropdownSetting<CalculationMethod>(
                      label: 'اختر الطريقة',
                      value: settings.calculationMethod,
                      items: CalculationMethod.values.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            m.displayNameAr,
                            style: TextStyle(fontSize: 13, color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                        onChanged: (v) async {
                          if (v != null) {
                            final settingsProvider = context.read<SettingsProvider>();
                            final locationProvider = context.read<LocationProvider>();
                            final prayerProv = context.read<PrayerTimesProvider>();
                            await settingsProvider.setCalculationMethod(v);
                            if (!context.mounted) return;
                            await _refreshPrayerTimes(
                              locationProvider,
                              settingsProvider,
                              prayerProv,
                            );
                          }
                        },
                    ),
                  ),

                  // ── Hijri Correction ────────────────────────────
                  _SectionHeader(
                      title: 'تصحيح التاريخ الهجري',
                      isDark: isDark),

                  _SettingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ضبط يدوي للتاريخ الهجري',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor),
                        ),
                        // Show the accumulated base offset as info
                        if (settings.hijriBaseOffset != 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            'الإزاحة المخزنة: ${settings.hijriBaseOffset > 0 ? '+' : ''}${settings.hijriBaseOffset} يوم',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: isDark ? AppColors.gold : Colors.brown),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // FIX 2: Cumulative toggle – tapping -1 or +1 applies
                        // the delta to hijriBaseOffset then resets selector to 0.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [-1, 0, 1].map((offset) {
                            final isSelected = settings.hijriOffset == offset;
                            return GestureDetector(
                              onTap: () async {
                                if (offset == 0) {
                                  // Tapping 0 resets any pending selection only
                                  // (hijriBaseOffset stays intact – that is the
                                  // permanent cumulative correction).
                                  return;
                                }
                                // Apply the delta cumulatively and reset the UI
                                final hijriProvider = context.read<HijriCalendarProvider>();
                                final locationProvider = context.read<LocationProvider>();
                                final settingsProvider = context.read<SettingsProvider>();
                                final targetBaseOffset = settingsProvider.hijriBaseOffset + offset;
                                final countryCode = locationProvider.location?.countryCode;

                                await settingsProvider.applyHijriOffset(offset);
                                if (!context.mounted) return;

                                await hijriProvider.fetch(
                                  offset: targetBaseOffset,
                                  countryCode: countryCode,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 72,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.gold
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.gold
                                        : Colors.white24,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    offset > 0 ? '+$offset' : '$offset',
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.darkNavy
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // ── Notifications ────────────────────────────────
                  _SectionHeader(
                      title: 'الأذان والإشعارات',
                      isDark: isDark),

                  _SettingCard(
                    child: Column(
                      children: [
                        _SwitchTile(
                          icon: Icons.volume_up,
                          title: 'تشغيل الأذان',
                          subtitle: 'تشغيل الأذان في أوقات الصلاة',
                          value: settings.athanEnabled,
                          onChanged: (v) => settings.setAthanEnabled(v),
                          isDark: isDark,
                        ),
                        _SwitchTile(
                          icon: Icons.notifications_active,
                          title: 'الإشعارات',
                          subtitle: 'إشعارات قبل وقت الصلاة',
                          value: settings.notificationsEnabled,
                          onChanged: (v) =>
                              settings.setNotificationsEnabled(v),
                          isDark: isDark,
                        ),
                        const Divider(height: 16),
                        _SwitchTile(
                          icon: Icons.audiotrack,
                          title: 'صوت الأذان',
                          subtitle: 'تنبيه بصوت الأذان عند دخول الوقت',
                          value: settings.athanSoundEnabled,
                          onChanged: (v) =>
                              settings.setAthanSoundEnabled(v),
                          isDark: isDark,
                        ),
                        if (settings.athanSoundEnabled) ...[ 
                          const SizedBox(height: 16),
                          _SwitchTile(
                            icon: Icons.sync,
                            title: 'توحيد صوت الأذان',
                            subtitle: 'نفس الصوت لجميع الصلوات',
                            value: settings.isUnifiedAthan,
                            onChanged: (v) =>
                                settings.setIsUnifiedAthan(v),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          if (settings.isUnifiedAthan) ...[
                            // ── Unified: one selector for all prayers ──
                            // Logic: Filter out any file containing "fajr" in its name.
                            _AthanSoundSelector(
                              label: 'صوت الأذان (جميع الصلوات)',
                              value: settings.selectedAthanSound,
                              options: _availableAthanSounds
                                  .where((opt) => !opt['path']!.contains('fajr'))
                                  .toList(),
                              playingPath: _playingPath,
                              onPlayToggle: _handlePlayToggle,
                              onChanged: (v) {
                                  _resetPlayingState();
                                  settings.setSelectedAthanSound(v);
                              },
                            ),
                            const SizedBox(height: 12),
                            // Info for Fajr in Unified Mode
                            _InfoBox(
                              text: 'ملاحظة: الفجر يستخدم أذان الحرم المكي دائماً في الوضع الموحد.',
                              isDark: isDark,
                            ),
                          ] else ...[
                            // ── Non-unified: one selector per prayer ──
                            // Fajr slot: allow any fajr_ prefix sound.
                            _AthanSoundSelector(
                              label: '🌙  الفجر',
                              value: settings.selectedFajrSound,
                              options: _availableFajrSounds,
                              playingPath: _playingPath,
                              onPlayToggle: _handlePlayToggle,
                              onChanged: (v) {
                                  _resetPlayingState();
                                  settings.setSelectedFajrSound(v);
                              },
                            ),
                            const SizedBox(height: 12),
                            // Other slots: allow any athan_ prefix sound.
                            _AthanSoundSelector(
                              label: '☀️  الظهر',
                              value: settings.selectedDhuhrSound,
                              options: _availableAthanSounds
                                  .where((opt) => opt['path']!.contains('athan_'))
                                  .toList(),
                              playingPath: _playingPath,
                              onPlayToggle: _handlePlayToggle,
                              onChanged: (v) {
                                  _resetPlayingState();
                                  settings.setSelectedDhuhrSound(v);
                              },
                            ),
                            const SizedBox(height: 12),
                            _AthanSoundSelector(
                              label: '🌤️  العصر',
                              value: settings.selectedAsrSound,
                              options: _availableAthanSounds
                                  .where((opt) => opt['path']!.contains('athan_'))
                                  .toList(),
                              playingPath: _playingPath,
                              onPlayToggle: _handlePlayToggle,
                              onChanged: (v) {
                                  _resetPlayingState();
                                  settings.setSelectedAsrSound(v);
                              },
                            ),
                            const SizedBox(height: 12),
                            _AthanSoundSelector(
                              label: '🌅  المغرب',
                              value: settings.selectedMaghribSound,
                              options: _availableAthanSounds
                                  .where((opt) => opt['path']!.contains('athan_'))
                                  .toList(),
                              playingPath: _playingPath,
                              onPlayToggle: _handlePlayToggle,
                              onChanged: (v) {
                                  _resetPlayingState();
                                  settings.setSelectedMaghribSound(v);
                              },
                            ),
                            const SizedBox(height: 12),
                            _AthanSoundSelector(
                              label: '🌙  العشاء',
                              value: settings.selectedIshaSound,
                              options: _availableAthanSounds
                                  .where((opt) => opt['path']!.contains('athan_'))
                                  .toList(),
                              playingPath: _playingPath,
                              onPlayToggle: _handlePlayToggle,
                              onChanged: (v) {
                                  _resetPlayingState();
                                  settings.setSelectedIshaSound(v);
                              },
                            ),
                          ],
                        ],
                        const Divider(height: 24),
                        _EidTakbeerTile(isDark: isDark),
                      ],
                    ),
                  ),

                  // ── Qibla ────────────────────────────────────────
                  _SectionHeader(
                      title: 'القبلة',
                      isDark: isDark),

                  _SettingCard(
                    child: Column(
                      children: [
                        _SwitchTile(
                          icon: Icons.vibration,
                          title: 'اهتزاز عند تحديد القبلة',
                          subtitle: 'ارتجاج خفيف عند توجيه الجهاز للقبلة',
                          value: settings.qiblaVibrationEnabled,
                          onChanged: (v) =>
                              settings.setQiblaVibrationEnabled(v),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // ── Appearance ───────────────────────────────────
                  _SectionHeader(
                      title: 'المظهر',
                      isDark: isDark),

                  _SettingCard(
                    child: Column(
                      children: [
                        _SwitchTile(
                          icon: Icons.dark_mode,
                          title: 'الوضع الداكن',
                          subtitle: '',
                          value: settings.isDarkMode,
                          onChanged: (v) => settings.setDarkMode(v),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _refreshPrayerTimes(
    LocationProvider locationProvider,
    SettingsProvider settingsProvider,
    PrayerTimesProvider prayerTimesProvider,
  ) async {
    final loc = locationProvider.location;
    final method = settingsProvider.calculationMethod;
    if (loc != null) {
      await prayerTimesProvider.calculate(loc, method);
    }
  }
}

// ── Helper Widgets ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.gold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _Option<T> {
  final IconData icon;
  final String label;
  final T value;
  const _Option({required this.icon, required this.label, required this.value});
}

class _SegmentedSetting<T> extends StatelessWidget {
  final String label;
  final List<_Option<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const _SegmentedSetting({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final unselectedColor = isDark ? Colors.white70 : AppColors.darkNavy.withValues(alpha: 0.6);
    final unselectedBgColor = isDark 
        ? Colors.white.withValues(alpha: 0.06) 
        : AppColors.darkNavy.withValues(alpha: 0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: options.map((opt) {
            final isSelected = opt.value == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold : unselectedBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : unselectedBgColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        opt.icon,
                        color: isSelected ? AppColors.darkNavy : unselectedColor,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opt.label,
                        style: TextStyle(
                          color: isSelected ? AppColors.darkNavy : unselectedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DropdownSetting<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownSetting({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final textColor = isDark ? Colors.white : AppColors.darkNavy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor)),
        const SizedBox(height: 12),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkCard : Colors.white,
          icon: const Icon(Icons.expand_more, color: AppColors.gold),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.darkNavy;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.gold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: subTextColor)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.gold,
        ),
      ],
    );
  }
}

// ── Eid Takbeer Toggle ───────────────────────────────────────────────────────

class _EidTakbeerTile extends StatefulWidget {
  final bool isDark;
  const _EidTakbeerTile({required this.isDark});

  @override
  State<_EidTakbeerTile> createState() => _EidTakbeerTileState();
}

class _EidTakbeerTileState extends State<_EidTakbeerTile> {
  static const _key = 'enable_eid_takbeer';
  bool _enabled = true; // default on

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _enabled = prefs.getBool(_key) ?? true;
      });
    }
  }

  Future<void> _toggle(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, v);
    if (mounted) setState(() => _enabled = v);
  }

  @override
  Widget build(BuildContext context) {
    return _SwitchTile(
      icon: Icons.celebration_outlined,
      title: 'تكبيرات العيد',
      subtitle: 'تشغيل تكبيرات العيد بعد أذان الفجر مباشرةً',
      value: _enabled,
      onChanged: _toggle,
      isDark: widget.isDark,
    );
  }
}

// ── City Search Widget ────────────────────────────────────────────────────────

class _CitySearch extends StatelessWidget {
  final bool isDark;
  final Future<void> Function() onLoad;
  final void Function(String) onSearch;
  final List<CityModel> filteredCities;
  final TextEditingController searchController;
  final String? selectedCityDisplay;
  final VoidCallback onClearSelection;
  final void Function(CityModel) onSelect;

  const _CitySearch({
    required this.isDark,
    required this.onLoad,
    required this.onSearch,
    required this.filteredCities,
    required this.searchController,
    required this.selectedCityDisplay,
    required this.onClearSelection,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = selectedCityDisplay != null;
    final textColor = isDark ? Colors.white : AppColors.darkNavy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'البحث عن مدينة',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          // When a city is already selected, tapping the field should clear
          // and re-enter search mode immediately.
          onTap: hasSelection ? onClearSelection : onLoad,
          onChanged: hasSelection ? null : onSearch,
          readOnly: hasSelection,
          style: TextStyle(
            color: hasSelection ? AppColors.gold : textColor,
            fontWeight:
                hasSelection ? FontWeight.w600 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: 'اكتب اسم المدينة...',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            prefixIcon: Icon(
              hasSelection ? Icons.location_on : Icons.search,
              color: AppColors.gold,
            ),
            // FIX 1: Show ✕ icon to clear the selection
            suffixIcon: hasSelection
                ? IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
                    onPressed: onClearSelection,
                    tooltip: 'مسح الاختيار',
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasSelection ? AppColors.gold : Colors.white24,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.gold),
            ),
            filled: true,
            fillColor: hasSelection
                ? AppColors.gold.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        // Show results list only when actively searching (not when city selected)
        if (!hasSelection &&
            filteredCities.isNotEmpty &&
            searchController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredCities.take(20).length,
              itemBuilder: (context, i) {
                final city = filteredCities[i];
                return ListTile(
                  leading: Icon(Icons.location_city,
                      color: AppColors.gold, size: 18),
                  title: Text(
                    city.nameAr,
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    city.countryAr,
                    style:
                        TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                  onTap: () => onSelect(city),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ── Athan Sound Selector ──────────────────────────────────────────────────────

class _AthanSoundSelector extends StatelessWidget {
  final String label;
  final String value;
  final List<Map<String, String>> options;
  final String? playingPath;
  final Future<void> Function(String) onPlayToggle;
  final ValueChanged<String> onChanged;

  const _AthanSoundSelector({
    required this.label,
    required this.value,
    required this.options,
    required this.playingPath,
    required this.onPlayToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final textColor = isDark ? Colors.white : AppColors.darkNavy;
    final bgColor = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : AppColors.darkNavy.withValues(alpha: 0.05);

    // Guard: if the current value is not in this list, fall back to first item
    final safeValue = options.any((o) => o['path'] == value)
        ? value
        : options.first['path']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: textColor)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: safeValue,
                    items: options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt['path'],
                        child: Text(
                          opt['name']!,
                          style: TextStyle(fontSize: 14, color: textColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                    isExpanded: true,
                    dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                    icon:
                        const Icon(Icons.expand_more, color: AppColors.gold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => onPlayToggle(safeValue),
              icon: Icon(
                playingPath == safeValue
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                foregroundColor: AppColors.gold,
              ),
            ),
            IconButton.filledTonal(
              onPressed: () {
                AthanAudioService().stop();
                onPlayToggle(''); // Trigger a reset via callback if needed, but here we just stop
              },
              icon: const Icon(Icons.stop_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  final bool isDark;

  const _InfoBox({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.darkNavy.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
