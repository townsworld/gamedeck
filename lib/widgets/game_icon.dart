import 'package:flutter/material.dart';

class GameIcon extends StatelessWidget {
  const GameIcon({
    required this.imageUrl,
    this.width = 78,
    this.height = 44,
    super.key,
  });

  final String imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl.isEmpty
            ? const _GameFallback()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _GameFallback(),
              ),
      ),
    );
  }
}

class _GameFallback extends StatelessWidget {
  const _GameFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
      child: Icon(
        Icons.sports_esports_outlined,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
