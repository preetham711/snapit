import 'package:flutter/material.dart';

class ZoomControlsWidget extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final Function(double) onZoomChanged;

  const ZoomControlsWidget({
    Key? key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final midZoom = (minZoom + maxZoom) / 2;

    return Column(
      children: [
        // 1x Zoom
        _buildZoomButton(
          label: '1x',
          isActive: (currentZoom - minZoom).abs() < 0.1,
          onTap: () => onZoomChanged(minZoom),
        ),
        const SizedBox(height: 12),

        // 2x Zoom
        _buildZoomButton(
          label: '2x',
          isActive: (currentZoom - midZoom).abs() < 0.5,
          onTap: () => onZoomChanged(midZoom),
        ),
      ],
    );
  }

  Widget _buildZoomButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? Colors.white
              : Colors.black.withOpacity(0.4),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
