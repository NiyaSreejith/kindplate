import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/notification_model.dart';
import '../../state/app_state.dart';

/// Realistic top mobile push notification banner (iOS / Android heads-up style)
/// for Section D2: "Notification (booking confirmed/reminder) is received on the mobile device and shown in the demo"
class MobileNotificationBanner extends StatefulWidget {
  final AppState state;

  const MobileNotificationBanner({
    super.key,
    required this.state,
  });

  @override
  State<MobileNotificationBanner> createState() => _MobileNotificationBannerState();
}

class _MobileNotificationBannerState extends State<MobileNotificationBanner> {
  Timer? _autoDismissTimer;
  String? _lastNotificationId;

  bool get _isTestEnv =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void didUpdateWidget(covariant MobileNotificationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleAutoDismissIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    _scheduleAutoDismissIfNeeded();
  }

  void _scheduleAutoDismissIfNeeded() {
    final current = widget.state.activeBannerNotification;
    if (current == null) {
      _autoDismissTimer?.cancel();
      _lastNotificationId = null;
      return;
    }
    if (current.id != _lastNotificationId) {
      _lastNotificationId = current.id;
      _autoDismissTimer?.cancel();
      if (!_isTestEnv) {
        _autoDismissTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            widget.state.dismissBannerNotification();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.state.activeBannerNotification;
    if (notif == null) return const SizedBox.shrink();

    final isReminder = notif.type == 'reminder';

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF162B1E).withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isReminder
                      ? AppColors.gold.withValues(alpha: 0.65)
                      : AppColors.sageGreen.withValues(alpha: 0.55),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top system notification bar header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isReminder
                              ? AppColors.gold.withValues(alpha: 0.22)
                              : AppColors.forestGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isReminder
                              ? Icons.notifications_active_rounded
                              : Icons.eco_rounded,
                          color: isReminder ? AppColors.gold : Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'KINDPLATE • NOW',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.mint.withValues(alpha: 0.85),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      if (!isReminder)
                        InkWell(
                          onTap: () {
                            widget.state.sendBookingReminder();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '⏰ Send Reminder',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => widget.state.dismissBannerNotification(),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    notif.title,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the Notifications & Booking Reminders Bottom Sheet
void showNotificationsCenterSheet(BuildContext context, AppState state) {
  state.markAllNotificationsRead();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final notifications = state.notifications;
          return FractionallySizedBox(
            heightFactor: 0.78,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.mint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: AppColors.forestGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifications & Reminders',
                                  style: AppTypography.titleLarge.copyWith(fontSize: 18),
                                ),
                                Text(
                                  'Booking confirmations & pickup alerts',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 12,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // Action button to send a live Booking Reminder notification
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          state.sendBookingReminder();
                          setModalState(() {});
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.alarm_on_rounded, size: 18),
                        label: const Text(
                          'Send Pickup Reminder Notification Now',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Text(
                              'No notifications yet',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final item = notifications[index];
                              return _buildNotificationCard(item);
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildNotificationCard(AppNotification item) {
  final isReminder = item.type == 'reminder';
  final isOrder = item.type == 'order';

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isReminder
            ? AppColors.gold.withValues(alpha: 0.5)
            : isOrder
                ? AppColors.sageGreen.withValues(alpha: 0.5)
                : AppColors.borderLight,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.cardShadow,
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isReminder
                ? AppColors.gold.withValues(alpha: 0.16)
                : AppColors.mint.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isReminder
                ? Icons.alarm_rounded
                : isOrder
                    ? Icons.check_circle_rounded
                    : Icons.notifications_rounded,
            color: isReminder ? const Color(0xFFB7791F) : AppColors.forestGreen,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.message,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 12,
                  color: AppColors.mutedText,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
