import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';

/// Ishihara plate viewer widget for color vision testing
/// Supports both PNG and SVG formats
class IshiharaPlateViewer extends StatelessWidget {
  final int plateNumber;
  final String imagePath;
  final double? size;

  const IshiharaPlateViewer({
    super.key,
    required this.plateNumber,
    required this.imagePath,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isSvg = imagePath.toLowerCase().endsWith('.svg');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isSvg
            ? SvgPicture.asset(
                imagePath,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => _buildPlaceholder(),
                // Add error handling for SVG loading
                // ignore: deprecated_member_use
                allowDrawingOutsideViewBox: true,
              )
            : Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.grey.withValues(alpha: 0.2),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.palette, size: 64, color: AppColors.grey),
            const SizedBox(height: 8),
            Text(
              'Plate $plateNumber',
              style: const TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
