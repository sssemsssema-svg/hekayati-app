import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/book.dart';

class PdfBuilder {
  /// Local picked image wins; otherwise fetch the AI image from imageUrl.
  static Future<pw.ImageProvider?> _resolvePageImage(BookPage page) async {
    final local = page.localImagePath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      try {
        final bytes = await File(local).readAsBytes();
        if (_isSupportedImage(bytes)) return pw.MemoryImage(bytes);
      } catch (_) {}
    }

    final url = page.imageUrl.trim();
    if (url.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 && _isSupportedImage(res.bodyBytes)) {
        return pw.MemoryImage(res.bodyBytes);
      }
    } catch (_) {
      // Network/timeout/bad URL: fall back to the placeholder box.
    }
    return null;
  }

  /// PNG or JPEG magic bytes only. Prevents a bad payload from crashing pdf.save().
  static bool _isSupportedImage(Uint8List b) {
    if (b.length < 4) return false;
    final isPng = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
    final isJpeg = b[0] == 0xFF && b[1] == 0xD8;
    return isPng || isJpeg;
  }

  static Future<Uint8List> generate(Book book) async {
    final pdf = pw.Document();

    // Load Arabic Font
    final pw.Font arabicFont;
    final pw.Font arabicBold;
    try {
      arabicFont = await PdfGoogleFonts.cairoRegular();
      arabicBold = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      throw Exception('تعذر تحميل خط Cairo، تأكد من اتصال الإنترنت');
    }

    // 1. Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 90,
                  height: 90,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColors.purple800, width: 3),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      book.title.isNotEmpty ? book.title.substring(0, 1) : 'ح',
                      style: const pw.TextStyle(fontSize: 40, color: PdfColors.purple800),
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  book.title,
                  style: const pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.purple900,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.purple50,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: PdfColors.purple200),
                  ),
                  child: pw.Text(
                    'كتاب تلوين وقصة مصورة (${book.pages.length} صفحة)',
                    style: const pw.TextStyle(
                      fontSize: 13,
                      color: PdfColors.purple800,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (book.transcript.isNotEmpty) ...[
                  pw.SizedBox(height: 24),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                    child: pw.Text(
                      '"${book.transcript}"',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    // 2. Story Pages
    // Resolve all page images in parallel (local file first, then AI imageUrl).
    final List<pw.ImageProvider?> pageImages =
        await Future.wait(book.pages.map(_resolvePageImage));

    for (int i = 0; i < book.pages.length; i++) {
      final page = book.pages[i];
      final pw.ImageProvider? imageProvider = pageImages[i];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'صفحة ${page.pageNumber} من ${book.pages.length}',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      book.title,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),

                // Image Box (Top ~70%)
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
                    ),
                    child: imageProvider != null
                        ? pw.Center(
                            child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
                          )
                        : pw.Center(
                            child: pw.Text(
                              'مكان رسمة التلوين لصفحة ${page.pageNumber}',
                              style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey500),
                            ),
                          ),
                  ),
                ),
                pw.SizedBox(height: 14),

                // Arabic Narration Banner (Bottom ~30%)
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.amber200),
                  ),
                  child: pw.Text(
                    page.narration,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      lineSpacing: 3,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static Future<void> save(Book book) async {
    final bytes = await generate(book);
    final filename = '${book.title.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')}.pdf';
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename.trim().isNotEmpty ? filename.trim() : 'hekayati.pdf',
    );
  }

  static Future<void> print(Book book) async {
    final bytes = await generate(book);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> share(Book book) async {
    final bytes = await generate(book);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/hekayati_book.pdf');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path)], text: 'كتيبي الجميل للتلوين والقصة المصورة! 🎨📖');
  }
}
