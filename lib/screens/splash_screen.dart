import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/fnet_theme.dart';

/// Clean, Handcrafted Material 3 Splash Screen for Fanny Network
/// Visual Concept:
/// 1. Satelit di orbit memancarkan sinyal internet stabil ke bumi ke rumah-rumah warga.
/// 2. Warna 100% ADAPTIF mengikuti pengaturan tema warna Material 3 pilihan pengguna.
/// 3. Animasi keluar (exit sequence) meluncur naik dan docking ke icon MikroTik Manager di AppBar.
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

  // Exit Docking Animations:
  late Animation<double> _groundFade;
  late Animation<Offset> _groundSlide;
  late Animation<double> _textFade;
  late Animation<Offset> _satelliteGlide;
  late Animation<double> _satelliteScale;
  late Animation<double> _dockingAura;

  @override
  void initState() {
    super.initState();

    // 1. Continuous signal wave pulses from satellite to homes
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // 2. Master timeline
    _timelineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Entrance: 0ms -> 480ms
    _enterFade = CurvedAnimation(
      parent: _timelineCtrl,
      curve: const Interval(0.0, 0.32, curve: Curves.easeOut),
    );
    _enterScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.0, 0.38, curve: Curves.easeOutCubic),
      ),
    );

    // Progress bar fill: 200ms -> 1200ms
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.15, 0.78, curve: Curves.easeInOutCubic),
      ),
    );

    // 3. Exit Sequence (Docking into MikroTik Manager icon): 1200ms -> 1600ms
    // Ground & homes sink and fade
    _groundFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.76, 0.92, curve: Curves.easeIn),
      ),
    );
    _groundSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 0.08),
    ).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.76, 0.95, curve: Curves.easeInCubic),
      ),
    );

    // Text & progress line fade away
    _textFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.75, 0.88, curve: Curves.easeIn),
      ),
    );

    // Satellite glides upward toward AppBar icon position and contracts into compact emblem
    _satelliteGlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.38),
    ).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.78, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _satelliteScale = Tween<double>(begin: 1.0, end: 0.36).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.80, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    // Docking circular aura emerges around the satellite as it reaches the top
    _dockingAura = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timelineCtrl,
        curve: const Interval(0.84, 1.0, curve: Curves.easeOut),
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
    if (_timelineCtrl.value < 0.78) {
      _timelineCtrl.animateTo(1.0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
        ? Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.07), const Color(0xFF090D16))
        : colorScheme.surface;
    final primaryColor = colorScheme.primary;
    final tertiaryColor = colorScheme.tertiary;

    return GestureDetector(
      onTap: _skip,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: bgSurface,
        body: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseCtrl, _timelineCtrl]),
            builder: (context, _) {
              final enterOpacity = _enterFade.value;

              return Opacity(
                opacity: enterOpacity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ==========================================
                    // 1. Satellite Emblem (Glides UP toward AppBar icon)
                    // ==========================================
                    SlideTransition(
                      position: _satelliteGlide,
                      child: Transform.scale(
                        scale: _enterScale.value * _satelliteScale.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Circular docking aura indicator (appears during exit glide)
                            Opacity(
                              opacity: _dockingAura.value,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: primaryColor,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.5),
                                      blurRadius: 18,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Satellite & Pulse Waves Vector Canvas
                            SizedBox(
                              width: 240,
                              height: 100,
                              child: CustomPaint(
                                painter: _SatelliteFlightPainter(
                                  pulseProgress: _pulseCtrl.value,
                                  primaryColor: primaryColor,
                                  accentColor: tertiaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ==========================================
                    // 2. Earth Horizon & Homes (Fades & sinks during exit)
                    // ==========================================
                    SlideTransition(
                      position: _groundSlide,
                      child: Opacity(
                        opacity: _groundFade.value,
                        child: SizedBox(
                          width: 260,
                          height: 90,
                          child: CustomPaint(
                            painter: _HomesGroundPainter(
                              pulseProgress: _pulseCtrl.value,
                              primaryColor: primaryColor,
                              accentColor: tertiaryColor,
                              isDark: widget.isDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // 3. Brand Text & Progress Track (Fades out cleanly)
                    // ==========================================
                    Opacity(
                      opacity: _textFade.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Brand Title
                          Text(
                            'Fanny Network',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: widget.isDark ? Colors.white : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Tagline with Adaptive Accent Dot
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tertiaryColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: tertiaryColor.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Internet stabil untuk anda',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                  color: widget.isDark ? Colors.white70 : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Adaptive Theme Progress Track
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 140,
                              height: 3,
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _progressAnim.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Upper Canvas: Satellite in Orbit with Solar Panels, Dish, and Downward Pulse Waves
class _SatelliteFlightPainter extends CustomPainter {
  final double pulseProgress;
  final Color primaryColor;
  final Color accentColor;

  _SatelliteFlightPainter({
    required this.pulseProgress,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const cy = 34.0;

    // 1. Cascading Signal Waves expanding downward
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final p = (pulseProgress + (i * 0.33)) % 1.0;
      final radius = 16.0 + (p * 55.0);
      final alpha = ((1.0 - p) * 0.70).clamp(0.0, 1.0);
      wavePaint.color = primaryColor.withValues(alpha: alpha);

      final rect = Rect.fromCircle(center: Offset(cx, cy + 12), radius: radius);
      canvas.drawArc(rect, 0.30 * math.pi, 0.40 * math.pi, false, wavePaint);
    }

    // 2. Solar Panels Left & Right
    final panelBg = Paint()..color = primaryColor.withValues(alpha: 0.88);
    final panelBorder = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final gridLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 0.8;

    // Left Panel
    final leftRect = Rect.fromLTWH(cx - 52, cy - 9, 22, 18);
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(3)), panelBg);
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(3)), panelBorder);
    canvas.drawLine(Offset(cx - 41, cy - 9), Offset(cx - 41, cy + 9), gridLine);
    canvas.drawLine(Offset(cx - 52, cy), Offset(cx - 30, cy), gridLine);

    // Right Panel
    final rightRect = Rect.fromLTWH(cx + 30, cy - 9, 22, 18);
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(3)), panelBg);
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(3)), panelBorder);
    canvas.drawLine(Offset(cx + 41, cy - 9), Offset(cx + 41, cy + 9), gridLine);
    canvas.drawLine(Offset(cx + 30, cy), Offset(cx + 52, cy), gridLine);

    // Connecting Truss
    final trussPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.75)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(cx - 30, cy), Offset(cx + 30, cy), trussPaint);

    // 3. Central Satellite Body
    final bodyPaint = Paint()..color = Colors.white;
    final bodyStroke = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy), width: 22, height: 30);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(6)), bodyPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(6)), bodyStroke);

    // Core Beacon (Adaptive Accent)
    canvas.drawCircle(Offset(cx, cy), 3.8, Paint()..color = accentColor);

    // Dish Antenna
    final dishPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final dishRect = Rect.fromCircle(center: Offset(cx, cy + 12), radius: 9);
    canvas.drawArc(dishRect, 0.22 * math.pi, 0.56 * math.pi, false, dishPaint);

    final dishRod = Paint()..color = primaryColor..strokeWidth = 1.4;
    canvas.drawLine(Offset(cx, cy + 12), Offset(cx, cy + 17), dishRod);
    canvas.drawCircle(Offset(cx, cy + 17), 1.6, Paint()..color = primaryColor);
  }

  @override
  bool shouldRepaint(covariant _SatelliteFlightPainter oldDelegate) => true;
}

