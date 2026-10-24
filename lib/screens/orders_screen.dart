import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/order_model.dart';
import '../services/api_service.dart';
import 'book_screen.dart';
import 'loading_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _loading = true;
  String? _error;
  List<CustomerOrder> _orders = [];
  String _filter = 'all'; // 'all' or 'pending'
  String? _processingOrderId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getOrders(status: _filter);
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('ApiException: ', '');
        _loading = false;
      });
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _processOrder(CustomerOrder order) async {
    setState(() => _processingOrderId = order.id);
    try {
      final res = await ApiService.processOrder(order.id);
      if (!mounted) return;

      if (order.isStorybook && res['job_id'] != null) {
        final jobId = res['job_id'] as String;
        _snack('جاري تجهيز كتاب البطل ${order.childName} ✨');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LoadingScreen(jobId: jobId)),
        ).then((_) => _loadOrders());
      } else if (!order.isStorybook && res['single_art'] != null) {
        final art = res['single_art'];
        _showSingleArtDialog(art);
        _loadOrders();
      } else {
        _snack('تم بدء المعالجة بنجاح');
        _loadOrders();
      }
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _processingOrderId = null);
    }
  }

  void _showSingleArtDialog(Map<String, dynamic> art) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(art['title'] ?? 'لوحة التلوين جاهزة 🎨'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                art['concept_ar'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('البرومبت الإنجليزي لتوليد الصورة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  art['prompt_en'] ?? '',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: art['prompt_en'] ?? ''));
              Navigator.pop(ctx);
              _snack('تم نسخ البرومبت بنجاح! 📋');
            },
            icon: const Icon(Icons.copy),
            label: const Text('نسخ البرومبت'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزات وطلبات العملاء 📥'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الطلبات',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.purple.shade50.withOpacity(0.5),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('جميع الطلبات'),
                  selected: _filter == 'all',
                  onSelected: (val) {
                    if (val) {
                      setState(() => _filter = 'all');
                      _loadOrders();
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('قيد الانتظار ⏳'),
                  selected: _filter == 'pending',
                  onSelected: (val) {
                    if (val) {
                      setState(() => _filter = 'pending');
                      _loadOrders();
                    }
                  },
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_rounded, size: 54, color: Colors.orange),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadOrders,
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  _filter == 'pending'
                                      ? 'لا توجد طلبات جديدة قيد الانتظار 🎉'
                                      : 'لم يتم استلام أي حجوزات حتى الآن.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _orders.length,
                              itemBuilder: (context, idx) {
                                final order = _orders[idx];
                                return _buildOrderCard(order);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(CustomerOrder order) {
    final isProcessingThis = _processingOrderId == order.id;

    Color statusColor;
    switch (order.status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'processing':
        statusColor = Colors.blue;
        break;
      case 'failed':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.deepOrange;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order ID & Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    '#${order.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.statusArabic,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Hero & Details Row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: order.childGender == 'girl' ? Colors.pink.shade100 : Colors.blue.shade100,
                  child: Text(
                    order.childGender == 'girl' ? '👧' : '👦',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'البطل: ${order.childName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'العمر: ${order.childAge} سنة  •  النوع: ${order.isStorybook ? "📖 كتاب وقصة" : "🎨 لوحة تلوين"}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Style & Customer contact
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.brush_outlined, size: 16, color: Colors.purple),
                      const SizedBox(width: 6),
                      Text(
                        'الستايل المطلوب: ${order.styleArabic}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'العميل: ${order.customerName} (${order.customerPhone})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: 'نسخ رقم الهاتف',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: order.customerPhone));
                          _snack('تم نسخ رقم الهاتف: ${order.customerPhone}');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Idea or voice note
            if (order.storyIdea.isNotEmpty || order.hasAudio) ...[
              const SizedBox(height: 10),
              if (order.storyIdea.isNotEmpty)
                Text(
                  '💡 الفكرة: "${order.storyIdea}"',
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              if (order.hasAudio)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.mic, size: 18, color: Colors.red.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'يوجد تسجيل صوتي مرفق من العميل 🎙️',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // Action Buttons
            const SizedBox(height: 14),
            Row(
              children: [
                if (order.status == 'completed' && order.resultJobId != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final s = await ApiService.getStatus(order.resultJobId!);
                          if (s.book != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookScreen(book: s.book!),
                              ),
                            );
                          } else {
                            _snack('الكتاب لم يكتمل بعد');
                          }
                        } catch (e) {
                          _snack('تعذر فتح الكتاب: $e');
                        }
                      },
                      icon: const Icon(Icons.menu_book),
                      label: const Text('فتح الكتاب الجاهز 📖'),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: isProcessingThis ? null : () => _processOrder(order),
                      icon: isProcessingThis
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        isProcessingThis
                            ? 'جاري التجهيز...'
                            : order.isStorybook
                                ? 'توليد وتجهيز الكتاب الآن ✨'
                                : 'توليد برومبت اللوحة الآن 🎨',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
