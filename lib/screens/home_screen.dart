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
import 'questionnaire_screen.dart';
import 'result_screen.dart';
import 'esp32_screen.dart';

// ══════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — Clinical Dark (Strictly No Emojis)
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
          : ResultScreen(result: scan.result!, onNewScan: () { scan.reset(); setState(() => _tab = 1); }),
        const ESP32Screen(),
      ]),
      bottomNavigationBar: _NavBar(tab: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

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
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clinical Dashboard, $name', style: GoogleFonts.dmSans(fontSize: 13, color: D.text2)),
            const SizedBox(height: 2),
            Text('HemoScan AI', style: GoogleFonts.playfairDisplay(
              fontSize: 26, fontWeight: FontWeight.w900, color: D.text1)),
          ])),
          _Avatar(user: user),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: _HrCard(ecgCtrl: ecgCtrl, dotCtrl: dotCtrl, scan: scan)),
          const SizedBox(width: 12),
          Expanded(child: _Spo2Card(scan: scan)),
        ]),
        const SizedBox(height: 12),
        _PiCard(scan: scan),
        const SizedBox(height: 24),
        
        // Hero Banner
        _HeroBanner(),
        
        const SizedBox(height: 24),
        _SectionLabel('ANALYSIS MODULES'),
        const SizedBox(height: 14),
        _ModuleGrid(onTab: onTab, context: context),
        const SizedBox(height: 24),
        _SectionLabel('SESSION STATUS'),
        const SizedBox(height: 12),
        _SessionStatus(scan: scan),
      ]),
    ));
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: D.bg1,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: D.bdr),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // RIGHT CENTER: Doctor/Patient Image
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: MediaQuery.of(context).size.width * 0.5,
              child: Image.network(
                'https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&q=80&w=500',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: D.bg3),
              ),
            ),
            // Gradient to blend the image into the background
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                    colors: [D.bg1, D.bg1.withOpacity(0.8), Colors.transparent],
                    stops: const [0.4, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // LEFT CENTER: Wordings and Google Logo
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('HEMOSCAN PROJECT', 
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: D.teal, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text('Precision AI\nDiagnostics', 
                    style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w900, color: D.text1, height: 1.1)),
                  const SizedBox(height: 16),
                  // Google Sign
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png', height: 12),
                        const SizedBox(width: 6),
                        Text('Google Cloud AI', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold, color: D.text2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final User? user;
  const _Avatar({required this.user});
  @override
  Widget build(BuildContext context) {
    final url = user?.photoURL;
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: D.teal.withOpacity(0.35), width: 2),
          boxShadow: [BoxShadow(color: D.teal.withOpacity(0.18), blurRadius: 14)]),
        child: url != null
          ? ClipOval(child: Image.network(url, fit: BoxFit.cover))
          : Container(
              color: D.bg3,
              child: Icon(Icons.person_outline, size: 24, color: D.text2))));
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: D.bg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.logout, color: D.red),
            title: Text('Sign out', style: GoogleFonts.dmSans(color: D.text1, fontWeight: FontWeight.w600)),
            onTap: () async {
              await context.read<AuthService>().signOut();
              if (ctx.mounted) Navigator.pop(ctx);
            }),
        ])));
  }
}

class _HrCard extends StatelessWidget {
  final AnimationController ecgCtrl, dotCtrl;
  final ScanProvider scan;
  const _HrCard({required this.ecgCtrl, required this.dotCtrl, required this.scan});

  @override
  Widget build(BuildContext context) {
    final hr = scan.hr;
    final live = scan.sensorLive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: D.bg1, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: D.bdr),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
              color: D.red.withOpacity(0.10), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: D.red.withOpacity(0.22))),
            child: const Icon(Icons.favorite, size: 16, color: D.red)),
          const Spacer(),
          if (live) AnimatedBuilder(
            animation: dotCtrl,
            builder: (_, __) => Container(width: 8, height: 8,
              decoration: BoxDecoration(
                color: D.green.withOpacity(dotCtrl.value),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: D.green.withOpacity(dotCtrl.value * 0.8), blurRadius: 8)]))),
        ]),
        const SizedBox(height: 12),
        Text('Heart Rate', style: GoogleFonts.dmSans(fontSize: 11, color: D.text2)),
        const SizedBox(height: 4),
        Text(hr != null ? '${hr.toStringAsFixed(0)} bpm' : '-- bpm',
          style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w900, color: D.text1)),
        const SizedBox(height: 8),
        SizedBox(height: 36, child: CustomPaint(painter: _EcgPainter(ecgCtrl))),
      ]));
  }
}

