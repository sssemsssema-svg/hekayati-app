import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/book.dart';
import '../services/pdf_builder.dart';

class BookScreen extends StatefulWidget {
  final Book book;
  const BookScreen({super.key, required this.book});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final _c = PageController();
  final _picker = ImagePicker();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() job, String ok) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) _snack(ok);
    } catch (_) {
      if (mounted) _snack('حصلت مشكلة، جرّب تاني 😢');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPageImage(BookPage page) async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (img != null) {
        setState(() {
          page.localImagePath = img.path;
        });
        _snack('تمت إضافة رسمة صفحة ${page.pageNumber} بنجاح! 🎨');
      }
    } catch (e) {
      _snack('تعذر فتح المعرض 📷');
    }
  }

  Future<void> _pickAllImages() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (images.isNotEmpty) {
        setState(() {
          for (int i = 0; i < images.length && i < widget.book.pages.length; i++) {
            widget.book.pages[i].localImagePath = images[i].path;
          }
        });
        _snack('تم تعيين ${images.length} صورة للصفحات بنجاح! 🖼️');
      }
    } catch (e) {
      _snack('تعذر اختيار الصور 📷');
    }
  }

  String _arabicStyleName(String s) {
    switch (s.toLowerCase()) {
      case 'manga':
        return 'مانجا / كوميك';
      case 'mandala':
        return 'ماندالا وفنون';
      case 'sketch':
        return 'اسكتشات ورسم حر';
      case 'classic':
        return 'تلوين كلاسيكي';
      default:
        return s.isNotEmpty ? s : 'تلوين مخصص';
    }
  }

  Widget _cover(TextTheme text, int totalPages) {
    int imagesAttached = widget.book.pages.where((p) => p.localImagePath != null).length;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📖', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 14),
            Text(
              widget.book.title,
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    'كتاب من $totalPages صفحات',
                    style: TextStyle(
                      color: Colors.purple.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (widget.book.artStyle.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      _arabicStyleName(widget.book.artStyle),
                      style: TextStyle(
                        color: Colors.brown.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Images attached status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: imagesAttached > 0 ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: imagesAttached > 0 ? Colors.green.shade300 : Colors.blue.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    imagesAttached > 0 ? Icons.check_circle : Icons.photo_library,
                    color: imagesAttached > 0 ? Colors.green.shade700 : Colors.blue.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    imagesAttached > 0
                        ? 'تم إرفاق $imagesAttached من $totalPages رسومات جاهزة للـ PDF'
                        : 'يمكنك إرفاق الصور لتجميع كتيب PDF جاهز للطباعة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: imagesAttached > 0 ? Colors.green.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bulk pick button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple.shade700,
                side: BorderSide(color: Colors.purple.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _pickAllImages,
              icon: const Icon(Icons.add_photo_alternate, size: 20),
              label: const Text(
                'اختيار كل صور القصة من المعرض دفعة واحدة 🖼️',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),

            if (widget.book.transcript.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🎙️ فكرة القصة من تسجيلك:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"${widget.book.transcript}"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back, size: 18, color: Colors.purple.shade400),
                const SizedBox(width: 8),
                Text('اسحب لقلب الصفحة وإرفاق الرسومات', style: text.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(BookPage p, TextTheme text, int totalPages) {
    final hasPrompt = p.imagePrompt.trim().isNotEmpty;
    final hasLocalImage = p.localImagePath != null && File(p.localImagePath!).existsSync();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'صفحة ${p.pageNumber} من $totalPages',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (p.artStyle.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _arabicStyleName(p.artStyle),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Image preview container
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasLocalImage ? Colors.green.shade400 : Colors.grey.shade300,
                width: hasLocalImage ? 2 : 1,
              ),
              boxShadow: const [
                BoxShadow(blurRadius: 8, color: Colors.black12, offset: Offset(0, 3)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: hasLocalImage
                ? Image.file(
                    File(p.localImagePath!),
                    fit: BoxFit.contain,
                  )
                : (p.imageUrl.isNotEmpty
                    ? Image.network(
                        p.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (c, w, prog) => prog == null
                            ? w
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (c, e, s) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.brush, size: 48, color: Colors.purple.shade200),
                              const SizedBox(height: 8),
                              Text('صفحة تلوين رقم ${p.pageNumber}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 54, color: Colors.purple.shade200),
                            const SizedBox(height: 8),
                            Text('اضغط الزر بالأسفل لإرفاق صورة هذه الصفحة من المعرض 🖼️',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      )),
          ),
          const SizedBox(height: 10),

          // Button to pick image for this specific page
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              backgroundColor: hasLocalImage ? Colors.green.shade50 : Colors.purple.shade50,
              foregroundColor: hasLocalImage ? Colors.green.shade800 : Colors.purple.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: hasLocalImage ? Colors.green.shade300 : Colors.purple.shade200,
                ),
              ),
            ),
            onPressed: () => _pickPageImage(p),
            icon: Icon(
              hasLocalImage ? Icons.check_circle : Icons.add_photo_alternate,
              size: 20,
            ),
            label: Text(
              hasLocalImage
                  ? 'تم إرفاق الصورة (اضغط للتغيير) 🔄'
                  : '📷 اختيار رسمة صفحة ${p.pageNumber} من المعرض',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 14),

          // Arabic narration card
          Card(
            elevation: 1,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.amber.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('📜 ', style: TextStyle(fontSize: 18)),
                      Text(
                        'نص القصة لهذه الصفحة:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown.shade800,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'نسخ نص القصة',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: p.narration));
                          _snack('تم نسخ نص القصة 📋');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.narration,
                    style: text.bodyLarge?.copyWith(
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Image prompt card for external generation
          if (hasPrompt)
            Card(
              elevation: 2,
              color: const Color(0xFFFAF7FD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.purple.shade100, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette, color: Colors.purple.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'برومبت توليد الصورة (للمواقع الخارجية):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        p.imagePrompt,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: p.imagePrompt));
                        _snack('تم نسخ البرومبت! الصقه في Bing أو Leonardo أو ChatGPT ✨');
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text(
                        'نسخ برومبت الصفحة 📋',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pages = widget.book.pages;
    final totalPages = pages.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'اختيار كل الصور من المعرض دفعة واحدة',
            onPressed: _pickAllImages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _c,
              itemCount: totalPages + 1,
              itemBuilder: (context, i) {
                return AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    double v = -i.toDouble();
                    if (_c.hasClients && _c.position.haveDimensions) {
                      v = (_c.page ?? 0) - i;
                    }
                    v = v.clamp(-1.0, 1.0);
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(v * 0.8),
                      child: Opacity(
                        opacity: (1 - v.abs() * 0.6).clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: i == 0 ? _cover(text, totalPages) : _page(pages[i - 1], text, totalPages),
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => PdfBuilder.save(widget.book),
                                'تم تصدير كتيب PDF بنجاح 📑',
                              ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download, size: 22),
                          SizedBox(height: 4),
                          Text(
                            'حفظ PDF 📑',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => PdfBuilder.print(widget.book),
                                'تم فتح نافذة الطباعة 🖨️',
                              ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.print, size: 22),
                          SizedBox(height: 4),
                          Text(
                            'طباعة 🖨️',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => PdfBuilder.share(widget.book),
                                'تمت المشاركة بنجاح 📤',
                              ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share, size: 22),
                          SizedBox(height: 4),
                          Text(
                            'مشاركة 📤',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
