import 'package:flutter/material.dart';

class ThreeDTabBar extends StatelessWidget {
  final TabController? controller;
  final List<Widget> tabs;

  const ThreeDTabBar({
    super.key, 
    this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.orange.shade400,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: tabs,
      ),
    );
  }
}
