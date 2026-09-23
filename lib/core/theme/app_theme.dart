import 'package:flutter/material.dart';

/// Palette matched to goal.mp4 (dark navy + card blue + 3D orange buttons).
class AppColors {
  static const bgDeep = Color(0xFF0A1828);
  static const bgTop = Color(0xFF1B3A58);
  static const card = Color(0xFF2E4C6B);
  static const cardLight = Color(0xFF3B5C80);
  static const cardDark = Color(0xFF1E3550);
  static const divider = Color(0xFF23405D);

  static const orange = Color(0xFFF2992E);
  static const orangeLight = Color(0xFFF7B733);
  static const orangeDark = Color(0xFFD97B1A);
  static const orangeDeep = Color(0xFF9E5208); // 3D bottom edge

  static const text = Colors.white;
  static const textDim = Color(0xFFB9C9DB);
  static const textFaint = Color(0xFF7E94AB);

  static const green = Color(0xFF43B581);
  static const greenBright = Color(0xFF57D977);
  static const red = Color(0xFFE5484D);
  static const gold = Color(0xFFFFC93C);

  // Board (brown theme from video).
  static const lightSq = Color(0xFFE3B778);
  static const darkSq = Color(0xFF7A4A21);
  static const boardFrame = Color(0xFF3A2110);
  static const woodBg = Color(0xFF6B3A15);
  static const lastMove = Color(0xFFF5A623);
  static const selectSq = Color(0xFF57D977);
  static const checkSq = Color(0xFFE5484D);

  static const whitePiece = Color(0xFFF7F3EA);
  static const blackPiece = Color(0xFF191410);
}

/// A selectable board color scheme (Customize → Board).
class BoardTheme {
  final String name;
  final Color light;
  final Color dark;
  final Color frame;
  const BoardTheme(this.name, this.light, this.dark, this.frame);

  static const brown = BoardTheme(
    'Classic wood',
    Color(0xFFE3B778),
    Color(0xFF7A4A21),
    Color(0xFF3A2110),
  );
  static const green = BoardTheme(
    'Tournament green',
    Color(0xFFEAEED2),
    Color(0xFF7B9552),
    Color(0xFF3E4A2E),
  );
  static const slate = BoardTheme(
    'Slate blue',
    Color(0xFFDEE3E6),
    Color(0xFF7C93A8),
    Color(0xFF2C3A47),
  );

  static const List<BoardTheme> all = [brown, green, slate];
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.orange,
        secondary: AppColors.orangeLight,
        surface: AppColors.cardDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    );
  }

  static TextStyle get title22 =>
      const TextStyle(fontSize: 22, fontWeight: FontWeight.w800);
  static TextStyle get title18 =>
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
  static TextStyle get body14 =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle get dim13 => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textDim,
      );
  static TextStyle get dim12 => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textDim,
      );
}
