import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/api_service.dart';
import 'book_screen.dart';

class LoadingScreen extends StatefulWidget {
  final String? audioPath;
  final Booking? booking;
  final String? jobId;

  const LoadingScreen({
    super.key,
    this.audioPath,
    this.booking,
    this.jobId,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  static const int timeoutSeconds = 180;
  late final AnimationController _bounce =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);
  int _progress = 0;
  String _label = 'بنجهّز كل حاجة...';
  String? _error;
  bool _unsafe = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _cancelled = true;
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _unsafe = false;
      _progress = 0;
      _label = 'بنجهّز كل حاجة...';
    });
    try {
      final String id;
      if (widget.jobId != null && widget.jobId!.isNotEmpty) {
        id = widget.jobId!;
      } else {
        id = await ApiService.uploadAudio(widget.audioPath!, widget.booking!);
      }
      final deadline = DateTime.now().add(const Duration(seconds: timeoutSeconds));
      while (!_cancelled) {
        if (DateTime.now().isAfter(deadline)) {
          throw ApiException('الحكاية أخدت وقت أطول من المتوقع، جرّب تاني');
        }
        await Future.delayed(const Duration(seconds: 2));
        if (_cancelled || !mounted) return;
        final s = await ApiService.getStatus(id);
        if (!mounted) return;
        if (s.status == 'done') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => BookScreen(book: s.book!)));
          return;
        }
        if (s.status == 'failed') {
          setState(() {
            _error = s.error ?? 'حصلت مشكلة، جرّب تاني';
            _unsafe = s.unsafe;
          });
          return;
        }
        setState(() {
          _progress = s.progress;
          _label = s.stepLabel;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بالسيرفر 📶\nتأكد أن الموبايل والكمبيوتر على نفس شبكة الواي فاي');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: _error != null ? _errorView(text) : _progressView(text),
          ),
        ),
      ),
    );
  }

  Widget _progressView(TextTheme text) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.2).animate(
                CurvedAnimation(parent: _bounce, curve: Curves.easeInOut)),
            child: const Text('🎨', style: TextStyle(fontSize: 96)),
          ),
          const SizedBox(height: 32),
          Text(_label, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
                value: _progress / 100, minHeight: 16),
          ),
          const SizedBox(height: 8),
          Text('$_progress%'),
        ],
      );

  Widget _errorView(TextTheme text) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_unsafe ? '🌈' : '😢', style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text(_error!, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (_unsafe)
            FilledButton(
                onPressed: () => Navigator.pop(context), child: const Text('حكاية جديدة'))
          else
            FilledButton.icon(
                onPressed: _run,
                icon: const Icon(Icons.refresh),
                label: const Text('حاول تاني')),
        ],
      );
}
