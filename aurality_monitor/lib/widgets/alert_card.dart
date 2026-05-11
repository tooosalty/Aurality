import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert_model.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import 'alert_badge.dart';
import 'waveform_widget.dart';

/// Glassmorphism alert card with:
/// - Pulse animation on first appearance
/// - Swipe-to-dismiss (soft-deletes in Firestore)
/// - Tap to open HITL detail screen
class AlertCard extends StatefulWidget {
  final AlertModel alert;
  final VoidCallback onDismiss;

  const AlertCard({super.key, required this.alert, required this.onDismiss});

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _pulseController.stop();
        _pulseController.animateTo(1.0);
        setState(() => _isNew = false);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _accentColor => AppTheme.priorityColor(widget.alert.priority);

  Future<void> _handleDismiss() async {
    widget.onDismiss();
    await FirebaseService().dismissAlert(widget.alert.id);
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.alert.id),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      onDismissed: (_) => _handleDismiss(),
      child: ScaleTransition(scale: _pulse, child: _buildCard(context)),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.delete_sweep_rounded,
            color: AppColors.accentRed,
            size: 28,
          ),
          const SizedBox(height: 4),
          const Text(
            'DISMISS',
            style: TextStyle(
              color: AppColors.accentRed,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: GlassDecoration(
                borderColor: _isNew
                    ? _accentColor.withValues(alpha: 0.5)
                    : AppColors.glassBorder,
                radius: 20,
              ),
              child: Stack(
                children: [
                  // Left priority accent bar
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: icon + title + badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _accentColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(
                                AppTheme.priorityIcon(widget.alert.eventType),
                                color: _accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _friendlyName(widget.alert.eventType),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 11,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimestamp(
                                          widget.alert.timestamp,
                                        ),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            AlertBadge(
                              priority: widget.alert.priority,
                              label: widget.alert.priority,
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 14),

                        // Waveform player (compact) — uses storagePath
                        WaveformWidget(
                          storagePath: widget.alert.storagePath,
                          accentColor: _accentColor,
                          compact: true,
                        ),

                        const SizedBox(height: 12),

                        // Footer: confidence + audit hint
                        Row(
                          children: [
                            _buildConfidenceChip(),
                            const Spacer(),
                            Text(
                              'Tap to verify →',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: _accentColor.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildConfidenceChip() {
    final pct = widget.alert.confidence;
    final color = pct >= 0.85
        ? AppColors.accentRed
        : pct >= 0.60
        ? AppColors.accentAmber
        : AppColors.accentCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_rounded, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            'AI Confidence ${widget.alert.confidenceLabel}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: _AlertDetailScreen(alert: widget.alert),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) =>
      DateFormat('MMM d, y  •  h:mm a').format(dt);

  static String _friendlyName(String raw) => raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ─── Detail Screen ───────────────────────────────────────────────────────────
class _AlertDetailScreen extends StatelessWidget {
  final AlertModel alert;
  const _AlertDetailScreen({required this.alert});

  Color get _accentColor => AppTheme.priorityColor(alert.priority);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: GlassDecoration(radius: 12),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Verify Alert',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Human-in-the-Loop Review',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: _accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // ── Audit card ──
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: GlassDecoration(
                      borderColor: _accentColor.withValues(alpha: 0.4),
                      radius: 20,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                AppTheme.priorityIcon(alert.eventType),
                                color: _accentColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _friendlyName(alert.eventType),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                AlertBadge(
                                  priority: alert.priority,
                                  label: alert.priority,
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(color: AppColors.divider),
                        const SizedBox(height: 16),

                        // ── Audit fields ──
                        _infoRow(
                          Icons.calendar_today_rounded,
                          'Date',
                          DateFormat('EEEE, MMM d, y').format(alert.timestamp),
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.access_time_rounded,
                          'Time',
                          DateFormat(
                            'h:mm:ss a',
                          ).format(alert.timestamp.toLocal()),
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.analytics_rounded,
                          'AI Confidence',
                          alert.confidenceLabel,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.compare_arrows_rounded,
                          'Decision Margin',
                          '${(alert.margin * 100).toStringAsFixed(1)}%',
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Icons.devices_rounded,
                          'Device',
                          alert.deviceId,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(Icons.tag_rounded, 'Record ID', alert.id),

                        // ── allProbabilities breakdown ──
                        if (alert.allProbabilities.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: 14),
                          const Text(
                            'CLASS PROBABILITIES',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...alert.allProbabilities.entries.map(
                            (e) => _probBar(e.key, e.value),
                          ),
                        ],

                        const SizedBox(height: 24),
                        const Divider(color: AppColors.divider),
                        const SizedBox(height: 20),

                        // ── Full waveform player ──
                        const Text(
                          'AUDIO RECORDING',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        WaveformWidget(
                          storagePath: alert.storagePath,
                          accentColor: _accentColor,
                          compact: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── HITL Action buttons ──
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      context,
                      label: 'Confirm Alert',
                      icon: Icons.check_circle_rounded,
                      color: _accentColor,
                      onTap: () async {
                        await FirebaseService().acknowledgeAlert(alert.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Alert confirmed and logged.',
                              ),
                              backgroundColor: _accentColor.withValues(
                                alpha: 0.85,
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      context,
                      label: 'False Alarm',
                      icon: Icons.cancel_rounded,
                      color: AppColors.textMuted,
                      outlined: true,
                      onTap: () async {
                        await FirebaseService().dismissAlert(alert.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Horizontal probability bar for class breakdown.
  Widget _probBar(String label, double value) {
    final color = label == 'glass'
        ? AppColors.accentRed
        : label == 'shouting'
        ? AppColors.accentAmber
        : AppColors.accentCyan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                backgroundColor: AppColors.textMuted.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 16,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _friendlyName(String raw) => raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
