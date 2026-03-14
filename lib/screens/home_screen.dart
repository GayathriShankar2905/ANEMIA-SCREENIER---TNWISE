import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/scan_provider.dart';
import '../services/auth_service.dart';
import 'nail_capture_screen.dart';
import 'palm_capture_screen.dart';
import 'conjunctiva_capture_screen.dart';
import 'result_screen.dart';
import 'esp32_screen.dart';

// ══════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — Clinical Dark  (Zero emojis)
// ══════════════════════════════════════════════════════════════════
class D {
  static const bg0    = Color(0xFF050D1A);
  static const bg1    = Color(0xFF0A1628);
  static const bg2    = Color(0xFF0F1E36);
  static const bg3    = Color(0xFF162440);
  static const teal   = Color(0xFF00D4C8);
  static const tealDk = Color(0xFF00A89E);
  static const green  = Color(0xFF22D47A);
  static const amber  = Color(0xFFFFB547);
  static const red    = Color(0xFFFF4D6A);
  static const blue   = Color(0xFF4D9EFF);
  static const purp   = Color(0xFFB47FFF);
  static const text1  = Color(0xFFF0F8FF);
  static const text2  = Color(0xFF7A9BBE);
  static const text3  = Color(0xFF3D5A7A);
  static const bdr    = Color(0xFF1A2E4A);
}

BoxDecoration _cardDeco({Color? border, double r = 20}) => BoxDecoration(
  color: D.bg1,
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: border ?? D.bdr, width: 1),
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 5))],
);

// ══════════════════════════════════════════════════════════════════
//  HOME SCREEN SHELL
// ══════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _ecgCtrl;
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _ecgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ecgCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    return Scaffold(
      backgroundColor: D.bg0,
      body: IndexedStack(index: _tab, children: [
        _DashPage(ecgCtrl: _ecgCtrl, dotCtrl: _dotCtrl, onTab: (i) => setState(() => _tab = i)),
        _ScanPage(onTab: (i) => setState(() => _tab = i)),
        scan.result == null
          ? _EmptyReports(onScan: () => setState(() => _tab = 1))
          : ResultScreen(
              result: scan.result!,
              onNewScan: () { scan.reset(); setState(() => _tab = 1); }),
        const ESP32Screen(),
      ]),
      bottomNavigationBar: _NavBar(tab: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  DASHBOARD PAGE
// ══════════════════════════════════════════════════════════════════
class _DashPage extends StatelessWidget {
  final AnimationController ecgCtrl, dotCtrl;
  final ValueChanged<int> onTab;
  const _DashPage({required this.ecgCtrl, required this.dotCtrl, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'Clinician';

    return SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ───────────────────────────────────────
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clinical Dashboard  ·  $name',
              style: GoogleFonts.dmSans(fontSize: 12, color: D.text2, letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text('HemoScan AI', style: GoogleFonts.playfairDisplay(
              fontSize: 27, fontWeight: FontWeight.w900, color: D.text1,
              shadows: [Shadow(color: D.teal.withOpacity(0.35), blurRadius: 16)])),
          ])),
          _AvatarButton(user: user),
        ]),
        const SizedBox(height: 20),

        // ── Vitals row ───────────────────────────────────
        Row(children: [
          Expanded(child: _HrCard(ecgCtrl: ecgCtrl, dotCtrl: dotCtrl, scan: scan)),
          const SizedBox(width: 12),
          Expanded(child: _Spo2Card(scan: scan)),
        ]),
        const SizedBox(height: 22),

        // ── Project description banner ───────────────────
        _ProjectBanner(),
        const SizedBox(height: 22),

        // ── Analysis modules ─────────────────────────────
        _SectionLabel('ANALYSIS MODULES'),
        const SizedBox(height: 14),
        _ModuleGrid(onTab: onTab, ctx: context),
        const SizedBox(height: 22),

        // ── Session status ───────────────────────────────
        _SectionLabel('SESSION STATUS'),
        const SizedBox(height: 12),
        _SessionStatus(scan: scan),
        const SizedBox(height: 20),

        // ── Medical Disclaimer ───────────────────────────
        _Disclaimer(),
      ]),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════
