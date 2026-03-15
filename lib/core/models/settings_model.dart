enum LocationMode { gps, manual }

enum CalculationMethod {
  egyptian,
  ummAlQura,
  muslimWorldLeague,
  northAmerica,
  karachi,
  dubai,
  kuwait,
  qatar,
  singapore,
  tehran,
  turkey,
}

extension CalculationMethodExtension on CalculationMethod {
  String get displayNameEn {
    switch (this) {
      case CalculationMethod.egyptian:
        return 'Egyptian General Authority';
      case CalculationMethod.ummAlQura:
        return 'Umm al-Qura, Makkah';
      case CalculationMethod.muslimWorldLeague:
        return 'Muslim World League';
      case CalculationMethod.northAmerica:
        return 'North America (ISNA)';
      case CalculationMethod.karachi:
        return 'University of Islamic Sciences, Karachi';
      case CalculationMethod.dubai:
        return 'Dubai';
      case CalculationMethod.kuwait:
        return 'Kuwait';
      case CalculationMethod.qatar:
        return 'Qatar';
      case CalculationMethod.singapore:
        return 'Singapore';
      case CalculationMethod.tehran:
        return 'Institute of Geophysics, Tehran';
      case CalculationMethod.turkey:
        return 'Diyanet İşleri Başkanlığı, Turkey';
    }
  }

  String get displayNameAr {
    switch (this) {
      case CalculationMethod.egyptian:
        return 'الهيئة المصرية العامة للمساحة';
      case CalculationMethod.ummAlQura:
        return 'أم القرى، مكة المكرمة';
      case CalculationMethod.muslimWorldLeague:
        return 'رابطة العالم الإسلامي';
      case CalculationMethod.northAmerica:
        return 'أمريكا الشمالية (ISNA)';
      case CalculationMethod.karachi:
        return 'جامعة العلوم الإسلامية، كراتشي';
      case CalculationMethod.dubai:
        return 'دبي';
      case CalculationMethod.kuwait:
        return 'الكويت';
      case CalculationMethod.qatar:
        return 'قطر';
      case CalculationMethod.singapore:
        return 'سنغافورة';
      case CalculationMethod.tehran:
        return 'معهد الجيوفيزياء، طهران';
      case CalculationMethod.turkey:
        return 'رئاسة الشؤون الدينية، تركيا';
    }
  }
}

class SettingsModel {
  final LocationMode locationMode;
  final CalculationMethod calculationMethod;

  /// Accumulated (persisted) Hijri day offset.
  final int hijriBaseOffset;

  /// Transient UI selector value (-1, 0, +1). Always 0 after an adjustment.
  final int hijriOffset;

  final bool athanEnabled;
  final bool notificationsEnabled;
  final bool athanSoundEnabled;
  final bool isUnifiedAthan;
  final bool qiblaVibrationEnabled;

  // Unified / default athan sound (used for all prayers when isUnifiedAthan=true)
  final String selectedAthanSound;

  // Per-prayer sounds (used when isUnifiedAthan=false)
  final String selectedFajrSound;
  final String selectedDhuhrSound;
  final String selectedAsrSound;
  final String selectedMaghribSound;
  final String selectedIshaSound;

  final String languageCode; // 'ar' or 'en'
  final bool isDarkMode;

  const SettingsModel({
    this.locationMode = LocationMode.gps,
    this.calculationMethod = CalculationMethod.egyptian,
    this.hijriBaseOffset = 0,
    this.hijriOffset = 0,
    this.athanEnabled = true,
    this.notificationsEnabled = true,
    this.athanSoundEnabled = true,
    this.isUnifiedAthan = true,
    this.qiblaVibrationEnabled = true,
    this.selectedAthanSound = 'assets/audio/athan_egypt_ab.mp3',
    this.selectedFajrSound = 'assets/audio/athan_fajr.mp3',
    this.selectedDhuhrSound = 'assets/audio/athan_egypt_ab.mp3',
    this.selectedAsrSound = 'assets/audio/athan_egypt_ab.mp3',
    this.selectedMaghribSound = 'assets/audio/athan_egypt_ab.mp3',
    this.selectedIshaSound = 'assets/audio/athan_egypt_ab.mp3',
    this.languageCode = 'ar',
    this.isDarkMode = true,
  });

