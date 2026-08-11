/// نموذج بيانات مناسبة إسلامية واحدة.
///
/// [names]          — قائمة أسماء المناسبة (قد يتعدد الحدث في يوم واحد).
/// [hasFastingReminder] — هل ينبغي إرسال تذكير بالصيام قبلها؟
/// [reminderDaysBefore] — عدد الأيام قبل المناسبة لإرسال إشعار الصيام.
/// [fastingReminderTitle] — عنوان إشعار الصيام (null = لا صيام).
/// [fastingReminderBody]  — نص إشعار الصيام.
class IslamicOccasion {
  final List<String> names;
  final bool hasFastingReminder;
  final int reminderDaysBefore;
  final String? fastingReminderTitle;
  final String? fastingReminderBody;

  const IslamicOccasion({
    required this.names,
    this.hasFastingReminder = false,
    this.reminderDaysBefore = 1,
    this.fastingReminderTitle,
    this.fastingReminderBody,
  });

  /// اسم المناسبة الأساسي (أول عنصر في القائمة).
  String get primaryName => names.first;
}

/// قاموس المناسبات الإسلامية والتاريخية في التقويم الهجري.
/// المفتاح: (رقم_الشهر, رقم_اليوم)
/// القيمة: [IslamicOccasion]
class IslamicOccasions {
  static const Map<(int, int), IslamicOccasion> occasions = {
    // ─────────────────────────────────────────────
    // 1 محرم
    // ─────────────────────────────────────────────
    (1, 1): IslamicOccasion(
      names: ['رأس السنة الهجرية الجديدة • بداية هجرة النبي ﷺ'],
    ),
    (1, 8): IslamicOccasion(
      // يوم 8 محرم: تذكير بصيام تاسوعاء وعاشوراء
      names: ['اليوم الثامن من محرم'],
      hasFastingReminder: true,
      reminderDaysBefore: 0, // الإشعار في نفس هذا اليوم (8 محرم)
      fastingReminderTitle: 'تذكير: تاسوعاء وعاشوراء غداً وبعده 🌙',
      fastingReminderBody:
          'غداً يوم التاسع (تاسوعاء)، وبعده يوم العاشر (عاشوراء). '
          'صيامهما سنة نبوية مؤكدة. لا تفوّتك!',
    ),
    (1, 9): IslamicOccasion(
      names: ['يوم تاسوعاء'],
      hasFastingReminder: true,
      reminderDaysBefore: 0, // الإشعار في نفس هذا اليوم
      fastingReminderTitle: 'اليوم تاسوعاء — غداً عاشوراء 🌙',
      fastingReminderBody:
          'غداً عاشوراء (10 محرم). صيامه يُكفّر ذنوب سنة كاملة. '
          'جهّز نيّتك الآن!',
    ),
    (1, 10): IslamicOccasion(
      names: [
        'يوم عاشوراء',
        'يوم نجّى الله فيه موسى عليه السلام وأغرق فرعون',
      ],
    ),

    // ─────────────────────────────────────────────
    // 3 ربيع الأول
    // ─────────────────────────────────────────────
    (3, 12): IslamicOccasion(
      names: ['المولد النبوي الشريف • ذكرى مولد النبي محمد ﷺ'],
    ),
    (3, 17): IslamicOccasion(
      names: ['وفاة السيدة خديجة رضي الله عنها • عام الحزن'],
    ),

    // ─────────────────────────────────────────────
    // 4 ربيع الآخر
    // ─────────────────────────────────────────────
    (4, 18): IslamicOccasion(
      names: ['بناء أول مسجد في الإسلام (مسجد قباء)'],
    ),

    // ─────────────────────────────────────────────
    // 5 جمادى الأولى
    // ─────────────────────────────────────────────
    (5, 8): IslamicOccasion(
      names: ['معركة مؤتة (أولى غزوات المسلمين خارج الجزيرة العربية)'],
    ),
    (5, 15): IslamicOccasion(
      names: ['وفاة السيدة فاطمة الزهراء رضي الله عنها'],
    ),

    // ─────────────────────────────────────────────
    // 7 رجب
    // ─────────────────────────────────────────────
    (7, 1): IslamicOccasion(names: ['غزوة تبوك']),
    (7, 13): IslamicOccasion(
      names: ['مولد الإمام علي بن أبي طالب رضي الله عنه'],
    ),
    (7, 27): IslamicOccasion(names: ['ذكرى الإسراء والمعراج']),

    // ─────────────────────────────────────────────
    // 8 شعبان
    // ─────────────────────────────────────────────
    (8, 1): IslamicOccasion(
      names: ['تحويل القبلة من المسجد الأقصى إلى المسجد الحرام'],
    ),
    (8, 14): IslamicOccasion(
      // يوم 14 شعبان: تذكير بليلة النصف من شعبان (15 شعبان)
      names: ['اليوم الرابع عشر من شعبان'],
      hasFastingReminder: true,
      reminderDaysBefore: 0,
      fastingReminderTitle: 'غداً ليلة النصف من شعبان 🌙',
      fastingReminderBody:
          'غداً ليلة البراءة (15 شعبان). يستحب الإكثار من الدعاء '
          'والاستغفار. ويسنّ صيام يوم 15 شعبان.',
    ),
    (8, 15): IslamicOccasion(
      names: ['ليلة النصف من شعبان (ليلة البراءة)'],
    ),

    // ─────────────────────────────────────────────
    // 9 رمضان
    // ─────────────────────────────────────────────
    (9, 1): IslamicOccasion(names: ['أول أيام شهر رمضان المبارك']),
    (9, 17): IslamicOccasion(names: ['غزوة بدر الكبرى • يوم الفرقان']),
    (9, 20): IslamicOccasion(names: ['فتح مكة المكرمة']),
    (9, 21): IslamicOccasion(
      names: ['استشهاد الإمام علي بن أبي طالب رضي الله عنه'],
    ),
    (9, 27): IslamicOccasion(names: ['ليلة القدر (على الأرجح)']),
    (9, 29): IslamicOccasion(
      names: ['ليلة القدر في الأعوام ذات 29 يوماً'],
    ),
    (9, 30): IslamicOccasion(names: ['آخر يوم من رمضان المبارك']),

    // ─────────────────────────────────────────────
    // 10 شوال
    // ─────────────────────────────────────────────
    (10, 1): IslamicOccasion(names: ['عيد الفطر المبارك']),
    (10, 3): IslamicOccasion(names: ['غزوة أحد']),
    (10, 25): IslamicOccasion(names: ['غزوة بني قينقاع']),

    // ─────────────────────────────────────────────
    // 11 ذو القعدة
    // ─────────────────────────────────────────────
    (11, 1): IslamicOccasion(names: ['أشهر الحج تبدأ']),
    (11, 25): IslamicOccasion(names: ['صلح الحديبية']),

    // ─────────────────────────────────────────────
    // 12 ذو الحجة
    // ─────────────────────────────────────────────
    (12, 8): IslamicOccasion(
      names: ['يوم التروية (بداية مناسك الحج)'],
      // يوم 8 ذو الحجة: تذكير بصيام يوم عرفة (9 ذو الحجة)
      hasFastingReminder: true,
      reminderDaysBefore: 0,
      fastingReminderTitle: 'لا تنس صيام يوم عرفة غداً 🕋',
      fastingReminderBody:
          'غداً يوم عرفة (9 ذو الحجة)، أفضل يوم في السنة. '
          'صيامه يُكفّر ذنوب سنتين: الماضية والقادمة. أعدّ نيّتك!',
    ),
    (12, 9): IslamicOccasion(
      names: ['يوم عرفة • أفضل يوم في السنة'],
    ),
    (12, 10): IslamicOccasion(names: ['عيد الأضحى المبارك']),
    (12, 11): IslamicOccasion(names: ['أول أيام التشريق']),
    (12, 12): IslamicOccasion(names: ['ثاني أيام التشريق']),
    (12, 13): IslamicOccasion(
      names: ['ثالث أيام التشريق (آخر أيام منى)'],
    ),
    (12, 18): IslamicOccasion(names: ['غدير خم']),
  };

