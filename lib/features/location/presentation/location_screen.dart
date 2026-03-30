import 'dart:async';

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
  Timer? _locationUpdateTimer;
  bool _isMapReady = false;
  bool _isInitializing = true;
  bool _isAppInForeground = true;
  String? _errorMessage;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      await FlutterNaverMap().init(clientId: AppConstants.naverMapClientId);

      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = _errorMessage ?? '앱 사용 중 위치 권한이 필요합니다.';
          _isInitializing = false;
        });
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _startLocationUpdates();

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '초기화 중 오류가 발생했습니다: $e';
        _isInitializing = false;
      });
    }
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

  void _startLocationUpdates() {
    if (!_isAppInForeground) return;
    if (!ref.read(locationSharingEnabledProvider)) return;

    _locationUpdateTimer?.cancel();
    _updateMyLocation();

    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: AppConstants.locationUpdateIntervalSeconds),
      (_) => _updateMyLocation(),
    );
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _updateMyLocation() async {
    if (!_isAppInForeground) return;

    final sharingEnabled = ref.read(locationSharingEnabledProvider);
    if (!sharingEnabled) return;

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final familyAsync = ref.read(currentFamilyProvider);
    final family = familyAsync.valueOrNull;
    if (family == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
      });

      await ref
          .read(locationRepositoryProvider)
          .updateLocation(
            family.id,
            user.uid,
            position.latitude,
            position.longitude,
            accuracy: position.accuracy,
          );
    } catch (e) {
      debugPrint('위치 업데이트 실패: $e');
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

      marker.setOnTapListener((_) {
        marker.openInfoWindow(
          NInfoWindow.onMarker(id: '${location.uid}_info', text: memberName),
        );
      });

      // 기본적으로 이름 표시
      marker.openInfoWindow(
        NInfoWindow.onMarker(id: '${location.uid}_info', text: memberName),
      );

      markers.add(marker);
    }

    _mapController!.clearOverlays();
    _mapController!.addOverlayAll(markers);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => false,
      AppLifecycleState.hidden => false,
      AppLifecycleState.paused => false,
      AppLifecycleState.detached => false,
    };

    _isAppInForeground = isForeground;

    if (isForeground) {
      _startLocationUpdates();
    } else {
      _stopLocationUpdates();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 위치'),
        actions: [_buildSharingToggle()],
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_errorMessage!),
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
              ),
            );
          }

          return _buildMapView(family.id);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }

  Widget _buildSharingToggle() {
    final sharingEnabled = ref.watch(locationSharingEnabledProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sharingEnabled ? '포그라운드 공유 중' : '공유 꺼짐',
          style: const TextStyle(fontSize: 12),
        ),
        Switch(
          value: sharingEnabled,
          onChanged: (value) {
            ref.read(locationSharingEnabledProvider.notifier).state = value;

            final user = ref.read(authRepositoryProvider).currentUser;
            final familyAsync = ref.read(currentFamilyProvider);
            final family = familyAsync.valueOrNull;

            if (user != null && family != null) {
              ref
                  .read(locationRepositoryProvider)
                  .toggleLocationSharing(family.id, user.uid, value);
            }

            if (value) {
              _startLocationUpdates();
            } else {
              _stopLocationUpdates();
            }
          },
        ),
      ],
    );
  }

  Widget _buildMapView(String familyId) {
    final locationsAsync = ref.watch(familyLocationsProvider(familyId));

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: _currentPosition != null
                        ? NLatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          )
                        : const NLatLng(37.5665, 126.9780), // 서울 시청
                    zoom: 15,
                  ),
                  locationButtonEnable: true,
                ),
                onMapReady: _onMapReady,
              ),
              // 내 위치로 이동 버튼
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'myLocation',
                  onPressed: () {
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
                  },
                  child: const Icon(Icons.my_location),
                ),
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
                      '위치 공유는 앱이 화면에 보이는 동안에만 갱신됩니다.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
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
              // 마커 업데이트
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.people, size: 20),
                SizedBox(width: 8),
                Text(
                  '가족 위치',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                final memberName =
                    members
                        .where((m) => m.uid == location.uid)
                        .map((m) => m.nickname)
                        .firstOrNull ??
                    '알 수 없음';

                final timeDiff = DateTime.now().difference(location.updatedAt);
                final timeText = _formatTimeDiff(timeDiff);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      memberName.isNotEmpty ? memberName[0] : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(memberName),
                  subtitle: Text(
                    location.address ?? '주소 정보 없음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeText,
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
              },
            ),
          ),
        ],
      ),
    );
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
