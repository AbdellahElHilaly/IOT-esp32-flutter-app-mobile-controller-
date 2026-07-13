import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  Set<int> _selectedAnimationRooms = {1, 2, 3, 4};

  BluetoothConnection? _connection;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _buffer = "";
  Completer<bool>? _pongCompleter;
  late AnimationController _pulseController;

  int _currentIndex = 0;
  int _activeSubmittedPageIndex = 0;

  final List<Map<String, dynamic>> _ledConfig = [
    {'name': 'LED 1', 'pin': '13', 'color': const Color(0xFFFFA500)},
    {'name': 'LED 2', 'pin': '12', 'color': const Color(0xFFFFA500)},
    {'name': 'LED 3', 'pin': '14', 'color': const Color(0xFF4AE183)},
    {'name': 'LED 4', 'pin': '27', 'color': const Color(0xFF4AE183)},
    {'name': 'LED 5', 'pin': '26', 'color': const Color(0xFF00B4D8)},
    {'name': 'LED 6', 'pin': '25', 'color': const Color(0xFF00B4D8)},
    {'name': 'LED 7', 'pin': '33', 'color': const Color(0xFFC8B6FF)},
    {'name': 'LED 8', 'pin': '32', 'color': const Color(0xFFC8B6FF)},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _requestAllPermissionsOnLaunch().then((_) {
      _connectToBluetooth();
    });
  }

  @override
  void dispose() {
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

      final List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
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

      final connection = await BluetoothConnection.toAddress(targetDevice.address);
      setState(() {
        _connection = connection;
        _isConnected = true;
        _isConnecting = false;
      });

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
        _selectedAnimationRooms = {};
        for (int i = 0; i < 4; i++) {
          if (((roomsMask >> i) & 1) == 1) {
            _selectedAnimationRooms.add(i + 1);
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

  Future<void> _checkConnectionAndShowAlert() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
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
      final success = await _pongCompleter!.future.timeout(const Duration(seconds: 2));
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
        content: Text(
          message,
          style: GoogleFonts.manrope(fontSize: 13),
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
      ),
    );
  }

  void _toggleLed(int index) {
    if (_isHomeClosed || _activeSubmittedPageIndex == 1) return;
    setState(() {
      _ledStates[index] = !_ledStates[index];
    });
    _sendCommand('L${index + 1}:${_ledStates[index] ? 1 : 0}');
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
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
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
                colors: [
                  Color(0xFFF1F2F6),
                  Color(0xFFE2E8F0),
                ],
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
            right: 24,
            child: _buildBluetoothFloatingButton(),
          ),
          if (_isAlarmTriggered)
            Positioned.fill(
              child: _buildDangerPage(textTheme),
            ),
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
      children: [
        _buildHouseLayout(textTheme),
      ],
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
          'Automatically turn ON Room 1 and Room 2 LEDs when environmental light is below the run threshold.',
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
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
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
                  color: _autoMotionEnabled ? LuminaTheme.outlineColor : Colors.grey,
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
                      activeColor: _autoMotionEnabled ? LuminaTheme.primaryColor : Colors.grey,
                      inactiveColor: _autoMotionEnabled ? null : Colors.grey.withValues(alpha: 0.2),
                      onChanged: _autoMotionEnabled ? _changeLightOnDuration : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _autoMotionEnabled ? '$_lightOnDuration sec' : 'MUTED',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _autoMotionEnabled ? LuminaTheme.primaryColor : Colors.grey,
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
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DARK THRESHOLD (RUN 2 LEDs)',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: LuminaTheme.outlineColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lux value split-point for Night (below this runs 2 LEDs)',
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEMI-DARK THRESHOLD (RUN 1 LED)',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: LuminaTheme.outlineColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lux value split-point for Day (above this turns OFF all LEDs)',
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEnabled ? activeColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
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
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
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
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? LuminaTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? LuminaTheme.primaryColor : LuminaTheme.outlineColor,
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
          border: Border.all(
            color: statusColor,
            width: 1.5,
          ),
        ),
        child: Center(
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
                  ),
                )
              : Icon(
                  Icons.bluetooth,
                  color: statusColor,
                  size: 24,
                ),
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
    return Column(
      children: [
        ClipPath(
          clipper: RoofClipper(),
          child: Container(
            height: 90,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LuminaTheme.primaryColor,
                  Color(0xFF00B4D8),
                ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 36.0),
                child: Text(
                  '2-STORY RESIDENCE',
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
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              _buildFloorHeader('FIRST FLOOR - BEDROOMS & GUEST ROOMS'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildRoomCard(
                      'Room 3',
                      'Left Upper',
                      [4, 5],
                      textTheme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRoomCard(
                      'Room 4',
                      'Right Upper',
                      [6, 7],
                      textTheme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),
              _buildFloorHeader('GROUND FLOOR - CONTROL CENTER & LIVING ROOM'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildRoomCard(
                      'Room 1',
                      'Left Lower',
                      [0, 1],
                      textTheme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildHomeModeWidget(textTheme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRoomCard(
                      'Room 2',
                      'Right Lower',
                      [2, 3],
                      textTheme,
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

  Widget _buildRoomCard(
    String roomName,
    String subtitle,
    List<int> ledIndices,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roomName,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: LuminaTheme.outlineColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLedTile(ledIndices[0], textTheme)),
              const SizedBox(width: 8),
              Expanded(child: _buildLedTile(ledIndices[1], textTheme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedTile(int index, TextTheme textTheme) {
    final config = _ledConfig[index];
    final isOn = _ledStates[index];
    final color = config['color'] as Color;

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
            color: !(_isHomeClosed || _activeSubmittedPageIndex == 1) && isOn ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: !(_isHomeClosed || _activeSubmittedPageIndex == 1) && isOn
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              isOn && !(_isHomeClosed || _activeSubmittedPageIndex == 1) ? Icons.lightbulb : Icons.lightbulb_outline,
              color: isOn && !(_isHomeClosed || _activeSubmittedPageIndex == 1) ? color : LuminaTheme.outlineColor,
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
                color: isOn && !(_isHomeClosed || _activeSubmittedPageIndex == 1) ? LuminaTheme.onSurfaceColor : LuminaTheme.outlineColor,
              ),
            ),
            Text(
              'GP${config['pin']}',
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
    final themeColor = isRed ? const Color(0xFFEF4444) : const Color(0xFF4AE183);
    final text2 = _activeSubmittedPageIndex == 1 ? 'PROTECTION' : (_isHomeClosed ? 'CLOSED' : 'OPEN');
    final icon = _activeSubmittedPageIndex == 1 ? Icons.security : (_isHomeClosed ? Icons.lock : Icons.lock_open);

    return GestureDetector(
      onTap: _toggleHomeMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 70,
        height: 100,
        decoration: BoxDecoration(
          color: themeColor.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          border: Border.all(
            color: themeColor,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: themeColor,
              size: 24,
            ),
            const SizedBox(height: 6),
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
              style: GoogleFonts.hankenGrotesk(
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
          ],
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
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTelemetryTile(
              Icons.sensors,
              'Motion Sensor',
              _isMotionDetected ? 'Active' : 'No Motion',
              _isMotionDetected ? const Color(0xFFEF4444) : LuminaTheme.outlineColor,
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

  void _toggleAnimationRoom(int roomNum) {
    setState(() {
      if (_selectedAnimationRooms.contains(roomNum)) {
        if (_selectedAnimationRooms.length > 1) {
          _selectedAnimationRooms.remove(roomNum);
        }
      } else {
        _selectedAnimationRooms.add(roomNum);
      }
    });
    int mask = 0;
    for (int r in _selectedAnimationRooms) {
      mask |= (1 << (r - 1));
    }
    _sendCommand('AR:$mask');
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
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  _buzzerSoundEnabled ? Icons.volume_up : Icons.volume_off,
                  color: _buzzerSoundEnabled ? const Color(0xFF4AE183) : LuminaTheme.outlineColor,
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
                        _buzzerSoundEnabled ? 'Buzzer beep sounds are active' : 'Buzzer beep sounds are muted',
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
        'description': 'Sequential room-to-room light wave',
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
                            )
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
                             color: isSelected ? anim['color'] : LuminaTheme.outlineColor,
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
    final rooms = [
      {'id': 1, 'name': 'Room 1', 'floor': 'Ground Floor L'},
      {'id': 2, 'name': 'Room 2', 'floor': 'Ground Floor R'},
      {'id': 3, 'name': 'Room 3', 'floor': 'First Floor L'},
      {'id': 4, 'name': 'Room 4', 'floor': 'First Floor R'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TARGET ROOMS',
          style: textTheme.labelSmall?.copyWith(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            color: LuminaTheme.outlineColor,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            final roomId = room['id'] as int;
            final isSelected = _selectedAnimationRooms.contains(roomId);
            return GestureDetector(
              onTap: () => _toggleAnimationRoom(roomId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? LuminaTheme.primaryColor.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? LuminaTheme.primaryColor : Colors.white,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.meeting_room_rounded,
                          color: isSelected ? LuminaTheme.primaryColor : LuminaTheme.outlineColor,
                          size: 20,
                        ),
                        Checkbox(
                          value: isSelected,
                          activeColor: LuminaTheme.primaryColor,
                          onChanged: (_) => _toggleAnimationRoom(roomId),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room['name'] as String,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: LuminaTheme.onSurfaceColor,
                          ),
                        ),
                        Text(
                          room['floor'] as String,
                          style: GoogleFonts.manrope(
                            fontSize: 8,
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
      ],
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
