import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfActions {
  static Future<Uint8List> _bytes(String url) async {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('download failed');
    return res.bodyBytes;
  }

  /// Opens the system "save / share" sheet so the user can save it to Files / Drive.
  static Future<void> save(String url) async {
    final bytes = await _bytes(url);
    await Printing.sharePdf(bytes: bytes, filename: 'hekayati.pdf');
  }

  static Future<void> print(String url) async {
    final bytes = await _bytes(url);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> share(String url) async {
    final bytes = await _bytes(url);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/hekayati.pdf');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path)], text: 'شوف حكايتي الملونة! 🎨');
  }
}
