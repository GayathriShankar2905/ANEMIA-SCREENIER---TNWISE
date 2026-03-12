import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/scan_provider.dart';
import '../services/auth_service.dart';
import 'nail_capture_screen.dart';
import 'palm_capture_screen.dart';
import 'result_screen.dart';
import 'esp32_screen.dart';

// ══════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — Clinical Dark
// ══════════════════════════════════════════════════════════════════
class D {
  // Backgrounds
  static const bg0    = Color(0xFF050D1A);
  static const bg1    = Color(0xFF0A1628);
  static const bg2    = Color(0xFF0F1E36);
  static const bg3    = Color(0xFF162440);
  // Teal
  static const teal   = Color(0xFF00D4C8);
  static const tealDk = Color(0xFF00A89E);
  static const tealLt = Color(0xFF1AFFE8);
  // Status
  static const green  = Color(0xFF22D47A);
  static const amber  = Color(0xFFFFB547);
  static const red    = Color(0xFFFF4D6A);
  static const blue   = Color(0xFF4D9EFF);
  // Text
  static const text1  = Color(0xFFF0F8FF);
  static const text2  = Color(0xFF7A9BBE);
  static const text3  = Color(0xFF3D5A7A);
  // Borders
  static const bdr    = Color(0xFF1A2E4A);
  static const bdrT   = Color(0xFF00D4C8);
  // Helpers
  static Color teal10  = const Color(0xFF00D4C8).withOpacity(0.10);
  static Color teal20  = const Color(0xFF00D4C8).withOpacity(0.20);
  static Color green10 = const Color(0xFF22D47A).withOpacity(0.12);
  static Color amber10 = const Color(0xFFFFB547).withOpacity(0.12);
  static Color red10   = const Color(0xFFFF4D6A).withOpacity(0.12);
  static Color blue10  = const Color(0xFF4D9EFF).withOpacity(0.12);
}

BoxDecoration _card({Color? border, double r = 20}) => BoxDecoration(
  color: D.bg1,
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: border ?? D.bdr, width: 1),
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
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
  void dispose() { _ecgCtrl.dispose(); _dotCtrl.dispose(); super.dispose(); }

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
          : ResultScreen(result: scan.result!, onNewScan: () { scan.reset(); setState(() => _tab = 1); }),
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
    final name = user?.displayName?.split(' ').first ?? 'Doctor';

    return SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header bar ───────────────────────────────
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Good day, $name', style: GoogleFonts.dmSans(fontSize: 13, color: D.text2)),
            const SizedBox(height: 2),
            Text('HemoScan', style: GoogleFonts.playfairDisplay(
              fontSize: 26, fontWeight: FontWeight.w900, color: D.text1,
              shadows: [Shadow(color: D.teal.withOpacity(0.4), blurRadius: 16)])),
          ])),
          _Avatar(user: user),
        ]),
        const SizedBox(height: 22),

        // ── Live vitals row ──────────────────────────
        Row(children: [
          Expanded(child: _HrCard(ecgCtrl: ecgCtrl, dotCtrl: dotCtrl, scan: scan)),
          const SizedBox(width: 12),
          Expanded(child: _Spo2Card(scan: scan)),
        ]),
        const SizedBox(height: 20),

        // ── Section label ────────────────────────────
        _SectionLabel('Scan Modules'),
        const SizedBox(height: 14),

        // ── Module grid ──────────────────────────────
        _ModuleGrid(onTab: onTab, context: context),
        const SizedBox(height: 20),

        // ── Hero banner ──────────────────────────────
        _HeroBanner(),
        const SizedBox(height: 20),

        // ── Session status ───────────────────────────
        _SectionLabel('Session Status'),
        const SizedBox(height: 12),
        _SessionStatus(scan: scan),
      ]),
    ));
  }
}

