import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dongine/core/constants/app_constants.dart';
import 'package:dongine/core/services/mqtt_service.dart';
import 'package:dongine/features/auth/domain/auth_provider.dart';
import 'package:dongine/features/family/domain/family_provider.dart';
import 'package:dongine/features/iot/domain/iot_provider.dart';
import 'package:dongine/shared/models/automation_model.dart';
import 'package:dongine/shared/models/iot_device_model.dart';

class IoTScreen extends ConsumerStatefulWidget {
  const IoTScreen({super.key});

  @override
  ConsumerState<IoTScreen> createState() => _IoTScreenState();
}

class _IoTScreenState extends ConsumerState<IoTScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _autoConnectAttempted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tryAutoConnect();
  }

  /// 브로커가 설정되어 있고 아직 연결되지 않았으면 자동 연결 시도.
  void _tryAutoConnect() {
    if (_autoConnectAttempted) return;
    _autoConnectAttempted = true;

    if (!AppConstants.isMqttBrokerConfigured) return;

    final mqtt = MqttService.instance;
    if (mqtt.connectionStatus == MqttConnectionStatus.connected ||
        mqtt.connectionStatus == MqttConnectionStatus.connecting ||
        mqtt.connectionStatus == MqttConnectionStatus.reconnecting) {
      return;
    }

    final clientId = 'dongine_${DateTime.now().millisecondsSinceEpoch}';
    mqtt.connect(
      AppConstants.mqttBrokerUrl,
      AppConstants.mqttBrokerPort,
      clientId,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '기기'),
            Tab(text: '자동화'),
          ],
        ),
        actions: const [
          _MqttStatusBadge(),
        ],
      ),
      body: Column(
        children: [
          const _MqttConnectionBanner(),
          Expanded(
            child: familyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (family) {
                if (family == null) {
                  return const Center(child: Text('가족 그룹에 참여해주세요'));
                }
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _DevicesTab(familyId: family.id),
                    _AutomationsTab(familyId: family.id),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: familyAsync.valueOrNull != null
          ? FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  _showAddDeviceDialog(
                      context, familyAsync.valueOrNull!.id);
                } else {
                  _showCreateAutomationSheet(
                      context, familyAsync.valueOrNull!.id);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddDeviceDialog(BuildContext context, String familyId) {
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final topicController = TextEditingController();
    String selectedType = 'light';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('기기 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '기기 이름',
                    hintText: '거실 조명',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: '기기 유형'),
                  items: const [
                    DropdownMenuItem(value: 'light', child: Text('조명')),
                    DropdownMenuItem(value: 'sensor', child: Text('센서')),
                    DropdownMenuItem(value: 'switch', child: Text('스위치')),
                    DropdownMenuItem(value: 'plug', child: Text('플러그')),
                    DropdownMenuItem(value: 'lock', child: Text('잠금장치')),
                    DropdownMenuItem(
                        value: 'thermostat', child: Text('온도조절기')),
                    DropdownMenuItem(value: 'camera', child: Text('카메라')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedType = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomController,
                  decoration: const InputDecoration(
                    labelText: '방 이름 (선택)',
                    hintText: '거실',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: topicController,
                  decoration: const InputDecoration(
                    labelText: 'MQTT 토픽',
                    hintText: 'home/living_room/light',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    topicController.text.isEmpty) {
                  return;
                }
                final authState = ref.read(authStateProvider).valueOrNull;
                if (authState == null) return;

                final device = IoTDeviceModel(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  type: selectedType,
                  status: 'offline',
                  state: _defaultState(selectedType),
                  familyId: familyId,
                  roomName: roomController.text.trim().isEmpty
                      ? null
                      : roomController.text.trim(),
                  mqttTopic: topicController.text.trim(),
                  lastSeen: DateTime.now(),
                  addedBy: authState.uid,
                  createdAt: DateTime.now(),
                );

                final repo = ref.read(iotRepositoryProvider);
                await repo.addDevice(familyId, device);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _defaultState(String type) {
    return switch (type) {
      'light' => {'on': false, 'brightness': 100},
      'switch' || 'plug' => {'on': false},
      'sensor' => {'temperature': 0.0, 'humidity': 0.0},
      'lock' => {'locked': true},
      'thermostat' => {'targetTemp': 22.0, 'currentTemp': 20.0},
      'camera' => {'recording': false},
      _ => {},
    };
  }

  void _showCreateAutomationSheet(BuildContext context, String familyId) {
    final nameController = TextEditingController();
    String triggerType = 'time';
    TimeOfDay? selectedTime;
    String? selectedDeviceId;
    String actionType = 'on';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final devicesAsync = ref.watch(devicesProvider(familyId));
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '자동화 만들기',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '자동화 이름',
                      hintText: '퇴근 후 조명 켜기',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: triggerType,
                    decoration: const InputDecoration(labelText: '트리거 유형'),
                    items: const [
                      DropdownMenuItem(value: 'time', child: Text('시간')),
                      DropdownMenuItem(value: 'device', child: Text('기기')),
                      DropdownMenuItem(
                          value: 'location', child: Text('위치')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() => triggerType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (triggerType == 'time')
                    ListTile(
                      title: Text(selectedTime != null
                          ? '${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                          : '시간 선택'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setSheetState(() => selectedTime = time);
                        }
                      },
                    ),
                  if (triggerType == 'device')
                    devicesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Text('기기를 불러올 수 없습니다'),
                      data: (devices) =>
                          DropdownButtonFormField<String>(
                        initialValue: selectedDeviceId,
                        decoration:
                            const InputDecoration(labelText: '기기 선택'),
                        items: devices
                            .map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setSheetState(() => selectedDeviceId = v);
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    '동작',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  devicesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Text('기기를 불러올 수 없습니다'),
                    data: (devices) => Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: devices.isNotEmpty
                              ? (selectedDeviceId ?? devices.first.id)
                              : null,
                          decoration:
                              const InputDecoration(labelText: '대상 기기'),
                          items: devices
                              .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setSheetState(() => selectedDeviceId = v);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: actionType,
                          decoration:
                              const InputDecoration(labelText: '동작'),
                          items: const [
                            DropdownMenuItem(
                                value: 'on', child: Text('켜기')),
                            DropdownMenuItem(
                                value: 'off', child: Text('끄기')),
                            DropdownMenuItem(
                                value: 'toggle', child: Text('토글')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setSheetState(() => actionType = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;
                      final authState =
                          ref.read(authStateProvider).valueOrNull;
                      if (authState == null) return;

                      final trigger = <String, dynamic>{
                        'type': triggerType,
                      };
                      if (triggerType == 'time' && selectedTime != null) {
                        trigger['condition'] = {
                          'hour': selectedTime!.hour,
                          'minute': selectedTime!.minute,
                        };
                      } else if (triggerType == 'device' &&
                          selectedDeviceId != null) {
                        trigger['condition'] = {
                          'deviceId': selectedDeviceId,
                          'state': 'changed',
                        };
                      }

                      final targetDeviceId = selectedDeviceId ??
                          (ref
                                  .read(devicesProvider(familyId))
                                  .valueOrNull
                                  ?.firstOrNull
                                  ?.id ??
                              '');

                      final automation = AutomationModel(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        trigger: trigger,
                        actions: [
                          {
                            'deviceId': targetDeviceId,
                            'action': actionType,
                            'value': actionType == 'on' ? true : false,
                          },
                        ],
                        isEnabled: true,
                        familyId: familyId,
                        createdBy: authState.uid,
                        createdAt: DateTime.now(),
                      );

                      final repo = ref.read(iotRepositoryProvider);
                      await repo.createAutomation(familyId, automation);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('자동화 만들기'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- MQTT 연결 상태 배지 (AppBar에 표시) ---

class _MqttStatusBadge extends ConsumerWidget {
  const _MqttStatusBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brokerConfigured = ref.watch(mqttBrokerConfiguredProvider);

    if (!brokerConfigured) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Tooltip(
          message: 'MQTT: 미설정',
          child: Icon(Icons.wifi_off, color: Colors.blueGrey, size: 20),
        ),
      );
    }

    final statusAsync = ref.watch(mqttConnectionStatusProvider);
    final status =
        statusAsync.valueOrNull ?? MqttConnectionStatus.disconnected;

    final (Color color, String label, IconData icon) = switch (status) {
      MqttConnectionStatus.connected => (Colors.green, '연결됨', Icons.wifi),
      MqttConnectionStatus.connecting =>
        (Colors.orange, '연결 중...', Icons.wifi),
      MqttConnectionStatus.reconnecting =>
        (Colors.orange, '재연결 중...', Icons.wifi),
      MqttConnectionStatus.disconnected =>
        (Colors.grey, '연결 끊김', Icons.wifi_off),
      MqttConnectionStatus.error =>
        (Colors.red, '연결 오류', Icons.wifi_off),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'MQTT: $label',
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// --- MQTT 연결 끊김 배너 ---

class _MqttConnectionBanner extends ConsumerWidget {
  const _MqttConnectionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brokerConfigured = ref.watch(mqttBrokerConfiguredProvider);

    // 브로커가 설정되지 않은 경우 안내 배너
    if (!brokerConfigured) {
      return MaterialBanner(
        content: const Text(
          'MQTT 브로커가 설정되지 않았습니다.\n'
          '빌드 시 --dart-define=MQTT_BROKER_URL=<주소> 를 추가해주세요.',
        ),
        backgroundColor: Colors.blue.shade50,
        leading: const Icon(Icons.info_outline, size: 20),
        actions: const [SizedBox.shrink()],
      );
    }

    final statusAsync = ref.watch(mqttConnectionStatusProvider);
    final status =
        statusAsync.valueOrNull ?? MqttConnectionStatus.disconnected;

    if (status == MqttConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    final (Color bgColor, String message, bool showRetry) = switch (status) {
      MqttConnectionStatus.connecting =>
        (Colors.orange.shade100, 'MQTT 서버에 연결하는 중...', false),
      MqttConnectionStatus.reconnecting =>
        (Colors.orange.shade100, 'MQTT 서버에 재연결하는 중...', false),
      MqttConnectionStatus.error =>
        (Colors.red.shade100, 'MQTT 연결 오류가 발생했습니다', true),
      MqttConnectionStatus.disconnected =>
        (Colors.grey.shade200, 'MQTT 서버에 연결되지 않았습니다', true),
      MqttConnectionStatus.connected => (Colors.transparent, '', false),
    };

    return MaterialBanner(
      content: Text(message),
      backgroundColor: bgColor,
      leading: status == MqttConnectionStatus.connecting ||
              status == MqttConnectionStatus.reconnecting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.wifi_off, size: 20),
      actions: [
        if (showRetry)
          TextButton(
            onPressed: () {
              final mqtt = ref.read(mqttServiceProvider);
              mqtt.reconnect();
            },
            child: const Text('재연결'),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

// --- Devices Tab ---

class _DevicesTab extends ConsumerWidget {
  final String familyId;
  const _DevicesTab({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider(familyId));

    return devicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (devices) {
        if (devices.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.devices, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('등록된 기기가 없습니다'),
                SizedBox(height: 8),
                Text(
                  '+ 버튼을 눌러 기기를 추가하세요',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return _DeviceCard(
              device: device,
              familyId: familyId,
            );
          },
        );
      },
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  final IoTDeviceModel device;
  final String familyId;

  const _DeviceCard({required this.device, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = device.status == 'online';
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => _showDeviceControlSheet(context, ref),
        onLongPress: () => _showRemoveDialog(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    IoTDeviceModel.typeIcon(device.type),
                    size: 28,
                    color: isOnline
                        ? theme.colorScheme.primary
                        : Colors.grey,
                  ),
                  const Spacer(),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                device.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                device.roomName ?? IoTDeviceModel.typeName(device.type),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _stateLabel(),
                style: theme.textTheme.bodySmall,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stateLabel() {
    return switch (device.type) {
      'light' => device.state['on'] == true
          ? '켜짐 (${device.state['brightness'] ?? 100}%)'
          : '꺼짐',
      'switch' || 'plug' => device.state['on'] == true ? '켜짐' : '꺼짐',
      'sensor' =>
        '${device.state['temperature'] ?? '-'}C / ${device.state['humidity'] ?? '-'}%',
      'lock' => device.state['locked'] == true ? '잠김' : '열림',
      'thermostat' =>
        '${device.state['currentTemp'] ?? '-'}C -> ${device.state['targetTemp'] ?? '-'}C',
      'camera' =>
        device.state['recording'] == true ? '녹화 중' : '대기',
      _ => '',
    };
  }

  void _showDeviceControlSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _DeviceControlSheet(
        device: device,
        familyId: familyId,
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기기 삭제'),
        content: Text('"${device.name}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final repo = ref.read(iotRepositoryProvider);
              await repo.removeDevice(familyId, device.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _DeviceControlSheet extends ConsumerStatefulWidget {
  final IoTDeviceModel device;
  final String familyId;

  const _DeviceControlSheet({
    required this.device,
    required this.familyId,
  });

  @override
  ConsumerState<_DeviceControlSheet> createState() =>
      _DeviceControlSheetState();
}

class _DeviceControlSheetState extends ConsumerState<_DeviceControlSheet> {
  late Map<String, dynamic> _state;

  @override
  void initState() {
    super.initState();
    _state = Map<String, dynamic>.from(widget.device.state);
  }

  void _updateState() {
    final mqttConnected = ref.read(mqttConnectedProvider);
    final repo = ref.read(iotRepositoryProvider);
    repo.updateDeviceState(widget.familyId, widget.device.id, _state);

    if (mqttConnected) {
      final mqtt = ref.read(mqttServiceProvider);
      repo.controlDevice(mqtt, widget.device.mqttTopic, _state);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MQTT 연결이 끊겨 기기에 명령을 보내지 못했습니다. '
                'Firestore에는 저장되었습니다.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mqttConnected = ref.watch(mqttConnectedProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                IoTDeviceModel.typeIcon(widget.device.type),
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.device.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.device.roomName != null)
                      Text(
                        widget.device.roomName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!mqttConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MQTT 미연결 - 기기에 직접 전달되지 않습니다',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ..._buildControls(theme),
        ],
      ),
    );
  }

  List<Widget> _buildControls(ThemeData theme) {
    return switch (widget.device.type) {
      'light' => _lightControls(theme),
      'switch' || 'plug' => _toggleControls(theme),
      'sensor' => _sensorDisplay(theme),
      'lock' => _lockControls(theme),
      'thermostat' => _thermostatControls(theme),
      _ => [const Text('이 기기 유형은 제어를 지원하지 않습니다')],
    };
  }

  List<Widget> _lightControls(ThemeData theme) {
    final isOn = _state['on'] == true;
    final brightness = (_state['brightness'] as num?)?.toDouble() ?? 100.0;

    return [
      SwitchListTile(
        title: Text(isOn ? '켜짐' : '꺼짐'),
        value: isOn,
        onChanged: (v) {
          setState(() => _state['on'] = v);
          _updateState();
        },
      ),
      const SizedBox(height: 12),
      Text('밝기: ${brightness.round()}%'),
      Slider(
        value: brightness,
        min: 0,
        max: 100,
        divisions: 20,
        label: '${brightness.round()}%',
        onChanged: isOn
            ? (v) {
                setState(() => _state['brightness'] = v.round());
              }
            : null,
        onChangeEnd: isOn ? (_) => _updateState() : null,
      ),
    ];
  }

  List<Widget> _toggleControls(ThemeData theme) {
    final isOn = _state['on'] == true;
    return [
      SwitchListTile(
        title: Text(isOn ? '켜짐' : '꺼짐'),
        value: isOn,
        onChanged: (v) {
          setState(() => _state['on'] = v);
          _updateState();
        },
      ),
    ];
  }

  List<Widget> _sensorDisplay(ThemeData theme) {
    return [
      ListTile(
        leading: const Icon(Icons.thermostat),
        title: const Text('온도'),
        trailing: Text(
          '${_state['temperature'] ?? '-'}C',
          style: theme.textTheme.titleMedium,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.water_drop),
        title: const Text('습도'),
        trailing: Text(
          '${_state['humidity'] ?? '-'}%',
          style: theme.textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '읽기 전용',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    ];
  }

  List<Widget> _lockControls(ThemeData theme) {
    final isLocked = _state['locked'] == true;
    return [
      SwitchListTile(
        title: Text(isLocked ? '잠김' : '열림'),
        secondary: Icon(isLocked ? Icons.lock : Icons.lock_open),
        value: isLocked,
        onChanged: (v) {
          setState(() => _state['locked'] = v);
          _updateState();
        },
      ),
    ];
  }

  List<Widget> _thermostatControls(ThemeData theme) {
    final targetTemp =
        (_state['targetTemp'] as num?)?.toDouble() ?? 22.0;
    final currentTemp =
        (_state['currentTemp'] as num?)?.toDouble() ?? 20.0;

    return [
      ListTile(
        leading: const Icon(Icons.thermostat),
        title: const Text('현재 온도'),
        trailing: Text(
          '${currentTemp.toStringAsFixed(1)}C',
          style: theme.textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 8),
      Text('목표 온도: ${targetTemp.toStringAsFixed(1)}C'),
      Slider(
        value: targetTemp.clamp(10.0, 35.0),
        min: 10,
        max: 35,
        divisions: 50,
        label: '${targetTemp.toStringAsFixed(1)}C',
        onChanged: (v) {
          setState(
              () => _state['targetTemp'] = double.parse(v.toStringAsFixed(1)));
        },
        onChangeEnd: (_) => _updateState(),
      ),
    ];
  }
}

// --- Automations Tab ---

class _AutomationsTab extends ConsumerWidget {
  final String familyId;
  const _AutomationsTab({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automationsAsync = ref.watch(automationsProvider(familyId));

    return automationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (automations) {
        if (automations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('자동화 규칙이 없습니다'),
                SizedBox(height: 8),
                Text(
                  '+ 버튼을 눌러 자동화를 만들어보세요',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: automations.length,
          itemBuilder: (context, index) {
            final automation = automations[index];
            return Dismissible(
              key: Key(automation.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) => showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('자동화 삭제'),
                  content:
                      Text('"${automation.name}"을(를) 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              ),
              onDismissed: (_) {
                final repo = ref.read(iotRepositoryProvider);
                repo.deleteAutomation(familyId, automation.id);
              },
              child: Card(
                child: ListTile(
                  leading: Icon(
                    _triggerIcon(automation.trigger['type'] as String?),
                    color: automation.isEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(automation.name),
                  subtitle: Text(_describeAutomation(automation)),
                  trailing: Switch(
                    value: automation.isEnabled,
                    onChanged: (v) {
                      final repo = ref.read(iotRepositoryProvider);
                      repo.toggleAutomation(familyId, automation.id, v);
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _triggerIcon(String? type) {
    return switch (type) {
      'time' => Icons.schedule,
      'device' => Icons.devices,
      'location' => Icons.location_on,
      _ => Icons.auto_awesome,
    };
  }

  String _describeAutomation(AutomationModel automation) {
    final triggerType = automation.trigger['type'] as String?;
    String triggerDesc;
    switch (triggerType) {
      case 'time':
        final cond =
            automation.trigger['condition'] as Map<String, dynamic>?;
        if (cond != null) {
          final hour = cond['hour'] ?? 0;
          final minute = (cond['minute'] ?? 0).toString().padLeft(2, '0');
          triggerDesc = '매일 $hour:$minute';
        } else {
          triggerDesc = '시간 트리거';
        }
      case 'device':
        triggerDesc = '기기 상태 변경 시';
      case 'location':
        triggerDesc = '위치 도착 시';
      default:
        triggerDesc = '트리거';
    }

    final actionCount = automation.actions.length;
    return '$triggerDesc -> $actionCount개 동작';
  }
}
