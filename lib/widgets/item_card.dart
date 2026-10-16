import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/grocery_item.dart';

class ItemCard extends StatelessWidget {
  final GroceryItem item;
  final ValueChanged<bool?> onToggleCheck;
  final VoidCallback onIncrementQty;
  final VoidCallback onDecrementQty;
  final VoidCallback onTapPrice;
  final VoidCallback onDelete;

  const ItemCard({
    super.key,
    required this.item,
    required this.onToggleCheck,
    required this.onIncrementQty,
    required this.onDecrementQty,
    required this.onTapPrice,
    required this.onDelete,
  });

  static final NumberFormat _rpFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  String _formatRange(int minVal, int maxVal) {
    if (minVal == maxVal) {
      return _rpFormat.format(minVal);
    }
    return '${_rpFormat.format(minVal)} - ${_rpFormat.format(maxVal)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isChecked = item.isChecked;
    final bool isLangganan = item.isCustomPrice;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      elevation: isChecked ? 0 : 1.5,
      color: isChecked ? const Color(0xFFF3F7F5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isLangganan
              ? const Color(0xFFB7E4C7)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: onToggleCheck,
                  activeColor: const Color(0xFF047857),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.namaProdukStandar,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isChecked
                                      ? Colors.black45
                                      : const Color(0xFF0F172A),
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildStatusBadge(isLangganan),
                          ],
                        ),
                        if (item.catatanGrosir.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.catatanGrosir,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Hapus barang',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const Divider(height: 14, thickness: 0.7),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTapPrice,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isLangganan
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLangganan
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${_formatRange(item.hargaSatuanMin, item.hargaSatuanMax)} / ${item.satuan}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 13,
                                  color: Color(0xFF047857),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Subtotal: ${_formatRange(item.subtotalMin, item.subtotalMax)}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isLangganan
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onDecrementQty,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(9),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              size: 18,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 34),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${item.qty} ${item.satuan}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onIncrementQty,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(9),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isLangganan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLangganan
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLangganan
              ? const Color(0xFF34D399)
              : const Color(0xFFFBBF24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLangganan
                ? Icons.verified_rounded
                : Icons.auto_awesome_rounded,
            size: 12,
            color: isLangganan
                ? const Color(0xFF065F46)
                : const Color(0xFF92400E),
          ),
          const SizedBox(width: 4),
          Text(
            isLangganan ? 'Harga Langganan' : 'Estimasi AI',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isLangganan
                  ? const Color(0xFF065F46)
                  : const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}