class _Spo2Card extends StatelessWidget {
  final ScanProvider scan;
  const _Spo2Card({required this.scan});

  @override
  Widget build(BuildContext context) {
    final spo2 = scan.spo2;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: D.bg1, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: D.bdr),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            color: D.blue.withOpacity(0.10), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: D.blue.withOpacity(0.22))),
          child: const Icon(Icons.air, size: 16, color: D.blue)),
        const SizedBox(height: 12),
        Text('SpO₂', style: GoogleFonts.dmSans(fontSize: 11, color: D.text2)),
        const SizedBox(height: 4),
        Text(spo2 != null ? '${spo2.toStringAsFixed(0)} %' : '-- %',
          style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w900, color: D.text1)),
        const SizedBox(height: 10),
        if (spo2 != null) LinearProgressIndicator(
          value: spo2 / 100,
          backgroundColor: D.bg3,
          valueColor: AlwaysStoppedAnimation(spo2 < 95 ? D.red : D.blue),
          minHeight: 6, borderRadius: BorderRadius.circular(3)),
      ]));
  }
}

class _PiCard extends StatelessWidget {
  final ScanProvider scan;
  const _PiCard({required this.scan});

  @override
  Widget build(BuildContext context) {
    final pi = scan.pi;
    final live = scan.sensorLive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: D.bg1, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: D.bdr),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0,4))]),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: D.purp.withOpacity(0.10), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: D.purp.withOpacity(0.22))),
          child: const Icon(Icons.waves, size: 20, color: D.purp)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Perfusion Index', style: GoogleFonts.dmSans(fontSize: 11, color: D.text2)),
          const SizedBox(height: 2),
          Text(pi != null ? '${pi.toStringAsFixed(2)} %' : '-- %',
            style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w900, color: D.text1)),
        ])),
        if (live && pi != null && pi < 2.0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: D.amber.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: D.amber.withOpacity(0.28))),
            child: Text('Low', style: GoogleFonts.dmSans(
              fontSize: 10, fontWeight: FontWeight.w800, color: D.amber))),
      ]));
  }
}

class _EcgPainter extends CustomPainter {
  final AnimationController ctrl;
  const _EcgPainter(this.ctrl) : super(repaint: ctrl);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = D.red..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final path = Path();
    final t = ctrl.value;
    for (int i = 0; i < size.width.toInt(); i++) {
      final x = i.toDouble();
      final phase = (x / size.width - t) * 2 * math.pi * 1.8;
      double y = size.height / 2;
      if (phase > -0.3 && phase < 0.1) {
        y += size.height * 0.35 * math.sin(phase * 14);
      } else if (phase > 0.15 && phase < 0.35) {
        y -= size.height * 0.2 * math.sin((phase - 0.15) * 15);
      }
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_EcgPainter old) => false;
}

Widget _SectionLabel(String t) => Text(t, style: GoogleFonts.dmSans(
  fontSize: 11, fontWeight: FontWeight.w800, color: D.teal, letterSpacing: 1.5));

class _ModuleGrid extends StatelessWidget {
  final ValueChanged<int> onTab;
  final BuildContext context;
  const _ModuleGrid({required this.onTab, required this.context});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1,
    children: [
      _ModuleTile('Nail Beds', Icons.bloodtype, D.red,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NailCaptureScreen()))),
      _ModuleTile('Palm Lines', Icons.pan_tool_outlined, D.amber,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PalmCaptureScreen()))),
      _ModuleTile('Conjunctiva', Icons.visibility_outlined, D.blue,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConjunctivaCaptureScreen()))),
      _ModuleTile('Symptoms', Icons.assignment_outlined, D.purp,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionnaireScreen()))),
    ]);
}

