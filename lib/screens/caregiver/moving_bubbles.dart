import 'dart:math';
import 'package:flutter/material.dart';

/// MODEL BUBBLE (data statik)
class Bubble {
  final double size;   // saiz bubble
  final double x;      // posisi X (0.0 - 1.0)
  final double speed;  // kelajuan (sangat kecil)

  Bubble({
    required this.size,
    required this.x,
    required this.speed,
  });
}

class MovingBubbles extends StatefulWidget {
  const MovingBubbles({super.key});

  @override
  State<MovingBubbles> createState() => _MovingBubblesState();
}

class _MovingBubblesState extends State<MovingBubbles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<Bubble> bubbles;

  @override
  void initState() {
    super.initState();

    /// Animation sangat perlahan
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 180), // 🔥 3 min satu loop
    )..repeat();

    /// Generate bubble SEKALI SAHAJA
    bubbles = List.generate(6, (index) {
      return Bubble(
        size: 80 + _random.nextDouble() * 80,     // 80 - 160
        x: _random.nextDouble(),                  // 0 - 1 (relative)
        speed: 0.01 + _random.nextDouble() * 0.02 // 🔥 sangat perlahan
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return IgnorePointer( // supaya bubble tak ganggu touch
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Stack(
            children: bubbles.map((bubble) {
              /// progress perlahan
              final double progress =
                  (_controller.value * bubble.speed) % 1;

              return Positioned(
                bottom: -bubble.size +
                    (screenSize.height + bubble.size) * progress,
                left: bubble.x * screenSize.width,
                child: Opacity(
                  opacity: 0.05, // soft & premium
                  child: Container(
                    width: bubble.size,
                    height: bubble.size,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
