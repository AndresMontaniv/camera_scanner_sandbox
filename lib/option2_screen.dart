import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Option2Screen extends StatefulWidget {
  const Option2Screen({super.key});

  @override
  State<Option2Screen> createState() => _Option2ScreenState();
}

class _Option2ScreenState extends State<Option2Screen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isBottomBarVisible = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final direction = _scrollController.position.userScrollDirection;

    if (direction == ScrollDirection.reverse && _isBottomBarVisible.value) {
      _isBottomBarVisible.value = false;
    } else if (direction == ScrollDirection.forward && !_isBottomBarVisible.value) {
      _isBottomBarVisible.value = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _isBottomBarVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Option2Screen'),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: 50,
        itemBuilder: (context, index) {
          return const ListTile(title: Text('Cart Item'));
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: _isBottomBarVisible,
        builder: (context, isVisible, child) {
          return AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            offset: isVisible ? Offset.zero : const Offset(0, 1),
            child: child,
          );
        },
        child: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
          ],
        ),
      ),
    );
  }
}
