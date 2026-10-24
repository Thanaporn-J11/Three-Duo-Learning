import 'package:flutter/material.dart';

class AvatarCustomizerScreen extends StatefulWidget {
  final Color initialSkinColor;
  final int initialHair;
  final int initialShirt;
  final int initialGlasses;
  final int initialHat;

  const AvatarCustomizerScreen({
    super.key,
    this.initialSkinColor = const Color(0xFFFFDFC4),
    this.initialHair = -1,
    this.initialShirt = -1,
    this.initialGlasses = -1,
    this.initialHat = -1,
  });

  @override
  State<AvatarCustomizerScreen> createState() => _AvatarCustomizerScreenState();
}

class _AvatarCustomizerScreenState extends State<AvatarCustomizerScreen> {
  // 0: Hair/Skin, 1: Shirt, 2: Glasses, 3: Hat
  int currentTab = 0;

  late Color selectedSkinColor;
  late int selectedHair;
  late int selectedShirt;
  late int selectedGlasses;
  late int selectedHat;

  // โทนสีผิวตามแถบ Skin tone
  final List<Color> skinTones = const [
    Color(0xFF231F20), // ผิวดำ
    Color(0xFFC67D48), // ผิวน้ำตาลเข้ม
    Color(0xFFE5A97D), // ผิวสองสี
    Color(0xFFF3CBB0), // ผิวขาวเหลือง
    Color(0xFFFFDFC4), // ผิวขาวอมชมพู
  ];

  @override
  void initState() {
    super.initState();
    selectedSkinColor = widget.initialSkinColor;
    selectedHair = widget.initialHair;
    selectedShirt = widget.initialShirt;
    selectedGlasses = widget.initialGlasses;
    selectedHat = widget.initialHat;
  }

  void _onDone() {
    Navigator.pop(context, {
      'skinColor': selectedSkinColor,
      'hair': selectedHair,
      'shirt': selectedShirt,
      'glasses': selectedGlasses,
      'hat': selectedHat,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F8FE),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Avatar',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _onDone,
            child: const Text(
              'DONE',
              style: TextStyle(
                color: Color(0xFF0088FF),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // โซนพรีวิวตัวละครสด (Preview Avatar Model)
          Container(
            width: double.infinity,
            height: 250,
            color: const Color(0xFFF1F8FE),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. เลเยอร์หน้าและลำตัวหลัก (Base Head)
                Image.asset(
                  'assets/images/avatar/base_head.png',
                  fit: BoxFit.contain,
                  height: 230,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.face_rounded,
                    size: 130,
                    color: Color(0xFFF3CBB0),
                  ),
                ),

                // 2. เลเยอร์ทรงผม (Hairstyle Layer)
                if (selectedHair != -1)
                  Image.asset(
                    'assets/images/avatar/hair_$selectedHair.png',
                    height: 230,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const SizedBox(),
                  ),

                // 3. เลเยอร์เสื้อผ้า (Shirt Layer)
                if (selectedShirt != -1)
                  Positioned(
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/avatar/shirt_$selectedShirt.png',
                      width: 175,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox(),
                    ),
                  ),

                // 4. เลเยอร์แว่นตา (Glasses Layer)
                if (selectedGlasses != -1)
                  Positioned(
                    top: 80,
                    child: Image.asset(
                      'assets/images/avatar/glasses_$selectedGlasses.png',
                      width: 110,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox(),
                    ),
                  ),

                // 5. เลเยอร์หมวก/ที่คาดผม (Hat Layer)
                if (selectedHat != -1)
                  Positioned(
                    top: 8,
                    child: Image.asset(
                      'assets/images/avatar/hat_$selectedHat.png',
                      width: 135,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox(),
                    ),
                  ),
              ],
            ),
          ),

          // แถบสลับหมวดหมู่ไอคอน (Hair, Shirt, Glasses, Hat)
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCategoryTab(0, Icons.face_rounded),
                _buildCategoryTab(1, Icons.checkroom_rounded),
                _buildCategoryTab(2, Icons.visibility_rounded),
                _buildCategoryTab(3, Icons.sports_baseball_rounded),
              ],
            ),
          ),

          // รายการไอเทมให้เลือกตามหมวดหมู่
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildCurrentTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  // วิดเจ็ตแท็บหมวดหมู่
  Widget _buildCategoryTab(int index, IconData icon) {
    final isSelected = currentTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          currentTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF0088FF) : Colors.transparent,
              width: 3.5,
            ),
          ),
        ),
        child: Icon(
          icon,
          size: 32,
          color: isSelected ? const Color(0xFF0088FF) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  // จัดการเนื้อหาตามแท็บ
  Widget _buildCurrentTabContent() {
    switch (currentTab) {
      case 0:
        return _buildHairAndSkinSection();
      case 1:
        return _buildCategoryGrid(
          title: 'shirt',
          prefix: 'shirt',
          count: 6,
          selectedIndex: selectedShirt,
          onSelect: (index) => setState(() => selectedShirt = index),
        );
      case 2:
        return _buildCategoryGrid(
          title: 'glasses',
          prefix: 'glasses',
          count: 6,
          selectedIndex: selectedGlasses,
          onSelect: (index) => setState(() => selectedGlasses = index),
        );
      case 3:
        return _buildCategoryGrid(
          title: 'hat',
          prefix: 'hat',
          count: 6,
          selectedIndex: selectedHat,
          onSelect: (index) => setState(() => selectedHat = index),
        );
      default:
        return const SizedBox();
    }
  }

  // ส่วนแท็บที่ 1: สีผิว + ทรงผม
  Widget _buildHairAndSkinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Skin tone',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: skinTones.map((color) {
            final isSelected = selectedSkinColor == color;
            return GestureDetector(
              onTap: () => setState(() => selectedSkinColor = color),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected ? Border.all(color: const Color(0xFF0088FF), width: 3.5) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Hairstyle',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildItemGrid(
          prefix: 'hair',
          count: 6,
          selectedIndex: selectedHair,
          onSelect: (index) => setState(() => selectedHair = index),
        ),
      ],
    );
  }

  // ส่วนแท็บตารางทั่วไป (Shirt, Glasses, Hat)
  Widget _buildCategoryGrid({
    required String title,
    required String prefix,
    required int count,
    required int selectedIndex,
    required Function(int) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildItemGrid(
          prefix: prefix,
          count: count,
          selectedIndex: selectedIndex,
          onSelect: onSelect,
        ),
      ],
    );
  }

  // Grid แสดงการ์ดไอเทมทั้ง 6 ช่อง
  Widget _buildItemGrid({
    required String prefix,
    required int count,
    required int selectedIndex,
    required Function(int) onSelect,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final isSelected = selectedIndex == index;
        return GestureDetector(
          onTap: () => onSelect(isSelected ? -1 : index), // แตะซ้ำเพื่อถอดออก
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF0088FF) : const Color(0xFF202939),
                width: isSelected ? 2.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/images/avatar/${prefix}_preview_$index.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.checkroom_rounded,
                size: 38,
                color: isSelected ? const Color(0xFF0088FF) : Colors.grey.shade400,
              ),
            ),
          ),
        );
      },
    );
  }
}