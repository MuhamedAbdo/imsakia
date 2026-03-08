import 'package:flutter/material.dart';

class NeumorphicBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  
  /// For standard elements, leave [baseColor] null.
  /// For branded/colored elements, provide the base color here, along with [lightShadowColor] and [darkShadowColor].
  final Color? baseColor;
  final Color? lightShadowColor;
  final Color? darkShadowColor;

  const NeumorphicBox({
    super.key, 
    required this.child, 
    this.borderRadius = 20,
    this.baseColor,
    this.lightShadowColor,
    this.darkShadowColor,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Use default Grey/DarkGrey if no baseColor is provided (Standard Neumorphism)
    Color finalColor = baseColor ?? (isDark ? const Color(0xFF2E3239) : const Color(0xFFE0E0E0));
    
    // Default shadows if no specific tinted shadows are provided
    Color defaultLightShadow = isDark ? const Color(0xFF3B4048) : Colors.white;
    Color defaultDarkShadow = isDark ? const Color(0xFF202328) : Colors.grey.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: finalColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: darkShadowColor ?? defaultDarkShadow,
            offset: const Offset(6, 6), 
            blurRadius: 15,
          ),
          BoxShadow(
            color: lightShadowColor ?? defaultLightShadow,
            offset: const Offset(-6, -6), 
            blurRadius: 15,
          ),
        ],
      ),
      child: child,
    );
  }
}
