import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/booking.dart';
import '../services/api_service.dart';

class SingleArtScreen extends StatefulWidget {
  const SingleArtScreen({super.key});

  @override
  State<SingleArtScreen> createState() => _SingleArtScreenState();
}

class _SingleArtScreenState extends State<SingleArtScreen> {
  final _textController = TextEditingController();
  final _rec = AudioRecorder();
  
  bool _useVoice = false;
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _timer;
  String? _audioPath;

  String _ageGroup = '11-16';
  String _gender = 'boy';
  String _artStyle = 'manga';
  bool _includeText = false;
  bool _loading = false;

  @override
  void dispose() {
    _textController.dispose();
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _startRecording() async {
    if (!await _rec.hasPermission()) {
      _snack('محتاجين إذن المايك لتسجيل فكرتك 🎤');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/single_art_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordSeconds = 0;
      _audioPath = path;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _recordSeconds++);
      if (_recordSeconds >= 120) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _rec.stop();
    setState(() {
      _recording = false;
      _audioPath = path;
    });
    _snack('تم تسجيل فكرتك بنجاح 🎙️');
  }

  Future<void> _generate() async {
    final textDesc = _textController.text.trim();
    if (!_useVoice && textDesc.isEmpty) {
      _snack('يرجى كتابة وصف للرسمة التي تتخيلها ✍️');
      return;
    }
    if (_useVoice && (_audioPath == null || !File(_audioPath!).existsSync())) {
      _snack('يرجى تسجيل فكرتك بالمايك أولاً 🎤');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.createSingleArt(
        ageGroup: _ageGroup,
        gender: _gender,
        artStyle: _artStyle,
        descriptionText: textDesc,
        audioPath: _useVoice ? _audioPath : null,
        includeText: _includeText,
      );

      if (!mounted) return;
      _showResultDialog(res);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceAll('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResultDialog(SingleArtResponse res) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('🎨', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      res.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  res.conceptAr,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.brown.shade900,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'برومبت توليد الصورة للمواقع الخارجية:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  res.promptEn,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: res.promptEn));
                  Navigator.pop(ctx);
                  _snack('تم نسخ البرومبت بنجاح! الصقه في Bing أو Leonardo أو ChatGPT ✨');
                },
                icon: const Icon(Icons.copy, size: 20),
                label: const Text(
                  'نسخ البرومبت بالكامل 📋',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تصميم لوحة تلوين بالوصف'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode toggle: text vs voice
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('كتابة نص الوصف ✍️')),
                    selected: !_useVoice,
                    onSelected: (v) => setState(() => _useVoice = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('تسجيل بالصوت 🎤')),
                    selected: _useVoice,
                    onSelected: (v) => setState(() => _useVoice = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Text input or voice box
            if (!_useVoice)
              TextField(
                controller: _textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب وصف اللوحة التي تتخيلها...\nمثال: ماندالا ذئب أسطوري في غابة تحت ضوء القمر، أو بطل أنمي في معركة خيالية',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      _recording ? Icons.mic : Icons.mic_none,
                      size: 48,
                      color: _recording ? Colors.red : Colors.purple,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recording
                          ? 'جاري التسجيل... ($_recordSeconds ثانية)'
                          : (_audioPath != null ? 'تم تسجيل فكرتك بالصوت بنجاح' : 'اضغط على الزر لتسجيل وصف اللوحة بالمايك'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _recording ? Colors.red : Colors.purple.shade900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _recording ? Colors.red : Colors.purple.shade700,
                      ),
                      onPressed: _recording ? _stopRecording : _startRecording,
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(_recording ? 'إيقاف التسجيل ⏹️' : 'بدء تسجيل فكرتك 🎙️'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            Text('الفئة العمرية المستهدفة:', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ageChip('3-5', '3 - 5 سنوات 👶'),
                _ageChip('6-10', '6 - 10 سنوات 🎒'),
                _ageChip('11-16', '11 - 16 سنة 🎧'),
                _ageChip('adult', 'كبار وبالغين 🧘'),
              ],
            ),

            const SizedBox(height: 20),
            Text('طابع العمل والنوع:', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _genderChip('boy', 'ولد / فتى 👦'),
                _genderChip('girl', 'بنت / فتاة 👧'),
                _genderChip('neutral', 'عام / طبيعة 🌟'),
              ],
            ),

            const SizedBox(height: 20),
            Text('طريقة وأسلوب الرسم (اختر الستايل المفضل):', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Booking.allStyles.map((s) => _styleChip(s)).toList(),
            ),

            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('كتابة نص الوصف أسفل الرسمة 📜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: const Text('إظهار شريط نصي عربي أسفل لوحة التلوين', style: TextStyle(fontSize: 12)),
              value: _includeText,
              onChanged: (v) => setState(() => _includeText = v ?? false),
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 22),
              label: Text(
                _loading ? 'جاري صياغة وتوليد البرومبت...' : 'توليد برومبت اللوحة الفنية 🎨',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ageChip(String val, String label) => ChoiceChip(
        label: Text(label),
        selected: _ageGroup == val,
        onSelected: (v) => setState(() => _ageGroup = val),
      );

  Widget _genderChip(String val, String label) => ChoiceChip(
        label: Text(label),
        selected: _gender == val,
        onSelected: (v) => setState(() => _gender = val),
      );

  Widget _styleChip(String s) => ChoiceChip(
        label: Text(Booking.styleLabel(s)),
        selected: _artStyle == s,
        onSelected: (v) => setState(() => _artStyle = s),
      );
}
