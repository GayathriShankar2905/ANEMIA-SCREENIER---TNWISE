import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

// ══════════════════════════════════════════════════════════════════
//  HemoScan — Login Screen
//  Design: Deep navy cosmos, teal ECG, floating particle nodes,
//          glassmorphism card, animated entry
// ══════════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // Animations
  late final AnimationController _bgCtrl;
  late final AnimationController _ecgCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;

  // Entry anims
  late final Animation<double>  _fadeCard;
  late final Animation<Offset>  _slideCard;
  late final Animation<double>  _fadeLogo;
  late final Animation<double>  _fadeText;
  late final Animation<double>  _fadeBtn;
  late final Animation<double>  _pulse;

  bool    _loading = false;
  String? _error;

  // Palette
  static const bg0    = Color(0xFF050D1A);
  static const bg1    = Color(0xFF0A1628);
  static const teal   = Color(0xFF00D4C8);
  static const tealDk = Color(0xFF00A89E);
  static const white  = Color(0xFFF0F8FF);
  static const slate  = Color(0xFF7A9BBE);
  static const red    = Color(0xFFFF4D6A);

  @override
  void initState() {
    super.initState();

    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    _ecgCtrl   = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse     = Tween<double>(begin: 0.94, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _fadeLogo  = _iv(0.00, 0.35, Curves.easeOut);
    _slideCard = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(_iv(0.20, 0.65, Curves.easeOutCubic));
    _fadeCard  = _iv(0.20, 0.60, Curves.easeOut);
    _fadeText  = _iv(0.40, 0.75, Curves.easeOut);
    _fadeBtn   = _iv(0.60, 1.00, Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  Animation<double> _iv(double b, double e, Curve c) => CurvedAnimation(
    parent: _entryCtrl, curve: Interval(b, e, curve: c));

  @override
  void dispose() {
    _bgCtrl.dispose(); _ecgCtrl.dispose(); _pulseCtrl.dispose(); _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = await AuthService.signInWithGoogle();
      if (user == null && mounted) setState(() { _loading = false; _error = 'Sign-in cancelled.'; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Authentication failed. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: bg0,
      body: Stack(children: [
        // ── Starfield + blobs ──
        _CosmosBackground(bgCtrl: _bgCtrl, size: size),
        // ── ECG line across screen ──
        Positioned(bottom: size.height * 0.32, left: 0, right: 0,
          child: SizedBox(height: 60,
            child: AnimatedBuilder(animation: _ecgCtrl,
              builder: (_, __) => CustomPaint(
                painter: _FullEcgPainter(_ecgCtrl.value, teal.withOpacity(0.18)),
                child: const SizedBox.expand())))),

        // ── Main content ──
        SafeArea(child: Column(children: [
          const Spacer(flex: 2),

          // Logo
          FadeTransition(opacity: _fadeLogo,
            child: AnimatedBuilder(animation: _pulse,
              builder: (_, __) => Transform.scale(scale: _pulse.value,
                child: _LogoMark()))),

          const SizedBox(height: 28),

          // Glass card
          SlideTransition(position: _slideCard,
            child: FadeTransition(opacity: _fadeCard,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _GlassCard(child: Column(children: [

                  // Title
                  FadeTransition(opacity: _fadeText, child: Column(children: [
                    Text('HemoScan',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 36, fontWeight: FontWeight.w900,
                        color: white, letterSpacing: -0.5,
                        shadows: [Shadow(color: teal.withOpacity(0.5), blurRadius: 20)])),
                    const SizedBox(height: 6),
                    Text('Clinical Anemia Screening',
                      style: GoogleFonts.dmSans(fontSize: 13, color: slate, letterSpacing: 2,
                        fontWeight: FontWeight.w500)),
                    const SizedBox(height: 20),
                    // Divider with teal glow
                    Container(height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent, teal.withOpacity(0.6), Colors.transparent]))),
                    const SizedBox(height: 20),
                    Text('Non-invasive hemoglobin estimation\nusing smartphone camera & optical sensor',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 13, color: slate, height: 1.6)),
                  ])),

                  const SizedBox(height: 28),

                  // Feature pills row
                  FadeTransition(opacity: _fadeText,
                    child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,
                      children: const [
                        _Pill('💅  Nail Analysis'),
                        _Pill('🤚  Palm Color'),
                        _Pill('📡  ESP32 Sensor'),
                        _Pill('📊  Risk Report'),
                      ])),

                  const SizedBox(height: 28),

                  // Error
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: red.withOpacity(0.35))),
                      child: Row(children: [
                        Icon(Icons.error_outline_rounded, color: red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!,
                          style: GoogleFonts.dmSans(fontSize: 12, color: red))),
                      ])),

                  // Google button
                  FadeTransition(opacity: _fadeBtn,
                    child: _GoogleSignInButton(loading: _loading, onTap: _signIn)),

                  const SizedBox(height: 14),
                  FadeTransition(opacity: _fadeBtn,
                    child: Text('Secured by Firebase Authentication',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 10, color: slate.withOpacity(0.6)))),
                ])),
              ))),

          const Spacer(flex: 3),

          // Bottom disclaimer
          FadeTransition(opacity: _fadeBtn,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
              child: Text('Screening tool only · Not a medical device · TNWiSE Hackathon 2025',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 10,
                  color: slate.withOpacity(0.4), letterSpacing: 0.3)))),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  COSMOS BACKGROUND — animated radial blobs + particle dots
