import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/home_events_service.dart';
import '../services/hadith_service.dart';
import '../widgets/neumorphic_box.dart';

class EventCardWidget extends StatelessWidget {
  const EventCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeEventsService>(
      builder: (context, eventService, child) {
        // 🔥 تحديث البيانات عند كل بناء للواجهة لضمان استجابة تاريخ الجهاز
        eventService.calculateCurrentEvent();

        final event = eventService.currentEvent;
        if (event == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        // Custom colors based on event type
        Color baseColor;
        switch (event.type) {
          case EventType.adhaCountdown:
          case EventType.arafah:
          case EventType.eidAdha:
            baseColor = const Color(0xFF50C878); // Emerald Green
            break;
          case EventType.ramadanCountdown:
          case EventType.ramadan:
            baseColor = const Color(0xFF191970); // Midnight Blue
            break;
          default:
            baseColor = Theme.of(context).primaryColor;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: NeumorphicBox(
            borderRadius: 25,
            baseColor: baseColor.withValues(alpha: isDark ? 0.2 : 0.9),
            darkShadowColor: baseColor.withValues(alpha: 0.3),
            lightShadowColor: Colors.white.withValues(alpha: 0.1),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (event.type == EventType.ramadan)
                          const _RamadanHadithContent()
                        else if (event.showCountdown)
                          _CountdownContent(
                            duration: eventService.getRemainingDurationToTarget(),
                            color: Colors.white,
                          )
                        else
                          Text(
                            event.subtitle,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onDoubleTap: () => eventService.refresh(),
                    child: Hero(
                      tag: 'event_image',
                      child: Image.asset(
                        event.imagePath,
                        height: 80,
                        width: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountdownContent extends StatelessWidget {
  final Duration duration;
  final Color color;

  const _CountdownContent({
    required this.duration,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final days = duration.inDays;

    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          '$days',
          style: GoogleFonts.oswald(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'يوم',
          style: GoogleFonts.tajawal(
            fontSize: 16,
            color: color.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _RamadanHadithContent extends StatelessWidget {
  const _RamadanHadithContent();

  @override
  Widget build(BuildContext context) {
    final hadith = HadithService.instance.getTodayHadith();
    if (hadith == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hadith.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '[ ${hadith.source} ]',
          textAlign: TextAlign.right,
          style: GoogleFonts.tajawal(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
