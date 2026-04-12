import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/audio_player_provider.dart';

class AudioBottomSheet extends StatefulWidget {
  const AudioBottomSheet({super.key});

  @override
  State<AudioBottomSheet> createState() => _AudioBottomSheetState();
}

class _AudioBottomSheetState extends State<AudioBottomSheet> {
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioPlayerProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 🛡️ Error Listener: مراقبة رسائل الخطأ وإظهارها للمستخدم
    if (audioProvider.errorMessage != null) {
      final msg = audioProvider.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: GoogleFonts.tajawal()),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          audioProvider.clearError();
        }
      });
    }

    if (audioProvider.currentSurah == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Track Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سورة ${audioProvider.currentSurah!.name}',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        audioProvider.currentReciter?.name ?? 'قارئ',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white54 : Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => audioProvider.stop(),
                ),
              ],
            ),

            // Progress Bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14.0,
                ),
              ),
              child: Slider(
                min: 0.0,
                max: audioProvider.totalDuration.inMilliseconds.toDouble() > 0
                    ? audioProvider.totalDuration.inMilliseconds.toDouble()
                    : 1.0,
                value: audioProvider.currentPosition.inMilliseconds
                    .toDouble()
                    .clamp(
                      0.0,
                      audioProvider.totalDuration.inMilliseconds.toDouble() > 0
                          ? audioProvider.totalDuration.inMilliseconds
                                .toDouble()
                          : 1.0,
                    ),
                onChanged: (value) {
                  audioProvider.seek(Duration(milliseconds: value.toInt()));
                },
                activeColor: Colors.blue,
                inactiveColor: isDarkMode ? Colors.grey[800] : Colors.blue[100],
              ),
            ),

            // Timestamps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(audioProvider.currentPosition),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    _formatDuration(audioProvider.totalDuration),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, size: 30),
                  onPressed: () => audioProvider.seekBackward10s(),
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 20),
                if (audioProvider.isBuffering)
                   const SizedBox(
                     height: 36,
                     width: 36,
                     child: CircularProgressIndicator(
                       strokeWidth: 3,
                       color: Colors.blue,
                     ),
                   )
                else
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: IconButton(
                      icon: Icon(
                        audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 36,
                      ),
                      color: Colors.white,
                      onPressed: () => audioProvider.togglePlayPause(),
                    ),
                  ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.forward_10, size: 30),
                  onPressed: () => audioProvider.seekForward10s(),
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ],
            ),
             if (audioProvider.isBuffering)
               Padding(
                 padding: const EdgeInsets.only(top: 4.0),
                 child: Text(
                   'جاري التحميل...',
                   style: GoogleFonts.tajawal(
                     fontSize: 10,
                     color: Colors.blue,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
               )
             else
               const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
