import 'package:flutter/material.dart';

import 'story_detail_screen.dart';
import 'tale_catalog.dart';

class TaleCard extends StatelessWidget {
  final TaleItem tale;
  final bool isFavorite;
  final bool isUpdatingFavorite;
  final VoidCallback onToggleFavorite;

  const TaleCard({
    super.key,
    required this.tale,
    required this.isFavorite,
    required this.isUpdatingFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF8B5CF6);
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(color: const Color(0xFF6D28D9), borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.only(bottom: 5.5),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: primary, width: 3)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(alignment: Alignment.topRight, children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              child: Image.asset(
                tale.imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 200, color: const Color(0xFFF3E8FF), child: const Center(child: Icon(Icons.auto_stories_rounded, size: 54, color: Color(0xFFC084FC)))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Material(
                color: Colors.white.withValues(alpha: .94),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: isFavorite ? 'นำออกจากรายการโปรด' : 'เพิ่มในรายการโปรด',
                  onPressed: isUpdatingFavorite ? null : onToggleFavorite,
                  icon: isUpdatingFavorite
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavorite ? Colors.red : primary),
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tale.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19.5, fontWeight: FontWeight.w900, color: Color.fromARGB(255, 90, 37, 183), letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text(tale.englishTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ])),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryDetailScreen(title: tale.englishTitle))),
                child: Container(
                  decoration: BoxDecoration(color: const Color.fromRGBO(59, 7, 100, 1), borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.only(bottom: 3.5),
                  child: Container(
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    alignment: Alignment.center,
                    child: const Text('เริ่มอ่าน', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
