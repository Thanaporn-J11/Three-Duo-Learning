import 'package:flutter/material.dart';
import 'package:threeduo_learning/services/app_version.dart';
import 'about/terms_screen.dart';
import 'about/privacy_screen.dart';
import 'about/help_center_screen.dart';
import 'about/contact_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
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
          "เกี่ยวกับแอปพลิเคชัน",
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 12),

              //=========================
              // HERO BRANDING CARD
              //=========================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          // Rounded square, same shape as the app icon.
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        // App logo (the mascot), same art as the app icon.
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/character/app_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "ThreeDuo Learning",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "เรียนภาษาอังกฤษสนุก ๆ ไปกับเพื่อน ๆ ทุกวัน",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: FutureBuilder<String>(
                        future: AppVersion.label(),
                        builder:
                            (context, snapshot) => Text(
                              "เวอร์ชัน ${snapshot.data ?? '...'}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              //=========================
              // LEGAL & INFO SECTION
              //=========================
              _buildSectionHeader("ข้อตกลงและข้อมูลทางกฎหมาย"),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingTile(
                      context: context,
                      icon: Icons.gavel_rounded,
                      iconBgColor: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      title: "ข้อตกลงการใช้งาน",
                      subtitle: "อ่านเงื่อนไขและข้อตกลงการให้บริการ",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TermsScreen()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.shield_outlined,
                      iconBgColor: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      title: "นโยบายความเป็นส่วนตัว",
                      subtitle: "วิธีการปกป้องและคุ้มครองข้อมูลของคุณ",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PrivacyScreen()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.code_rounded,
                      iconBgColor: const Color(0xFFF5F3FF),
                      iconColor: const Color(0xFF7C3AED),
                      title: "ใบอนุญาตโอเพ่นซอร์ส",
                      subtitle: "ประกาศการใช้งานซอฟต์แวร์ภายนอก",
                      onTap: () async {
                        final String version = await AppVersion.number();
                        if (!context.mounted) return;
                        showLicensePage(
                          context: context,
                          applicationName: "ThreeDuo Learning",
                          applicationVersion: version,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              //=========================
              // SUPPORT SECTION
              //=========================
              _buildSectionHeader("การเชื่อมต่อและความช่วยเหลือ"),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingTile(
                      context: context,
                      icon: Icons.help_center_outlined,
                      iconBgColor: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                      title: "ศูนย์ช่วยเหลือ",
                      subtitle: "คำถามที่พบบ่อยและวิธีแก้ไขปัญหา",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.mark_email_read_outlined,
                      iconBgColor: const Color(0xFFFEF2F2),
                      iconColor: const Color(0xFFEF4444),
                      title: "ติดต่อเรา",
                      subtitle: "threeduo.learning@gmail.com",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ContactScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              //=========================
              // FOOTER BRANDING
              //=========================
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "สร้างสรรค์ด้วยความใส่ใจโดย ThreeDuo Learning",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "© 2026 ThreeDuo Learning. สงวนลิขสิทธิ์ทั้งหมด",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
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

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 22,
        ),
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

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 64,
      endIndent: 16,
      color: Color(0xFFF1F5F9),
    );
  }
}