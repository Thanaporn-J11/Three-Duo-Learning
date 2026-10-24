import 'package:flutter/material.dart';
import 'level_selection_screen.dart';
import 'result_screen.dart';

class MatchScreen extends StatefulWidget {
  final GameDifficulty difficulty;
  final int rewardCoins;

  const MatchScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.rewardCoins = 25,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late Map<String, String> wordPairs;
  late List<String> leftList;
  late List<String> rightList;

  String? selectedLeft;
  String? selectedRight;
  final Set<String> matchedWords = {};
  bool isWrongPair = false;

  @override
  void initState() {
    super.initState();
    _loadDifficultyWords();
  }

  void _loadDifficultyWords() {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        wordPairs = {
          'Bird': 'นก',
          'Mouth': 'ปาก',
          'Purple': 'สีม่วง',
        };
        break;
      case GameDifficulty.medium:
        wordPairs = {
          'Apple': 'แอปเปิ้ล',
          'Water': 'น้ำ',
          'School': 'โรงเรียน',
          'Friend': 'เพื่อน',
        };
        break;
      case GameDifficulty.hard:
        wordPairs = {
          'Carpenter': 'ช่างไม้',
          'Grandparents': 'ปู่ย่าตายาย',
          'Programmer': 'โปรแกรมเมอร์',
          'Passion Fruit': 'เสาวรส',
          'Sibling': 'พี่น้อง',
          'Octopus': 'ปลาหมึกยักษ์',
        };
        break;
    }

    leftList = wordPairs.keys.toList()..shuffle();
    rightList = wordPairs.values.toList()..shuffle();
  }

  void _onLeftTap(String word) {
    if (matchedWords.contains(word)) return;
    setState(() {
      selectedLeft = word;
      isWrongPair = false;
      _checkMatch();
    });
  }

  void _onRightTap(String word) {
    if (matchedWords.contains(word)) return;
    setState(() {
      selectedRight = word;
      isWrongPair = false;
      _checkMatch();
    });
  }

  void _checkMatch() {
    if (selectedLeft != null && selectedRight != null) {
      if (wordPairs[selectedLeft] == selectedRight) {
        final leftWord = selectedLeft!;
        final rightWord = selectedRight!;

        setState(() {
          matchedWords.add(leftWord);
          matchedWords.add(rightWord);
        });

        _showCorrectBottomSheet();
      } else {
        setState(() {
          isWrongPair = true;
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              selectedLeft = null;
              selectedRight = null;
              isWrongPair = false;
            });
          }
        });
      }
    }
  }

  void _showCorrectBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
          decoration: const BoxDecoration(
            color: Color(0xFFB9EAC8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Correct!',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B4D3E),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      selectedLeft = null;
                      selectedRight = null;
                    });

                    if (matchedWords.length == leftList.length * 2) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResultScreen(
                            totalCoins: widget.rewardCoins,
                            scorePercentage: 100,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF00569E), size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Match Words',
          style: TextStyle(
            color: Color(0xFF00569E),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                "Let's pair them up.",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: leftList.map((word) {
                          return _buildWordButton(
                            text: word,
                            isSelected: selectedLeft == word,
                            isMatched: matchedWords.contains(word),
                            isWrong: selectedLeft == word && isWrongPair,
                            onTap: () => _onLeftTap(word),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: rightList.map((word) {
                          return _buildWordButton(
                            text: word,
                            isSelected: selectedRight == word,
                            isMatched: matchedWords.contains(word),
                            isWrong: selectedRight == word && isWrongPair,
                            onTap: () => _onRightTap(word),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 100,
              alignment: Alignment.bottomCenter,
              child: Image.asset(
                'assets/images/normal.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.sentiment_satisfied_alt_rounded,
                  size: 50,
                  color: Color(0xFF90CAFF),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildWordButton({
    required String text,
    required bool isSelected,
    required bool isMatched,
    required bool isWrong,
    required VoidCallback onTap,
  }) {
    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFF90CAFF);

    if (isMatched) {
      bgColor = const Color(0xFF90CAFF);
      borderColor = const Color(0xFF0088FF);
    } else if (isWrong) {
      bgColor = const Color(0xFFFFAB91);
      borderColor = const Color(0xFFFF7043);
    } else if (isSelected) {
      bgColor = const Color(0xFF90CAFF);
      borderColor = const Color(0xFF0077C8);
    }

    return GestureDetector(
      onTap: isMatched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: widget.difficulty == GameDifficulty.hard ? 48 : 58,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: widget.difficulty == GameDifficulty.hard ? 15 : 17,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}