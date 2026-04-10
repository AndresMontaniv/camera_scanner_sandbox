import 'package:flutter/material.dart';

class CircleCloseButton extends StatelessWidget {
  const CircleCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 28),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            debugPrint('CircleCloseButton: No routes to pop');
          }
        },
      ),
    );
  }
}
