import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

// ── naver.maps 로드 확인 ──

@JS('naver.maps')
external JSObject? get _naverMaps;

bool get _isNaverMapsLoaded => _naverMaps != null;

// ── JS interop bindings ──

@JS('naver.maps.LatLng')
extension type JSLatLng._(JSObject _) implements JSObject {
  external factory JSLatLng(JSNumber lat, JSNumber lng);
}

@JS('naver.maps.Map')
extension type JSNaverMap._(JSObject _) implements JSObject {
  external factory JSNaverMap(web.HTMLElement element, JSNaverMapOptions options);
  external void setCenter(JSLatLng center);
  external void setZoom(JSNumber zoom);
}

extension type JSNaverMapOptions._(JSObject _) implements JSObject {
  external factory JSNaverMapOptions({
    JSLatLng center,
    JSNumber zoom,
  });
}

@JS('naver.maps.Marker')
extension type JSNaverMarker._(JSObject _) implements JSObject {
  external factory JSNaverMarker(JSNaverMarkerOptions options);
  external void setMap(JSNaverMap? map);
}

extension type JSNaverMarkerOptions._(JSObject _) implements JSObject {
  external factory JSNaverMarkerOptions({
    JSLatLng position,
    JSNaverMap map,
  });
}

@JS('naver.maps.InfoWindow')
extension type JSInfoWindow._(JSObject _) implements JSObject {
  external factory JSInfoWindow(JSInfoWindowOptions options);
  external void open(JSNaverMap map, JSNaverMarker marker);
}

extension type JSInfoWindowOptions._(JSObject _) implements JSObject {
  external factory JSInfoWindowOptions({
    JSString content,
  });
}

// ── Helper ──

JSLatLng _latLng(double lat, double lng) => JSLatLng(lat.toJS, lng.toJS);

// ── Controller ──

class NaverMapWebController {
  final JSNaverMap _map;
  final List<JSNaverMarker> _markers = [];

  NaverMapWebController(this._map);

  void moveCamera(double lat, double lng, {int? zoom}) {
    _map.setCenter(_latLng(lat, lng));
    if (zoom != null) {
      _map.setZoom(zoom.toJS);
    }
  }

  void clearOverlays() {
    for (final marker in _markers) {
      marker.setMap(null);
    }
    _markers.clear();
  }

  void addMarker({
    required double lat,
    required double lng,
    String? label,
  }) {
    final marker = JSNaverMarker(JSNaverMarkerOptions(
      position: _latLng(lat, lng),
      map: _map,
    ));
    _markers.add(marker);

    if (label != null) {
      final iw = JSInfoWindow(JSInfoWindowOptions(
        content:
            '<div style="padding:5px 10px;font-size:12px;background:#fff;border:1px solid #ccc;border-radius:6px;white-space:nowrap;">$label</div>'
                .toJS,
      ));
      iw.open(_map, marker);
    }
  }

  void dispose() {
    clearOverlays();
  }
}

// ── Widget ──

class NaverMapWeb extends StatefulWidget {
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
  State<NaverMapWeb> createState() => _NaverMapWebState();
}

class _NaverMapWebState extends State<NaverMapWeb> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'naver-map-${identityHashCode(this)}';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = 'naver-map-el-$viewId';
      div.style.width = '100%';
      div.style.height = '100%';

      _waitForSdkAndCreateMap(div);

      return div;
    });
  }

  Future<void> _waitForSdkAndCreateMap(web.HTMLDivElement container) async {
    // 네이버맵 JS SDK가 로드될 때까지 대기 (최대 10초)
    for (var i = 0; i < 50; i++) {
      if (_isNaverMapsLoaded) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;

    if (!_isNaverMapsLoaded) {
      debugPrint('네이버맵 JS SDK 로드 실패');
      return;
    }

    // DOM에 마운트될 시간을 줌
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    _createMap(container);
  }

  void _createMap(web.HTMLDivElement container) {
    try {
      final options = JSNaverMapOptions(
        center: _latLng(widget.initialLat, widget.initialLng),
        zoom: widget.initialZoom.toInt().toJS,
      );

      final map = JSNaverMap(container, options);
      final controller = NaverMapWebController(map);
      widget.onMapReady?.call(controller);
    } catch (e) {
      debugPrint('네이버맵 생성 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