// ── Avatar with profile sheet ─────────────────────────────
class _Avatar extends StatelessWidget {
  final User? user;
  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _sheet(context),
    child: Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: D.teal.withOpacity(0.45), width: 1.5),
        boxShadow: [BoxShadow(color: D.teal.withOpacity(0.25), blurRadius: 12)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: user?.photoURL != null
          ? Image.network(user!.photoURL!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback())
          : _fallback())),
  );

  Widget _fallback() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [D.teal, D.tealDk],
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: const Center(child: Text('🩸', style: TextStyle(fontSize: 22))));

  void _sheet(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
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
      border: Border.all(color: D.bdr),
      boxShadow: [BoxShadow(color: D.teal.withOpacity(0.08), blurRadius: 40)]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(color: D.bg3, borderRadius: BorderRadius.circular(2))),
      Container(width: 72, height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: D.teal.withOpacity(0.4), width: 2),
          boxShadow: [BoxShadow(color: D.teal.withOpacity(0.25), blurRadius: 20)]),
        child: ClipOval(child: user?.photoURL != null
          ? Image.network(user!.photoURL!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fb())
          : _fb())),
      const SizedBox(height: 14),
      Text(user?.displayName ?? 'User',
        style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: D.text1)),
      const SizedBox(height: 4),
      Text(user?.email ?? '',
        style: GoogleFonts.dmSans(fontSize: 12, color: D.text2)),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: () async { Navigator.pop(context); await AuthService.signOut(); },
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: D.red10, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: D.red.withOpacity(0.3))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: D.red, size: 18),
            const SizedBox(width: 8),
            Text('Sign Out', style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w700, color: D.red)),
          ]))),
    ]));

  Widget _fb() => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      colors: [D.teal, D.tealDk],
      begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: const Center(child: Text('🩸', style: TextStyle(fontSize: 30))));
}

// ── HR Card ───────────────────────────────────────────────
class _HrCard extends StatelessWidget {
  final AnimationController ecgCtrl, dotCtrl;
  final ScanProvider scan;
  const _HrCard({required this.ecgCtrl, required this.dotCtrl, required this.scan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: D.bg1,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: D.teal.withOpacity(0.20)),
      boxShadow: [BoxShadow(color: D.teal.withOpacity(0.08), blurRadius: 20)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Heart Rate', style: GoogleFonts.dmSans(
          fontSize: 11, fontWeight: FontWeight.w600, color: D.teal, letterSpacing: 0.5)),
        AnimatedBuilder(animation: dotCtrl, builder: (_, __) => Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: scan.sensorLive ? D.red : D.text3,
            shape: BoxShape.circle,
            boxShadow: scan.sensorLive
              ? [BoxShadow(color: D.red.withOpacity(dotCtrl.value * 0.7), blurRadius: 8, spreadRadius: 1)]
              : []))),
      ]),
      const SizedBox(height: 8),
      RichText(text: TextSpan(children: [
        TextSpan(text: scan.hr != null ? scan.hr!.toStringAsFixed(0) : '--',
          style: GoogleFonts.dmSans(fontSize: 36, fontWeight: FontWeight.w900,
            color: D.text1, height: 1)),
        TextSpan(text: ' bpm',
          style: GoogleFonts.dmSans(fontSize: 12, color: D.text2)),
      ])),
      const SizedBox(height: 10),
      SizedBox(height: 40, child: AnimatedBuilder(
        animation: ecgCtrl,
        builder: (_, __) => CustomPaint(
          painter: _EcgPainter(ecgCtrl.value, D.teal),
          child: const SizedBox.expand()))),
      if (scan.hrAbnormal) _StatusPill('⚠ Elevated', D.red),
    ]));
}

// ── SpO2 Card ─────────────────────────────────────────────
class _Spo2Card extends StatelessWidget {
  final ScanProvider scan;
  const _Spo2Card({required this.scan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: D.bg1,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: D.blue.withOpacity(0.20)),
      boxShadow: [BoxShadow(color: D.blue.withOpacity(0.06), blurRadius: 20)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SpO₂', style: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w600, color: D.blue, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      RichText(text: TextSpan(children: [
        TextSpan(text: scan.spo2 != null ? scan.spo2!.toStringAsFixed(0) : '--',
          style: GoogleFonts.dmSans(fontSize: 36, fontWeight: FontWeight.w900,
            color: D.text1, height: 1)),
        TextSpan(text: ' %',
          style: GoogleFonts.dmSans(fontSize: 12, color: D.text2)),
      ])),
      const SizedBox(height: 14),
      Center(child: SizedBox(width: 54, height: 54,
        child: Stack(children: [
          CircularProgressIndicator(
            value: scan.spo2 != null ? (scan.spo2! / 100).clamp(0, 1) : 0,
            strokeWidth: 5,
            backgroundColor: D.bg3,
            valueColor: AlwaysStoppedAnimation(scan.spo2Abnormal ? D.red : D.blue),
            strokeCap: StrokeCap.round),
          Center(child: Icon(Icons.air_rounded, size: 18,
            color: scan.spo2Abnormal ? D.red : D.blue)),
        ]))),
      if (scan.spo2Abnormal) ...[const SizedBox(height: 8), _StatusPill('⚠ Low', D.red)],
    ]));
}

