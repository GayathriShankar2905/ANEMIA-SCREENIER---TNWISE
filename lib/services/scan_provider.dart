import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:web_socket_channel/web_socket_channel.dart';

// ── ROI Result ────────────────────────────────────────────
class ROIResult {
  final double r, g, b, pallor, redness, quality;
  const ROIResult({
    required this.r, required this.g, required this.b,
    required this.pallor, required this.redness, required this.quality,
  });
  Color get color => Color.fromARGB(
    255, r.round().clamp(0,255), g.round().clamp(0,255), b.round().clamp(0,255));
  bool get isPale => pallor > 0.55;
}

// ── Signal Breakdown ──────────────────────────────────────
class SignalBreakdown {
  final int points, max;
  final String label, icon;
  final double? pallor, redness;
  const SignalBreakdown({
    required this.points, required this.max,
    required this.label,  required this.icon,
    this.pallor, this.redness,
  });
  double get pct => max > 0 ? points / max : 0.0;
}

// ── Scan Result ───────────────────────────────────────────
class ScanResult {
  final double riskPct, estHgb;
  final String riskLevel;
  final Color  riskColor;
  final Map<String, SignalBreakdown> breakdown;
  const ScanResult({
    required this.riskPct, required this.estHgb,
    required this.riskLevel, required this.riskColor,
    required this.breakdown,
  });
}

// ── Color Analysis ────────────────────────────────────────
class ColorAnalysis {
  static List<ROIResult> analyze(img.Image image, List<Offset> centers,
      {int size = 52}) {
    final results = <ROIResult>[];
    for (final center in centers) {
      final sx = (center.dx - size/2).round().clamp(0, image.width  - 1);
      final sy = (center.dy - size/2).round().clamp(0, image.height - 1);
      final sw = (sx + size).clamp(0, image.width)  - sx;
      final sh = (sy + size).clamp(0, image.height) - sy;
      if (sw <= 0 || sh <= 0) continue;

      final pixels = <List<double>>[];
      for (int y = sy; y < sy + sh; y++) {
        for (int x = sx; x < sx + sw; x++) {
          final p = image.getPixel(x, y);
          pixels.add([p.r.toDouble(), p.g.toDouble(), p.b.toDouble()]);
        }
      }
      final n = pixels.length;
      if (n == 0) continue;

      double mr = 0, mg = 0, mb = 0;
      for (final p in pixels) { mr += p[0]; mg += p[1]; mb += p[2]; }
      mr /= n; mg /= n; mb /= n;

      double vr = 0, vg = 0, vb = 0;
      for (final p in pixels) {
        vr += (p[0]-mr)*(p[0]-mr);
        vg += (p[1]-mg)*(p[1]-mg);
        vb += (p[2]-mb)*(p[2]-mb);
      }
      final sr = vr/n < 1 ? 1.0 : vr/n;
      final sg = vg/n < 1 ? 1.0 : vg/n;
      final sb = vb/n < 1 ? 1.0 : vb/n;

      final qc = pixels.where((p) =>
        (p[0]-mr).abs() < 1.5*sr &&
        (p[1]-mg).abs() < 1.5*sg &&
        (p[2]-mb).abs() < 1.5*sb).toList();
      final qn = qc.isEmpty ? 1 : qc.length;
      double qr = 0, qg = 0, qb = 0;
      for (final p in qc) { qr += p[0]; qg += p[1]; qb += p[2]; }
      qr /= qn; qg /= qn; qb /= qn;

      final total = qr + qg + qb + 1;
      results.add(ROIResult(
        r: qr, g: qg, b: qb,
        pallor:  1.0 - (qr / total),
        redness: qr / (qg + qb + 1),
        quality: qn / n,
      ));
    }
    return results;
  }