//  PROJECT DESCRIPTION BANNER
//  Left half: title + description + badge
//  Right half: local asset image with shimmer scan-line effect
//              + hover tooltip that types project name
// ══════════════════════════════════════════════════════════════════
class _ProjectBanner extends StatefulWidget {
  @override
  State<_ProjectBanner> createState() => _ProjectBannerState();
}

class _ProjectBannerState extends State<_ProjectBanner> with TickerProviderStateMixin {
  // Scan line sweeping over image
  late final AnimationController _scanCtrl;
  late final Animation<double>   _scanAnim;

  // Hover typing effect
  late final AnimationController _typeCtrl;
  late final Animation<int>      _typeAnim;
  bool _hovered = false;

  static const _typeText = 'HemoScan Clinical AI';

  @override
  void initState() {
    super.initState();

    _scanCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))..repeat();
    _scanAnim = CurvedAnimation(parent: _scanCtrl, curve: Curves.linear);

    _typeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
    _typeAnim = IntTween(begin: 0, end: _typeText.length)
        .animate(CurvedAnimation(parent: _typeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _onHover(bool hovering) {
    setState(() => _hovered = hovering);
    if (hovering) {
      _typeCtrl.forward(from: 0);
    } else {
      _typeCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter:  (_) => _onHover(true),
      onExit:   (_) => _onHover(false),
      // On mobile: GestureDetector toggle
      child: GestureDetector(
        onTapDown: (_) => _onHover(true),
        onTapUp:   (_) => _onHover(false),
        onTapCancel: () => _onHover(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 170,
          decoration: BoxDecoration(
            color: D.bg1,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hovered ? D.teal.withOpacity(0.50) : D.bdr,
              width: 1),
            boxShadow: [
              BoxShadow(
                color: _hovered
                  ? D.teal.withOpacity(0.12)
                  : Colors.black.withOpacity(0.35),
                blurRadius: _hovered ? 28 : 16,
                offset: const Offset(0, 5)),
            ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Row(children: [

              // ── LEFT HALF: text content ───────────────
              Expanded(child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Typing effect label shown on hover
                    AnimatedBuilder(
                      animation: _typeAnim,
                      builder: (_, __) {
                        final displayed = _typeText.substring(0, _typeAnim.value);
                        return AnimatedOpacity(
                          opacity: _hovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(displayed,
                                style: GoogleFonts.sourceCodePro(
                                  fontSize: 10, color: D.teal,
                                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                              // Blinking cursor
                              AnimatedOpacity(
                                opacity: _hovered ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  width: 1.5, height: 11,
                                  margin: const EdgeInsets.only(left: 1),
                                  color: D.teal)),
                            ]));
                      }),
                    const SizedBox(height: 3),

                    // Project tag line
                    Text('HEMOSCAN PROJECT',
                      style: GoogleFonts.dmSans(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: D.teal, letterSpacing: 1.5)),
                    const SizedBox(height: 5),

                    // Title
                    Text('Non-Invasive\nAnemia Diagnostics',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: D.text1, height: 1.15)),
                    const SizedBox(height: 10),

                    // Description
                    Text(
                      'Multi-modal pallor analysis via palpebral conjunctiva, nail bed, and palmar chrominance indices.',
                      style: GoogleFonts.dmSans(
                        fontSize: 10, color: D.text2, height: 1.55)),
                    const SizedBox(height: 12),

                    // Badge row
                    Row(children: [
                      _SmallBadge('Firebase Auth', Icons.verified_user_outlined, D.blue),
                      const SizedBox(width: 6),
                      _SmallBadge('ESP32 Sensor', Icons.sensors, D.teal),
                    ]),
                  ],
                ),
              )),

              // ── RIGHT HALF: asset image + scan-line ──
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.40,
                child: Stack(fit: StackFit.expand, children: [

                  // Asset image
                  // ASSET PATH: assets/images/doctor_patient.jpg
                  // Place your image at: anemia_app/assets/images/doctor_patient.jpg
                  // Add to pubspec.yaml under flutter > assets:
                  //   - assets/images/doctor_patient.jpg
                  Image.asset(
                    'assets/images/doctor_patient.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _ImagePlaceholder(),
                  ),

                  // Dark gradient overlay — left fade blending into card
                  DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [D.bg1, D.bg1.withOpacity(0.45), Colors.transparent],
                      stops: const [0.0, 0.25, 1.0]))),

                  // Top & bottom dark vignette
                  DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        D.bg1.withOpacity(0.55),
                        Colors.transparent,
                        Colors.transparent,
                        D.bg1.withOpacity(0.55)]))),

                  // Animated scan line
                  AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (_, __) {
                      return CustomPaint(
                        painter: _ScanLinePainter(_scanAnim.value, D.teal));
                    }),

                  // Corner HUD brackets
                  Positioned(top: 8, right: 8,
                    child: _HudCorner(D.teal.withOpacity(0.60))),
                  Positioned(bottom: 8, left: 8,
                    child: Transform.rotate(angle: math.pi,
                      child: _HudCorner(D.teal.withOpacity(0.40)))),

                  // "LIVE SCAN" badge — only when hovered
                  if (_hovered)
                    Positioned(top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: D.teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: D.teal.withOpacity(0.45))),
                        child: Text('CLINICAL VIEW',
                          style: GoogleFonts.dmSans(
                            fontSize: 8, fontWeight: FontWeight.w800,
                            color: D.teal, letterSpacing: 1.2)))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Scan-line painter ─────────────────────────────────────