class _ModuleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ModuleTile(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: D.bg1, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: D.bdr),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0,4))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.22))),
          child: Icon(icon, color: color, size: 26)),
        const SizedBox(height: 12),
        Text(label, style: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w800, color: D.text1)),
      ])));
}

class _SessionStatus extends StatelessWidget {
  final ScanProvider scan;
  const _SessionStatus({required this.scan});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: D.bg1, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: D.bdr),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StatusRow('Nail bed analysis', scan.nailData != null),
      const SizedBox(height: 10),
      _StatusRow('Palm analysis', scan.palmData != null),
      const SizedBox(height: 10),
      _StatusRow('Conjunctiva analysis', scan.conjunctivaData != null),
      const SizedBox(height: 10),
      _StatusRow('Symptom questionnaire', scan.symptomScore != null),
      const SizedBox(height: 10),
      _StatusRow('Heart rate data', scan.hr != null),
      const SizedBox(height: 10),
      _StatusRow('SpO₂ data', scan.spo2 != null),
      const SizedBox(height: 10),
      _StatusRow('Perfusion index data', scan.pi != null),
    ]));
}

Widget _StatusRow(String label, bool done) => Row(children: [
  Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
    size: 18, color: done ? D.green : D.text3),
  const SizedBox(width: 10),
  Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: done ? D.text1 : D.text2)),
]);

class _EmptyReports extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyReports({required this.onScan});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.description_outlined, size: 72, color: D.text3),
      const SizedBox(height: 16),
      Text('No reports yet', style: GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w700, color: D.text2)),
      const SizedBox(height: 8),
      Text('Complete a scan to generate a report',
        style: GoogleFonts.dmSans(fontSize: 13, color: D.text3)),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: onScan,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [D.teal, D.tealDk]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: D.teal.withOpacity(0.4), blurRadius: 16, offset: const Offset(0,6))]),
          child: Text('Start New Scan', style: GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)))),
    ]));
}

class _NavBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const _NavBar({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    decoration: BoxDecoration(
      color: D.bg1,
      border: Border(top: BorderSide(color: D.bdr)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0,-2))]),
    child: Row(children: [
      _NavItem(0, tab, Icons.dashboard_outlined, 'Dashboard', onTap),
      _NavItem(1, tab, Icons.qr_code_scanner, 'Scan', onTap),
      _NavItem(2, tab, Icons.description_outlined, 'Reports', onTap),
      _NavItem(3, tab, Icons.settings_input_antenna, 'Sensor', onTap),
    ]));

  static Widget _NavItem(int i, int curr, IconData icon, String label, ValueChanged<int> cb) =>
    Expanded(child: GestureDetector(
      onTap: () => cb(i),
      child: Container(
        color: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 24, color: curr == i ? D.teal : D.text3),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.dmSans(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: curr == i ? D.teal : D.text3)),
        ]))));
}