  // ─── API Methods ─────────────────────────────────────────────────────────

  /// يُعيد [IslamicOccasion] لليوم الهجري المحدد، أو null إن لم توجد مناسبة.
  static IslamicOccasion? getOccasion(int hijriMonth, int hijriDay) {
    return occasions[(hijriMonth, hijriDay)];
  }

  /// يُعيد قائمة أسماء المناسبات (للتوافق العكسي مع الكود القديم).
  static List<String>? getOccasions(int hijriMonth, int hijriDay) {
    return occasions[(hijriMonth, hijriDay)]?.names;
  }

  /// يُعيد الاسم الأساسي للمناسبة، أو null إن لم توجد.
  static String? getPrimaryOccasion(int hijriMonth, int hijriDay) {
    return occasions[(hijriMonth, hijriDay)]?.primaryName;
  }

  /// يُعيد true إذا كان اليوم يحتوي على مناسبة مُسجَّلة.
  static bool hasOccasion(int hijriMonth, int hijriDay) {
    return occasions.containsKey((hijriMonth, hijriDay));
  }

  /// يُعيد true إذا كان اليوم يحتوي على تذكير بالصيام.
  static bool hasFastingReminder(int hijriMonth, int hijriDay) {
    return occasions[(hijriMonth, hijriDay)]?.hasFastingReminder ?? false;
  }
}