class _ScanLinePainter extends CustomPainter {
  final double t;
  final Color color;
  const _ScanLinePainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final y = t * size.height;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.transparent, color.withOpacity(0.55), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawRect(Rect.fromLTWH(0, y - 1.5, size.width, 3), paint);

    // Bright leading edge
    final edgePaint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), edgePaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter o) => o.t != t;
}

// ── HUD corner bracket ────────────────────────────────────
class _HudCorner extends StatelessWidget {
  final Color color;
  const _HudCorner(this.color);
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(14, 14),
    painter: _HudCornerPainter(color));
}

class _HudCornerPainter extends CustomPainter {
  final Color color;
  const _HudCornerPainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset.zero, Offset(s.width, 0), p);
    canvas.drawLine(Offset.zero, Offset(0, s.height), p);
  }
  @override bool shouldRepaint(_) => false;
}

// ── Image placeholder (shown if asset not yet added) ─────
class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: D.bg2,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.medical_services_outlined, color: D.teal.withOpacity(0.4), size: 32),
      const SizedBox(height: 8),
      Text('Add image to\nassets/images/',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(fontSize: 10, color: D.text3, height: 1.4)),
    ])));
}

// ── Small badge ───────────────────────────────────────────
class _SmallBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SmallBadge(this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.dmSans(
        fontSize: 9, fontWeight: FontWeight.w700,
        color: color, letterSpacing: 0.3)),
    ]));
}