  static ScanResult score({
    double? hr, double? spo2,
    List<ROIResult>? nailData, List<ROIResult>? palmData,
  }) {
    int score = 0, maxScore = 0;
    final bd = <String, SignalBreakdown>{};

    if (hr != null) {
      maxScore += 20;
      final pts = hr > 110 ? 20 : hr > 100 ? 13 : hr > 90 ? 5 : 0;
      score += pts;
      bd['hr'] = SignalBreakdown(points: pts, max: 20, icon: '❤️',
        label: hr > 110 ? 'Significant tachycardia'
             : hr > 100 ? 'Mild tachycardia'
             : hr > 90  ? 'High-normal HR' : 'Normal HR');
    }
    if (spo2 != null) {
      maxScore += 25;
      final pts = spo2 < 90 ? 25 : spo2 < 94 ? 18 : spo2 < 96 ? 8 : 0;
      score += pts;
      bd['spo2'] = SignalBreakdown(points: pts, max: 25, icon: '🫁',
        label: spo2 < 90 ? 'Very low SpO₂'
             : spo2 < 94 ? 'Low SpO₂'
             : spo2 < 96 ? 'Borderline SpO₂' : 'Normal SpO₂');
    }
    if (nailData != null && nailData.isNotEmpty) {
      maxScore += 30;
      final ap = nailData.map((r)=>r.pallor ).reduce((a,b)=>a+b) / nailData.length;
      final ar = nailData.map((r)=>r.redness).reduce((a,b)=>a+b) / nailData.length;
      final pts = (ap*20 + (1-ar).clamp(0.0,1.0)*10).round().clamp(0,30);
      score += pts;
      bd['nail'] = SignalBreakdown(points: pts, max: 30, icon: '💅',
        pallor: ap, redness: ar,
        label: ap > 0.55 ? 'Pale nail beds' : 'Normal nail bed color');
    }
    if (palmData != null && palmData.isNotEmpty) {
      maxScore += 25;
      final ap = palmData.map((r)=>r.pallor ).reduce((a,b)=>a+b) / palmData.length;
      final ar = palmData.map((r)=>r.redness).reduce((a,b)=>a+b) / palmData.length;
      final pts = (ap*15 + (1-ar).clamp(0.0,1.0)*10).round().clamp(0,25);
      score += pts;
      bd['palm'] = SignalBreakdown(points: pts, max: 25, icon: '🤚',
        pallor: ap, redness: ar,
        label: ap > 0.55 ? 'Pale palm lines' : 'Normal palm color');
    }

    final pct = maxScore > 0 ? (score / maxScore) * 100.0 : 0.0;
    final hgb = (16.0 - (pct/100)*11).clamp(5.0, 17.0);
    Color rc; String rl;
    if (pct >= 65)      { rc = const Color(0xFFEF4444); rl = 'HIGH RISK'; }
    else if (pct >= 40) { rc = const Color(0xFFF97316); rl = 'MODERATE RISK'; }
    else if (pct >= 20) { rc = const Color(0xFFEAB308); rl = 'MILD RISK'; }
    else                { rc = const Color(0xFF0D9488); rl = 'LOW RISK'; }
    return ScanResult(riskPct: pct, estHgb: hgb,
        riskLevel: rl, riskColor: rc, breakdown: bd);
  }
}

// ── Provider ──────────────────────────────────────────────
class ScanProvider extends ChangeNotifier {
  double? hr;
  double? spo2;
  bool    sensorLive = false;
  String  wsStatus   = 'disconnected';
  String  esp32IP    = '192.168.1.100';

  List<ROIResult>? nailData;
  List<ROIResult>? palmData;
  ScanResult?      result;

  WebSocketChannel?   _channel;
  StreamSubscription? _sub;

  bool get canAnalyze   => hr != null || spo2 != null || nailData != null || palmData != null;
  bool get hrAbnormal   => hr   != null && hr!   > 100;
  bool get spo2Abnormal => spo2 != null && spo2! < 95;

  void connectESP32(String ip) {
    esp32IP = ip;
    _disconnect();
    wsStatus = 'connecting';
    notifyListeners();
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:81'));
      wsStatus   = 'connected';
      sensorLive = true;
      notifyListeners();
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final j = jsonDecode(data as String);
            if (j['valid'] == 1 || j['valid'] == true) {
              hr   = (j['hr']   as num).toDouble();
              spo2 = (j['spo2'] as num).toDouble();
              notifyListeners();
            }
          } catch (_) {}
        },
        onError: (_) { wsStatus = 'error';        sensorLive = false; notifyListeners(); },
        onDone:  ()  { wsStatus = 'disconnected'; sensorLive = false; notifyListeners(); },
      );
    } catch (_) { wsStatus = 'error'; sensorLive = false; notifyListeners(); }
  }

  void _disconnect() {
    _sub?.cancel(); _channel?.sink.close();
    _channel = null; _sub = null;
  }

  void setManualHR(double? v)          { hr       = v; notifyListeners(); }
  void setManualSpo2(double? v)        { spo2     = v; notifyListeners(); }
  void setNailData(List<ROIResult>? d) { nailData = d; notifyListeners(); }
  void setPalmData(List<ROIResult>? d) { palmData = d; notifyListeners(); }

  void analyze() {
    result = ColorAnalysis.score(hr: hr, spo2: spo2, nailData: nailData, palmData: palmData);
    notifyListeners();
  }

  void reset() { nailData = null; palmData = null; result = null; notifyListeners(); }

  @override
  void dispose() { _disconnect(); super.dispose(); }
}