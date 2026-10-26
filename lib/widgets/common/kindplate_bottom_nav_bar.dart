import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class KindPlateBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const KindPlateBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8E5DA),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_rounded,
                unselectedIcon: Icons.home_outlined,
              ),
              _buildNavItem(
                index: 1,
                label: 'Discover',
                icon: Icons.search_rounded,
                unselectedIcon: Icons.search_rounded,
              ),
              _buildNavItem(
                index: 2,
                label: 'Map',
                icon: Icons.location_on_rounded,
                unselectedIcon: Icons.location_on_outlined,
              ),
              _buildNavItem(
                index: 3,
                label: 'Impact',
                icon: Icons.eco_rounded,
                unselectedIcon: Icons.eco_outlined,
              ),
              _buildNavItem(
                index: 4,
                label: 'Profile',
                icon: Icons.person_rounded,
                unselectedIcon: Icons.person_outline_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData unselectedIcon,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active pill container or inactive icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFDCEDE0) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? icon : unselectedIcon,
                size: 22,
                color: isSelected ? AppColors.forestGreen : const Color(0xFF334237),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.darkText : const Color(0xFF4A5A50),
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