// ══════════════════════════════════════════════════════════════════
//  ANALYSIS MODULE GRID  — 2×2 grid, clinical names, no emojis
// ══════════════════════════════════════════════════════════════════
class _ModuleGrid extends StatelessWidget {
  final ValueChanged<int> onTab;
  final BuildContext ctx;
  const _ModuleGrid({required this.onTab, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Mod(
        icon:  Icons.remove_red_eye_outlined,
        label: 'Palpebral Conjunctiva\nPallor Analysis',
        sub:   '35 pts · Highest accuracy',
        color: D.purp,
        action: () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => const ConjunctivaCaptureScreen())),
      ),
      _Mod(
        icon:  Icons.back_hand_outlined,
        label: 'Nail Bed Pallor\nDetection',
        sub:   '30 pts · Validated index',
        color: D.green,
        action: () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => const NailCaptureScreen())),
      ),
      _Mod(
        icon:  Icons.front_hand_outlined,
        label: 'Palmar Pallor\nAnalysis',
        sub:   '25 pts · Chrominance',
        color: D.amber,
        action: () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => const PalmCaptureScreen())),
      ),
      _Mod(
        icon:  Icons.settings_input_component_outlined,
        label: 'Hardware System\n(ESP32 + MAX30105)',
        sub:   '45 pts · HR & SpO₂',
        color: D.teal,
        action: () => onTab(3),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: items.map((m) => _ModuleCard(m: m)).toList(),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final _Mod m;
  const _ModuleCard({required this.m});
  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); m.action(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: D.bg1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: m.color.withOpacity(0.22)),
              boxShadow: [
                BoxShadow(color: m.color.withOpacity(0.06), blurRadius: 16),
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: m.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: m.color.withOpacity(0.20))),
                    child: Icon(m.icon, color: m.color, size: 18)),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: D.text3),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.label,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: D.text1, height: 1.3)),
                  const SizedBox(height: 3),
                  Text(m.sub,
                    style: GoogleFonts.dmSans(fontSize: 9, color: m.color, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mod {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback action;
  const _Mod({required this.icon, required this.label, required this.sub,
    required this.color, required this.action});
}

// ══════════════════════════════════════════════════════════════════
//  VITALS CARDS
// ══════════════════════════════════════════════════════════════════
class _HrCard extends StatelessWidget {
  final AnimationController ecgCtrl, dotCtrl;
  final ScanProvider scan;
  const _HrCard({required this.ecgCtrl, required this.dotCtrl, required this.scan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDeco(border: D.red.withOpacity(0.18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('HEART RATE', style: GoogleFonts.dmSans(
          fontSize: 9, fontWeight: FontWeight.w800, color: D.text2, letterSpacing: 1)),
        AnimatedBuilder(animation: dotCtrl, builder: (_, __) => Icon(
          Icons.favorite_rounded, size: 13,
          color: scan.sensorLive
            ? D.red.withOpacity(0.4 + dotCtrl.value * 0.6)
            : D.text3)),
      ]),
      const SizedBox(height: 10),
      Text(scan.hr != null ? '${scan.hr!.toInt()}' : '--',
        style: GoogleFonts.dmSans(fontSize: 30, fontWeight: FontWeight.w900, color: D.text1)),
      Text('BPM', style: GoogleFonts.dmSans(fontSize: 9, color: D.text3, letterSpacing: 1)),
      const SizedBox(height: 10),
      SizedBox(height: 32, child: AnimatedBuilder(
        animation: ecgCtrl,
        builder: (_, __) => CustomPaint(
          painter: _EcgPainter(ecgCtrl.value, D.red),
          child: const SizedBox.expand()))),
      if (scan.hrAbnormal)
        _StatusChip('Elevated', D.red),
    ]));
}

class _Spo2Card extends StatelessWidget {
  final ScanProvider scan;
  const _Spo2Card({required this.scan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDeco(border: D.blue.withOpacity(0.18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('OXYGEN SAT.', style: GoogleFonts.dmSans(
        fontSize: 9, fontWeight: FontWeight.w800, color: D.text2, letterSpacing: 1)),
      const SizedBox(height: 10),
      Text(scan.spo2 != null ? '${scan.spo2!.toInt()}' : '--',
        style: GoogleFonts.dmSans(fontSize: 30, fontWeight: FontWeight.w900, color: D.text1)),
      Text('% SpO₂', style: GoogleFonts.dmSans(fontSize: 9, color: D.text3, letterSpacing: 1)),
      const SizedBox(height: 10),
      Stack(children: [
        Container(height: 5,
          decoration: BoxDecoration(color: D.bg3, borderRadius: BorderRadius.circular(3))),
        FractionallySizedBox(
          widthFactor: scan.spo2 != null ? (scan.spo2! / 100).clamp(0, 1) : 0,
          child: Container(height: 5,
            decoration: BoxDecoration(
              color: scan.spo2Abnormal ? D.red : D.blue,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [BoxShadow(
                color: (scan.spo2Abnormal ? D.red : D.blue).withOpacity(0.5),
                blurRadius: 6)]))),
      ]),
      if (scan.spo2Abnormal) ...[
        const SizedBox(height: 6),
        _StatusChip('Below Normal', D.red),
      ],
    ]));
}

Widget _StatusChip(String text, Color c) => Container(
  margin: const EdgeInsets.only(top: 4),
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
  decoration: BoxDecoration(
    color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
    border: Border.all(color: c.withOpacity(0.30))),
  child: Text(text, style: GoogleFonts.dmSans(
    fontSize: 9, fontWeight: FontWeight.w800, color: c)));

// ══════════════════════════════════════════════════════════════════
//  SESSION STATUS
// ══════════════════════════════════════════════════════════════════
class _SessionStatus extends StatelessWidget {
  final ScanProvider scan;
  const _SessionStatus({required this.scan});

  @override
  Widget build(BuildContext context) {
    final wsOk  = scan.wsStatus == 'connected';
    final wsBusy = scan.wsStatus == 'connecting';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(children: [
        _StatusRow(
          icon:   Icons.sensors_rounded,
          label:  'Hardware Link (ESP32 + MAX30105)',
          value:  wsOk ? 'Connected' : wsBusy ? 'Connecting…' : 'Offline',
          color:  wsOk ? D.green : wsBusy ? D.amber : D.text3),
        _divider(),
        _StatusRow(
          icon:   Icons.remove_red_eye_outlined,
          label:  'Palpebral Conjunctiva Pallor Analysis',
          value:  scan.conjunctivaData != null ? 'Captured' : 'Pending',
          color:  scan.conjunctivaData != null ? D.green : D.text3),
        _divider(),
        _StatusRow(
          icon:   Icons.back_hand_outlined,
          label:  'Nail Bed Pallor Detection',
          value:  scan.nailData != null ? 'Captured' : 'Pending',
          color:  scan.nailData != null ? D.green : D.text3),
        _divider(),
        _StatusRow(
          icon:   Icons.front_hand_outlined,
          label:  'Palmar Pallor Analysis',
          value:  scan.palmData != null ? 'Captured' : 'Pending',
          color:  scan.palmData != null ? D.green : D.text3),
      ]));
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 11),
    child: Divider(color: D.bdr, height: 1));
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatusRow({required this.icon, required this.label,
    required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: D.text3),
    const SizedBox(width: 10),
    Expanded(child: Text(label,
      style: GoogleFonts.dmSans(fontSize: 11, color: D.text2))),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
      child: Text(value, style: GoogleFonts.dmSans(
        fontSize: 10, fontWeight: FontWeight.w800, color: color))),
  ]);
}

