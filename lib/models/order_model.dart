class CustomerOrder {
  final String id;
  final String createdAt;
  final String customerName;
  final String customerPhone;
  final String childName;
  final String childGender;
  final String childAge;
  final String orderType;
  final String artStyle;
  final String storyIdea;
  final String? audioFilename;
  final String status;
  final String? notes;
  final String? resultJobId;

  CustomerOrder({
    required this.id,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.childName,
    required this.childGender,
    required this.childAge,
    required this.orderType,
    required this.artStyle,
    required this.storyIdea,
    this.audioFilename,
    required this.status,
    this.notes,
    this.resultJobId,
  });

  bool get isStorybook => orderType == 'storybook';
  bool get hasAudio => audioFilename != null && audioFilename!.isNotEmpty;

  String get statusArabic {
    switch (status) {
      case 'pending':
        return 'طلب جديد ⏳';
      case 'processing':
        return 'جاري التنفيذ ✨';
      case 'completed':
        return 'مكتمل وجاهز ✅';
      case 'failed':
        return 'تعذر التنفيذ ❌';
      default:
        return status;
    }
  }

  String get styleArabic {
    switch (artStyle) {
      case 'chibi':
        return 'تشيبي ولطيف';
      case 'storybook':
        return 'كرتون حكايات';
      case 'manga':
        return 'مانجا وأنمي';
      case 'comic':
        return 'كوميك بوك';
      case 'sketch':
        return 'سكتش يدوي رصاص';
      case 'mandala':
        return 'ماندالا هندسية';
      case 'fantasy':
        return 'فانتازيا أسطورية';
      case 'popart':
        return 'بوب آرت';
      case 'pixel':
        return 'بكسل آرت';
      case 'classic':
        return 'كلاسيكي';
      default:
        return artStyle;
    }
  }

  factory CustomerOrder.fromJson(Map<String, dynamic> j) {
    return CustomerOrder(
      id: j['id'] ?? '',
      createdAt: j['created_at'] ?? '',
      customerName: j['customer_name'] ?? '',
      customerPhone: j['customer_phone'] ?? '',
      childName: j['child_name'] ?? '',
      childGender: j['child_gender'] ?? 'boy',
      childAge: j['child_age'] ?? '6-10',
      orderType: j['order_type'] ?? 'storybook',
      artStyle: j['art_style'] ?? 'storybook',
      storyIdea: j['story_idea'] ?? '',
      audioFilename: j['audio_filename'],
      status: j['status'] ?? 'pending',
      notes: j['notes'],
      resultJobId: j['result_job_id'],
    );
  }
}
