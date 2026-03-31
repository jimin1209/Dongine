import 'package:flutter/material.dart';

/// 모바일 빌드에서 사용되는 stub. 실제로 호출되지 않음 (kIsWeb 분기).
class NaverMapWebController {
  void moveCamera(double lat, double lng, {int? zoom}) {}
  void clearOverlays() {}
  void addMarker({required double lat, required double lng, String? label}) {}
  void dispose() {}
}

class NaverMapWeb extends StatelessWidget {
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final void Function(NaverMapWebController controller)? onMapReady;

  const NaverMapWeb({
    super.key,
    this.initialLat = 37.5665,
    this.initialLng = 126.9780,
    this.initialZoom = 15,
    this.onMapReady,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
