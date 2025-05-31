import 'package:flutter/material.dart';

class SectionWrapper extends StatelessWidget {
  final Widget child;

  const SectionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}