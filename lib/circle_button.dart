import 'package:flutter/material.dart';

class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border.all(color: Colors.white),
        shape: BoxShape.circle,
      ),
      child: IconButton.outlined(
        onPressed: onPressed,
        icon: Icon(icon),
        color: Colors.white,
        iconSize: 30,
      ),
    );
  }
}
