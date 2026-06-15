import 'package:flutter/material.dart';

class SteamAvatar extends StatelessWidget {
  const SteamAvatar({
    required this.imageUrl,
    required this.label,
    this.size = 48,
    super.key,
  });

  final String imageUrl;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: imageUrl.isEmpty
            ? _AvatarFallback(initial: initial)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _AvatarFallback(initial: initial),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.secondaryContainer),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
