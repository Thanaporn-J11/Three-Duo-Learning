import 'package:flutter/material.dart';
import 'story_detail_screen.dart';

class TaleItem {
  final String title;
  final String englishTitle;
  final String imageUrl;

  TaleItem({
    required this.title,
    required this.englishTitle,
    required this.imageUrl,
  });
}

class TaleScreen extends StatelessWidget {
  TaleScreen({Key? key}) : super(key: key);

  final List<TaleItem> tales = [
    TaleItem(
      title: 'หนูน้อยหมวกแดง',
      englishTitle: 'Little Red Riding Hood',
      imageUrl: 'assets/images/tale/Little Red Riding Hood.jpg',
    ),
    TaleItem(
      title: 'มดกับตั๊กแตน',
      englishTitle: 'The Ant and the Grasshopper',
      imageUrl: 'assets/images/tale/The Ant and the Grasshopper.png',
    ),
    TaleItem(
      title: 'เด็กเลี้ยงแกะ',
      englishTitle: 'The Boy Who Cried Wolf',
      imageUrl: 'assets/images/tale/The Boy Who Cried Wolf.png',
    ),
    TaleItem(
      title: 'หมาจิ้งจอกกับนกกระสา',
      englishTitle: 'The Fox and the Stork',
      imageUrl: 'assets/images/tale/The Fox and the Stork.png',
    ),
    TaleItem(
      title: 'ห่านกับไข่ทองคำ',
      englishTitle: 'The Goose That Laid the Golden Eggs',
      imageUrl: 'assets/images/tale/The Goose That Laid the Golden Eggs.png',
    ),
    TaleItem(
      title: 'สิงโตกับหมาจิ้งจอก',
      englishTitle: 'The Lion and the Fox',
      imageUrl: 'assets/images/tale/The Lion and the Fox.png',
    ),
    TaleItem(
      title: 'ราชสีห์กับหนู',
      englishTitle: 'The Lion and the Mouse',
      imageUrl: 'assets/images/tale/The Lion and the Mouse.png',
    ),
    TaleItem(
      title: 'ลูกหมูสามตัว',
      englishTitle: 'The Three Little Pigs',
      imageUrl: 'assets/images/tale/The Three Little Pigs.png',
    ),
    TaleItem(
      title: 'กระต่ายกับเต่า',
      englishTitle: 'The Tortoise and the Hare',
      imageUrl: 'assets/images/tale/The Tortoise and the Hare.jpg',
    ),
    TaleItem(
      title: 'ลูกเป็ดขี้เหร่',
      englishTitle: 'The Ugly Duckling',
      imageUrl: 'assets/images/tale/The Ugly Duckling.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const Color pageBgColor = Color(0xFFF3E8FF);
    const Color purplePrimary = Color(0xFF8B5CF6);
    const Color purpleDarkBevel = Color(0xFF6D28D9);

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: purplePrimary,
        elevation: 1.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'นิทาน',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. หัวข้อตรึงแน่นสนิท ไม่ขยับเด็ดขาด
          Container(
            width: double.infinity,
            color: pageBgColor,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: purplePrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'เลือกนิทานที่คุณชอบ',
                  style: TextStyle(
                    fontSize: 17.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          // 2. ลิสต์นิทานใช้ ClampingScrollPhysics ล็อคขอบบน ไม่มีการเด้งขยับลงเวลาลากเม้าส์
          Expanded(
            child: ListView.builder(
              physics: const ClampingScrollPhysics(), // ล็อกขอบบนสนิท ไม่ยืดเด้งลง
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              itemCount: tales.length,
              itemBuilder: (context, index) {
                final tale = tales[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 22.0),
                  decoration: BoxDecoration(
                    color: purpleDarkBevel,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.only(bottom: 5.5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: purplePrimary,
                        width: 3.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: Image.asset(
                            tale.imageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: const Color(0xFFF3E8FF),
                                child: const Icon(
                                  Icons.auto_stories_rounded,
                                  size: 54,
                                  color: Color(0xFFC084FC),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tale.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 19.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color.fromARGB(255, 90, 37, 183),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      tale.englishTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StoryDetailScreen(
                                        title: tale.englishTitle,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(59, 7, 100, 1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  padding: const EdgeInsets.only(bottom: 3.5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: purplePrimary,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 11,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'เริ่มอ่าน',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}