/// Lower Canvas: Earth Horizon and Houses of Residents Receiving Stable Internet
class _HomesGroundPainter extends CustomPainter {
  final double pulseProgress;
  final Color primaryColor;
  final Color accentColor;
  final bool isDark;

  _HomesGroundPainter({
    required this.pulseProgress,
    required this.primaryColor,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final earthY = h - 22.0;

    // 1. Earth Horizon Curve
    final earthPaint = Paint()
      ..color = primaryColor.withValues(alpha: isDark ? 0.20 : 0.12)
      ..style = PaintingStyle.fill;
    final earthPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, earthY + 12)
      ..quadraticBezierTo(cx, earthY - 8, w, earthY + 12)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(earthPath, earthPaint);

    final earthStroke = Paint()
      ..color = primaryColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final earthArc = Path()
      ..moveTo(0, earthY + 12)
      ..quadraticBezierTo(cx, earthY - 8, w, earthY + 12);
    canvas.drawPath(earthArc, earthStroke);

    // 2. Homes on Earth
    final wallPaint = Paint()
      ..color = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final roofPaint = Paint()..color = primaryColor;
    final accentPaint = Paint()..color = accentColor;
    final antennaStroke = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Left Home (House 1)
    final h1x = cx - 64;
    final h1y = earthY - 4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(h1x - 12, h1y - 16, 24, 18), const Radius.circular(2)),
      wallPaint,
    );
    final h1Roof = Path()
      ..moveTo(h1x - 15, h1y - 16)
      ..lineTo(h1x, h1y - 27)
      ..lineTo(h1x + 15, h1y - 16)
      ..close();
    canvas.drawPath(h1Roof, roofPaint);
    canvas.drawLine(Offset(h1x, h1y - 27), Offset(h1x, h1y - 34), antennaStroke);
    canvas.drawCircle(Offset(h1x, h1y - 34), 2.2, accentPaint);

    // Center Home (House 2 - Starlink Dish)
    final h2x = cx;
    final h2y = earthY - 7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(h2x - 16, h2y - 22, 32, 24), const Radius.circular(2.5)),
      wallPaint,
    );
    final h2Roof = Path()
      ..moveTo(h2x - 20, h2y - 22)
      ..lineTo(h2x, h2y - 36)
      ..lineTo(h2x + 20, h2y - 22)
      ..close();
    canvas.drawPath(h2Roof, roofPaint);

    // Door & Windows
    final doorPaint = Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(h2x - 4, h2y - 11, 8, 13), const Radius.circular(1.5)),
      doorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(h2x - 12, h2y - 17, 6, 6), const Radius.circular(1)),
      accentPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(h2x + 6, h2y - 17, 6, 6), const Radius.circular(1)),
      accentPaint,
    );

    // Dish Antenna on Roof
    final dishRect = Rect.fromCircle(center: Offset(h2x + 8, h2y - 38), radius: 6);
    canvas.drawArc(dishRect, 1.2 * math.pi, 0.7 * math.pi, false, antennaStroke);
    canvas.drawLine(Offset(h2x + 8, h2y - 34), Offset(h2x + 8, h2y - 28), antennaStroke);
    canvas.drawCircle(Offset(h2x + 8, h2y - 40), 2.8, accentPaint);

    // Right Home (House 3)
    final h3x = cx + 64;
    final h3y = earthY - 4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(h3x - 13, h3y - 17, 26, 19), const Radius.circular(2)),
      wallPaint,
    );
    final h3Roof = Path()
      ..moveTo(h3x - 16, h3y - 17)
      ..lineTo(h3x + 16, h3y - 28)
      ..lineTo(h3x + 16, h3y - 17)
      ..close();
    canvas.drawPath(h3Roof, roofPaint);
    canvas.drawLine(Offset(h3x + 12, h3y - 28), Offset(h3x + 12, h3y - 35), antennaStroke);
    canvas.drawCircle(Offset(h3x + 12, h3y - 35), 2.2, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _HomesGroundPainter oldDelegate) => true;
}
