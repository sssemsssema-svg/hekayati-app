class BookPage {
  final int pageNumber;
  final String imageUrl;
  final String narration;
  final String imagePrompt;
  final String artStyle;
  String? localImagePath;

  BookPage({
    required this.pageNumber,
    required this.imageUrl,
    required this.narration,
    this.imagePrompt = '',
    this.artStyle = '',
    this.localImagePath,
  });

  factory BookPage.fromJson(Map<String, dynamic> j) => BookPage(
        pageNumber: j['page_number'] ?? 1,
        imageUrl: j['image_url'] ?? '',
        narration: j['narration_ar'] ?? '',
        imagePrompt: j['image_prompt_en'] ?? '',
        artStyle: j['art_style'] ?? '',
      );
}

class Book {
  final String title;
  final String transcript;
  final String artStyle;
  final List<BookPage> pages;
  final String pdfUrl;

  Book({
    required this.title,
    this.transcript = '',
    this.artStyle = '',
    required this.pages,
    required this.pdfUrl,
  });
}

class JobStatus {
  final String status; // processing | done | failed
  final int progress;
  final String stepLabel;
  final String? error;
  final bool unsafe;
  final Book? book;

  JobStatus({
    required this.status,
    required this.progress,
    required this.stepLabel,
    this.error,
    this.unsafe = false,
    this.book,
  });

  factory JobStatus.fromJson(Map<String, dynamic> j) {
    Book? book;
    if (j['status'] == 'done') {
      book = Book(
        title: j['title'] ?? '',
        transcript: j['transcript_ar'] ?? '',
        artStyle: j['art_style'] ?? '',
        pages: (j['pages'] as List? ?? [])
            .map((e) => BookPage.fromJson(e as Map<String, dynamic>))
            .toList(),
        pdfUrl: j['pdf_url'] ?? '',
      );
    }
    return JobStatus(
      status: j['status'] ?? 'processing',
      progress: (j['progress'] ?? 0) as int,
      stepLabel: j['step_label_ar'] ?? '',
      error: j['error'],
      unsafe: j['unsafe'] ?? false,
      book: book,
    );
  }
}