Widget _StatusPill(String text, Color c) => Container(
  margin: const EdgeInsets.only(top: 4),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
    border: Border.all(color: c.withOpacity(0.3))),
  child: Text(text, style: GoogleFonts.dmSans(
    fontSize: 10, fontWeight: FontWeight.w700, color: c)));

// ── Module Grid ───────────────────────────────────────────
class _ModuleGrid extends StatelessWidget {
  final ValueChanged<int> onTab;
  final BuildContext context;
  const _ModuleGrid({required this.onTab, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final items = [
      _Mod('💅', 'Nail Scan',  D.green, D.green10,
        () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const NailCaptureScreen()))),
      _Mod('🤚', 'Palm Scan',  D.amber, D.amber10,
        () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const PalmCaptureScreen()))),
      _Mod('📡', 'Sensor',     D.teal,  D.teal10,  () => onTab(3)),
      _Mod('📊', 'Report',     D.blue,  D.blue10,   () => onTab(2)),
    ];
    return Row(
      children: items.map((m) => Expanded(
        child: GestureDetector(
          onTap: m.action,
          child: Container(
            margin: EdgeInsets.only(right: m == items.last ? 0 : 10),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: D.bg1, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: m.color.withOpacity(0.22)),
              boxShadow: [BoxShadow(color: m.color.withOpacity(0.08), blurRadius: 14)]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(m.icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 8),
              Text(m.label, style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w600, color: m.color)),
            ])),
        )),
      ).toList(),
    );
  }
}

class _Mod {
  final String icon, label;
  final Color color, bg;
  final VoidCallback action;
  const _Mod(this.icon, this.label, this.color, this.bg, this.action);
}

// ── Hero Banner ───────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 114,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [D.teal.withOpacity(0.85), D.tealDk],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: D.teal.withOpacity(0.3), blurRadius: 24, offset: const Offset(0,8))]),
    child: Stack(children: [
      Positioned(right: -30, top: -30,
        child: Container(width: 120, height: 120,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),
      Positioned(right: 20, bottom: -40,
        child: Container(width: 100, height: 100,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), shape: BoxShape.circle))),
      Padding(padding: const EdgeInsets.all(22), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Non-Invasive', style: GoogleFonts.dmSans(
            fontSize: 11, color: Colors.white70, letterSpacing: 1)),
          Text('Anemia Screening', style: GoogleFonts.playfairDisplay(
            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
          const SizedBox(height: 4),
          Text('No needles · AI-powered · Portable',
            style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white60)),
        ])),
        Container(width: 54, height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.2))),
          child: const Center(child: Text('🩺', style: TextStyle(fontSize: 28)))),
      ])),
    ]));
}

// ── Session Status ────────────────────────────────────────
class _SessionStatus extends StatelessWidget {
  final ScanProvider scan;
  const _SessionStatus({required this.scan});