  SettingsModel copyWith({
    LocationMode? locationMode,
    CalculationMethod? calculationMethod,
    int? hijriBaseOffset,
    int? hijriOffset,
    bool? athanEnabled,
    bool? notificationsEnabled,
    bool? athanSoundEnabled,
    bool? isUnifiedAthan,
    bool? qiblaVibrationEnabled,
    String? selectedAthanSound,
    String? selectedFajrSound,
    String? selectedDhuhrSound,
    String? selectedAsrSound,
    String? selectedMaghribSound,
    String? selectedIshaSound,
    String? languageCode,
    bool? isDarkMode,
  }) {
    return SettingsModel(
      locationMode: locationMode ?? this.locationMode,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      hijriBaseOffset: hijriBaseOffset ?? this.hijriBaseOffset,
      hijriOffset: hijriOffset ?? this.hijriOffset,
      athanEnabled: athanEnabled ?? this.athanEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      athanSoundEnabled: athanSoundEnabled ?? this.athanSoundEnabled,
      isUnifiedAthan: isUnifiedAthan ?? this.isUnifiedAthan,
      qiblaVibrationEnabled: qiblaVibrationEnabled ?? this.qiblaVibrationEnabled,
      selectedAthanSound: selectedAthanSound ?? this.selectedAthanSound,
      selectedFajrSound: selectedFajrSound ?? this.selectedFajrSound,
      selectedDhuhrSound: selectedDhuhrSound ?? this.selectedDhuhrSound,
      selectedAsrSound: selectedAsrSound ?? this.selectedAsrSound,
      selectedMaghribSound: selectedMaghribSound ?? this.selectedMaghribSound,
      selectedIshaSound: selectedIshaSound ?? this.selectedIshaSound,
      languageCode: languageCode ?? this.languageCode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'locationMode': locationMode.index,
        'calculationMethod': calculationMethod.index,
        'hijriBaseOffset': hijriBaseOffset,
        'hijriOffset': hijriOffset,
        'athanEnabled': athanEnabled,
        'notificationsEnabled': notificationsEnabled,
        'athanSoundEnabled': athanSoundEnabled,
        'isUnifiedAthan': isUnifiedAthan,
        'qiblaVibrationEnabled': qiblaVibrationEnabled,
        'selectedAthanSound': selectedAthanSound,
        'selectedFajrSound': selectedFajrSound,
        'selectedDhuhrSound': selectedDhuhrSound,
        'selectedAsrSound': selectedAsrSound,
        'selectedMaghribSound': selectedMaghribSound,
        'selectedIshaSound': selectedIshaSound,
        'languageCode': languageCode,
        'isDarkMode': isDarkMode,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        locationMode:
            LocationMode.values[json['locationMode'] as int? ?? 0],
        calculationMethod:
            CalculationMethod.values[json['calculationMethod'] as int? ?? 0],
        hijriBaseOffset: json['hijriBaseOffset'] as int? ?? 0,
        hijriOffset: 0,
        athanEnabled: json['athanEnabled'] as bool? ?? true,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        athanSoundEnabled: json['athanSoundEnabled'] as bool? ?? true,
        isUnifiedAthan: json['isUnifiedAthan'] as bool? ?? true,
        qiblaVibrationEnabled: json['qiblaVibrationEnabled'] as bool? ?? true,
        selectedAthanSound: json['selectedAthanSound'] as String? ??
            'assets/audio/athan_egypt_ab.mp3',
        selectedFajrSound: json['selectedFajrSound'] as String? ??
            'assets/audio/athan_fajr.mp3',
        selectedDhuhrSound: json['selectedDhuhrSound'] as String? ??
            'assets/audio/athan_egypt_ab.mp3',
        selectedAsrSound: json['selectedAsrSound'] as String? ??
            'assets/audio/athan_egypt_ab.mp3',
        selectedMaghribSound: json['selectedMaghribSound'] as String? ??
            'assets/audio/athan_egypt_ab.mp3',
        selectedIshaSound: json['selectedIshaSound'] as String? ??
            'assets/audio/athan_egypt_ab.mp3',
        languageCode: json['languageCode'] as String? ?? 'ar',
        isDarkMode: json['isDarkMode'] as bool? ?? true,
      );
}
