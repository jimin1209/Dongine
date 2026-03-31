import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'package:dongine/core/constants/app_constants.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/location/domain/location_provider.dart';
import 'package:dongine/shared/models/location_model.dart';

import 'package:dongine/features/family/domain/family_provider.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen>
    with WidgetsBindingObserver {
  NaverMapController? _mapController;
  bool _isMapReady = false;
  bool _isInitializing = true;
  bool _isRefreshing = false;
  bool _sharingToggleBusy = false;
  String? _errorMessage;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<Position?>(
      lastTrackedPositionProvider,
      (previous, next) {
        if (next != null && mounted) {
          setState(() => _currentPosition = next);
        }
      },
    );
    _initializeMap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(locationPermissionSnapshotProvider);
    }
  }

  void _refreshPermissionSnapshot() {
    ref.invalidate(locationPermissionSnapshotProvider);
  }

  Future<void> _openAppSettingsForLocation() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _openDeviceLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _initializeMap() async {
    final initOverride = ref.read(locationScreenInitOverrideProvider);
    if (initOverride != null) {
      setState(() {
        _isInitializing = false;
        _errorMessage = initOverride.errorMessage;
        _currentPosition = initOverride.position;
      });
      _scheduleRefreshPermissionSnapshot();
      return;
    }

    try {
      if (!ref.read(locationSkipNaverMapSdkInitProvider)) {
        await FlutterNaverMap().init(clientId: AppConstants.naverMapClientId);
      }

      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = _errorMessage ?? '앱 사용 중 위치 권한이 필요합니다.';
          _isInitializing = false;
        });
        _scheduleRefreshPermissionSnapshot();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _isInitializing = false;
      });
      _scheduleRefreshPermissionSnapshot();
    } catch (e) {
      setState(() {
        _errorMessage = '초기화 중 오류가 발생했습니다: $e';
        _isInitializing = false;
      });
      _scheduleRefreshPermissionSnapshot();
    }
  }

  void _scheduleRefreshPermissionSnapshot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshPermissionSnapshot();
    });
  }

  Future<String?> _resolveCurrentUid() async {
    final immediate = ref.read(authStateProvider).valueOrNull?.uid;
    if (immediate != null) return immediate;
    return (await ref.read(authStateProvider.future))?.uid;
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = '위치 서비스를 켜주세요.';
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage = '앱 사용 중 위치 권한이 필요합니다.';
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _errorMessage = '설정에서 위치 권한을 허용해주세요.';
      return false;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _errorMessage = null;
      return true;
    }

    _errorMessage = '앱 사용 중 위치 권한이 필요합니다.';
    return false;
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      if (!ref.read(locationSharingEnabledProvider)) return;

      final uid = await _resolveCurrentUid();
      if (uid == null) return;

      final familyAsync = ref.read(currentFamilyProvider);
      final family = familyAsync.valueOrNull;
      if (family == null) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() => _currentPosition = position);
      }

      await ref.read(locationRepositoryProvider).updateLocation(
            family.id,
            uid,
            position.latitude,
            position.longitude,
            accuracy: position.accuracy,
          );

      ref.invalidate(familyLocationsProvider(family.id));
    } catch (e) {
      debugPrint('새로고침 위치 업데이트 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _onMapReady(NaverMapController controller) {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
    });

    if (_currentPosition != null) {
      _mapController?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 15,
        ),
      );
    }
  }

  void _updateMarkers(List<LocationModel> locations) {
    if (_mapController == null || !_isMapReady) return;

    final familyAsync = ref.read(currentFamilyProvider);
    final family = familyAsync.valueOrNull;
    if (family == null) return;

    final membersAsync = ref.read(familyMembersProvider(family.id));
    final members = membersAsync.valueOrNull ?? [];

    final markers = <NMarker>{};

    for (final location in locations) {
      final memberName =
          members
              .where((m) => m.uid == location.uid)
              .map((m) => m.nickname)
              .firstOrNull ??
          '알 수 없음';

      final marker = NMarker(
        id: location.uid,
        position: NLatLng(location.latitude, location.longitude),
      );

      final freshnessLabel = switch (location.freshness) {
        LocationFreshness.fresh => memberName,
        LocationFreshness.recent => '$memberName (${_formatTimeDiff(DateTime.now().difference(location.updatedAt))})',
        LocationFreshness.stale => '$memberName (오래됨)',
      };

      marker.setOnTapListener((_) {
        marker.openInfoWindow(
          NInfoWindow.onMarker(id: '${location.uid}_info', text: freshnessLabel),
        );
      });

      marker.openInfoWindow(
        NInfoWindow.onMarker(id: '${location.uid}_info', text: freshnessLabel),
      );

      markers.add(marker);
    }

    _mapController!.clearOverlays();
    _mapController!.addOverlayAll(markers);
  }

  void _moveToMyLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 15,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 위치'),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _manualRefresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
          _buildSharingToggle(),
        ],
      ),
      body: familyAsync.when(
        data: (family) {
          if (family == null) {
            return const Center(child: Text('가족 그룹에 먼저 참여해주세요.'));
          }

          if (_isInitializing) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('지도를 불러오는 중...'),
                ],
              ),
            );
          }

          if (_errorMessage != null) {
            return _buildPermissionErrorBody();
          }

          return _buildMapView(family.id);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
      floatingActionButton: (!_isInitializing && _errorMessage == null)
          ? FloatingActionButton.small(
              heroTag: 'myLocation',
              onPressed: _moveToMyLocation,
              tooltip: '내 위치로 이동',
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  Future<void> _persistLocationSharing(bool enabled) async {
    final uid = await _resolveCurrentUid();
    final family = ref.read(currentFamilyProvider).valueOrNull;
    if (uid == null || family == null) return;

    try {
      await ref.read(locationRepositoryProvider).toggleLocationSharing(
            family.id,
            uid,
            enabled,
          );
      _scheduleRefreshPermissionSnapshot();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 공유 설정을 저장하지 못했습니다: $e')),
      );
    }
  }

  String _sharingToggleLabel(bool enabled, LocationPermissionSnapshot snap) {
    if (!enabled) return '꺼짐';
    if (_errorMessage != null && _errorMessage!.isNotEmpty) {
      return '켜짐(지도 불가)';
    }
    if (!snap.hasUsablePermission) {
      return '켜짐(위치 불가)';
    }
    if (!snap.isBackgroundSharingFullySupported) {
      return '공유 중(백그라운드 제한)';
    }
    return '공유 중';
  }

  Widget _buildPermissionErrorBody() {
    final permAsync = ref.watch(locationPermissionSnapshotProvider);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: permAsync.when(
          loading: () => _buildPermissionErrorCore(ui: null),
          error: (error, stackTrace) => _buildPermissionErrorCore(ui: null),
          data: (snap) {
            final ui = buildLocationPermissionUiModel(
              serviceEnabled: snap.serviceEnabled,
              permission: snap.permission,
              platform: defaultTargetPlatform,
            );
            return _buildPermissionErrorCore(ui: ui);
          },
        ),
      ),
    );
  }

  Widget _buildPermissionErrorCore({LocationPermissionUiModel? ui}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_off, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
        ),
        if (ui != null) ...[
          const SizedBox(height: 20),
          Text(
            ui.statusTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ui.statusSubtitle,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (ui.showBanner && ui.bannerMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              ui.bannerMessage!,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _buildPermissionCtaButtons(ui),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _errorMessage = null;
              _isInitializing = true;
            });
            _initializeMap();
          },
          child: const Text('다시 시도'),
        ),
      ],
    );
  }

  List<Widget> _buildPermissionCtaButtons(LocationPermissionUiModel ui) {
    final buttons = <Widget>[];
    if (ui.showOpenAppSettingsCta) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _openAppSettingsForLocation,
          icon: const Icon(Icons.app_settings_alt_outlined, size: 18),
          label: Text(ui.openAppSettingsCtaLabel),
        ),
      );
    }
    if (ui.showOpenLocationSettingsCta) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _openDeviceLocationSettings,
          icon: const Icon(Icons.location_searching, size: 18),
          label: Text(ui.openLocationSettingsCtaLabel),
        ),
      );
    }
    return buttons;
  }

  Widget _buildPermissionStatusBanner(LocationPermissionSnapshot snap) {
    final ui = buildLocationPermissionUiModel(
      serviceEnabled: snap.serviceEnabled,
      permission: snap.permission,
      platform: defaultTargetPlatform,
    );
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('location_permission_status_banner'),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ui.statusTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ui.statusSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (ui.showBanner && ui.bannerMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                ui.bannerMessage!,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ],
            if (ui.showOpenAppSettingsCta ||
                ui.showOpenLocationSettingsCta) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildPermissionCtaButtons(ui),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSharingToggle() {
    final sharingAsync = ref.watch(locationSharingEnabledStreamProvider);
    final permAsync = ref.watch(locationPermissionSnapshotProvider);
    final enabled = sharingAsync.valueOrNull ?? false;
    final switchDisabled = sharingAsync.isLoading || _sharingToggleBusy;

    final label = !enabled
        ? '꺼짐'
        : permAsync.when(
            data: (snap) => _sharingToggleLabel(enabled, snap),
            loading: () => '공유 중',
            error: (error, stackTrace) => '공유 중',
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        Switch(
          key: const ValueKey('location_sharing_switch'),
          value: enabled,
          onChanged: switchDisabled
              ? null
              : (value) async {
                  setState(() => _sharingToggleBusy = true);
                  try {
                    await _persistLocationSharing(value);
                  } finally {
                    if (mounted) setState(() => _sharingToggleBusy = false);
                  }
                },
        ),
      ],
    );
  }

  Widget _buildMapView(String familyId) {
    final locationsAsync = ref.watch(familyLocationsProvider(familyId));
    final permAsync = ref.watch(locationPermissionSnapshotProvider);

    return Column(
      children: [
        permAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (snap) => _buildPermissionStatusBanner(snap),
        ),
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              if (ref.watch(locationUseNaverMapPlaceholderProvider))
                const ColoredBox(
                  key: ValueKey('location_naver_map_placeholder'),
                  color: Color(0xFFE8E8E8),
                  child: Center(child: Text('NaverMap(placeholder)')),
                )
              else
                NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: _currentPosition != null
                          ? NLatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            )
                          : const NLatLng(37.5665, 126.9780),
                      zoom: 15,
                    ),
                    locationButtonEnable: false,
                  ),
                  onMapReady: _onMapReady,
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      '공유가 켜져 있고 로그인·가족이 있을 때, 앱 프로세스가 살아 있는 동안 백그라운드에서도 갱신됩니다. Android는 전면 위치 알림이 뜰 수 있습니다. 앱을 완전히 종료하거나 OS가 프로세스를 종료하면 멈춥니다. iOS는 오래 유지하려면 설정에서 위치를 항상 허용하는 것이 좋습니다.',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 하단 가족 위치 목록 패널
        Expanded(
          flex: 2,
          child: locationsAsync.when(
            data: (locations) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateMarkers(locations);
              });

              if (locations.isEmpty) {
                return const Center(child: Text('가족 위치 정보가 없습니다.'));
              }

              return _buildMemberLocationList(locations);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('위치 정보 로드 실패: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberLocationList(List<LocationModel> locations) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final family = familyAsync.valueOrNull;
    final membersAsync = family != null
        ? ref.watch(familyMembersProvider(family.id))
        : null;
    final members = membersAsync?.valueOrNull ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 핸들 바
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.people, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '가족 위치',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${locations.length}명',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return _buildMemberTile(location, members);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    LocationModel location,
    List<dynamic> members,
  ) {
    final memberName =
        members
            .where((m) => m.uid == location.uid)
            .map((m) => m.nickname)
            .firstOrNull ??
        '알 수 없음';

    final timeDiff = DateTime.now().difference(location.updatedAt);
    final timeText = _formatTimeDiff(timeDiff);
    final freshness = location.freshness;
    final freshnessColor = _freshnessColor(freshness);

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              memberName.isNotEmpty ? memberName[0] : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          // 최신성 인디케이터 점
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: freshnessColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Flexible(child: Text(memberName)),
          const SizedBox(width: 8),
          _buildFreshnessBadge(freshness, timeText),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              location.address ?? '주소 정보 없음',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (location.accuracy != null)
            Text(
              '  ~${location.accuracy!.round()}m',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('HH:mm').format(location.updatedAt),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (location.battery != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getBatteryIcon(location.battery!),
                  size: 14,
                  color: _getBatteryColor(location.battery!),
                ),
                const SizedBox(width: 2),
                Text(
                  '${location.battery!.toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
        ],
      ),
      onTap: () {
        _mapController?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(location.latitude, location.longitude),
            zoom: 17,
          ),
        );
      },
    );
  }

  Widget _buildFreshnessBadge(LocationFreshness freshness, String timeText) {
    final (label, bgColor, fgColor) = switch (freshness) {
      LocationFreshness.fresh => (
        '방금 전',
        Colors.green.shade50,
        Colors.green.shade700,
      ),
      LocationFreshness.recent => (
        timeText,
        Colors.orange.shade50,
        Colors.orange.shade700,
      ),
      LocationFreshness.stale => (
        '오래됨',
        Colors.red.shade50,
        Colors.red.shade700,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: fgColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _freshnessColor(LocationFreshness freshness) {
    return switch (freshness) {
      LocationFreshness.fresh => Colors.green,
      LocationFreshness.recent => Colors.orange,
      LocationFreshness.stale => Colors.red,
    };
  }

  String _formatTimeDiff(Duration diff) {
    if (diff.inMinutes < 1) {
      return '방금 전';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else {
      return DateFormat('M/d HH:mm').format(DateTime.now().subtract(diff));
    }
  }

  IconData _getBatteryIcon(double battery) {
    if (battery > 80) return Icons.battery_full;
    if (battery > 60) return Icons.battery_5_bar;
    if (battery > 40) return Icons.battery_4_bar;
    if (battery > 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(double battery) {
    if (battery > 50) return Colors.green;
    if (battery > 20) return Colors.orange;
    return Colors.red;
  }
}
