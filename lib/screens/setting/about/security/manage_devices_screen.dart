
import 'package:flutter/material.dart';
import 'package:threeduo_learning/services/device_api_service.dart';

class ManageDevicesScreen extends StatefulWidget {
  const ManageDevicesScreen({super.key});

  @override
  State<ManageDevicesScreen> createState() =>
      _ManageDevicesScreenState();
}

class _ManageDevicesScreenState extends State<ManageDevicesScreen> {
  List<Map<String, dynamic>> _devices = [];

  bool _isLoading = true;
  String? _errorMessage;
  String? _loggingOutDeviceId;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final devices = await DeviceApiService.getDevices();

      if (!mounted) return;

      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } on DeviceApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeDevice(Map<String, dynamic> device) async {
    final deviceId = device['id']?.toString();
    final deviceName = device['name']?.toString() ?? 'อุปกรณ์นี้';

    if (deviceId == null || deviceId.isEmpty) {
      _showMessage('ไม่พบข้อมูล Session ของอุปกรณ์');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากระบบอุปกรณ์'),
        content: Text('ต้องการออกจากระบบ $deviceName ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _loggingOutDeviceId = deviceId;
    });

    try {
      await DeviceApiService.logoutDevice(deviceId);

      if (!mounted) return;

      setState(() {
        _devices.removeWhere(
          (item) => item['id']?.toString() == deviceId,
        );
        _loggingOutDeviceId = null;
      });

      _showMessage('ออกจากระบบอุปกรณ์เรียบร้อยแล้ว');
    } on DeviceApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _loggingOutDeviceId = null;
      });

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loggingOutDeviceId = null;
      });

      _showMessage('ออกจากระบบไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  IconData _deviceIcon(Map<String, dynamic> device) {
    final type = (device['type'] ?? '').toString().toLowerCase();
    final name = (device['name'] ?? '').toString().toLowerCase();

    if (type.contains('phone') ||
        type.contains('mobile') ||
        name.contains('iphone') ||
        name.contains('android')) {
      return Icons.phone_iphone_rounded;
    }

    if (type.contains('tablet') ||
        name.contains('ipad')) {
      return Icons.tablet_rounded;
    }

    if (type.contains('laptop') ||
        name.contains('macbook')) {
      return Icons.laptop_mac_rounded;
    }

    if (type.contains('desktop') ||
        name.contains('windows') ||
        name.contains('chrome')) {
      return Icons.desktop_windows_rounded;
    }

    return Icons.devices_rounded;
  }

  String _deviceTypeLabel(dynamic value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'phone':
      case 'mobile':
        return 'โทรศัพท์';
      case 'tablet':
        return 'แท็บเล็ต';
      case 'laptop':
        return 'แล็ปท็อป';
      case 'desktop':
        return 'คอมพิวเตอร์';
      default:
        return 'ไม่ระบุประเภทอุปกรณ์';
    }
  }

  String _formatLastActive(dynamic value, bool isCurrent) {
    if (isCurrent) return 'กำลังใช้งาน';

    if (value == null) return 'ไม่ทราบเวลาที่ใช้งานล่าสุด';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'ไม่ทราบเวลาที่ใช้งานล่าสุด';

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inSeconds < 60) {
      return 'ใช้งานล่าสุดเมื่อสักครู่';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    }

    if (difference.inDays < 2) {
      return 'เมื่อวานนี้';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final isCurrent = device['isCurrent'] == true;
    final deviceId = device['id']?.toString();
    final isLoggingOut = deviceId != null &&
        deviceId == _loggingOutDeviceId;

    final deviceName =
        (device['name'] ?? 'Unknown device').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _deviceIcon(device),
              color: isCurrent
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      deviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'อุปกรณ์นี้',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_deviceTypeLabel(device['type'])} • '
                  '${_formatLastActive(device['lastActiveAt'], isCurrent)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            IconButton(
              tooltip: 'ออกจากระบบอุปกรณ์นี้',
              onPressed: isLoggingOut
                  ? null
                  : () => _removeDevice(device),
              icon: isLoggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A),
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'จัดการอุปกรณ์',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDevices,
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }

    if (_devices.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDevices,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.devices_rounded,
              size: 52,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'ไม่พบอุปกรณ์ที่เข้าสู่ระบบอยู่',
                style: TextStyle(
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(24),
        itemCount: _devices.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildDeviceCard(_devices[index]),
      ),
    );
  }
}
