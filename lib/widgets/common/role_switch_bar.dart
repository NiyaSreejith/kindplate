import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/user_model.dart';
import '../../state/app_state.dart';

class RoleSwitchBar extends StatelessWidget {
  final AppState state;

  const RoleSwitchBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.deepGreen,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Role icon and active badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.freshGreen.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.freshGreen, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👤', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  state.currentUser.roleDisplayName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Role Switcher Dropdown
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _roleChip(context, UserRole.buyer, '🛒 Surplus food buyer', state),
                  _roleChip(context, UserRole.recipient, '💚 care recipient', state),
                  _roleChip(context, UserRole.seller, '🏪 restaurant /home baker', state),
                  _roleChip(context, UserRole.volunteer, '🚴 delivery partner/volenterr', state),
                  _roleChip(context, UserRole.ngo, '🤝 NGO & community hub', state),
                ],
              ),
            ),
          ),

          // Onboarding Quick Reset Button
          IconButton(
            tooltip: 'View Onboarding Reference Screens',
            icon: const Icon(Icons.slideshow, color: AppColors.mint, size: 20),
            onPressed: () {
              state.setOnboardingStep(0);
            },
          ),

          // Mobile Viewport Frame Toggle
          IconButton(
            tooltip: state.isWebDevicePreviewMode ? 'Switch to Full Width View' : 'Switch to Mobile Phone Frame View',
            icon: Icon(
              state.isWebDevicePreviewMode ? Icons.desktop_windows : Icons.phone_iphone,
              color: AppColors.goldenYellow,
              size: 20,
            ),
            onPressed: () {
              state.toggleWebDevicePreview();
            },
          ),
        ],
      ),
    );
  }

  Widget _roleChip(BuildContext context, UserRole role, String label, AppState state) {
    final isSelected = state.currentUser.role == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => state.switchUserRole(role),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.freshGreen : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
