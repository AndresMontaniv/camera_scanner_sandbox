import 'package:flutter/material.dart';

class CircleCloseButton extends StatelessWidget {
  final void Function()? pop;
  const CircleCloseButton({super.key, this.pop});

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
            if (pop != null) {
              pop?.call();
            } else {
              Navigator.of(context).pop();
            }
          } else {
            debugPrint('CircleCloseButton: No routes to pop');
          }
        },
      ),
    );
  }
}