// ══════════════════════════════════════════════════════════════════
class _CosmosBackground extends StatelessWidget {
  final AnimationController bgCtrl;
  final Size size;
  const _CosmosBackground({required this.bgCtrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, __) {
        final t = bgCtrl.value * 2 * math.pi;
        return Stack(children: [
          // Top-right blob
          Positioned(
            right: -60 + math.cos(t * 0.4) * 30,
            top:   -80 + math.sin(t * 0.3) * 25,
            child: Container(width: size.width * 0.85, height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF00D4C8).withOpacity(0.12),
                  Colors.transparent])))),
          // Bottom-left blob
          Positioned(
            left: -80 + math.cos(t * 0.5 + 1) * 20,
            bottom: size.height * 0.05 + math.sin(t * 0.4) * 15,
            child: Container(width: size.width * 0.70, height: size.width * 0.70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF0A4FFF).withOpacity(0.09),
                  Colors.transparent])))),
          // Star particles
          CustomPaint(painter: _StarfieldPainter(bgCtrl.value),
            child: const SizedBox.expand()),
        ]);
      },
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final double t;
  static final _rng = math.Random(42);
  static final _stars = List.generate(55, (_) => Offset(_rng.nextDouble(), _rng.nextDouble()));
  static final _sizes = List.generate(55, (_) => _rng.nextDouble() * 1.8 + 0.4);

  const _StarfieldPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _stars.length; i++) {
      final opacity = (math.sin(t * 2 * math.pi + i * 0.7) * 0.3 + 0.4).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(_stars[i].dx * size.width, _stars[i].dy * size.height),
        _sizes[i],
        Paint()..color = const Color(0xFF7AB8FF).withOpacity(opacity * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════
//  FULL-WIDTH ECG PAINTER
// ══════════════════════════════════════════════════════════════════
class _FullEcgPainter extends CustomPainter {
  final double t;
  final Color color;
  const _FullEcgPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const pts = 200;
    for (int i = 0; i < pts; i++) {
      final x = (i / pts) * size.width;
      final phase = ((i / pts) * 2.5 + t) % 1.0;
      double y = size.height / 2;
      if (phase < 0.06)       y = size.height/2 - math.sin(phase/0.06*math.pi)*size.height*0.08;
      else if (phase < 0.13)  y = size.height/2;
      else if (phase < 0.16)  y = size.height/2 + size.height*0.12;
      else if (phase < 0.20)  y = size.height/2 - size.height*0.48;
      else if (phase < 0.24)  y = size.height/2 + size.height*0.20;
      else if (phase < 0.36)  y = size.height/2 - math.sin((phase-0.24)/0.12*math.pi)*size.height*0.14;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FullEcgPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════
//  LOGO MARK
// ══════════════════════════════════════════════════════════════════
class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
    Container(width: 120, height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          const Color(0xFF00D4C8).withOpacity(0.20),
          Colors.transparent]))),
    Container(width: 86, height: 86,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4C8), Color(0xFF00A89E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00D4C8).withOpacity(0.5),
            blurRadius: 32, offset: const Offset(0, 8))]),
      child: const Center(child: Text('🩸', style: TextStyle(fontSize: 38)))),
  ]);
}

// ══════════════════════════════════════════════════════════════════
//  GLASS CARD
// ══════════════════════════════════════════════════════════════════
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1628).withOpacity(0.92),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFF00D4C8).withOpacity(0.18), width: 1),
      boxShadow: [
        BoxShadow(color: const Color(0xFF00D4C8).withOpacity(0.08),
          blurRadius: 40, spreadRadius: 0),
        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 12)),
      ]),
    child: child,
  );
}

// ══════════════════════════════════════════════════════════════════
//  FEATURE PILL
// ══════════════════════════════════════════════════════════════════
class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF00D4C8).withOpacity(0.08),
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: const Color(0xFF00D4C8).withOpacity(0.25))),
    child: Text(text,
      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600,
        color: const Color(0xFF00D4C8))),
  );
}

// ══════════════════════════════════════════════════════════════════
//  GOOGLE SIGN-IN BUTTON
// ══════════════════════════════════════════════════════════════════
class _GoogleSignInButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.loading, required this.onTap});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF00D4C8).withOpacity(0.15),
                const Color(0xFF00A89E).withOpacity(0.08)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00D4C8).withOpacity(0.40), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00D4C8).withOpacity(0.15),
                  blurRadius: 20, offset: const Offset(0, 6))]),
            child: widget.loading
              ? const Center(child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00D4C8), strokeWidth: 2.5, strokeCap: StrokeCap.round)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CustomPaint(size: const Size(22, 22), painter: _GoogleGPainter()),
                  const SizedBox(width: 12),
                  Text('Continue with Google',
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700,
                      color: const Color(0xFFF0F8FF))),
                ]),
          ),
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width/2, s.height/2);
    final r = s.width/2;
    final arc = Paint()..style = PaintingStyle.stroke..strokeWidth = s.width*0.155..strokeCap = StrokeCap.butt;
    final rect = Rect.fromCircle(center: c, radius: r*0.72);
    arc.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi/2, math.pi/2, false, arc);
    arc.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi*1.5, -math.pi/2, false, arc);
    arc.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi, math.pi/2, false, arc);
    arc.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi/2, math.pi/2, false, arc);
    canvas.drawRect(
      Rect.fromLTWH(c.dx-0.5, c.dy-s.height*0.13, r*0.82, s.height*0.265),
      Paint()..color = const Color(0xFF4285F4));
    canvas.drawCircle(c, r*0.44, Paint()..color = const Color(0xFF0A1628));
  }
  @override bool shouldRepaint(_) => false;
}