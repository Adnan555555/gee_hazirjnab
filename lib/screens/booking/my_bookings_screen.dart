import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';
import '../../models/booking.dart';
import '../../widgets/common_widgets.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchBookings();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<BookingProvider>().fetchBookings();
  }

  // ──── Actions ────

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dial $phoneNumber')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final url = Uri.parse('https://wa.me/${phoneNumber.replaceAll(RegExp(r'[^0-9]'), '')}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openMap(double? lat, double? lng, String address) async {
    if (lat != null && lng != null) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showCancelBookingDialog(Booking booking) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Entire Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cancel all ${booking.activeItemCount} service(s) in #${booking.bookingNumber}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelBooking(booking.id, booking.bookingNumber, reasonCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }

  void _showCancelItemDialog(Booking booking, BookingItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Service'),
        content: Text('Cancel "${item.serviceName}" from this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelItem(booking.id, item.id, item.serviceName);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(int id, String number, String reason) async {
    _showLoading();
    final ok = await context.read<BookingProvider>().cancelBooking(id, reason: reason.isEmpty ? null : reason);
    if (mounted) Navigator.pop(context);
    _showResult(ok, ok ? 'Order #$number cancelled' : 'Failed to cancel');
  }

  Future<void> _cancelItem(int bookingId, int itemId, String name) async {
    _showLoading();
    final ok = await context.read<BookingProvider>().cancelItem(bookingId, itemId);
    if (mounted) Navigator.pop(context);
    _showResult(ok, ok ? '"$name" cancelled' : 'Failed to cancel');
  }

  void _showLoading() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  }

  void _showResult(bool ok, String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red, duration: const Duration(seconds: 2)),
      );
    }
  }

  // ──── Booking Details Bottom Sheet ────

  void _showBookingDetails(Booking booking, {required bool allowCancel}) {
    final status = booking.status.toLowerCase();
    final statusColor = _statusColor(status);
    final canCancel = allowCancel && (status == 'pending' || status == 'assigned');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(booking.categoryName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 2),
                          Text('#${booking.bookingNumber}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    _statusBadge(status, statusColor),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Date & Time
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Text('${booking.date} • ${booking.time}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Services Section
                    const Text('Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    ...booking.items.map((item) => _itemRow(booking, item, canCancel: canCancel)),
                    const SizedBox(height: 8),
                    // Total
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('Rs.${booking.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                        ],
                      ),
                    ),

                    // Handyman Section
                    if (booking.handyman != null) ...[
                      const SizedBox(height: 20),
                      const Text('Assigned Handyman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: booking.handyman!.profileImage != null
                                  ? NetworkImage(booking.handyman!.profileImage!)
                                  : null,
                              child: booking.handyman!.profileImage == null
                                  ? const Icon(Icons.person, size: 20, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(booking.handyman!.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(booking.handyman!.mobile,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            _iconBtn(Icons.call, Colors.green, () => _makePhoneCall(booking.handyman!.mobile)),
                            const SizedBox(width: 8),
                            _iconBtn(Icons.chat, const Color(0xFF25D366), () => _openWhatsApp(booking.handyman!.mobile)),
                          ],
                        ),
                      ),
                    ],

                    // Address Section
                    if (booking.address != null) ...[
                      const SizedBox(height: 20),
                      const Text('Service Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openMap(booking.address!.latitude, booking.address!.longitude, booking.address!.address),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(booking.address!.address,
                                    style: TextStyle(fontSize: 13, color: Colors.blue[800])),
                              ),
                              Icon(Icons.open_in_new, size: 16, color: Colors.blue[400]),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Cancel Order Button
                    if (canCancel) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCancelBookingDialog(booking);
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel Entire Order'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──── Build ────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.secondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'In-Process'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _onRefresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(provider.inProcess, 'No active bookings', allowCancel: true),
              _buildList(provider.completed, 'No completed bookings', allowCancel: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<Booking> bookings, String empty, {required bool allowCancel}) {
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(empty, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: bookings.length,
        itemBuilder: (_, i) => _buildCard(bookings[i], allowCancel: allowCancel),
      ),
    );
  }

  // ──── Compact Card ────

  Widget _buildCard(Booking booking, {required bool allowCancel}) {
    final status = booking.status.toLowerCase();
    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: () => _showBookingDetails(booking, allowCancel: allowCancel),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Category + Status badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.home_repair_service_rounded, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(booking.categoryName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('#${booking.bookingNumber}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      _statusBadge(status, statusColor),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Services summary
                  Text(booking.servicesText,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  // Divider
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 10),
                  // Row 3: Date + Amount
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('${booking.date} • ${booking.time}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const Spacer(),
                      Text('Rs.${booking.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                    ],
                  ),
                ],
              ),
            ),
            // Tap hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Tap to view details',
                      style: TextStyle(fontSize: 11, color: AppTheme.primary.withOpacity(0.7))),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_up, size: 14, color: AppTheme.primary.withOpacity(0.7)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──── Item Row ────

  Widget _itemRow(Booking booking, BookingItem item, {required bool canCancel}) {
    final cancelled = item.isCancelled;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cancelled ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Service info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.serviceName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      color: cancelled ? Colors.grey : Colors.black87,
                    )),
                const SizedBox(height: 2),
                Text('${item.quantity} × Rs.${item.price.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11, color: cancelled ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          // Price or badge
          if (cancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
              child: const Text('CANCELLED', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
            )
          else ...[
            Text('Rs.${item.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (canCancel) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showCancelItemDialog(booking, item),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.close, size: 14, color: Colors.red),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ──── Reusable Widgets ────

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppTheme.warning;
      case 'completed': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      case 'assigned': return AppTheme.info;
      case 'in_progress': return Colors.blue;
      default: return AppTheme.info;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