  @override
  Widget build(BuildContext context) {
    final wsColor = scan.wsStatus == 'connected' ? D.green
        : scan.wsStatus == 'connecting' ? D.amber : D.text3;
    final wsText = scan.wsStatus == 'connected' ? '● Live'
        : scan.wsStatus == 'connecting' ? '◌ Connecting'
        : scan.wsStatus == 'error' ? '✕ Error' : '○ Offline';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _card(border: D.bdr),
      child: Column(children: [
        _row('📡', 'ESP32 Sensor', wsText, wsColor),
        _div(),
        _row('💅', 'Nail Analysis',
          scan.nailData != null ? '● Analyzed' : '○ Pending',
          scan.nailData != null ? D.green : D.text3),
        _div(),
        _row('🤚', 'Palm Analysis',
          scan.palmData != null ? '● Analyzed' : '○ Pending',
          scan.palmData != null ? D.green : D.text3),
      ]));
  }

  Widget _row(String ic, String label, String status, Color c) =>
    Row(children: [
      Text(ic, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
        style: GoogleFonts.dmSans(fontSize: 13, color: D.text2))),
      Text(status, style: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w700, color: c)),
    ]);

  Widget _div() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(color: D.bdr, height: 1));
}

Widget _SectionLabel(String t) => Text(t,
  style: GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w700,
    color: D.teal, letterSpacing: 1.5));

// ══════════════════════════════════════════════════════════════════
//  SCAN PAGE
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
        Text('Complete all three modules for best accuracy',
          style: GoogleFonts.dmSans(fontSize: 12, color: D.text2)),
        const SizedBox(height: 24),

        // Step cards
        _StepCard(
          num: '01', title: 'Sensor', subtitle: 'Live HR & SpO₂ via ESP32 WebSocket',
          icon: '📡', accentColor: D.teal,
          done: scan.sensorLive,
          trailing: scan.hr != null ? Row(children: [
            _Tag('❤ ${scan.hr!.toStringAsFixed(0)}', D.red),
            const SizedBox(width: 8),
            _Tag('🫁 ${scan.spo2?.toStringAsFixed(0) ?? '--'}%', D.blue),
          ]) : null,
          onTap: () => onTab(3),
        ),
        const SizedBox(height: 12),
        _StepCard(
          num: '02', title: 'Nail Bed', subtitle: 'Drag markers onto each fingernail bed',
          icon: '💅', accentColor: D.green,
          done: scan.nailData != null,
          trailing: scan.nailData != null ? _ColorRow(scan.nailData!, 4) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const NailCaptureScreen())),
        ),
        const SizedBox(height: 12),
        _StepCard(
          num: '03', title: 'Palm Crease', subtitle: 'Mark the palmar crease for color analysis',
          icon: '🤚', accentColor: D.amber,
          done: scan.palmData != null,
          trailing: scan.palmData != null ? _ColorRow(scan.palmData!, 3) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const PalmCaptureScreen())),
        ),
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
                ? [BoxShadow(color: D.teal.withOpacity(0.45), blurRadius: 24, offset: const Offset(0,8))]
                : []),
            child: Center(child: Text(
              scan.canAnalyze ? '🔬  Analyze Anemia Risk' : 'Complete at least one module',
              style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800,
                color: scan.canAnalyze ? Colors.white : D.text3, letterSpacing: 0.3)))),
        ),
      ]),
    ));
  }
}

class _StepCard extends StatelessWidget {
  final String num, title, icon, subtitle;
  final Color accentColor;
  final bool done;
  final Widget? trailing;
  final VoidCallback onTap;
  const _StepCard({required this.num, required this.title, required this.icon,
    required this.subtitle, required this.accentColor, required this.done,
    required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: D.bg1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: done ? accentColor.withOpacity(0.30) : D.bdr),
        boxShadow: [BoxShadow(color: done ? accentColor.withOpacity(0.06) : Colors.black38,
          blurRadius: 14, offset: const Offset(0,4))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.20))),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 24)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$num. ', style: GoogleFonts.dmSans(fontSize: 11, color: D.text3)),
            Expanded(child: Text(title, style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w800, color: D.text1))),
            if (done)
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: D.green.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: D.green.withOpacity(0.35))),
                child: Text('Done ✓', style: GoogleFonts.dmSans(
                  fontSize: 10, fontWeight: FontWeight.w700, color: D.green)))
            else
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withOpacity(0.25))),
                child: Text('Tap →', style: GoogleFonts.dmSans(
                  fontSize: 10, fontWeight: FontWeight.w600, color: accentColor))),
          ]),
          const SizedBox(height: 3),
          Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, color: D.text2)),
          if (trailing != null) ...[const SizedBox(height: 8), trailing!],
        ])),
      ])));
}

