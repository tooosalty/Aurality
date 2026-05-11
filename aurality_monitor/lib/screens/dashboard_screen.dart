import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_card.dart';
import '../widgets/alert_badge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Local dismissed IDs (UI hides them instantly before Firebase confirms)
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: StreamBuilder<List<AlertModel>>(
              stream: FirebaseService().alertsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _loadingSliver();
                }
                if (snapshot.hasError) {
                  return _errorSliver(snapshot.error.toString());
                }

                final all = snapshot.data ?? [];
                final alerts = all
                    .where((a) => !_dismissed.contains(a.id))
                    .toList();

                if (alerts.isEmpty) {
                  return _emptySliver();
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final alert = alerts[index];
                    return AlertCard(
                      key: ValueKey(alert.id),
                      alert: alert,
                      onDismiss: () {
                        setState(() => _dismissed.add(alert.id));
                      },
                    );
                  }, childCount: alerts.length),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live indicator
              Row(
                children: [
                  _LiveIndicator(),
                  const SizedBox(width: 10),
                  const Text(
                    'MONITORING LIVE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentCyan,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text(
                    'Aurality',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'MONITOR',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentCyan,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: _buildFilterBar(),
      ),
    );
  }

  Widget _buildFilterBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: AppColors.background.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              const Text(
                'Recent Alerts  •  Swipe to dismiss',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              AlertBadge(priority: 'high', label: 'HIGH'),
              const SizedBox(width: 6),
              AlertBadge(priority: 'medium', label: 'MED'),
              const SizedBox(width: 6),
              AlertBadge(priority: 'low', label: 'LOW'),
            ],
          ),
        ),
      ),
    );
  }

  SliverFillRemaining _loadingSliver() {
    return const SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accentCyan),
            SizedBox(height: 16),
            Text(
              'Connecting to Aurality…',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverFillRemaining _errorSliver(String message) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.accentRed,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Connection Error',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverFillRemaining _emptySliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated sonar rings
            _SonarWidget(),
            const SizedBox(height: 28),
            const Text(
              'All Clear',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Monitoring your environment.\nNo acoustic events detected.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live blinking dot ───────────────────────────────────────────────────────
class _LiveIndicator extends StatefulWidget {
  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.accentCyan,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accentCyan.withValues(alpha: 0.7),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sonar empty-state animation ─────────────────────────────────────────────
class _SonarWidget extends StatefulWidget {
  @override
  State<_SonarWidget> createState() => _SonarWidgetState();
}

class _SonarWidgetState extends State<_SonarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _scale = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentCyan, width: 2),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentCyan.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.hearing_rounded,
              color: AppColors.accentCyan,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}
