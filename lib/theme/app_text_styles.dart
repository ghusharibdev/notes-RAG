import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display(BuildContext context) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    );
  }

  static TextStyle h1(BuildContext context) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
  }

  static TextStyle h2(BuildContext context) {
    return GoogleFonts.hankenGrotesk(
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
  }

  static TextStyle body(BuildContext context) {
    return GoogleFonts.hankenGrotesk(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    );
  }

  static TextStyle bodyMedium(BuildContext context) {
    return GoogleFonts.hankenGrotesk(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
    );
  }

  static TextStyle bodySemiBold(BuildContext context) {
    return GoogleFonts.hankenGrotesk(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
  }

  static TextStyle caption(BuildContext context) {
    return GoogleFonts.hankenGrotesk(
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400,
      color: AppColors.inkLight,
    );
  }

  static TextStyle citation(BuildContext context) {
    return GoogleFonts.hankenGrotesk(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      color: AppColors.ochre,
    );
  }

  static TextStyle buttonText(BuildContext context) {
    return GoogleFonts.hankenGrotesk(
      fontSize: 15,
      height: 20 / 15,
      fontWeight: FontWeight.w600,
      color: AppColors.stone,
    );
  }

  static TextStyle inputText(BuildContext context) {
    return GoogleFonts.hankenGrotesk(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    );
  }
}