class _ScanPage extends StatelessWidget {
  final ValueChanged<int> onTab;
  const _ScanPage({required this.onTab});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    return SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CLINICAL PROTOCOL', style: GoogleFonts.dmSans(
          fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700, color: D.teal)),
        Text('Multi-Signal Anemia Assessment', style: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w900, color: D.text1)),
        const SizedBox(height: 24),

        _StepCard(num: '1', title: 'Nail bed chrominance', subtitle: 'Capture nail bed images for pallor analysis',
          icon: Icons.bloodtype, color: D.red, done: scan.nailData != null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NailCaptureScreen())),
          trailing: scan.nailData != null ? _RoiColorRow(scan.nailData!, 4) : null),
        const SizedBox(height: 12),

        _StepCard(num: '2', title: 'Palm crease assessment', subtitle: 'Evaluate palmar pallor via crease analysis',
          icon: Icons.pan_tool_outlined, color: D.amber, done: scan.palmData != null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PalmCaptureScreen())),
          trailing: scan.palmData != null ? _RoiColorRow(scan.palmData!, 4) : null),
        const SizedBox(height: 12),

        _StepCard(num: '3', title: 'Conjunctival redness', subtitle: 'Measure lower palpebral conjunctival redness index',
          icon: Icons.visibility_outlined, color: D.blue, done: scan.conjunctivaData != null,
          badge: 'SHETH et al. 2016',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConjunctivaCaptureScreen())),
          trailing: scan.conjunctivaData != null ? _ConjunctivaInline(scan.conjunctivaData!) : null),
        const SizedBox(height: 12),

        _StepCard(num: '4', title: 'Symptom questionnaire', subtitle: 'Complete 10-question clinical symptom screen',
          icon: Icons.assignment_outlined, color: D.purp, done: scan.questionnaireOk,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionnaireScreen())),
          trailing: scan.symptomScore != null && scan.symptomMax != null
            ? _SymptomScoreTag(scan.symptomScore!, scan.symptomMax!) : null),
        const SizedBox(height: 12),

        _StepCard(num: '5', title: 'Physiological signals', subtitle: 'Connect ESP32 sensor for HR, SpO₂, and PI',
          icon: Icons.settings_input_antenna, color: D.teal, 
          done: scan.hr != null && scan.spo2 != null && scan.pi != null,
          badge: 'MAX30105 SENSOR',
          onTap: () => onTab(3)),
        const SizedBox(height: 28),

        GestureDetector(
          onTap: scan.canAnalyze ? () { scan.analyze(); onTab(2); } : null,
          child: Container(
            width: double.infinity, height: 62,
            decoration: BoxDecoration(
              gradient: scan.canAnalyze ? const LinearGradient(colors: [D.teal, D.tealDk]) : null,
              color: scan.canAnalyze ? null : D.bg2,
              borderRadius: BorderRadius.circular(18),
              boxShadow: scan.canAnalyze
                ? [BoxShadow(color: D.teal.withOpacity(0.40),
                    blurRadius: 24, offset: const Offset(0, 8))] : []),
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
      child: Text('Done', style: GoogleFonts.dmSans(
        fontSize: 9, fontWeight: FontWeight.w800, color: D.green)))
  : Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.25))),
      child: Text('Tap to begin', style: GoogleFonts.dmSans(
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
                : ratio >= 0.32 ? 'Moderate Pallor' : 'Severe Pallor';
    final c = ratio >= 0.43 ? D.green : ratio >= 0.38 ? D.amber
            : ratio >= 0.32 ? const Color(0xFFF97316) : D.red;
    return Row(children: [
      Container(width: 16, height: 16,
        decoration: BoxDecoration(color: data.first.color, shape: BoxShape.circle,
          border: Border.all(color: D.bdr),
          boxShadow: [BoxShadow(color: data.first.color.withOpacity(0.5), blurRadius: 5)])),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.28))),
        child: Text(grade, style: GoogleFonts.dmSans(
          fontSize: 10, fontWeight: FontWeight.w800, color: c))),
      const SizedBox(width: 8),
      Text('ratio ${ratio.toStringAsFixed(3)}',
        style: GoogleFonts.dmSans(fontSize: 9, color: D.text3)),
    ]);
  }
}

// ── Symptom score tag shown after questionnaire done ──────
class _SymptomScoreTag extends StatelessWidget {
  final int score, max;
  const _SymptomScoreTag(this.score, this.max);
  @override
  Widget build(BuildContext context) {
    final pct = score / max;
    final c   = pct >= 0.65 ? D.red
              : pct >= 0.40 ? const Color(0xFFF97316)
              : pct >= 0.20 ? D.amber
              : D.green;
    final label = pct >= 0.65 ? 'High Burden'
                : pct >= 0.40 ? 'Moderate'
                : pct >= 0.20 ? 'Mild'
                : 'Low Burden';
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.28))),
        child: Text(label, style: GoogleFonts.dmSans(
          fontSize: 10, fontWeight: FontWeight.w800, color: c))),
      const SizedBox(width: 8),
      Text('$score / $max pts',
        style: GoogleFonts.dmSans(fontSize: 9, color: D.text3)),
    ]);
  }
}