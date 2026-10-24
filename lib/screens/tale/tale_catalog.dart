import 'story_detail_screen.dart';

class TaleItem {
  final String title;
  final String englishTitle;
  final String imageUrl;

  const TaleItem({required this.title, required this.englishTitle, required this.imageUrl});

  String? get id => StoryDetailScreen.taleIdForTitle(englishTitle);
}

const List<TaleItem> taleItems = [
  TaleItem(title: 'หนูน้อยหมวกแดง', englishTitle: 'Little Red Riding Hood', imageUrl: 'assets/images/tale/Little Red Riding Hood.jpg'),
  TaleItem(title: 'มดกับตั๊กแตน', englishTitle: 'The Ant and the Grasshopper', imageUrl: 'assets/images/tale/The Ant and the Grasshopper.png'),
  TaleItem(title: 'เด็กเลี้ยงแกะ', englishTitle: 'The Boy Who Cried Wolf', imageUrl: 'assets/images/tale/The Boy Who Cried Wolf.png'),
  TaleItem(title: 'หมาจิ้งจอกกับนกกระสา', englishTitle: 'The Fox and the Stork', imageUrl: 'assets/images/tale/The Fox and the Stork.png'),
  TaleItem(title: 'ห่านกับไข่ทองคำ', englishTitle: 'The Goose That Laid the Golden Eggs', imageUrl: 'assets/images/tale/The Goose That Laid the Golden Eggs.png'),
  TaleItem(title: 'สิงโตกับหมาจิ้งจอก', englishTitle: 'The Lion and the Fox', imageUrl: 'assets/images/tale/The Lion and the Fox.png'),
  TaleItem(title: 'ราชสีห์กับหนู', englishTitle: 'The Lion and the Mouse', imageUrl: 'assets/images/tale/The Lion and the Mouse.png'),
  TaleItem(title: 'ลูกหมูสามตัว', englishTitle: 'The Three Little Pigs', imageUrl: 'assets/images/tale/The Three Little Pigs.png'),
  TaleItem(title: 'กระต่ายกับเต่า', englishTitle: 'The Tortoise and the Hare', imageUrl: 'assets/images/tale/The Tortoise and the Hare.png'),
  TaleItem(title: 'ลูกเป็ดขี้เหร่', englishTitle: 'The Ugly Duckling', imageUrl: 'assets/images/tale/The Ugly Duckling.jpg'),
];