Widget _Tag(String t, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
    border: Border.all(color: c.withOpacity(0.3))),
  child: Text(t, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: c)));

class _ColorRow extends StatelessWidget {
  final List<ROIResult> data;
  final int max;
  const _ColorRow(this.data, this.max);
  @override
  Widget build(BuildContext context) => Row(children: [
    for (int i = 0; i < data.length && i < max; i++)
      Container(width: 20, height: 20, margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: data[i].color, shape: BoxShape.circle,
          border: Border.all(color: D.bdr, width: 1.5),
          boxShadow: [BoxShadow(color: data[i].color.withOpacity(0.5), blurRadius: 6)])),
    const SizedBox(width: 6),
    Text('extracted', style: GoogleFonts.dmSans(fontSize: 10, color: D.text3)),
  ]);
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
      Container(width: 90, height: 90,
        decoration: BoxDecoration(
          color: D.teal10, borderRadius: BorderRadius.circular(28),
          border: Border.all(color: D.teal.withOpacity(0.25))),
        child: Center(child: Text('📊', style: const TextStyle(fontSize: 44)))),
      const SizedBox(height: 24),
      Text('No Results Yet', style: GoogleFonts.playfairDisplay(
        fontSize: 22, fontWeight: FontWeight.w800, color: D.text1)),
      const SizedBox(height: 10),
      Text('Complete a scan to see your anemia risk assessment here.',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(fontSize: 13, color: D.text2, height: 1.5)),
      const SizedBox(height: 28),
      GestureDetector(onTap: onScan,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [D.teal, D.tealDk]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: D.teal.withOpacity(0.4), blurRadius: 22, offset: const Offset(0,8))]),
          child: Text('Start Scan', style: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)))),
    ]))));
}

// ══════════════════════════════════════════════════════════════════
//  BOTTOM NAV BAR
// ══════════════════════════════════════════════════════════════════
class _NavBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const _NavBar({required this.tab, required this.onTap});

  static const _items = [
    {'icon': Icons.home_rounded,       'label': 'Home'},
    {'icon': Icons.document_scanner,   'label': 'Scan'},
    {'icon': Icons.bar_chart_rounded,  'label': 'Reports'},
    {'icon': Icons.settings_remote,    'label': 'Sensor'},
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: D.bg1,
      border: Border(top: BorderSide(color: D.bdr, width: 1)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0,-4))]),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final active = tab == i;
            return GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.symmetric(horizontal: active ? 18 : 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? D.teal.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: active ? Border.all(color: D.teal.withOpacity(0.25)) : null),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_items[i]['icon'] as IconData, size: 22,
                    color: active ? D.teal : D.text3),
                  const SizedBox(height: 3),
                  Text(_items[i]['label'] as String,
                    style: GoogleFonts.dmSans(fontSize: 10,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? D.teal : D.text3)),
                ])));
          })))));
}

// ══════════════════════════════════════════════════════════════════
//  ECG PAINTER
// ══════════════════════════════════════════════════════════════════
class _EcgPainter extends CustomPainter {
  final double t;
  final Color color;
  const _EcgPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Teal glow pass
    canvas.drawPath(_buildPath(size),
      Paint()..color = color.withOpacity(0.25)
        ..strokeWidth = 5 ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(_buildPath(size), paint);
  }

  Path _buildPath(Size size) {
    final path = Path();
    const pts = 140;
    for (int i = 0; i < pts; i++) {
      final x = (i / pts) * size.width;
      final phase = ((i / pts) + t) % 1.0;
      double y = size.height / 2;
      if (phase < 0.07)       y = size.height/2 - math.sin(phase/0.07*math.pi)*size.height*0.10;
      else if (phase < 0.14)  y = size.height/2;
      else if (phase < 0.17)  y = size.height/2 + size.height*0.14;
      else if (phase < 0.21)  y = size.height/2 - size.height*0.44;
      else if (phase < 0.25)  y = size.height/2 + size.height*0.20;
      else if (phase < 0.38)  y = size.height/2 - math.sin((phase-0.25)/0.13*math.pi)*size.height*0.17;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    return path;
  }

  @override
  bool shouldRepaint(_EcgPainter o) => o.t != t;
}