// ══════════════════════════════════════════════════════════════════
//  MEDICAL DISCLAIMER
// ══════════════════════════════════════════════════════════════════
class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: D.amber.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: D.amber.withOpacity(0.20))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline_rounded, size: 14, color: D.amber.withOpacity(0.80)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MEDICAL DISCLAIMER',
          style: GoogleFonts.dmSans(
            fontSize: 8, fontWeight: FontWeight.w900,
            color: D.amber, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(
          'HemoScan is a non-invasive screening tool and does not constitute a medical diagnosis. '
          'Results must not replace a complete blood count (CBC) laboratory test or evaluation by a qualified physician. '
          'Developed for academic research — TNWiSE Hackathon 2025.',
          style: GoogleFonts.dmSans(
            fontSize: 10, color: D.text2, height: 1.6)),
      ])),
    ]));
}

// ══════════════════════════════════════════════════════════════════
//  SCAN PAGE  (Step-by-step modules)
// ══════════════════════════════════════════════════════════════════
class _ScanPage extends StatelessWidget {
  final ValueChanged<int> onTab;
  const _ScanPage({required this.onTab});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    return SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('New Scan', style: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w900, color: D.text1)),
        const SizedBox(height: 4),
        Text('Complete all modules for maximum diagnostic accuracy.',
          style: GoogleFonts.dmSans(fontSize: 12, color: D.text2)),
        const SizedBox(height: 24),

        _StepCard(
          num: '01',
          title: 'Hardware System',
          subtitle: 'Connect ESP32 + MAX30105 optical sensor for live heart rate and arterial oxygen saturation.',
          icon: Icons.settings_input_component_outlined,
          color: D.teal,
          done: scan.sensorLive,
          onTap: () => onTab(3),
          trailing: scan.hr != null ? Row(children: [
            _Tag('HR  ${scan.hr!.toInt()} BPM', D.red),
            const SizedBox(width: 8),
            _Tag('SpO₂  ${scan.spo2?.toInt() ?? '--'} %', D.blue),
          ]) : null),
        const SizedBox(height: 12),

        _StepCard(
          num: '02',
          title: 'Palpebral Conjunctiva Pallor Analysis',
          subtitle: 'Photograph the inner lower eyelid. Redness ratio is the most clinically reliable non-invasive anemia indicator.',
          icon: Icons.remove_red_eye_outlined,
          color: D.purp,
          done: scan.conjunctivaData != null,
          badge: 'HIGHEST ACCURACY · 35 pts',
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ConjunctivaCaptureScreen())),
          trailing: scan.conjunctivaData != null
            ? _ConjunctivaInline(scan.conjunctivaData!) : null),
        const SizedBox(height: 12),

        _StepCard(
          num: '03',
          title: 'Nail Bed Pallor Detection',
          subtitle: 'Position ROI markers on each fingernail bed to extract mean chrominance for pallor index scoring.',
          icon: Icons.back_hand_outlined,
          color: D.green,
          done: scan.nailData != null,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const NailCaptureScreen())),
          trailing: scan.nailData != null ? _RoiColorRow(scan.nailData!, 4) : null),
        const SizedBox(height: 12),

        _StepCard(
          num: '04',
          title: 'Palmar Pallor Analysis',
          subtitle: 'Sample thenar and hypothenar eminence regions for palmar crease redness ratio analysis.',
          icon: Icons.front_hand_outlined,
          color: D.amber,
          done: scan.palmData != null,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const PalmCaptureScreen())),
          trailing: scan.palmData != null ? _RoiColorRow(scan.palmData!, 3) : null),
        const SizedBox(height: 32),

        // Analyze CTA
        GestureDetector(
          onTap: scan.canAnalyze ? () { scan.analyze(); onTab(2); } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: scan.canAnalyze
                ? LinearGradient(colors: [D.teal, D.tealDk])
                : null,
              color: scan.canAnalyze ? null : D.bg2,
              borderRadius: BorderRadius.circular(18),
              boxShadow: scan.canAnalyze
                ? [BoxShadow(color: D.teal.withOpacity(0.40),
                    blurRadius: 24, offset: const Offset(0, 8))]
                : []),
            child: Center(child: Text(
              scan.canAnalyze
                ? 'Compute Anemia Risk Score'
                : 'Complete at least one module to proceed',
              style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: scan.canAnalyze ? Colors.white : D.text3,
                letterSpacing: 0.2))))),
      ]),
    ));
  }
}

