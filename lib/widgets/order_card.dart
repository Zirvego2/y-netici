import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order.dart';

class OrderCard extends StatefulWidget {
  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onAssignCourier;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onAssignCourier,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst kısım: Platform ikonu + Paket ID
              Row(
                children: [
                  // Platform ikonu (eğer varsa)
                  if (order.platformIconPath != null)
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey[100],
                      ),
                      child: Image.asset(
                        order.platformIconPath!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.shopping_bag, size: 14);
                        },
                      ),
                    ),
                  // Paket ID (s_id)
                  Text(
                    '#${order.sId}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                  const Spacer(),
                  // Durum badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Color(order.statusColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Color(order.statusColor).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      order.statusWithTime,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(order.statusColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  // Detay butonu
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onTap,
                    tooltip: 'Detaylar',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Restoran bilgisi
              Row(
                children: [
                  const Icon(Icons.restaurant, size: 11, color: Colors.grey),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.restaurantName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (order.restaurantPhone != null)
                          Text(
                            order.restaurantPhone!,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Adres
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 11, color: Colors.grey),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      order.customer.address,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Alt bilgiler: Zaman, Ödeme, Kurye
              Row(
                children: [
                  // Zaman
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 10, color: Colors.grey),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            order.formattedCreateTime,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Ödeme
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.payment, size: 10, color: Colors.grey),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${order.payment.typeName} - ${order.payment.amount.toStringAsFixed(0)} TL',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Kurye bilgisi ve atama butonu
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    size: 10,
                    color: order.sCourier > 0 ? const Color(0xFF1E3A8A) : Colors.red,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      order.sCourier > 0
                          ? (order.courierName != null
                              ? 'Kurye: ${order.courierName}'
                              : 'Kurye: #${order.sCourier}')
                          : 'Atama Bekliyor',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: order.sCourier > 0 ? const Color(0xFF1E3A8A) : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.onAssignCourier != null)
                    InkWell(
                      onTap: widget.onAssignCourier,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order.sCourier > 0
                              ? Colors.orange.withOpacity(0.1)
                              : const Color(0xFF1E3A8A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: order.sCourier > 0
                                ? Colors.orange
                                : const Color(0xFF1E3A8A),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              order.sCourier > 0 ? Icons.swap_horiz : Icons.person_add,
                              size: 14,
                              color: order.sCourier > 0
                                  ? Colors.orange[700]
                                  : const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              order.sCourier > 0 ? 'Değiştir' : 'Ata',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: order.sCourier > 0
                                    ? Colors.orange[700]
                                    : const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
