import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'booking_screen.dart';
import 'orders_screen.dart';
import 'single_art_screen.dart';

enum _S { idle, recording, recorded }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const int maxSeconds = 180;
  final _rec = AudioRecorder();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  _S _state = _S.idle;
  int _seconds = 0;
  Timer? _timer;
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _rec.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      _snack('محتاجين إذن المايك علشان نسمع حكايتك 🎤');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: path,
    );
    setState(() {
      _state = _S.recording;
      _seconds = 0;
      _path = null;
    });
    _pulse.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      if (_seconds >= maxSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    if (_state != _S.recording) return;
    _timer?.cancel();
    _pulse.stop();
    _pulse.value = 0;
    final p = await _rec.stop();
    if (!mounted) return;
    if (_seconds < 2 || p == null) {
      setState(() => _state = _S.idle);
      _snack('الحكاية قصيرة قوي، جرّب تاني 😊');
      return;
    }
    setState(() {
      _state = _S.recorded;
      _path = p;
    });
  }

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final recording = _state == _S.recording;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('حكاياتي الملونة 🎨'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox_rounded),
            tooltip: 'حجوزات وطلبات العملاء',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'تصميم لوحة تلوين بالوصف',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SingleArtScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  recording
                      ? 'بنسمعك... احكي حكايتك!'
                      : _state == _S.recorded
                          ? 'حلو! تحب نبعتها؟'
                          : 'دوس على الزرار واحكيلي حكاية',
                  style: text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple.shade700,
                        side: BorderSide(color: Colors.purple.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SingleArtScreen()),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text(
                        'لوحة تلوين بالوصف 🎨',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purple.shade50,
                        foregroundColor: Colors.purple.shade900,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrdersScreen()),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                      label: const Text(
                        'حجوزات الموقع 📥',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (_state != _S.recorded)
                  GestureDetector(
                    onTap: recording ? _stop : _start,
                    child: ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.15).animate(_pulse),
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: recording ? Colors.red : const Color(0xFFFF7043),
                          boxShadow: [
                            BoxShadow(
                              color: (recording ? Colors.red : Colors.deepOrange)
                                  .withOpacity(0.4),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded,
                            size: 90, color: Colors.white),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(_time, style: text.headlineMedium),
                Text('الحد الأقصى 3 دقائق', style: text.bodySmall),
                const SizedBox(height: 32),
                if (_state == _S.recorded)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _state = _S.idle;
                          _seconds = 0;
                        }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('من جديد'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => BookingScreen(audioPath: _path!)),
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('ابعت'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
