// lib/ui/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../widgets/background_effects.dart';

/// Heavy Emerald Design System
/// Тёмная кибер-тема с изумрудными акцентами

class AppColors {
  // Backgrounds
  static const Color bg = Color(0xFF05140c);
  static const Color bgPanel = Color(0xFF0a1f14);
  static const Color bgElevated = Color(0xFF0d2e1b);

  // Emerald accent
  static const Color emerald = Color(0xFF00ff88);
  static const Color emeraldDim = Color(0xFF00cc6a);
  static const Color emeraldDark = Color(0xFF006633);
  static const Color emeraldGlow = Color(0x2600ff88);

  // Glass (matching reference WPF/HTML exactly)
  static const Color glassBg = Color(0x0A00ff88);
  static const Color glassBorder = Color(0x2E00ff88);
  static const Color glassHighlight = Color(0x1EFFFFFF);
  static const Color glassSurface = Color(0xFF0a1f14);

  // Text
  static const Color text = Color(0xFFe8f5e9);
  static const Color textDim = Color(0xFF88b89a);
  static const Color textDark = Color(0xFF4a7a5c);

  // Status
  static const Color disconnected = Color(0xFFff4444);
  static const Color connecting = Color(0xFFffaa00);
  static const Color connected = Color(0xFF00ff88);
  static const Color error = Color(0xFFff4444);

  // Utility
  static const Color warning = Color(0xFFffaa00);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

class AppTypography {
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textDim,
    decoration: TextDecoration.none,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
    decoration: TextDecoration.none,
  );

  static const TextStyle monoHeadline = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w300,
    letterSpacing: 4,
    color: AppColors.text,
    fontFamily: 'JetBrainsMono',
    decoration: TextDecoration.none,
  );
}

/// breakpoints для адаптивной вёрстки
class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 720;
  static const double desktop = 1100;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= tablet;
}

/// Адаптивный каркас приложения
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.navigationItems,
    required this.bodyBuilder,
    this.selectedIndex = 0,
    this.onNavigationChanged,
  });

  final List<AdaptiveNavigationItem> navigationItems;
  final Widget Function(BuildContext context, int index) bodyBuilder;
  final int selectedIndex;
  final ValueChanged<int>? onNavigationChanged;

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isWideScreen(context);

    if (isWide) {
      return Row(
        children: [
          _Sidebar(
            items: navigationItems,
            selectedIndex: selectedIndex,
            onDestinationSelected: onNavigationChanged,
          ),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Stack(
                children: [
                  const RepaintBoundary(child: BackgroundEffects()),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey<int>(selectedIndex),
                      child: bodyBuilder(context, selectedIndex),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Stack(
          children: [
            const RepaintBoundary(child: BackgroundEffects()),
            bodyBuilder(context, selectedIndex),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0a2819), Color(0xFF05140c)],
          ),
          border: Border(
            top: BorderSide(color: AppColors.glassBorder.withOpacity(0.5)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.emerald.withOpacity(0.15),
          selectedIndex: selectedIndex,
          onDestinationSelected: onNavigationChanged,
          destinations: navigationItems
              .map(
                (item) => NavigationDestination(
                  icon: Text(
                    item.iconSymbol,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textDim,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  selectedIcon: Text(
                    item.iconSymbol,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.emerald,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  final List<AdaptiveNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0a2819), Color(0xFF05140c)],
          ),
          border: Border(
            right: BorderSide(color: const Color(0xFF00ff88).withOpacity(0.12)),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 32),
            _buildLogo(),
            const SizedBox(height: 48),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final isActive = selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onDestinationSelected?.call(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isActive
                                ? Border.all(
                                    color: const Color(
                                      0xFF00ff88,
                                    ).withOpacity(0.2),
                                  )
                                : null,
                            gradient: isActive
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFF00ff88).withOpacity(0.12),
                                      Colors.transparent,
                                    ],
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Text(
                                items[i].iconSymbol,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isActive
                                      ? const Color(0xFF00ff88)
                                      : const Color(0xFF88b89a),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                items[i].label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF00ff88)
                                      : const Color(0xFF88b89a),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Heavy Emerald v1.0.1',
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF4a7a5c).withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'HEAVY EMERALD',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF00ff88),
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: const Color(0xFF00ff88).withOpacity(0.4),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SECURE CONNECTION',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            color: Color(0xFF88b89a),
          ),
        ),
      ],
    );
  }
}

class AdaptiveNavigationItem {
  const AdaptiveNavigationItem({
    this.icon,
    required this.iconSymbol,
    required this.label,
    this.selectedIcon,
  });

  final IconData? icon;
  final String iconSymbol;
  final String label;
  final IconData? selectedIcon;
}

/// Glass toggle switch matching reference design
class GlassToggle extends StatelessWidget {
  const GlassToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          gradient: value
              ? const LinearGradient(
                  colors: [AppColors.emerald, AppColors.emeraldDim],
                )
              : null,
          color: value ? null : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: value
                ? AppColors.emerald.withOpacity(0.4)
                : const Color(0x20FFFFFF),
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass text field matching reference design
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.2, -1),
          end: const Alignment(1, 1),
          colors: [Color(0x08FFFFFF), Color(0x0300ff88)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textDark),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          suffixIcon: suffix,
        ),
        onSubmitted: onSubmitted,
        keyboardType: keyboardType,
        obscureText: obscureText,
      ),
    );
  }
}

/// Темы приложения
class AppThemes {
  static ThemeData light() => _buildTheme(Brightness.light);
  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emerald,
        brightness: brightness,
        surface: AppColors.bgPanel,
        primary: AppColors.emerald,
        onPrimary: AppColors.bg,
        secondary: AppColors.emeraldDim,
        onSecondary: AppColors.bg,
        error: AppColors.error,
        onError: Colors.white,
        onSurface: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: AppColors.bgPanel,
        indicatorColor: AppColors.emerald.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: AppColors.textDim,
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.emerald);
          }
          return const IconThemeData(color: AppColors.textDim);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.bg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            decoration: TextDecoration.none,
          ),
          shadowColor: AppColors.emerald.withOpacity(0.35),
          elevation: 4,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.emerald,
          side: const BorderSide(color: AppColors.emerald),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x08FFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.emerald),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: const TextStyle(color: AppColors.textDark),
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(decoration: TextDecoration.none),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.emerald.withOpacity(0.1),
        side: const BorderSide(color: AppColors.emerald),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        labelStyle: const TextStyle(
          color: AppColors.emerald,
          decoration: TextDecoration.none,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x0800ff88),
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelLarge: AppTypography.labelLarge,
        labelSmall: AppTypography.labelSmall,
      ).apply(decoration: TextDecoration.none),
    );
  }
}
