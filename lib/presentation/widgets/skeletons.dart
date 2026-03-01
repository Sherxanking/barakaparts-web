import 'package:flutter/material.dart';

/// Shimmer effektli Skeleton widgetlari kolleksiyasi
class OrderItemSkeleton extends StatelessWidget {
  const OrderItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 140, // OrderItemWidget bilan deyarli bir xil balandlik
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Chap tarafdagi rangli chiziq o'rniga xira chiziq
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: Colors.grey[200]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Product nomi o'rniga
                      Container(
                        width: 150,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Status badge o'rniga
                      Container(
                        width: 80,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Metadata qatorlari (Department, Customer)
                  _buildLine(width: 200),
                  const SizedBox(height: 8),
                  _buildLine(width: 120),
                  const Spacer(),
                  // Pastdagi tugmalar o'rniga
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 100,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Shimmer effekti animatsiyasi (bu darsda sodda grey ishlatamiz)
          ],
        ),
      ),
    );
  }

  Widget _buildLine({required double width, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[50], // Shimmer bo'lmaganda juda och rang
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Parts ro'yxati uchun Skeleton
class PartSkeleton extends StatelessWidget {
  const PartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rasm o'rni
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          // Matnlar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBox(width: 150, height: 18),
                const SizedBox(height: 8),
                _buildBox(width: 100, height: 14),
                const SizedBox(height: 4),
                _buildBox(width: 80, height: 12),
              ],
            ),
          ),
          // Action (plus/minus) o'rni
          _buildBox(width: 40, height: 40, radius: 20),
        ],
      ),
    );
  }

  Widget _buildBox({required double width, required double height, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Products ro'yxati uchun Skeleton
class ProductSkeleton extends StatelessWidget {
  const ProductSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon o'rni
              _buildBox(width: 40, height: 40, radius: 10),
              const SizedBox(width: 12),
              // Nom o'rni
              _buildBox(width: 180, height: 20),
              const Spacer(),
              // Action o'rni
              _buildBox(width: 24, height: 24, radius: 12),
            ],
          ),
          const SizedBox(height: 16),
          // Department badge o'rni
          _buildBox(width: 100, height: 24, radius: 12),
          const SizedBox(height: 12),
          // Parts list o'rni
          _buildBox(width: double.infinity, height: 12),
          const SizedBox(height: 4),
          _buildBox(width: 200, height: 12),
        ],
      ),
    );
  }

  Widget _buildBox({required double width, required double height, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
