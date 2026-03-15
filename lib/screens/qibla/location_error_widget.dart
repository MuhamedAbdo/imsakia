import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LocationErrorWidget extends StatelessWidget {
  final String? error;
  final Function? callback;
  final String locale;

  const LocationErrorWidget({
    super.key,
    this.error,
    this.callback,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = AppColors.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.location_off_rounded,
              size: 100,
              color: errorColor,
            ),
            const SizedBox(height: 24),
            Text(
              error ?? (locale == 'ar' ? 'خطأ في الموقع' : 'Location Error'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                locale == 'ar' ? 'إعادة المحاولة' : 'Retry',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                if (callback != null) callback!();
              },
            )
          ],
        ),
      ),
    );
  }
}
