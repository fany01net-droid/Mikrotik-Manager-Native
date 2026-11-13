import 'package:flutter/material.dart';
import '../theme/fnet_theme.dart';

/// Clean, Handcrafted Material 3 Splash Screen for Fanny Network
/// Visual Concept:
/// 1. Logo FNet (Letter F Google Palette + Satelit + Gelombang Sinyal Wi-Fi).
/// 2. Warna 100% ADAPTIF mengikuti pengaturan tema warna Material 3 pengguna.
/// 3. Gelombang sinyal Wi-Fi dinamis berdenyut memancar dari satelit orbit.
/// 4. Animasi transisi halus menuju layar utama/login dengan fitur ketuk untuk lewati.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final String themeColor;
  final bool isDark;

  const SplashScreen({
    super.key,
    required this.onFinish,
    this.themeColor = 'blue',
    this.isDark = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _timelineCtrl;

  late Animation<double> _enterFade;
  late Animation<double> _enterScale;
  late Animation<double> _progressAnim;
  late Animation<double> _exitFade;
  late Animation<double> _exitScale;

  @override
  void initState() {
    super.initState();

    // 1. Continuous Wi-Fi signal & breathing pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // 2. Main timeline controller (1800ms)
    _timelineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Entrance sequence (0 -> 450ms)
    _enterFade = CurvedAnimation(
      parent: _timelineCtrl,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _enterScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.0, 0.38, curve: Curves.easeOutBack),
      ),
    );

    // Progress bar fill (200ms -> 1500ms)
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.12, 0.86, curve: Curves.easeInOutCubic),
      ),
    );

    // Exit transition (1500ms -> 1800ms)
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.86, 1.0, curve: Curves.easeIn),
      ),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.86, 1.0, curve: Curves.easeInCubic),
      ),
    );

    _timelineCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinish();
      }
    });

    _timelineCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timelineCtrl.dispose();
    super.dispose();
  }

  void _skip() {
    if (_timelineCtrl.value < 0.86) {
      _timelineCtrl
          .animateTo(
            1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (mounted) {
              widget.onFinish();
            }
          });
    }
  }

  String _getStatusText(double progress) {
    if (progress < 0.30) {
      return 'Menginisialisasi modul FNet...';
    } else if (progress < 0.65) {
      return 'Memeriksa profil MikroTik...';
    } else if (progress < 0.90) {
      return 'Menyiapkan koneksi aman...';
    } else {
      return 'Siap!';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 100% Dynamic Adaptive Palette from chosen Theme Color
    final seed = FNetTheme.getSeedColor(widget.themeColor);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: widget.isDark ? Brightness.dark : Brightness.light,
    );

    final bgSurface = widget.isDark
        ? Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.06), const Color(0xFF0C1017))
        : Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.03), const Color(0xFFF8FAFC));
    final primaryColor = colorScheme.primary;

    return GestureDetector(
      onTap: _skip,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: bgSurface,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseCtrl, _timelineCtrl]),
            builder: (context, _) {
              final overallOpacity = (_enterFade.value * _exitFade.value).clamp(0.0, 1.0);
              final overallScale = _enterScale.value * _exitScale.value;
              final progress = _progressAnim.value;

              return Opacity(
                opacity: overallOpacity,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ==========================================
                          // 1. Central FNet Logo with Dynamic Wi-Fi Waves
                          // ==========================================
                          Transform.scale(
                            scale: overallScale,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Concentric Animated Wi-Fi Wave Ripples
                                SizedBox(
                                  width: 250,
                                  height: 250,
                                  child: CustomPaint(
                                    painter: _WifiPulsePainter(
                                      pulseProgress: _pulseCtrl.value,
                                      pulseColor: primaryColor,
                                    ),
                                  ),
                                ),

                                // Ambient soft glow container
                                Container(
                                  width: 154,
                                  height: 154,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(
                                          alpha: widget.isDark ? 0.35 : 0.15,
                                        ),
                                        blurRadius: 36,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),

                                // Logo Squircle Badge
                                Card(
                                  elevation: widget.isDark ? 8 : 3,
                                  shadowColor: primaryColor.withValues(
                                    alpha: widget.isDark ? 0.4 : 0.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(36),
                                  ),
                                  color: Colors.white,
                                  clipBehavior: Clip.antiAlias,
                                  child: Container(
                                    width: 144,
                                    height: 144,
                                    padding: const EdgeInsets.all(12),
                                    child: Image.asset(
                                      'assets/icons/fnet_logo_badge.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        // Graceful fallback if asset cache takes a moment
                                        return Icon(
                                          Icons.satellite_alt_rounded,
                                          size: 64,
                                          color: primaryColor,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ==========================================
                          // 2. Brand Name & Identity
                          // ==========================================
                          Text(
                            'Fanny Network',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: widget.isDark ? Colors.white : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Material 3 Badge / Pill Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: widget.isDark ? 0.45 : 0.65,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: widget.isDark ? 0.35 : 0.5,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Pulsing green online beacon
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF34A853),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF34A853).withValues(
                                          alpha: 0.4 + (_pulseCtrl.value * 0.4),
                                        ),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'MikroTik Network Manager',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tagline
                          Text(
                            'Internet Cepat, Stabil & Terpercaya',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                              color: widget.isDark
                                  ? Colors.white70
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ==========================================
                          // 3. Material 3 Linear Progress Track & Status
                          // ==========================================
                          SizedBox(
                            width: 170,
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    height: 4,
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: widget.isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : colorScheme.outlineVariant.withValues(alpha: 0.35),
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _getStatusText(progress),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isDark
                                        ? Colors.white60
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 48),

                          // ==========================================
                          // 4. Subtle Footer
                          // ==========================================
                          Text(
                            'FNet v1.0.0 • MikroTik RouterOS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                              color: widget.isDark
                                  ? Colors.white30
                                  : colorScheme.outline.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Custom Painter: Dynamic concentric Wi-Fi / orbital pulse waves radiating from emblem
class _WifiPulsePainter extends CustomPainter {
  final double pulseProgress;
  final Color pulseColor;

  _WifiPulsePainter({
    required this.pulseProgress,
    required this.pulseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final p = (pulseProgress + (i * 0.33)) % 1.0;
      final radius = 78.0 + (p * 45.0);
      final alpha = ((1.0 - p) * 0.40).clamp(0.0, 1.0);
      wavePaint.color = pulseColor.withValues(alpha: alpha);

      canvas.drawCircle(Offset(cx, cy), radius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WifiPulsePainter oldDelegate) {
    return oldDelegate.pulseProgress != pulseProgress || oldDelegate.pulseColor != pulseColor;
  }
}
