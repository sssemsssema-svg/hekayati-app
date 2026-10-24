import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/api_service.dart';
import 'loading_screen.dart';

class BookingScreen extends StatefulWidget {
  final String audioPath;
  const BookingScreen({super.key, required this.audioPath});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _name = TextEditingController();
  String? _gender;               // no default: the parent must choose
  String? _age;                  // no default: the parent must choose
  String _artStyle = 'classic';  // classic | manga | mandala | sketch
  String _imagination = 'ai';    // default = AI imagination

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready => _name.text.trim().isNotEmpty && _gender != null && _age != null;

  void _send() {
    final b = Booking(
      childName: _name.text.trim(),
      gender: _gender!,
      ageGroup: _age!,
      artStyle: _artStyle,
      imagination: _imagination,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => LoadingScreen(audioPath: widget.audioPath, booking: b)),
    );
  }

  void _showServerSettings(BuildContext context) {
    final ipController = TextEditingController(text: ApiService.baseUrl);
    String status = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('عنوان السيرفر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('عنوان IP لجهاز الكمبيوتر مع البورت 8000:'),
              const SizedBox(height: 12),
              TextField(
                controller: ipController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'http://192.168.100.102:8000',
                ),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: status.contains('✅') ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                setDialogState(() => status = 'جاري الاختبار...');
                final ok = await ApiService.testConnection(ipController.text.trim());
                setDialogState(() {
                  status = ok ? 'متصل بنجاح بالسيرفر! ✅' : 'تعذر الاتصال بالسيرفر! ❌';
                });
              },
              child: const Text('اختبار الاتصال'),
            ),
            FilledButton(
              onPressed: () {
                ApiService.baseUrl = ipController.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('احجز حكايتك ✨'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_rounded),
            tooltip: 'إعدادات السيرفر',
            onPressed: () => _showServerSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('اسم البطل / المبدع'),
            TextField(
              controller: _name,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'مثلاً: ليلى أو يوسف',
              ),
            ),
            _label('البطل ولد ولا بنت؟'),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: 'boy', label: Text('ولد 👦')),
                ButtonSegment(value: 'girl', label: Text('بنت 👧')),
              ],
              selected: _gender == null ? {} : {_gender!},
              onSelectionChanged: (s) =>
                  setState(() => _gender = s.isEmpty ? null : s.first),
            ),
            _label('السن'),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: '3-5', label: Text('3 - 5')),
                ButtonSegment(value: '6-10', label: Text('6 - 10')),
                ButtonSegment(value: '11-16', label: Text('11 - 16 🎒')),
              ],
              selected: _age == null ? {} : {_age!},
              onSelectionChanged: (s) {
                if (s.isNotEmpty) {
                  setState(() {
                    _age = s.first;
                    if (_age == '3-5') {
                      _artStyle = 'classic';
                    } else if (_age == '11-16' && _artStyle == 'classic') {
                      _artStyle = 'manga';
                    }
                  });
                }
              },
            ),
            _label('ستايل الرسم المفضل 🎨'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Booking.allStyles.map((s) {
                return ChoiceChip(
                  label: Text(Booking.styleLabel(s)),
                  selected: _artStyle == s,
                  onSelected: (sel) {
                    if (sel) setState(() => _artStyle = s);
                  },
                );
              }).toList(),
            ),
            _label('مستوى الخيال'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'exact', label: Text('زي ما قلتها بالظبط')),
                ButtonSegment(value: 'ai', label: Text('سيبها لخيال الـ AI ✨')),
              ],
              selected: {_imagination},
              onSelectionChanged: (s) => setState(() => _imagination = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _imagination == 'exact'
                  ? 'هنرتّب كلام الطفل لغوياً بس من غير ما نضيف أحداث جديدة.'
                  : 'هناخد كلام الطفل ونبني عليه حكاية مغامرة مبهرة ومرتبة.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _ready ? _send : null,
              icon: const Icon(Icons.send_rounded),
              label: const Text('ابعت الحجز'),
            ),
          ],
        ),
      ),
    );
  }
}