// ── Step Card ──────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String num, title, subtitle;
  final IconData icon;
  final Color color;
  final bool done;
  final String? badge;
  final Widget? trailing;
  final VoidCallback onTap;
  const _StepCard({required this.num, required this.title, required this.subtitle,
    required this.icon, required this.color, required this.done,
    required this.onTap, this.badge, this.trailing});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: D.bg1, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: done ? color.withOpacity(0.28) : D.bdr),
        boxShadow: [BoxShadow(
          color: done ? color.withOpacity(0.05) : Colors.black38,
          blurRadius: 14, offset: const Offset(0, 4))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.20))),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$num.  ', style: GoogleFonts.dmSans(
              fontSize: 11, color: D.text3, fontWeight: FontWeight.w600)),
            Expanded(child: Text(title, style: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w800, color: D.text1))),
            _DoneChip(done, color),
          ]),
          if (badge != null && !done) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(5)),
              child: Text(badge!, style: GoogleFonts.dmSans(
                fontSize: 8, fontWeight: FontWeight.w800,
                color: color, letterSpacing: 0.8))),
          ],
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.dmSans(
            fontSize: 10, color: D.text2, height: 1.5)),
          if (trailing != null) ...[const SizedBox(height: 8), trailing!],
        ])),
      ])));
}

