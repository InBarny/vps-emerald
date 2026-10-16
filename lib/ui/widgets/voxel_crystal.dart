// lib/ui/widgets/voxel_crystal.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Анимированный воксельный кристалл как в дизайне
class VoxelCrystal extends StatefulWidget {
  const VoxelCrystal({super.key, this.size = 130});

  final double size;

  @override
  State<VoxelCrystal> createState() => _VoxelCrystalState();
}

class _VoxelCrystalState extends State<VoxelCrystal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _timer;
  int _highlightedIndex = -1;

  // Паттерн из heavy_emerald_vpn_design.html
  final List<List<int>> _pattern = [
    [0, 0, 0, 1, 1, 0, 0, 0],
    [0, 0, 1, 2, 3, 1, 0, 0],
    [0, 1, 2, 4, 3, 2, 1, 0],
    [0, 1, 3, 4, 4, 3, 1, 0],
    [1, 2, 3, 4, 4, 3, 2, 1],
    [1, 2, 3, 3, 3, 3, 2, 1],
    [1, 2, 2, 3, 3, 2, 2, 1],
    [0, 1, 2, 2, 2, 2, 1, 0],
    [0, 1, 1, 2, 2, 1, 1, 0],
    [0, 0, 1, 5, 5, 1, 0, 0],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Анимация случайных вокселей каждые 150ms
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) return;
      setState(() {
        final flat = _pattern.expand((row) => row).toList();
        final candidates = <int>[];
        for (var i = 0; i < flat.length; i++) {
          final type = flat[i];
          if (type == 1 || type == 4) {
            candidates.add(i);
          }
        }
        if (candidates.isNotEmpty) {
          _highlightedIndex = candidates[Random().nextInt(candidates.length)];
          _controller.forward(from: 0).then((_) {
            if (mounted) {
              setState(() => _highlightedIndex = -1);
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _voxelColor(int type) {
    switch (type) {
      case 1: // a - bright emerald
        return const Color(0xE600FF88);
      case 2: // d - dark
        return const Color(0xCC00643C);
      case 3: // m - medium
        return const Color(0xD900B464);
      case 4: // l - light
        return const Color(0xE664FFB4);
      case 5: // b - blue
        return const Color(0xCC0096FF);
      default:
        return Colors.transparent;
    }
  }

  bool _hasGlow(int type) => type == 1 || type == 4;

  @override
  Widget build(BuildContext context) {
    final cols = _pattern[0].length;
    final rows = _pattern.length;
    final cellSize = widget.size / cols;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size * (rows / cols),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var c = 0; c < cols; c++)
                      Builder(
                        builder: (context) {
                          final type = _pattern[r][c];
                          final index = r * cols + c;
                          final isHighlighted = index == _highlightedIndex;
                          final scale = isHighlighted
                              ? 1.0 + (_controller.value * 0.5)
                              : 1.0;
                          final brightness = isHighlighted
                              ? 1.0 + (_controller.value * 1.2)
                              : 1.0;

                          if (type == 0) {
                            return SizedBox(width: cellSize, height: cellSize);
                          }

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: cellSize - 1,
                              height: cellSize - 1,
                              margin: const EdgeInsets.all(0.5),
                              decoration: BoxDecoration(
                                color: _voxelColor(type).withOpacity(
                                  (type == 0) ? 0 : min(1.0, brightness),
                                ),
                                boxShadow: _hasGlow(type)
                                    ? [
                                        BoxShadow(
                                          color: _voxelColor(type).withOpacity(
                                            isHighlighted ? 0.9 : 0.6,
                                          ),
                                          blurRadius: isHighlighted ? 8 : 4,
                                          spreadRadius: isHighlighted ? 2 : 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
