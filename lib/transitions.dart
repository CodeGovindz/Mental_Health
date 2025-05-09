import 'package:flutter/material.dart';

// Fade transition
PageRouteBuilder fadeTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      return page;
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var tween = Tween(begin: 0.0, end: 1.0);
      var fadeAnimation = animation.drive(tween);
      return FadeTransition(opacity: fadeAnimation, child: child);
    },
  );
}

// Slide transition (horizontal)
PageRouteBuilder slideTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      return page;
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // Slide in from the right
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

// Scale transition
PageRouteBuilder scaleTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      return page;
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var scaleTween = Tween(begin: 0.0, end: 1.0);
      var scaleAnimation = animation.drive(scaleTween);
      return ScaleTransition(scale: scaleAnimation, child: child);
    },
  );
}

// Rotation transition
PageRouteBuilder rotationTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      return page;
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var rotationTween = Tween(begin: 0.0, end: 1.0);
      var rotationAnimation = animation.drive(rotationTween);
      return RotationTransition(turns: rotationAnimation, child: child);
    },
  );
}

// Slide transition (vertical)
PageRouteBuilder slideVerticalTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      return page;
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0); // Slide in from the bottom
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

// Custom transition with multiple animations (combine scale and fade)
PageRouteBuilder customTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      return page;
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var scaleTween = Tween(begin: 0.0, end: 1.0);
      var scaleAnimation = animation.drive(scaleTween);

      var fadeTween = Tween(begin: 0.0, end: 1.0);
      var fadeAnimation = animation.drive(fadeTween);

      return FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(scale: scaleAnimation, child: child),
      );
    },
  );
}