Widget _DoneChip(bool done, Color c) => done
  ? Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: D.green.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: D.green.withOpacity(0.30))),
      child: Text('Captured', style: GoogleFonts.dmSans(
        fontSize: 9, fontWeight: FontWeight.w800, color: D.green)))
  : Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.25))),
      child: Text('Tap to scan', style: GoogleFonts.dmSans(
        fontSize: 9, fontWeight: FontWeight.w600, color: c)));

Widget _Tag(String t, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(
    color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
    border: Border.all(color: c.withOpacity(0.28))),
  child: Text(t, style: GoogleFonts.dmSans(
    fontSize: 10, fontWeight: FontWeight.w700, color: c)));

class _RoiColorRow extends StatelessWidget {
  final List<ROIResult> data;
  final int max;
  const _RoiColorRow(this.data, this.max);
  @override
  Widget build(BuildContext context) => Row(children: [
    for (int i = 0; i < data.length && i < max; i++)
      Container(width: 18, height: 18, margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: data[i].color, shape: BoxShape.circle,
          border: Border.all(color: D.bdr),
          boxShadow: [BoxShadow(color: data[i].color.withOpacity(0.5), blurRadius: 5)])),
    const SizedBox(width: 6),
    Text('chrominance extracted',
      style: GoogleFonts.dmSans(fontSize: 9, color: D.text3)),
  ]);
}

class _ConjunctivaInline extends StatelessWidget {
  final List<ROIResult> data;
  const _ConjunctivaInline(this.data);
  @override
  Widget build(BuildContext context) {
    final ratio = data.map((r) => r.redness).reduce((a,b) => a+b) / data.length;
    final grade = ratio >= 0.43 ? 'No Pallor'
                : ratio >= 0.38 ? 'Mild Pallor'
                : ratio >= 0.32 ? 'Moderate Pallor'
                : 'Severe Pallor';
    final c     = ratio >= 0.43 ? D.green
                : ratio >= 0.38 ? D.amber
                : ratio >= 0.32 ? const Color(0xFFF97316)
                : D.red;
    return Row(children: [
      Container(width: 16, height: 16,
        decoration: BoxDecoration(
          color: data.first.color, shape: BoxShape.circle,
          border: Border.all(color: D.bdr),
          boxShadow: [BoxShadow(color: data.first.color.withOpacity(0.5), blurRadius: 5)])),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.28))),
        child: Text(grade, style: GoogleFonts.dmSans(
          fontSize: 10, fontWeight: FontWeight.w800, color: c))),
      const SizedBox(width: 8),
      Text('ratio ${ratio.toStringAsFixed(3)}',
        style: GoogleFonts.dmSans(fontSize: 9, color: D.text3)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//  AVATAR WITH PROFILE SHEET
// ══════════════════════════════════════════════════════════════════
class _AvatarButton extends StatelessWidget {
  final User? user;
  const _AvatarButton({required this.user});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _showSheet(context),
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: D.bg3, borderRadius: BorderRadius.circular(13),
        border: Border.all(color: D.teal.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: D.teal.withOpacity(0.15), blurRadius: 10)]),
      child: user?.photoURL != null
        ? ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.network(user!.photoURL!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: D.teal, size: 20)))
        : const Icon(Icons.person, color: D.teal, size: 20)));

  void _showSheet(BuildContext ctx) => showModalBottomSheet(
    context: ctx, backgroundColor: Colors.transparent,
    builder: (_) => _ProfileSheet(user: user));
}

class _ProfileSheet extends StatelessWidget {
  final User? user;
  const _ProfileSheet({required this.user});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: D.bg1, borderRadius: BorderRadius.circular(28),
      border: Border.all(color: D.bdr)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(color: D.bg3, borderRadius: BorderRadius.circular(2))),
      Container(width: 64, height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: D.teal.withOpacity(0.4), width: 2)),
        child: ClipOval(child: user?.photoURL != null
          ? Image.network(user!.photoURL!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: D.teal, size: 28))
          : const Icon(Icons.person, color: D.teal, size: 28))),
      const SizedBox(height: 12),
      Text(user?.displayName ?? 'Clinician',
        style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: D.text1)),
      const SizedBox(height: 3),
      Text(user?.email ?? '',
        style: GoogleFonts.dmSans(fontSize: 12, color: D.text2)),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: () async { Navigator.pop(context); await AuthService.signOut(); },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: D.red.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: D.red.withOpacity(0.25))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: D.red, size: 16),
            const SizedBox(width: 8),
            Text('Sign Out', style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w700, color: D.red)),
          ]))),
    ]));
}

