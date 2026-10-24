
import 'package:flutter/material.dart';
import 'package:threeduo_learning/services/device_api_service.dart';
import 'package:threeduo_learning/services/account_settings_api_service.dart';

// หน้าปลายทาง
import 'about/security/change_password_screen.dart';
import 'about/security/manage_devices_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {

  int _activeDeviceCount = 0;
  bool _isLoadingDeviceCount = false;

  String _passwordChangedSubtitle = 'กำลังโหลดข้อมูล...';
  bool _isLoadingPasswordChangedAt = false;

  // โหลดวันที่เปลี่ยนรหัสผ่านล่าสุดจาก Backend
  Future<void> _loadPasswordChangedAt() async {
    if (_isLoadingPasswordChangedAt) return;

    _isLoadingPasswordChangedAt = true;

    try {
      final changedAt =
          await AccountSettingsApiService.getPasswordChangedAt();

      if (!mounted) return;

      setState(() {
        _passwordChangedSubtitle = changedAt == null
            ? 'ยังไม่มีข้อมูลวันที่เปลี่ยนรหัสผ่าน'
            : _formatPasswordChangedAt(changedAt);
      });
    } catch (e) {
      debugPrint('Load password changed date error: $e');

      if (!mounted) return;

      setState(() {
        _passwordChangedSubtitle =
            'ไม่สามารถโหลดข้อมูลวันที่ได้';
      });
    } finally {
      _isLoadingPasswordChangedAt = false;
    }
  }

  // แปลงวันที่เป็นข้อความภาษาไทย
  String _formatPasswordChangedAt(DateTime changedAt) {
    final now = DateTime.now();

    // เปรียบเทียบเฉพาะวันที่ โดยใช้เวลาท้องถิ่นของเครื่อง
    final changedDate = changedAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final passwordDate = DateTime(
      changedDate.year,
      changedDate.month,
      changedDate.day,
    );

    if (passwordDate.isAfter(today)) {
      return 'เปลี่ยนรหัสผ่านล่าสุด ${_formatDate(changedDate)}';
    }

    final days = today.difference(passwordDate).inDays;

    if (days == 0) {
      return 'เปลี่ยนรหัสผ่านล่าสุดวันนี้';
    }

    if (days == 1) {
      return 'เปลี่ยนรหัสผ่านล่าสุดเมื่อวาน';
    }

    if (days < 30) {
      return 'เปลี่ยนล่าสุดเมื่อ $days วันที่แล้ว';
    }

    if (days < 365) {
      final months = (days / 30).floor();
      return 'เปลี่ยนล่าสุดเมื่อ $months เดือนที่แล้ว';
    }

    final years = (days / 365).floor();
    return 'เปลี่ยนล่าสุดเมื่อ $years ปีที่แล้ว';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  // โหลดจำนวนอุปกรณ์ที่เข้าสู่ระบบอยู่
  Future<void> _loadActiveDeviceCount() async {
    if (_isLoadingDeviceCount) return;

    _isLoadingDeviceCount = true;

    try {
      final devices = await DeviceApiService.getDevices();

      if (!mounted) return;

      setState(() {
        _activeDeviceCount = devices.length;
      });
    } catch (e) {
      debugPrint('Load active device count error: $e');
    } finally {
      _isLoadingDeviceCount = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadActiveDeviceCount();
    _loadPasswordChangedAt();
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
          'ความปลอดภัยและรหัสผ่าน',
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // =========================
              // LOGIN & AUTHENTICATION
              // =========================
              _buildSectionHeader('ความปลอดภัยในการเข้าสู่ระบบ'),
              const SizedBox(height: 12),

              _buildCardContainer([
                _buildActionTile(
                  icon: Icons.key_rounded,
                  iconBgColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  title: 'เปลี่ยนรหัสผ่าน',
                  subtitle: _passwordChangedSubtitle,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ChangePasswordScreen(),
                      ),
                    );

                    if (mounted) {
                      await _loadPasswordChangedAt();
                    }
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // =========================
              // DEVICE MANAGEMENT
              // =========================
              _buildSectionHeader('อุปกรณ์ที่ใช้งานอยู่'),
              const SizedBox(height: 12),

              _buildCardContainer([
                _buildActionTile(
                  icon: Icons.devices_rounded,
                  iconBgColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                  title: 'จัดการอุปกรณ์',
                  subtitle: _isLoadingDeviceCount
                      ? 'กำลังโหลดข้อมูลอุปกรณ์...'
                      : 'เข้าสู่ระบบอยู่ $_activeDeviceCount อุปกรณ์',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ManageDevicesScreen(),
                      ),
                    );

                    if (mounted) {
                      await _loadActiveDeviceCount();
                    }
                  },
                ),
              ]),

              const SizedBox(height: 32),

              // =========================
              // LOG OUT
              // =========================
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: Color(0xFFFCA5A5),
                        width: 1,
                      ),
                    ),
                  ),
                  onPressed: () {
                    _showLogoutConfirmDialog(context);
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  label: const Text(
                    'ออกจากระบบในอุปกรณ์อื่นทั้งหมด',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ออกจากระบบในอุปกรณ์อื่นทั้งหมด (เครื่องนี้ยังใช้งานต่อได้)
  Future<void> _performLogout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final int count = await DeviceApiService.logoutOtherDevices();

      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'ออกจากระบบอุปกรณ์อื่นแล้ว $count เครื่อง'
                : 'ไม่มีอุปกรณ์อื่นที่เข้าสู่ระบบอยู่',
          ),
        ),
      );

      await _loadActiveDeviceCount();
    } catch (e) {
      if (!context.mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ออกจากระบบอุปกรณ์อื่นไม่สำเร็จ: $e'),
        ),
      );
    }
  }

  // Dialog ยืนยันการออกจากระบบ
  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากระบบอุปกรณ์อื่นทั้งหมด ?'),
        content: const Text(
          'อุปกรณ์อื่นทั้งหมดจะถูกออกจากระบบและต้องเข้าสู่ระบบใหม่ '
          'ส่วนเครื่องนี้ยังใช้งานต่อได้ตามปกติ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _performLogout(context);
            },
            child: const Text(
              'ออกจากระบบ',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF94A3B8),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF64748B),
          size: 18,
        ),
      ),
      onTap: onTap,
    );
  }
}
