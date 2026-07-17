import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/lumina_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<bool> _ledStates = List.generate(8, (_) => false);
  bool _isHomeClosed = false;
  int _ldrValue = 0;
  bool _isMotionDetected = false;
  bool _isAlarmTriggered = false;

  bool _autoMotionEnabled = true;
  bool _autoLightEnabled = true;
  int _lightOnDuration = 10;
  int _ldrDarkThreshold = 800;
  int _ldrSemiThreshold = 2000;
  bool _buzzerSoundEnabled = true;
  int _selectedAnimationIndex = 0;
  Set<int> _selectedAnimationLeds = {0, 1, 2, 3, 4, 5, 6, 7};
  Timer? _animationSimulationTimer;

  BluetoothConnection? _connection;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _buffer = "";
  Completer<bool>? _pongCompleter;
  late AnimationController _pulseController;

  int _currentIndex = 0;
  int _activeSubmittedPageIndex = 0;
  int _selectedGridConfigIndex = 0;

  final List<Map<String, dynamic>> _gridLedConfigs = [
    {'name': 'LED 1', 'color': const Color(0xFFFFD54F), 'physicalIndex': 0},
    {'name': 'LED 2', 'color': const Color(0xFF00B4D8), 'physicalIndex': 1},
    {'name': 'LED 3', 'color': const Color(0xFF4AE183), 'physicalIndex': 2},
    {'name': 'LED 4', 'color': const Color(0xFF4AE183), 'physicalIndex': 3},
    {'name': 'LED 5', 'color': const Color(0xFFEF4444), 'physicalIndex': 4},
    {'name': 'LED 6', 'color': const Color(0xFFFFD54F), 'physicalIndex': 5},
    {'name': 'LED 7', 'color': const Color(0xFF4AE183), 'physicalIndex': 6},
    {'name': 'LED 8', 'color': const Color(0xFFFFD54F), 'physicalIndex': 7},
  ];

  final List<String> _physicalPins = const [
    '13',
    '12',
    '14',
    '27',
    '26',
    '25',
    '33',
    '32',
  ];

  final List<Color> _availableColors = const [
    Color(0xFFFFD54F), // Amber/Yellow
    Color(0xFF00B4D8), // Cyan/Blue
    Color(0xFF4AE183), // Emerald/Green
    Color(0xFFEF4444), // Red
    Color(0xFF9B59B6), // Purple
    Color(0xFFFFA500), // Orange
    Color(0xFFE24A8D), // Pink/Magenta
    Color(0xFF00677D), // Dark Teal
  ];

  Future<void> _loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('grid_led_configs');
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        for (int i = 0; i < 8 && i < decoded.length; i++) {
          final map = decoded[i] as Map<String, dynamic>;
          setState(() {
            _gridLedConfigs[i]['name'] = map['name'];
            _gridLedConfigs[i]['color'] = Color(map['color'] as int);
            _gridLedConfigs[i]['physicalIndex'] = map['physicalIndex'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading saved config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> toSave = _gridLedConfigs.map((config) {
        return {
          'name': config['name'],
          'color': (config['color'] as Color).value,
          'physicalIndex': config['physicalIndex'],
        };
      }).toList();
      await prefs.setString('grid_led_configs', jsonEncode(toSave));
      _sendMappingToEsp32(); // Sync custom mapping with ESP32 whenever saved
    } catch (e) {
      debugPrint('Error saving config: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _loadSavedConfig().then((_) {
      _requestAllPermissionsOnLaunch().then((_) {
        _connectToBluetooth();
      });
    });
    _animationSimulationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      _runAnimationSimulation,
    );
  }

  @override
  void dispose() {
    _animationSimulationTimer?.cancel();
    _pulseController.dispose();
    _connection?.dispose();
    super.dispose();
  }

  Future<void> _requestAllPermissionsOnLaunch() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.phone,
    ].request();
  }

  Future<void> _connectToBluetooth() async {
    if (_isConnecting || _isConnected) return;
    setState(() {
      _isConnecting = true;
    });

    try {
      final connectGranted = await Permission.bluetoothConnect.isGranted;
      final scanGranted = await Permission.bluetoothScan.isGranted;
      final locationGranted = await Permission.location.isGranted;

      if (!connectGranted || !scanGranted || !locationGranted) {
        setState(() {
          _isConnecting = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bluetooth & Location permissions are required.'),
            ),
          );
        }
        return;
      }

      final List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial
          .instance
          .getBondedDevices();
      BluetoothDevice? targetDevice;
      for (var device in bondedDevices) {
        if (device.name == 'esp32 abdellah') {
          targetDevice = device;
          break;
        }
      }

      if (targetDevice == null) {
        setState(() {
          _isConnecting = false;
        });
        return;
      }

      final connection = await BluetoothConnection.toAddress(
        targetDevice.address,
      );
      setState(() {
        _connection = connection;
        _isConnected = true;
        _isConnecting = false;
      });

      _sendMappingToEsp32(); // Sync custom mapping on Bluetooth connection

      connection.input!.listen(_onDataReceived).onDone(() {
        setState(() {
          _isConnected = false;
          _connection = null;
        });
      });
    } catch (_) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });
    }
  }

  void _onDataReceived(Uint8List data) {
    _buffer += utf8.decode(data);
    while (_buffer.contains('\n')) {
      int idx = _buffer.indexOf('\n');
      String line = _buffer.substring(0, idx).trim();
      _buffer = _buffer.substring(idx + 1);
      if (line == 'PONG') {
        if (_pongCompleter != null && !_pongCompleter!.isCompleted) {
          _pongCompleter!.complete(true);
        }
      } else if (line == 'ALARM:1') {
        setState(() {
          _isAlarmTriggered = true;
        });
      } else if (line == 'ALARM:0') {
        setState(() {
          _isAlarmTriggered = false;
          _isHomeClosed = false;
        });
      } else {
        _parseTelemetry(line);
      }
    }
  }

  void _parseTelemetry(String line) {
    if (line.startsWith('LDR:')) {
      setState(() {
        _ldrValue = int.tryParse(line.substring(4)) ?? _ldrValue;
      });
    } else if (line.startsWith('PIR:')) {
      setState(() {
        _isMotionDetected = line.substring(4).trim() == '1';
      });
    } else if (line.startsWith('SYS:')) {
      _parseSystemState(line.substring(4));
    }
  }

  void _parseSystemState(String data) {
    try {
      List<String> parts = data.split(',');
      int mode = _activeSubmittedPageIndex;
      bool motion = _autoMotionEnabled;
      bool light = _autoLightEnabled;
      int duration = _lightOnDuration;
      int dark = _ldrDarkThreshold;
      int semi = _ldrSemiThreshold;
      bool buzzer = _buzzerSoundEnabled;
      int animIdx = _selectedAnimationIndex;
      int roomsMask = 15;
      for (var part in parts) {
        List<String> kv = part.split('=');
        if (kv.length == 2) {
          String key = kv[0].trim();
          String val = kv[1].trim();
          if (key == 'MODE') {
            mode = int.tryParse(val) ?? mode;
          } else if (key == 'M') {
            motion = val == '1';
          } else if (key == 'S') {
            light = val == '1';
          } else if (key == 'O') {
            duration = int.tryParse(val) ?? duration;
          } else if (key == 'TD') {
            dark = int.tryParse(val) ?? dark;
          } else if (key == 'TS') {
            semi = int.tryParse(val) ?? semi;
          } else if (key == 'B') {
            buzzer = val == '1';
          } else if (key == 'A') {
            animIdx = int.tryParse(val) ?? animIdx;
          } else if (key == 'AR') {
            roomsMask = int.tryParse(val) ?? roomsMask;
          }
        }
      }
      setState(() {
        _activeSubmittedPageIndex = mode;
        _autoMotionEnabled = motion;
        _autoLightEnabled = light;
        _lightOnDuration = duration;
        _ldrDarkThreshold = dark;
        _ldrSemiThreshold = semi;
        _buzzerSoundEnabled = buzzer;
        _selectedAnimationIndex = animIdx;
        _selectedAnimationLeds = {};
        for (int i = 0; i < 8; i++) {
          if (((roomsMask >> i) & 1) == 1) {
            _selectedAnimationLeds.add(i);
          }
        }
      });
    } catch (_) {}
  }

  void _sendCommand(String cmd) {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(Uint8List.fromList(utf8.encode('$cmd\n')));
    }
  }

  void _sendMappingToEsp32() {
    final mapping = List.generate(8, (i) => _gridLedConfigs[i]['physicalIndex'] as int);
    _sendCommand('MAP:${mapping.join(',')}');
  }

  Future<void> _checkConnectionAndShowAlert() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    if (!_isConnected) {
      await _connectToBluetooth();
    }

    if (!_isConnected) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showAlertDialog(
        'Connection Failed',
        'Could not connect to "esp32 abdellah". Please ensure the device is paired in your system settings and powered on.',
        isError: true,
      );
      return;
    }

    _pongCompleter = Completer<bool>();
    _sendCommand('PING');

    try {
      final success = await _pongCompleter!.future.timeout(
        const Duration(seconds: 2),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (success) {
        _showAlertDialog(
          'Verification Success',
          'Successfully connected to ESP32! Bidirectional Bluetooth communication is active and verified (PING -> PONG).',
          isError: false,
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showAlertDialog(
        'Verification Timeout',
        'Device connected but did not respond to the verification request. Serial communication might be blocked or busy.',
        isError: true,
      );
    } finally {
      _pongCompleter = null;
    }
  }

  void _showAlertDialog(String title, String message, {required bool isError}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(message, style: GoogleFonts.manrope(fontSize: 13)),
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
      ),
    );
  }

  void _toggleLed(int gridIndex) {
    if (_isHomeClosed || _activeSubmittedPageIndex == 1) return;
    final physicalIndex = _gridLedConfigs[gridIndex]['physicalIndex'] as int;
    setState(() {
      _ledStates[physicalIndex] = !_ledStates[physicalIndex];
    });
    _sendCommand('L${physicalIndex + 1}:${_ledStates[physicalIndex] ? 1 : 0}');
  }

  void _toggleHomeMode() {
    if (_activeSubmittedPageIndex == 1) return;
    setState(() {
      _isHomeClosed = !_isHomeClosed;
      if (_isHomeClosed) {
        for (int i = 0; i < 8; i++) {
          _ledStates[i] = false;
        }
      }
    });
    _sendCommand('D:${_isHomeClosed ? 1 : 0}');
  }

  Future<void> _callEmergency() async {
    final Uri url = Uri.parse('tel:212');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _stopAlarm() {
    setState(() {
      _isAlarmTriggered = false;
      _isHomeClosed = false;
    });
    _sendCommand('D:0');
  }

  void _toggleAutoMotion(bool val) {
    setState(() {
      _autoMotionEnabled = val;
    });
    _sendCommand('M:${val ? 1 : 0}');
  }

  void _toggleAutoLight(bool val) {
    setState(() {
      _autoLightEnabled = val;
    });
    _sendCommand('S:${val ? 1 : 0}');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF1F2F6), Color(0xFFE2E8F0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                    child: _buildHeader(textTheme),
                  ),
                  if (_currentIndex != 2)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0),
                      child: _buildSystemOverview(textTheme),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildActivePage(textTheme),
                    ),
                  ),
                  _buildBottomNavBar(textTheme),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 95,
            right: 84,
            child: _buildConfigFloatingButton(),
          ),
          Positioned(
            bottom: 95,
            right: 24,
            child: _buildBluetoothFloatingButton(),
          ),
          if (_isAlarmTriggered)
            Positioned.fill(child: _buildDangerPage(textTheme)),
        ],
      ),
    );
  }

  Widget _buildActivePage(TextTheme textTheme) {
    switch (_currentIndex) {
      case 0:
        return _buildPage0(textTheme);
      case 1:
        return _buildPage1(textTheme);
      case 2:
        return _buildPage2(textTheme);
      default:
        return _buildPage0(textTheme);
    }
  }

  Widget _buildPage0(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildHouseLayout(textTheme)],
    );
  }

  void _changeLightOnDuration(double val) {
    setState(() {
      _lightOnDuration = val.round();
    });
    _sendCommand('O:${val.round()}');
  }

  void _changeLdrDarkThreshold(double val) {
    setState(() {
      _ldrDarkThreshold = val.round();
    });
    _sendCommand('TD:${val.round()}');
  }

  void _changeLdrSemiThreshold(double val) {
    setState(() {
      _ldrSemiThreshold = val.round();
    });
    _sendCommand('TS:${val.round()}');
  }

  Widget _buildPage1(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAutomationCard(
          Icons.directions_run_rounded,
          'Motion Automation',
          'Use the PIR sensor to trigger sirens, blink LEDs, and alert the mobile application.',
          _autoMotionEnabled,
          _toggleAutoMotion,
          const Color(0xFFEF4444),
        ),
        const SizedBox(height: 16),
        _buildAutomationCard(
          Icons.brightness_auto_rounded,
          'Light Automation',
          'Automatically turn ON half or all house LEDs when environmental light is below the thresholds.',
          _autoLightEnabled,
          _toggleAutoLight,
          const Color(0xFFFFA500),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIGHT ON DURATION',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: _autoMotionEnabled
                      ? LuminaTheme.outlineColor
                      : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _autoMotionEnabled
                    ? 'Adjust how long LEDs remain ON after a sensor trigger'
                    : 'Duration config is MUTED because Motion Automation is disabled',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: _autoMotionEnabled
                      ? LuminaTheme.outlineColor.withValues(alpha: 0.7)
                      : Colors.grey.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _lightOnDuration.toDouble(),
                      min: 5.0,
                      max: 60.0,
                      divisions: 11,
                      activeColor: _autoMotionEnabled
                          ? LuminaTheme.primaryColor
                          : Colors.grey,
                      inactiveColor: _autoMotionEnabled
                          ? null
                          : Colors.grey.withValues(alpha: 0.2),
                      onChanged: _autoMotionEnabled
                          ? _changeLightOnDuration
                          : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _autoMotionEnabled ? '$_lightOnDuration sec' : 'MUTED',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _autoMotionEnabled
                            ? LuminaTheme.primaryColor
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DARK THRESHOLD (RUN 8 LEDs)',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: LuminaTheme.outlineColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lux split-point for Night: below this, the system activates all 8 LEDs.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: LuminaTheme.outlineColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _ldrDarkThreshold.toDouble(),
                      min: 0.0,
                      max: 2000.0,
                      divisions: 200,
                      activeColor: const Color(0xFFC8B6FF),
                      onChanged: _changeLdrDarkThreshold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_ldrDarkThreshold Lux',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: const Color(0xFFC8B6FF),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEMI-DARK THRESHOLD (RUN 4 LEDs)',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: LuminaTheme.outlineColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lux split-point for dim light: below this, the system runs 4 LEDs; above it, all LEDs switch off.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: LuminaTheme.outlineColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _ldrSemiThreshold.toDouble(),
                      min: 0.0,
                      max: 4000.0,
                      divisions: 400,
                      activeColor: const Color(0xFFFFA500),
                      onChanged: _changeLdrSemiThreshold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_ldrSemiThreshold Lux',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: const Color(0xFFFFA500),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutomationCard(
    IconData icon,
    String title,
    String description,
    bool isEnabled,
    void Function(bool) onChanged,
    Color activeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? activeColor.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? activeColor : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: LuminaTheme.onSurfaceColor,
                      ),
                    ),
                    Text(
                      isEnabled ? 'ACTIVE' : 'DISABLED',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: isEnabled ? activeColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: onChanged,
                activeColor: activeColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: LuminaTheme.outlineColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavBarItem(0, Icons.home_filled, 'Home'),
          _buildNavBarItem(1, Icons.sensors_rounded, 'Auto Mode'),
          _buildNavBarItem(2, Icons.auto_awesome_rounded, 'Animations'),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          // Clear all LED states to prevent leftover animation states
          for (int i = 0; i < 8; i++) {
            _ledStates[i] = false;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? LuminaTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? LuminaTheme.primaryColor
                  : LuminaTheme.outlineColor,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: LuminaTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothFloatingButton() {
    final statusColor = _isConnected
        ? const Color(0xFF4AE183)
        : _isConnecting
        ? const Color(0xFF00B4D8)
        : Colors.grey;

    return GestureDetector(
      onTap: _checkConnectionAndShowAlert,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: statusColor, width: 1.5),
        ),
        child: Center(
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00B4D8),
                    ),
                  ),
                )
              : Icon(Icons.bluetooth, color: statusColor, size: 24),
        ),
      ),
    );
  }

  Widget _buildHeader(TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SMART HOME',
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: LuminaTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Interactive Layout',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: LuminaTheme.onSurfaceColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: _activeSubmittedPageIndex == _currentIndex,
              activeColor: LuminaTheme.primaryColor,
              onChanged: (bool val) {
                setState(() {
                  if (val) {
                    _activeSubmittedPageIndex = _currentIndex;
                    _sendCommand('MODE:$_currentIndex');
                  } else {
                    _activeSubmittedPageIndex = -1;
                    _sendCommand('MODE:-1');
                    for (int i = 0; i < 8; i++) {
                      _ledStates[i] = false;
                    }
                  }
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHouseLayout(TextTheme textTheme) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          children: [
        ClipPath(
          clipper: RoofClipper(),
          child: Container(
            height: 90,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [LuminaTheme.primaryColor, Color(0xFF00B4D8)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 36.0),
                child: Text(
                  'RECTANGLE RESIDENCE',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildFloorHeader('OPEN-PLAN LED LAYOUT'),
              const SizedBox(height: 8),
              // Top row: LED 1 — LED 2 — LED 3
              Row(
                children: [
                  Expanded(child: _buildLedTile(0, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildLedTile(1, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildLedTile(2, textTheme)),
                ],
              ),
              const SizedBox(height: 6),
              // Middle row: LED 4 — HOME MODE — LED 5
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildLedTile(3, textTheme)),
                  const SizedBox(width: 6),
                  _buildHomeModeWidget(textTheme),
                  const SizedBox(width: 6),
                  Expanded(child: _buildLedTile(4, textTheme)),
                ],
              ),
              const SizedBox(height: 6),
              // Bottom row: LED 6 — LED 7 — LED 8
              Row(
                children: [
                  Expanded(child: _buildLedTile(5, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildLedTile(6, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildLedTile(7, textTheme)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
}

  Widget _buildFloorHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: LuminaTheme.onSurfaceVariantColor.withValues(alpha: 0.7),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLedTile(int index, TextTheme textTheme) {
    final config = _gridLedConfigs[index];
    final physicalIndex = config['physicalIndex'] as int;
    final isOn = _ledStates[physicalIndex];
    final color = config['color'] as Color;
    final pin = _physicalPins[physicalIndex];

    return GestureDetector(
      onTap: () => _toggleLed(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _isHomeClosed || _activeSubmittedPageIndex == 1
              ? Colors.grey.withValues(alpha: 0.15)
              : (isOn ? Colors.white : Colors.white.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !(_isHomeClosed || _activeSubmittedPageIndex == 1) && isOn
                ? color.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: !(_isHomeClosed || _activeSubmittedPageIndex == 1) && isOn
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              isOn && !(_isHomeClosed || _activeSubmittedPageIndex == 1)
                  ? Icons.lightbulb
                  : Icons.lightbulb_outline,
              color: isOn && !(_isHomeClosed || _activeSubmittedPageIndex == 1)
                  ? color
                  : LuminaTheme.outlineColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              config['name'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color:
                    isOn && !(_isHomeClosed || _activeSubmittedPageIndex == 1)
                    ? LuminaTheme.onSurfaceColor
                    : LuminaTheme.outlineColor,
              ),
            ),
            Text(
              'GP$pin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 8,
                color: LuminaTheme.outlineColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeModeWidget(TextTheme textTheme) {
    final isRed = _activeSubmittedPageIndex == 1 || _isHomeClosed;
    final themeColor = isRed
        ? const Color(0xFFEF4444)
        : const Color(0xFF4AE183);
    final text2 = _activeSubmittedPageIndex == 1
        ? 'PROTECTION'
        : (_isHomeClosed ? 'CLOSED' : 'OPEN');
    final icon = _activeSubmittedPageIndex == 1
        ? Icons.security
        : (_isHomeClosed ? Icons.lock : Icons.lock_open);

    return Expanded(
      child: GestureDetector(
        onTap: _toggleHomeMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: themeColor, size: 24),
              const SizedBox(height: 4),
              Text(
                'HOME',
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              Text(
                text2,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleBuzzerSound() {
    setState(() {
      _buzzerSoundEnabled = !_buzzerSoundEnabled;
    });
    _sendCommand('B:${_buzzerSoundEnabled ? 1 : 0}');
  }

  Widget _buildSystemOverview(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTelemetryTile(
              Icons.sensors,
              'Motion Sensor',
              _isMotionDetected ? 'Active' : 'No Motion',
              _isMotionDetected
                  ? const Color(0xFFEF4444)
                  : LuminaTheme.outlineColor,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTelemetryTile(
              Icons.wb_sunny_outlined,
              'Light Level',
              '$_ldrValue Lux',
              LuminaTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: _toggleBuzzerSound,
              child: _buildTelemetryTile(
                _buzzerSoundEnabled ? Icons.volume_up : Icons.volume_off,
                'Buzzer Sound',
                _buzzerSoundEnabled ? 'Active' : 'Muted',
                _buzzerSoundEnabled ? const Color(0xFF4AE183) : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile(
    IconData icon,
    String title,
    String value,
    Color activeColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: activeColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 8,
                    color: LuminaTheme.outlineColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: LuminaTheme.onSurfaceColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildConfigFloatingButton() {
    const statusColor = LuminaTheme.primaryColor;

    return GestureDetector(
      onTap: _showLedConfigDialog,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: statusColor, width: 1.5),
        ),
        child: const Center(
          child: Icon(Icons.settings, color: statusColor, size: 24),
        ),
      ),
    );
  }

  void _showLedConfigDialog() {
    final List<TextEditingController> controllers = List.generate(8, (i) {
      return TextEditingController(text: _gridLedConfigs[i]['name'] as String);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double keyboardHeight =
                MediaQuery.of(context).viewInsets.bottom;

            void updatePhysicalMapping(int newPhysicalIndex) {
              setState(() {
                _gridLedConfigs[_selectedGridConfigIndex]['physicalIndex'] = newPhysicalIndex;
              });

              _saveConfig();
              _sendCommand('ID:${newPhysicalIndex + 1}');

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  duration: const Duration(seconds: 2),
                  content: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: LuminaTheme.primaryContainerColor.withValues(
                          alpha: 0.5,
                        ),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.volume_up,
                          color: LuminaTheme.primaryContainerColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sent identify command to Physical LED ${newPhysicalIndex + 1}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + keyboardHeight),
                  decoration: BoxDecoration(
                    color: const Color(0xEC12161F), // Dark glassmorphic background
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Configure LED Mapping',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  for (var c in controllers) {
                                    c.dispose();
                                  }
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 8),
                          // Horizontal selector of Grid Positions
                          SizedBox(
                            height: 55,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 8,
                              itemBuilder: (context, i) {
                                final isSelected = i == _selectedGridConfigIndex;
                                final config = _gridLedConfigs[i];
                                final color = config['color'] as Color;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _selectedGridConfigIndex = i;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color.withValues(alpha: 0.15)
                                          : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? color : Colors.white12,
                                        width: 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(
                                                  alpha: 0.25,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lightbulb,
                                          color: color,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          config['name'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white60,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Display Name Input
                          Text(
                            'Display Name',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controllers[_selectedGridConfigIndex],
                            decoration: InputDecoration(
                              hintText: 'Enter LED name...',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: LuminaTheme.primaryContainerColor,
                                ),
                              ),
                            ),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _gridLedConfigs[_selectedGridConfigIndex]
                                    ['name'] = val;
                              });
                              _saveConfig();
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 20),
                          // Color Picker
                          Text(
                            'LED Color',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 38,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _availableColors.length,
                              itemBuilder: (context, colorIdx) {
                                final c = _availableColors[colorIdx];
                                final currentColor =
                                    _gridLedConfigs[_selectedGridConfigIndex]
                                        ['color'] as Color;
                                final isSelected =
                                    c.value == currentColor.value;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _gridLedConfigs[_selectedGridConfigIndex]
                                          ['color'] = c;
                                    });
                                    _saveConfig();
                                    setModalState(() {});
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: isSelected ? 2.5 : 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: c.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Physical LED Mappings
                          Text(
                            'Physical LED Mapping (GP Pin)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: List.generate(8, (i) {
                              final isCurrentMapping =
                                  _gridLedConfigs[_selectedGridConfigIndex]
                                          ['physicalIndex'] ==
                                      i;

                              int mappedToGridIndex = -1;
                              for (int g = 0; g < 8; g++) {
                                if (_gridLedConfigs[g]['physicalIndex'] == i) {
                                  mappedToGridIndex = g;
                                  break;
                                }
                              }

                              final pin = _physicalPins[i];

                              return GestureDetector(
                                onTap: () {
                                  updatePhysicalMapping(i);
                                  setModalState(() {});
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentMapping
                                        ? LuminaTheme.primaryContainerColor
                                            .withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCurrentMapping
                                          ? LuminaTheme.primaryContainerColor
                                          : Colors.white12,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'GP$pin',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentMapping
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                      if (mappedToGridIndex != -1 &&
                                          mappedToGridIndex !=
                                              _selectedGridConfigIndex)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '(${_gridLedConfigs[mappedToGridIndex]['name']})',
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      for (var c in controllers) {
        c.dispose();
      }
    });
  }

  Widget _buildDangerPage(TextTheme textTheme) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final colorVal = (0.2 + (_pulseController.value * 0.4));
        return Container(
          color: Color.fromRGBO((colorVal * 255).round(), 0, 0, 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.gpp_bad,
                color: Colors.white.withValues(alpha: 0.9),
                size: 96,
              ),
              const SizedBox(height: 24),
              Text(
                'SECURITY BREACH',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Someone is in the home right now!',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _callEmergency,
                icon: const Icon(Icons.phone_in_talk, color: Colors.red),
                label: Text(
                  'CALL URGENCY (212)',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _stopAlarm,
                icon: const Icon(Icons.shield, color: Colors.white),
                label: Text(
                  'STOP THE ALARM',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleAnimationLed(int physicalIndex) {
    setState(() {
      if (_selectedAnimationLeds.contains(physicalIndex)) {
        if (_selectedAnimationLeds.length > 1) {
          _selectedAnimationLeds.remove(physicalIndex);
        }
      } else {
        _selectedAnimationLeds.add(physicalIndex);
      }
    });
    int mask = 0;
    for (int idx in _selectedAnimationLeds) {
      mask |= (1 << idx);
    }
    _sendCommand('AR:$mask');
  }

  void _runAnimationSimulation(Timer timer) {
    if (_currentIndex != 2 || _activeSubmittedPageIndex != 2) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final anim = _selectedAnimationIndex;
    
    int ledMask = 0;
    for (int idx in _selectedAnimationLeds) {
      ledMask |= (1 << idx);
    }
    if (ledMask == 0) {
      setState(() {
        for (int i = 0; i < 8; i++) {
          _ledStates[i] = false;
        }
      });
      return;
    }

    const List<int> gridWaveSequence = [0, 1, 2, 4, 7, 6, 5, 3];

    if (anim == 0) {
      final step = (now ~/ 150) % 8;
      int activeStep = step;
      for (int attempt = 0; attempt < 8; attempt++) {
        final checkStep = (step + attempt) % 8;
        final gridIdx = gridWaveSequence[checkStep];
        final physIdx = _gridLedConfigs[gridIdx]['physicalIndex'] as int;
        if (((ledMask >> physIdx) & 1) == 1) {
          activeStep = checkStep;
          break;
        }
      }
      final activeGridIdx = gridWaveSequence[activeStep];
      final activePhysIdx = _gridLedConfigs[activeGridIdx]['physicalIndex'] as int;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          _ledStates[physIdx] = (physIdx == activePhysIdx) && (((ledMask >> physIdx) & 1) == 1);
        }
      });
    } else if (anim == 1) {
      final toggle = (now ~/ 500) % 2 == 0;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          if (((ledMask >> physIdx) & 1) == 1) {
            _ledStates[physIdx] = toggle;
          } else {
            _ledStates[physIdx] = false;
          }
        }
      });
    } else if (anim == 2) {
      final toggle = (now ~/ 100) % 2 == 0;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          if (((ledMask >> physIdx) & 1) == 1) {
            _ledStates[physIdx] = toggle;
          } else {
            _ledStates[physIdx] = false;
          }
        }
      });
    } else if (anim == 3) {
      final toggle = (now ~/ 200) % 2 == 0;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          if (((ledMask >> physIdx) & 1) == 1) {
            if (i % 2 == 0) {
              _ledStates[physIdx] = toggle;
            } else {
              _ledStates[physIdx] = !toggle;
            }
          } else {
            _ledStates[physIdx] = false;
          }
        }
      });
    } else if (anim == 4) {
      final step = (now ~/ 150) % 8;
      int offStep = step;
      for (int attempt = 0; attempt < 8; attempt++) {
        final checkStep = (step + attempt) % 8;
        final gridIdx = gridWaveSequence[checkStep];
        final physIdx = _gridLedConfigs[gridIdx]['physicalIndex'] as int;
        if (((ledMask >> physIdx) & 1) == 1) {
          offStep = checkStep;
          break;
        }
      }
      final offGridIdx = gridWaveSequence[offStep];
      final offPhysIdx = _gridLedConfigs[offGridIdx]['physicalIndex'] as int;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          if (((ledMask >> physIdx) & 1) == 1) {
            _ledStates[physIdx] = (physIdx != offPhysIdx);
          } else {
            _ledStates[physIdx] = false;
          }
        }
      });
    } else if (anim == 5) {
      final step = (now ~/ 150) % 6;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          _ledStates[physIdx] = false;
        }
        if (step == 0) {
          final phys = _gridLedConfigs[3]['physicalIndex'] as int;
          if (((ledMask >> phys) & 1) == 1) _ledStates[phys] = true;
        } else if (step == 1) {
          final phys0 = _gridLedConfigs[0]['physicalIndex'] as int;
          final phys5 = _gridLedConfigs[5]['physicalIndex'] as int;
          if (((ledMask >> phys0) & 1) == 1) _ledStates[phys0] = true;
          if (((ledMask >> phys5) & 1) == 1) _ledStates[phys5] = true;
        } else if (step == 2) {
          final phys1 = _gridLedConfigs[1]['physicalIndex'] as int;
          final phys6 = _gridLedConfigs[6]['physicalIndex'] as int;
          if (((ledMask >> phys1) & 1) == 1) _ledStates[phys1] = true;
          if (((ledMask >> phys6) & 1) == 1) _ledStates[phys6] = true;
        } else if (step == 3) {
          final phys2 = _gridLedConfigs[2]['physicalIndex'] as int;
          final phys7 = _gridLedConfigs[7]['physicalIndex'] as int;
          if (((ledMask >> phys2) & 1) == 1) _ledStates[phys2] = true;
          if (((ledMask >> phys7) & 1) == 1) _ledStates[phys7] = true;
        } else if (step == 4) {
          final phys4 = _gridLedConfigs[4]['physicalIndex'] as int;
          if (((ledMask >> phys4) & 1) == 1) _ledStates[phys4] = true;
        }
      });
    } else if (anim == 6) {
      final step = (now ~/ 250) % 4;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          _ledStates[physIdx] = false;
        }
        if (step == 0) {
          final p3 = _gridLedConfigs[3]['physicalIndex'] as int;
          final p4 = _gridLedConfigs[4]['physicalIndex'] as int;
          if (((ledMask >> p3) & 1) == 1) _ledStates[p3] = true;
          if (((ledMask >> p4) & 1) == 1) _ledStates[p4] = true;
        } else if (step == 1) {
          final p0 = _gridLedConfigs[0]['physicalIndex'] as int;
          final p2 = _gridLedConfigs[2]['physicalIndex'] as int;
          final p5 = _gridLedConfigs[5]['physicalIndex'] as int;
          final p7 = _gridLedConfigs[7]['physicalIndex'] as int;
          if (((ledMask >> p0) & 1) == 1) _ledStates[p0] = true;
          if (((ledMask >> p2) & 1) == 1) _ledStates[p2] = true;
          if (((ledMask >> p5) & 1) == 1) _ledStates[p5] = true;
          if (((ledMask >> p7) & 1) == 1) _ledStates[p7] = true;
        } else if (step == 2) {
          final p1 = _gridLedConfigs[1]['physicalIndex'] as int;
          final p6 = _gridLedConfigs[6]['physicalIndex'] as int;
          if (((ledMask >> p1) & 1) == 1) _ledStates[p1] = true;
          if (((ledMask >> p6) & 1) == 1) _ledStates[p6] = true;
        }
      });
    } else if (anim == 7) {
      final step = (now ~/ 200) % 4;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          _ledStates[physIdx] = false;
        }
        if (step == 0) {
          final p0 = _gridLedConfigs[0]['physicalIndex'] as int;
          final p7 = _gridLedConfigs[7]['physicalIndex'] as int;
          if (((ledMask >> p0) & 1) == 1) _ledStates[p0] = true;
          if (((ledMask >> p7) & 1) == 1) _ledStates[p7] = true;
        } else if (step == 1) {
          final p2 = _gridLedConfigs[2]['physicalIndex'] as int;
          final p5 = _gridLedConfigs[5]['physicalIndex'] as int;
          if (((ledMask >> p2) & 1) == 1) _ledStates[p2] = true;
          if (((ledMask >> p5) & 1) == 1) _ledStates[p5] = true;
        } else if (step == 2) {
          final p1 = _gridLedConfigs[1]['physicalIndex'] as int;
          final p6 = _gridLedConfigs[6]['physicalIndex'] as int;
          final p3 = _gridLedConfigs[3]['physicalIndex'] as int;
          final p4 = _gridLedConfigs[4]['physicalIndex'] as int;
          if (((ledMask >> p1) & 1) == 1) _ledStates[p1] = true;
          if (((ledMask >> p6) & 1) == 1) _ledStates[p6] = true;
          if (((ledMask >> p3) & 1) == 1) _ledStates[p3] = true;
          if (((ledMask >> p4) & 1) == 1) _ledStates[p4] = true;
        }
      });
    } else if (anim == 8) {
      final step = (now ~/ 150) % 8;
      setState(() {
        for (int i = 0; i < 8; i++) {
          final physIdx = _gridLedConfigs[i]['physicalIndex'] as int;
          _ledStates[physIdx] = false;
        }
        final gridIdx1 = gridWaveSequence[step];
        final gridIdx2 = gridWaveSequence[(step + 4) % 8];
        final p1 = _gridLedConfigs[gridIdx1]['physicalIndex'] as int;
        final p2 = _gridLedConfigs[gridIdx2]['physicalIndex'] as int;
        if (((ledMask >> p1) & 1) == 1) _ledStates[p1] = true;
        if (((ledMask >> p2) & 1) == 1) _ledStates[p2] = true;
      });
    }
  }

  Widget _buildPage2(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBuzzerToggleRow(textTheme),
        const SizedBox(height: 24),
        _buildAnimationAlbum(textTheme),
        const SizedBox(height: 24),
        _buildAnimationRoomsSelector(textTheme),
      ],
    );
  }

  Widget _buildBuzzerToggleRow(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  _buzzerSoundEnabled ? Icons.volume_up : Icons.volume_off,
                  color: _buzzerSoundEnabled
                      ? const Color(0xFF4AE183)
                      : LuminaTheme.outlineColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buzzer Sound Status',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: LuminaTheme.onSurfaceColor,
                        ),
                      ),
                      Text(
                        _buzzerSoundEnabled
                            ? 'Buzzer beep sounds are active'
                            : 'Buzzer beep sounds are muted',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: LuminaTheme.outlineColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _buzzerSoundEnabled,
            activeColor: const Color(0xFF4AE183),
            onChanged: (val) {
              _toggleBuzzerSound();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationAlbum(TextTheme textTheme) {
    final List<Map<String, dynamic>> animationsList = [
      {
        'title': 'Wave Chase',
        'description': 'Sequential perimeter light wave',
        'icon': Icons.waves_rounded,
        'color': const Color(0xFF4A90E2),
      },
      {
        'title': 'Breathing Glow',
        'description': 'Slow breathing glow transition',
        'icon': Icons.favorite_rounded,
        'color': const Color(0xFFE24A8D),
      },
      {
        'title': 'Party Strobe',
        'description': 'Rapid strobe flashing lights',
        'icon': Icons.flash_on_rounded,
        'color': const Color(0xFFF5A623),
      },
      {
        'title': 'Alternating Pulse',
        'description': 'Pulse between odd and even LEDs',
        'icon': Icons.sync_alt_rounded,
        'color': const Color(0xFF4AE183),
      },
      {
        'title': 'Snake Circle',
        'description': 'All ON, one gap circles around',
        'icon': Icons.rotate_right_rounded,
        'color': const Color(0xFF9B59B6),
      },
      {
        'title': 'Parallel Split',
        'description': 'Wave split from center-left to right',
        'icon': Icons.splitscreen_rounded,
        'color': const Color(0xFFE67E22),
      },
      {
        'title': 'Radial Ripple',
        'description': 'Expanding ripple from inside out',
        'icon': Icons.blur_circular_rounded,
        'color': const Color(0xFF1ABC9C),
      },
      {
        'title': 'Symmetric Cross',
        'description': 'Diagonal and cross pulse sequence',
        'icon': Icons.add_circle_outline_rounded,
        'color': const Color(0xFFE74C3C),
      },
      {
        'title': 'Double Spiral',
        'description': 'Dual-point spiral chase wave',
        'icon': Icons.all_inclusive_rounded,
        'color': const Color(0xFF2ECC71),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT LIGHT ANIMATION',
          style: textTheme.labelSmall?.copyWith(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            color: LuminaTheme.outlineColor,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: animationsList.length,
            itemBuilder: (context, index) {
              final anim = animationsList[index];
              final isSelected = _selectedAnimationIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAnimationIndex = index;
                  });
                  _sendCommand('A:$index');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? anim['color'].withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? anim['color'] : Colors.white,
                      width: 2.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: anim['color'].withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            anim['icon'],
                            color: isSelected
                                ? anim['color']
                                : LuminaTheme.outlineColor,
                            size: 32,
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: anim['color'],
                              size: 20,
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            anim['title'],
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: LuminaTheme.onSurfaceColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            anim['description'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: LuminaTheme.outlineColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimationRoomsSelector(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT ACTIVE LEDS',
          style: textTheme.labelSmall?.copyWith(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            color: LuminaTheme.outlineColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildMiniLedTile(0, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildMiniLedTile(1, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildMiniLedTile(2, textTheme)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _buildMiniLedTile(3, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 58,
                      child: const Center(
                        child: Icon(Icons.home_outlined, color: Colors.grey, size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: _buildMiniLedTile(4, textTheme)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _buildMiniLedTile(5, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildMiniLedTile(6, textTheme)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildMiniLedTile(7, textTheme)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniLedTile(int index, TextTheme textTheme) {
    final config = _gridLedConfigs[index];
    final physicalIndex = config['physicalIndex'] as int;
    final isIncluded = _selectedAnimationLeds.contains(physicalIndex);
    final isOn = _ledStates[physicalIndex];
    final color = config['color'] as Color;

    return GestureDetector(
      onTap: () => _toggleAnimationLed(physicalIndex),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Icon(
          isOn ? Icons.lightbulb : Icons.lightbulb_outline,
          color: isIncluded
              ? (isOn ? color : color.withValues(alpha: 0.4))
              : Colors.grey,
          size: 34,
        ),
      ),
    );
  }
}

class RoofClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