// ══════════════════════════════════════════════════════════════════
//  BOTTOM NAV BAR
// ══════════════════════════════════════════════════════════════════
class _NavBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const _NavBar({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: D.bg1,
      border: Border(top: BorderSide(color: D.bdr, width: 1)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0,-3))]),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.grid_view_rounded,    label: 'Home',    active: tab == 0, onTap: () => onTap(0)),
            _NavItem(icon: Icons.document_scanner,     label: 'Scan',    active: tab == 1, onTap: () => onTap(1)),
            _NavItem(icon: Icons.assignment_outlined,  label: 'Reports', active: tab == 2, onTap: () => onTap(2)),
            _NavItem(icon: Icons.sensors_rounded,      label: 'Sensor',  active: tab == 3, onTap: () => onTap(3)),
          ]))));
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: active ? 16 : 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? D.teal.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: D.teal.withOpacity(0.22)) : null),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: active ? D.teal : D.text3),
        const SizedBox(height: 3),
        Text(label, style: GoogleFonts.dmSans(
          fontSize: 9, fontWeight: active ? FontWeight.w800 : FontWeight.w400,
          color: active ? D.teal : D.text3)),
      ])));
}

// ══════════════════════════════════════════════════════════════════
//  EMPTY REPORTS
// ══════════════════════════════════════════════════════════════════
class _EmptyReports extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyReports({required this.onScan});

  @override
  Widget build(BuildContext context) => SafeArea(child: Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 80, height: 80,
        decoration: BoxDecoration(
          color: D.teal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: D.teal.withOpacity(0.20))),
        child: Icon(Icons.analytics_outlined, color: D.teal.withOpacity(0.6), size: 36)),
      const SizedBox(height: 22),
      Text('No Assessment Yet', style: GoogleFonts.playfairDisplay(
        fontSize: 22, fontWeight: FontWeight.w900, color: D.text1)),
      const SizedBox(height: 10),
      Text('Complete a scan session to generate\nyour anemia risk assessment report.',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(fontSize: 12, color: D.text2, height: 1.55)),
      const SizedBox(height: 26),
      GestureDetector(onTap: onScan,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [D.teal, D.tealDk]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: D.teal.withOpacity(0.40), blurRadius: 20, offset: const Offset(0, 7))]),
          child: Text('Begin Assessment', style: GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)))),
    ]))));
}

// ══════════════════════════════════════════════════════════════════
//  ECG PAINTER
// ══════════════════════════════════════════════════════════════════
class _EcgPainter extends CustomPainter {
  final double t;
  final Color  color;
  const _EcgPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const pts = 120;
    for (int i = 0; i < pts; i++) {
      final x = (i / pts) * size.width;
      final phase = ((i / pts) + t) % 1.0;
      double y = size.height / 2;
      if      (phase < 0.07) y = size.height/2 - math.sin(phase/0.07*math.pi)*size.height*0.10;
      else if (phase < 0.14) y = size.height/2;
      else if (phase < 0.17) y = size.height/2 + size.height*0.15;
      else if (phase < 0.21) y = size.height/2 - size.height*0.46;
      else if (phase < 0.25) y = size.height/2 + size.height*0.22;
      else if (phase < 0.38) y = size.height/2 - math.sin((phase-0.25)/0.13*math.pi)*size.height*0.16;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.25)..strokeWidth = 5
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(path, Paint()
      ..color = color..strokeWidth = 1.8
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override bool shouldRepaint(_EcgPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════
//  SECTION LABEL
// ══════════════════════════════════════════════════════════════════
Widget _SectionLabel(String t) => Text(t, style: GoogleFonts.dmSans(
  fontSize: 10, fontWeight: FontWeight.w800, color: D.teal, letterSpacing: 1.8));