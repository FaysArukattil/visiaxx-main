import 'package:flutter/material.dart';

/// Ishihara plate viewer widget for color vision testing
class IshiharaPlateViewer extends StatelessWidget {
  final int plateNumber;
  final String imagePath;

  const IshiharaPlateViewer({
    super.key,
    required this.plateNumber,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 64),
                    SizedBox(height: 8),
                    Text('Image not available'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
