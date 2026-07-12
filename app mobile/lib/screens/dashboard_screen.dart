import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../theme/lumina_theme.dart';
import '../widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 0;
  
  bool _isAdaptiveLightingOn = true;
  bool _mockMotionDetected = false;
  double _mockLdrValue = 420;

  final List<bool> _ledStates = List.generate(6, (index) => false);
  final List<Map<String, dynamic>> _ledConfigs = [
    {'name': 'LED 1', 'color': const Color(0xFFFFA500), 'icon': Icons.lightbulb},
    {'name': 'LED 2', 'color': const Color(0xFF4AE183), 'icon': Icons.lightbulb},
    {'name': 'LED 3', 'color': const Color(0xFFEF4444), 'icon': Icons.lightbulb},
    {'name': 'LED 4', 'color': const Color(0xFF00B4D8), 'icon': Icons.lightbulb},
    {'name': 'LED 5', 'color': const Color(0xFFFFD700), 'icon': Icons.lightbulb},
    {'name': 'LED 6', 'color': Colors.white, 'icon': Icons.lightbulb},
  ];

  int _selectedAnimationIndex = 0;
  double _animationDuration = 5.0;

  final List<String> _animations = [
    'Northern Lights',
    'Pulse Wave',
    'Breathe',
    'Rainbow Shift',
    'Flicker',
    'SOS Pattern',
  ];

  StreamSubscription<String>? _telemetrySubscription;
  BluetoothConnection? _bluetoothConnection;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _connectedDeviceName;
  String _telemetryBuffer = '';

  @override
  void initState() {
    super.initState();
    _logCommand('mood 1', 'Switched to mode 1 (Dynamic Light System)');
    _telemetrySubscription = Stream<String>.periodic(
      const Duration(seconds: 4),
      (count) {
        if (count % 3 == 0) {
          return 'PIR:${count % 6 == 0 ? 1 : 0}';
        } else {
          return 'LDR:${(300 + (count * 179) % 3500)}';
        }
      },
    ).listen((telemetry) {
      if (!_isConnected) {
        _handleIncomingTelemetry(telemetry);
      }
    });
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _bluetoothConnection?.dispose();
    super.dispose();
  }

  void _handleIncomingTelemetry(String data) {
    _telemetryBuffer += data;
    while (_telemetryBuffer.contains('\n')) {
      final index = _telemetryBuffer.indexOf('\n');
      final line = _telemetryBuffer.substring(0, index).trim();
      _telemetryBuffer = _telemetryBuffer.substring(index + 1);
      _processTelemetryLine(line);
    }
  }

  void _processTelemetryLine(String line) {
    if (line.startsWith('PIR:')) {
      final value = int.tryParse(line.substring(4));
      if (value != null) {
        setState(() {
          _mockMotionDetected = (value == 1);
        });
      }
    } else if (line.startsWith('LDR:')) {
      final value = double.tryParse(line.substring(4));
      if (value != null) {
        setState(() {
          _mockLdrValue = value;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text(
                'Connection Error',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.manrope(
              color: LuminaTheme.onSurfaceColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.manrope(
                  color: LuminaTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBluetoothDeviceDialog() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(
              color: LuminaTheme.primaryColor,
            ),
          );
        },
      );
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.bluetooth, color: LuminaTheme.primaryColor),
                const SizedBox(width: 10),
                Text(
                  'Select ESP32 Device',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    color: LuminaTheme.onSurfaceColor,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: devices.isEmpty
                  ? Text(
                      'No paired Bluetooth devices found. Please pair your ESP32 in Android settings first.',
                      style: GoogleFonts.manrope(
                        color: LuminaTheme.onSurfaceVariantColor,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return ListTile(
                          leading: const Icon(Icons.settings_remote, color: LuminaTheme.primaryColor),
                          title: Text(
                            device.name ?? 'Unknown Device',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            device.address,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _connectToDevice(device);
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.manrope(
                    color: LuminaTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showErrorDialog('Failed to load bonded devices: $e');
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const CircularProgressIndicator(
                color: LuminaTheme.primaryColor,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Connecting to ${device.name ?? "ESP32"}...',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final connection = await BluetoothConnection.toAddress(device.address)
          .timeout(const Duration(seconds: 10));
      
      _bluetoothConnection = connection;
      if (!mounted) return;
      Navigator.of(context).pop();

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _connectedDeviceName = device.name ?? device.address;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $_connectedDeviceName successfully!'),
          backgroundColor: LuminaTheme.secondaryColor,
        ),
      );

      connection.input?.listen((data) {
        final telemetry = String.fromCharCodes(data);
        _handleIncomingTelemetry(telemetry);
      }).onDone(() {
        _handleDisconnect();
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });
      _showErrorDialog('Connection Timeout or Failed. Make sure the ESP32 is powered on and within range.');
    }
  }

  void _handleDisconnect() {
    if (_isConnected) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _connectedDeviceName = null;
      });
      _bluetoothConnection?.dispose();
      _bluetoothConnection = null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnected from ESP32'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showDisconnectConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Disconnect',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to disconnect from $_connectedDeviceName?',
            style: GoogleFonts.manrope(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.manrope(
                  color: LuminaTheme.outlineColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleDisconnect();
              },
              child: const Text(
                'Disconnect',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _sendBluetoothCommand(String command) async {
    if (_isConnected && _bluetoothConnection != null) {
      try {
        _bluetoothConnection!.output.add(
          Uint8List.fromList('$command\n'.codeUnits),
        );
        await _bluetoothConnection!.output.allSent;
      } catch (e) {
        _handleDisconnect();
        _showErrorDialog('Failed to send command: $e');
      }
    }
  }

  void _logCommand(String command, String response) {
    _sendBluetoothCommand(command);
  }

  String _formatDuration(double seconds) {
    final int totalSeconds = seconds.toInt();
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    } else {
      final int minutes = totalSeconds ~/ 60;
      final int remainingSeconds = totalSeconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      }
      return '${minutes}m ${remainingSeconds}s';
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
    });

    if (index == 0) {
      _logCommand('mood 1', 'Success: Switched to mode 1 (Dynamic Light System)');
    } else if (index == 1) {
      _logCommand('mood 2', 'Success: Switched to mode 2 (Independent Remote Controller)');
    } else if (index == 2) {
      _logCommand('mood 3', 'Success: Switched to mode 3 (Animated Mode)');
    }
  }

  void _toggleAdaptiveLighting(bool value) {
    setState(() {
      _isAdaptiveLightingOn = value;
    });
    if (value) {
      _logCommand('mood 1', 'Success: Switched to mode 1 (Dynamic Light System)');
    } else {
      _logCommand('mood 2', 'Success: Switched to mode 2 (Independent Remote Controller)');
      setState(() {
        _selectedTabIndex = 1;
      });
    }
  }

  void _toggleLed(int index) {
    if (_selectedTabIndex != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please switch to Manual Remote tab first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _ledStates[index] = !_ledStates[index];
    });

    final ledNumber = index + 1;
    final stateStr = _ledStates[index] ? 'ON' : 'OFF';
    _logCommand(
      'led $ledNumber',
      'Remote Control: Toggled LED $ledNumber to $stateStr',
    );
  }

  void _controlAllLeds(bool turnOn) {
    if (_selectedTabIndex != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please switch to Manual Remote tab first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      for (int i = 0; i < 6; i++) {
        _ledStates[i] = turnOn;
      }
    });

    if (turnOn) {
      _logCommand('led *', 'Remote Control: Turned ON all LEDs');
    } else {
      _logCommand('led 0', 'Remote Control: Turned OFF all LEDs');
    }
  }

  void _startAnimationSequence() {
    if (_selectedTabIndex != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please switch to Animations tab first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final animNumber = _selectedAnimationIndex + 1;
    final durationMs = (_animationDuration * 1000).toInt();
    _logCommand(
      'anim $animNumber $durationMs',
      'Success: Animation $animNumber started for $durationMs ms',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: LuminaTheme.backgroundColor,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedTabIndex == 0) _buildDynamicView(textTheme),
                      if (_selectedTabIndex == 1) _buildRemoteView(textTheme),
                      if (_selectedTabIndex == 2) _buildAnimationView(textTheme),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isConnected) {
            _showDisconnectConfirmDialog();
          } else if (!_isConnecting) {
            _showBluetoothDeviceDialog();
          }
        },
        backgroundColor: _isConnected
            ? LuminaTheme.secondaryColor
            : (_isConnecting ? LuminaTheme.primaryColor : LuminaTheme.outlineColor),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: _isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(
                _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                size: 28,
              ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B4D8).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, -10),
          )
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: _onTabChanged,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: LuminaTheme.primaryColor,
        unselectedItemColor: LuminaTheme.onSurfaceVariantColor.withOpacity(0.6),
        selectedLabelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.05,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: 0.05,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'DYNAMIC',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fluorescent),
            label: 'REMOTE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.animation),
            label: 'ANIMATION',
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicView(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dynamic Intelligence',
          style: textTheme.titleMedium?.copyWith(
            color: LuminaTheme.onSurfaceVariantColor,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LuminaTheme.backgroundColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: LuminaTheme.primaryContainerColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sensors,
                              color: LuminaTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PIR MOTION',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _mockMotionDetected ? 'Motion Detected' : 'No Motion',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: LuminaTheme.primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LuminaTheme.backgroundColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: LuminaTheme.tertiaryContainerColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.light_mode,
                              color: LuminaTheme.tertiaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LDR SENSOR',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_mockLdrValue.toInt()} Lux',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: LuminaTheme.tertiaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LuminaTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adaptive Lighting',
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    Switch(
                      value: _isAdaptiveLightingOn,
                      onChanged: _toggleAdaptiveLighting,
                      activeColor: Colors.white,
                      activeTrackColor: LuminaTheme.primaryContainerColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteView(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Manual Remote',
              style: textTheme.titleMedium?.copyWith(
                color: LuminaTheme.onSurfaceVariantColor,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => _controlAllLeds(true),
                  child: const Text('ALL ON'),
                ),
                TextButton(
                  onPressed: () => _controlAllLeds(false),
                  child: const Text('ALL OFF'),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            final config = _ledConfigs[index];
            final isOn = _ledStates[index];
            final color = config['color'] as Color;

            return InkWell(
              onTap: () => _toggleLed(index),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOn
                        ? (color == Colors.white
                            ? LuminaTheme.outlineVariantColor
                            : color.withValues(alpha: 0.8))
                        : Colors.white.withValues(alpha: 0.4),
                    width: isOn ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isOn
                          ? (color == Colors.white
                              ? LuminaTheme.outlineVariantColor.withValues(alpha: 0.4)
                              : color.withValues(alpha: 0.4))
                          : const Color(0xFF00B4D8).withValues(alpha: 0.08),
                      blurRadius: isOn ? 20 : 30,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isOn
                            ? color
                            : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        config['icon'] as IconData,
                        color: isOn
                            ? (color == Colors.white
                                ? LuminaTheme.onSurfaceColor
                                : Colors.white)
                            : LuminaTheme.outlineColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      config['name'] as String,
                      style: textTheme.labelSmall?.copyWith(
                        color: LuminaTheme.onSurfaceColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimationView(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Atmospheric Animations',
          style: textTheme.titleMedium?.copyWith(
            color: LuminaTheme.onSurfaceVariantColor,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _animations.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedAnimationIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(_animations[index]),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedAnimationIndex = index;
                            });
                          }
                        },
                        selectedColor: LuminaTheme.primaryColor,
                        backgroundColor: LuminaTheme.backgroundColor,
                        labelStyle: GoogleFonts.hankenGrotesk(
                          color: isSelected ? Colors.white : LuminaTheme.onSurfaceVariantColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DURATION',
                        style: textTheme.labelSmall,
                      ),
                      Text(
                        _formatDuration(_animationDuration),
                        style: textTheme.titleMedium?.copyWith(
                          color: LuminaTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _animationDuration,
                    min: 5.0,
                    max: 900.0,
                    activeColor: LuminaTheme.primaryColor,
                    inactiveColor: LuminaTheme.outlineVariantColor.withValues(alpha: 0.3),
                    onChanged: (value) {
                      setState(() {
                        _animationDuration = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startAnimationSequence,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LuminaTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.animation),
                    SizedBox(width: 8),
                    Text(
                      'Start Sequence',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
