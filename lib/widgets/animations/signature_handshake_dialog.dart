import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/order_model.dart';
import '../../services/pdf_invoice_service.dart';

class SignatureHandshakeDialog extends StatefulWidget {
  final Order order;
  final VoidCallback onTrackOrder;
  final bool isErrorTest; // allows testing retry/error state
  final bool startAtConfirmation;
  final VoidCallback? onSendReminder;

  const SignatureHandshakeDialog({
    super.key,
    required this.order,
    required this.onTrackOrder,
    this.isErrorTest = false,
    this.startAtConfirmation = false,
    this.onSendReminder,
  });

  @override
  State<SignatureHandshakeDialog> createState() => _SignatureHandshakeDialogState();
}

class _SignatureHandshakeDialogState extends State<SignatureHandshakeDialog>
    with TickerProviderStateMixin {
  late AnimationController _masterController;
  late AnimationController _sparkleController;
  late AnimationController _handshakeMotionController;
  late AnimationController _pulseHeartController;
  late ConfettiController _confettiController;

  // Stages:
  // 0: Donor preparing & packing meal (0.0 - 0.28)
  // 1: Meal traveling along curved leafy path (0.28 - 0.54)
  // 2: Food handover & animated handshake (0.54 - 0.82)
  // 3: Order confirmation & celebration (0.82 - 1.0)
  int _currentStage = 0;
  bool _isReducedMotion = false;
  bool _hasError = false;
  bool _reminderSent = false;

  @override
  void initState() {
    super.initState();

    _hasError = widget.isErrorTest;
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseHeartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    _handshakeMotionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Target duration 5.2 seconds for full cinematic sequence
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );

    _masterController.addListener(() {
      if (_hasError) return;

      final val = _masterController.value;
      int newStage = 0;
      if (val >= 0.82) {
        newStage = 3;
      } else if (val >= 0.54) {
        newStage = 2;
      } else if (val >= 0.28) {
        newStage = 1;
      }

      if (newStage != _currentStage) {
        setState(() {
          _currentStage = newStage;
          if (_currentStage == 3 && !_isReducedMotion) {
            _confettiController.play();
          }
        });
      }
    });

    if (!_hasError) {
      if (widget.startAtConfirmation) {
        _currentStage = 3;
        _masterController.value = 1.0;
        _confettiController.play();
      } else {
        _masterController.forward();
      }
    }
  }

  @override
  void dispose() {
    _masterController.dispose();
    _sparkleController.dispose();
    _handshakeMotionController.dispose();
    _pulseHeartController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _skipToSuccess() {
    _masterController.value = 1.0;
    setState(() {
      _currentStage = 3;
    });
    _confettiController.play();
  }

  void _retryOrder() {
    setState(() {
      _hasError = false;
      _currentStage = 0;
    });
    _masterController.reset();
    _masterController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.forestGreen.withValues(alpha: 0.25),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
            border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.4), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                // Ambient floating leaf particles background
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sparkleController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _AmbientLeafShimmerPainter(
                            progress: _sparkleController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Celebration Confetti Cannon
                Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      colors: const [
                        AppColors.forestGreen,
                        AppColors.sageGreen,
                        AppColors.gold,
                        AppColors.softGreen,
                        Color(0xFFFF8066),
                      ],
                      numberOfParticles: 40,
                      gravity: 0.18,
                    ),
                  ),
                ),

                // Main Content Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      // Header with Brand Badge and Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.forestGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🤝🌿', style: TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.order.isFreeDonation
                                          ? 'Care Journey'
                                          : 'Handshake',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.forestGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Reduced Motion Toggle
                              IconButton(
                                icon: Icon(
                                  _isReducedMotion ? Icons.motion_photos_off : Icons.motion_photos_on,
                                  size: 18,
                                  color: AppColors.mutedText,
                                ),
                                tooltip: 'Toggle reduced motion',
                                onPressed: () {
                                  setState(() {
                                    _isReducedMotion = !_isReducedMotion;
                                    if (_isReducedMotion) {
                                      _skipToSuccess();
                                    }
                                  });
                                },
                              ),
                              if (_currentStage < 3 && !_hasError)
                                TextButton(
                                  onPressed: _skipToSuccess,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.mutedText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Stage Content Switcher
                      Expanded(
                        flex: 12,
                        child: _hasError
                            ? _buildErrorView()
                            : AnimatedBuilder(
                                animation: _masterController,
                                builder: (context, _) => _buildStageContent(),
                              ),
                      ),

                      const Spacer(),

                      // Progress Step Indicator Pills
                      if (_currentStage < 3 && !_hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final active = index <= _currentStage;
                              final isCurrent = index == _currentStage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: isCurrent ? 26 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: active ? AppColors.forestGreen : AppColors.softGreen.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_currentStage) {
      case 0:
        return _buildStage0Packing();
      case 1:
        return _buildStage1LeafyJourney();
      case 2:
        return _buildStage2HandoverAndHandshake();
      case 3:
      default:
        return _buildStage3OrderSuccess();
    }
  }

  // ==========================================
  // STAGE 0: DONOR PREPARING & PACKING MEAL
  // ==========================================
  Widget _buildStage0Packing() {
    final subProgress = (_masterController.value / 0.28).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Vector packing counter illustration
        SizedBox(
          height: 180,
          width: 220,
          child: CustomPaint(
            painter: _DonorPackingPainter(
              progress: subProgress,
              pulse: _pulseHeartController.value,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Your kindness is on its way!',
          textAlign: TextAlign.center,
          style: AppTypography.displayMedium.copyWith(
            color: AppColors.forestGreen,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.order.sellerName} is carefully preparing\nand packing your meal with eco-friendly care...',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.darkText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STAGE 1: MEAL TRAVELING ON LEAFY CURVED PATH
  // ==========================================
  Widget _buildStage1LeafyJourney() {
    final subProgress = ((_masterController.value - 0.28) / 0.26).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: CustomPaint(
            painter: _LeafyCurvedJourneyPainter(
              progress: subProgress,
              sparkle: _sparkleController.value,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Travelling along green paths...',
          textAlign: TextAlign.center,
          style: AppTypography.displayMedium.copyWith(
            color: AppColors.forestGreen,
            fontSize: 21,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.order.fulfilmentMethod == FulfilmentMethod.delivery
              ? 'Eco-friendly delivery partner en route with fresh care.'
              : 'Meal staged at pickup window with your safety code.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.mutedText,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STAGE 2: THE EMOTIONAL HIGHLIGHT —
  // FOOD HANDOVER & ANIMATED HANDSHAKE 🤝🌿
  // ==========================================
  Widget _buildStage2HandoverAndHandshake() {
    final subProgress = ((_masterController.value - 0.54) / 0.28).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Two vector illustrated characters with animated handover & handshake
        SizedBox(
          height: 200,
          width: double.infinity,
          child: CustomPaint(
            painter: _CharacterHandshakePainter(
              progress: subProgress,
              handshakeBounce: _handshakeMotionController.value,
              pulseScale: _pulseHeartController.value,
              donorName: widget.order.sellerName.split(' ').first,
              customerName: widget.order.userName.split(' ').first,
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Brand signature message
        Text(
          'Food shared. Hearts connected.',
          textAlign: TextAlign.center,
          style: AppTypography.displayLarge.copyWith(
            color: AppColors.forestGreen,
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Kindness, trust, and community in every single meal.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.darkText,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STAGE 3: ORDER SUCCESS & TRANSITION
  // ==========================================
  Widget _buildStage3OrderSuccess() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Live Mobile Notification Banner inside Confirmation Screen (Section D2)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF162B1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _reminderSent
                    ? AppColors.gold.withValues(alpha: 0.7)
                    : AppColors.sageGreen.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _reminderSent
                        ? AppColors.gold.withValues(alpha: 0.22)
                        : AppColors.forestGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _reminderSent
                        ? Icons.alarm_on_rounded
                        : Icons.notifications_active_rounded,
                    color: _reminderSent ? AppColors.gold : Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _reminderSent
                            ? '⏰ Booking Reminder Sent • NOW'
                            : '🔔 Booking Confirmed Notification • NOW',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _reminderSent
                            ? 'Reminder: Order #${widget.order.orderNumber} at ${widget.order.sellerName} is ready. Show code ${widget.order.handoverCode}.'
                            : '${widget.order.itemsSummary} reserved at ${widget.order.sellerName}. Handover Code: ${widget.order.handoverCode}.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Green leaf checkmark emblem
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.forestGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestGreen.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 10),

          // Contextual celebratory headline
          Text(
            widget.order.isFreeDonation
                ? 'A little care is on its way 💚'
                : 'You saved a meal from going to waste! 🌿',
            textAlign: TextAlign.center,
            style: AppTypography.displayMedium.copyWith(
              color: AppColors.forestGreen,
              fontSize: 19,
            ),
          ),

          const SizedBox(height: 4),
          Text(
            'Booking Confirmed & Saved (#${widget.order.orderNumber})',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          // Order Details Card (Section D1: complete booking details)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Order Number
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order Number:', style: AppTypography.bodyMedium.copyWith(fontSize: 12.5)),
                    Flexible(
                      child: Text(
                        '#${widget.order.orderNumber}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.forestGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),

                // Partner Kitchen
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Partner Kitchen:', style: AppTypography.bodyMedium.copyWith(fontSize: 12.5)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.order.sellerName,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),

                // Booked Items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booked Items:', style: AppTypography.bodyMedium.copyWith(fontSize: 12.5)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.order.itemsSummary,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),

                // Fulfilment & Estimate
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.order.fulfilmentMethodDisplay,
                      style: AppTypography.bodyMedium.copyWith(fontSize: 12.5),
                    ),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: AppColors.forestGreen),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.order.fulfilmentMethod == FulfilmentMethod.delivery
                                  ? 'Arriving ~12 mins'
                                  : 'Ready 6:00 PM',
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),

                // Total Paid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount:', style: AppTypography.bodyMedium.copyWith(fontSize: 12.5)),
                    Text(
                      widget.order.isFreeDonation
                          ? 'FREE 💚'
                          : '${widget.order.currencySymbol}${widget.order.finalTotal.toStringAsFixed(2)}',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),

                // Secure Handover Verification Code
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Handover Code:', style: AppTypography.bodyMedium.copyWith(fontSize: 12.5)),
                          const Text('(Verify at handover)', style: TextStyle(fontSize: 10, color: AppColors.mutedText)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        widget.order.handoverCode,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.forestGreen,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),

                // Green Tokens Earned
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tokens Earned:', style: AppTypography.bodyMedium.copyWith(fontSize: 12.5)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙 ', style: TextStyle(fontSize: 13)),
                        Text(
                          '+${widget.order.tokensEarned}',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.forestGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Send Reminder Notification Button (Section D2)
          SizedBox(
            width: double.infinity,
            height: 38,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _reminderSent = true);
                widget.onSendReminder?.call();
              },
              icon: Icon(
                _reminderSent ? Icons.check_circle_rounded : Icons.notifications_active_outlined,
                size: 16,
                color: AppColors.forestGreen,
              ),
              label: Text(
                _reminderSent
                    ? 'Pickup Reminder Notification Sent to Device ✓'
                    : 'Send Pickup Reminder Notification to Device',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestGreen,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.mint.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Download PDF Invoice Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                PdfInvoiceService.printOrShareInvoice(context, widget.order);
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.forestGreen),
              label: const Text('Download Bill / Invoice (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.forestGreen)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.mint, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Primary Track Order Live Button & Secondary Close Button
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forestGreen,
                      side: BorderSide(color: AppColors.forestGreen.withValues(alpha: 0.4), width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      widget.onTrackOrder();
                    },
                    icon: const Icon(Icons.near_me_rounded, size: 18),
                    label: const Text(
                      'Track Order Live',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: AppColors.forestGreen.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ERROR & RETRY STATE
  // ==========================================
  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.coral.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.wifi_off_rounded, color: AppColors.coral, size: 38),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Connection Interrupted',
          style: AppTypography.displayMedium.copyWith(
            color: AppColors.darkText,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We could not verify your order with KindPlate servers. Please retry connecting.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _retryOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: const Text('Retry Order'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel & Return to Cart'),
        ),
      ],
    );
  }
}

// =========================================================================
// CUSTOM VECTOR PAINTER: DONOR PACKING MEAL WITH ECO-BOX FLAPS & STEAM
// =========================================================================
class _DonorPackingPainter extends CustomPainter {
  final double progress;
  final double pulse;

  _DonorPackingPainter({required this.progress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Chef / Donor Character
    final chefPaint = Paint()..color = const Color(0xFFF0D5BE);
    canvas.drawCircle(Offset(w * 0.5, h * 0.28), 26, chefPaint); // Face

    // Chef green bandana / hat
    final hatPaint = Paint()..color = AppColors.forestGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.16), width: 36, height: 16),
        const Radius.circular(8),
      ),
      hatPaint,
    );

    // Apron Body
    final apronPaint = Paint()..color = AppColors.sageGreen;
    final apronPath = Path()
      ..moveTo(w * 0.38, h * 0.44)
      ..lineTo(w * 0.62, h * 0.44)
      ..lineTo(w * 0.68, h * 0.76)
      ..lineTo(w * 0.32, h * 0.76)
      ..close();
    canvas.drawPath(apronPath, apronPaint);

    // 2. Prep Counter Table
    final counterPaint = Paint()..color = const Color(0xFFD7C7B0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.76, w * 0.84, 18),
        const Radius.circular(6),
      ),
      counterPaint,
    );

    // 3. Biodegradable Meal Box
    final boxPaint = Paint()..color = const Color(0xFFDFBF84);
    final boxRect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.68), width: 68, height: 38);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(8)), boxPaint);

    // Green leaf ribbon tied around the box
    final ribbonPaint = Paint()
      ..color = AppColors.forestGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.86), ribbonPaint);

    // Box top flap animated closing based on progress
    final flapAngle = (1.0 - progress) * 0.8;
    final flapPaint = Paint()..color = const Color(0xFFCFA668);
    final flapPath = Path()
      ..moveTo(w * 0.34, h * 0.50)
      ..lineTo(w * 0.50 - 20 * math.cos(flapAngle), h * 0.44 - 15 * math.sin(flapAngle))
      ..lineTo(w * 0.50 + 20 * math.cos(flapAngle), h * 0.44 - 15 * math.sin(flapAngle))
      ..lineTo(w * 0.66, h * 0.50)
      ..close();
    canvas.drawPath(flapPath, flapPaint);

    // 4. Soft Steam & Sparkles
    final steamPaint = Paint()
      ..color = AppColors.forestGreen.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final sx = w * 0.42 + i * 10.0;
      final sy = h * 0.40 - (progress * 15.0 + i * 4);
      final steamPath = Path()
        ..moveTo(sx, sy)
        ..quadraticBezierTo(sx + 5 * (pulse - 0.5), sy - 10, sx, sy - 18);
      canvas.drawPath(steamPath, steamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonorPackingPainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM VECTOR PAINTER: CURVED LEAFY PATH JOURNEY
// =========================================================================
class _LeafyCurvedJourneyPainter extends CustomPainter {
  final double progress;
  final double sparkle;

  _LeafyCurvedJourneyPainter({required this.progress, required this.sparkle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Cubic curved leafy green path
    final path = Path()
      ..moveTo(w * 0.12, h * 0.75)
      ..cubicTo(w * 0.35, h * 0.18, w * 0.65, h * 0.88, w * 0.88, h * 0.30);

    // Track line
    final trackPaint = Paint()
      ..color = AppColors.mint
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, trackPaint);

    // Sprouting little leaves along track
    final leafPaint = Paint()..color = AppColors.sageGreen;
    for (int i = 1; i <= 6; i++) {
      final t = i / 7.0;
      final pt = _evaluateCubic(
        Offset(w * 0.12, h * 0.75),
        Offset(w * 0.35, h * 0.18),
        Offset(w * 0.65, h * 0.88),
        Offset(w * 0.88, h * 0.30),
        t,
      );
      canvas.drawCircle(Offset(pt.dx, pt.dy + 7), 4.5, leafPaint);
    }

    // Moving meal package along the curve
    final curPt = _evaluateCubic(
      Offset(w * 0.12, h * 0.75),
      Offset(w * 0.35, h * 0.18),
      Offset(w * 0.65, h * 0.88),
      Offset(w * 0.88, h * 0.30),
      progress,
    );

    // Soft glow behind package
    final glowPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(curPt, 24, glowPaint);

    // Food Package Icon Circle
    final packageBg = Paint()..color = AppColors.gold;
    canvas.drawCircle(curPt, 18, packageBg);

    final packageBorder = Paint()
      ..color = AppColors.forestGreen
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(curPt, 18, packageBorder);

    // Little eco-leaf stamp on moving package
    final stampPaint = Paint()..color = AppColors.forestGreen;
    canvas.drawCircle(Offset(curPt.dx, curPt.dy - 1), 5, stampPaint);
  }

  Offset _evaluateCubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final x = math.pow(1 - t, 3) * p0.dx +
        3 * math.pow(1 - t, 2) * t * p1.dx +
        3 * (1 - t) * math.pow(t, 2) * p2.dx +
        math.pow(t, 3) * p3.dx;
    final y = math.pow(1 - t, 3) * p0.dy +
        3 * math.pow(1 - t, 2) * t * p1.dy +
        3 * (1 - t) * math.pow(t, 2) * p2.dy +
        math.pow(t, 3) * p3.dy;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _LeafyCurvedJourneyPainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM VECTOR PAINTER: TWO CHARACTERS HANDOVER & ANIMATED HANDSHAKE RIG
// =========================================================================
class _CharacterHandshakePainter extends CustomPainter {
  final double progress;
  final double handshakeBounce;
  final double pulseScale;
  final String donorName;
  final String customerName;

  _CharacterHandshakePainter({
    required this.progress,
    required this.handshakeBounce,
    required this.pulseScale,
    required this.donorName,
    required this.customerName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background soft stage pedestal
    final stageBg = Paint()..color = AppColors.mint.withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(12, 10, w - 24, h - 20), const Radius.circular(24)),
      stageBg,
    );

    // ----------------------------------------------------
    // CHARACTER 1 (LEFT): DONOR / DELIVERY PARTNER
    // ----------------------------------------------------
    final donorCenterX = w * 0.22;
    final donorCenterY = h * 0.48;

    // Head
    canvas.drawCircle(Offset(donorCenterX, donorCenterY - 32), 22, Paint()..color = const Color(0xFFF2D1B8));
    // Green Cap / Hair
    canvas.drawArc(
      Rect.fromCircle(center: Offset(donorCenterX, donorCenterY - 36), radius: 23),
      math.pi,
      math.pi,
      true,
      Paint()..color = AppColors.forestGreen,
    );
    // Smiling eyes
    canvas.drawCircle(Offset(donorCenterX - 6, donorCenterY - 34), 2.5, Paint()..color = AppColors.darkText);
    canvas.drawCircle(Offset(donorCenterX + 6, donorCenterY - 34), 2.5, Paint()..color = AppColors.darkText);

    // Body / Green Jacket
    final donorBody = Path()
      ..moveTo(donorCenterX - 18, donorCenterY - 10)
      ..lineTo(donorCenterX + 18, donorCenterY - 10)
      ..lineTo(donorCenterX + 22, donorCenterY + 44)
      ..lineTo(donorCenterX - 22, donorCenterY + 44)
      ..close();
    canvas.drawPath(donorBody, Paint()..color = AppColors.sageGreen);

    // ----------------------------------------------------
    // CHARACTER 2 (RIGHT): GRATEFUL CUSTOMER
    // ----------------------------------------------------
    final customerCenterX = w * 0.78;
    final customerCenterY = h * 0.48;

    // Head
    canvas.drawCircle(Offset(customerCenterX, customerCenterY - 32), 22, Paint()..color = const Color(0xFFECD0B5));
    // Dark Hair
    canvas.drawArc(
      Rect.fromCircle(center: Offset(customerCenterX, customerCenterY - 36), radius: 23),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF3C2C24),
    );
    // Happy grateful curved eyes (smiling arcs)
    final smileEyePaint = Paint()
      ..color = AppColors.darkText
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(Rect.fromLTWH(customerCenterX - 10, customerCenterY - 36, 8, 6), 0, math.pi, false, smileEyePaint);
    canvas.drawArc(Rect.fromLTWH(customerCenterX + 2, customerCenterY - 36, 8, 6), 0, math.pi, false, smileEyePaint);

    // Body / Warm Cream Sweater
    final custBody = Path()
      ..moveTo(customerCenterX - 18, customerCenterY - 10)
      ..lineTo(customerCenterX + 18, customerCenterY - 10)
      ..lineTo(customerCenterX + 22, customerCenterY + 44)
      ..lineTo(customerCenterX - 22, customerCenterY + 44)
      ..close();
    canvas.drawPath(custBody, Paint()..color = const Color(0xFFD6C8AF));

    // ----------------------------------------------------
    // CENTER: FOOD HANDOVER & REAL ANIMATED HANDSHAKE
    // ----------------------------------------------------
    final centerX = w * 0.50;
    final centerY = h * 0.52;

    // Handover motion: meal moves from donor to customer
    final foodX = donorCenterX + (customerCenterX - donorCenterX) * (0.35 + progress * 0.30);
    final foodY = centerY - 28 - math.sin(progress * math.pi) * 12;

    // Food Package Bento Box
    final bentoRect = Rect.fromCenter(center: Offset(foodX, foodY), width: 38, height: 26);
    canvas.drawRRect(RRect.fromRectAndRadius(bentoRect, const Radius.circular(6)), Paint()..color = AppColors.gold);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bentoRect, const Radius.circular(6)),
      Paint()
        ..color = AppColors.forestGreen
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );

    // THE ANIMATED HANDSHAKE LINKAGE (Vertical pump up and down)
    final handshakeY = centerY + 18 + (handshakeBounce - 0.5) * 10;

    // Donor Arm reaching to center
    final donorArmPaint = Paint()
      ..color = const Color(0xFFF2D1B8)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(donorCenterX + 12, donorCenterY + 12), Offset(centerX - 6, handshakeY), donorArmPaint);

    // Customer Arm reaching to center
    final custArmPaint = Paint()
      ..color = const Color(0xFFECD0B5)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(customerCenterX - 12, customerCenterY + 12), Offset(centerX + 6, handshakeY), custArmPaint);

    // Joined Hands Clasp (Warm Handshake)
    final handClaspPaint = Paint()..color = AppColors.forestGreen;
    canvas.drawCircle(Offset(centerX, handshakeY), 10, handClaspPaint);

    // Glowing Leaf & Pulsing Heart between the joined hands
    final glowHeartPaint = Paint()
      ..color = AppColors.softGreen.withValues(alpha: 0.45 * pulseScale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(centerX, handshakeY - 14), 16 * pulseScale, glowHeartPaint);

    // Central Green Heart & Sprouting Leaf
    final heartPaint = Paint()..color = AppColors.forestGreen;
    canvas.drawCircle(Offset(centerX, handshakeY - 14), 8, heartPaint);

    // Sprouting Leaf Tip
    final sproutPaint = Paint()..color = AppColors.sageGreen;
    canvas.drawCircle(Offset(centerX, handshakeY - 24), 5, sproutPaint);
  }

  @override
  bool shouldRepaint(covariant _CharacterHandshakePainter oldDelegate) => true;
}

// =========================================================================
// BACKGROUND AMBIENT LEAF SHIMMER PAINTER
// =========================================================================
class _AmbientLeafShimmerPainter extends CustomPainter {
  final double progress;

  _AmbientLeafShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final leafPaint = Paint()
      ..color = AppColors.forestGreen.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 7; i++) {
      final x = (i * 75.0 + progress * 35.0) % size.width;
      final y = (i * 110.0 + math.sin(progress * 2 * math.pi + i) * 25.0) % size.height;
      canvas.drawCircle(Offset(x, y), 10 + i * 2, leafPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientLeafShimmerPainter oldDelegate) => true;
}
