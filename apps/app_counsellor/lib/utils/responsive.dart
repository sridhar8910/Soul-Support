import 'package:flutter/material.dart';

class Responsive {
  // Screen breakpoints
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1024;

  // Check device type
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileMaxWidth;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileMaxWidth &&
      MediaQuery.of(context).size.width < tabletMaxWidth;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMaxWidth;

  // Get responsive value based on device
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  // Responsive padding
  static double horizontalPadding(BuildContext context) =>
      value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0);

  static double verticalPadding(BuildContext context) =>
      value(context, mobile: 12.0, tablet: 16.0, desktop: 20.0);

  // Responsive font sizes
  static double heading1(BuildContext context) =>
      value(context, mobile: 24.0, tablet: 28.0, desktop: 32.0);

  static double heading2(BuildContext context) =>
      value(context, mobile: 20.0, tablet: 22.0, desktop: 24.0);

  static double body(BuildContext context) =>
      value(context, mobile: 14.0, tablet: 15.0, desktop: 16.0);

  static double caption(BuildContext context) =>
      value(context, mobile: 12.0, tablet: 13.0, desktop: 14.0);

  // Responsive grid columns
  static int gridColumns(BuildContext context) =>
      value(context, mobile: 2, tablet: 3, desktop: 4);

  // Safe area for mobile notch/gesture bar
  static EdgeInsets safeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
    );
  }

  // Screen height percentage
  static double screenHeight(BuildContext context, double percentage) =>
      MediaQuery.of(context).size.height * percentage;

  // Screen width percentage
  static double screenWidth(BuildContext context, double percentage) =>
      MediaQuery.of(context).size.width * percentage;
}
