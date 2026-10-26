import 'package:flutter/material.dart';

/// "เรียนค้างไว้ที่คำที่ X" — asks whether to continue from the saved word.
/// Returns true = continue, false = start again from the first word.
/// (Closing the dialog another way also continues.)
Future<bool> askVocabularyResume(
  BuildContext context, {
  required int wordNumber,
  required int total,
  required String wordPreview,
}) async {
  const blue = Color(0xFF3886D8);
  final result = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFFBFDBFE), width: 2.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: blue, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'เรียนต่อจากเดิมไหม ?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'เรียนค้างไว้ที่คำที่ $wordNumber จาก $total\n($wordPreview)',
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: blue,
                      side: const BorderSide(color: Color(0xFF93C5FD), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text(
                      'เริ่มคำแรก',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text(
                      'เรียนต่อ',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
  );
  return result ?? true;
}

/// "ทำแบบทดสอบค้างไว้" — asks whether to go on with the quiz that was left
/// unfinished. Returns true = continue the quiz, false = learn the words
/// again (the unfinished quiz is dropped by the caller).
/// (Closing the dialog another way also continues.)
Future<bool> askQuizResume(BuildContext context) async {
  const blue = Color(0xFF3886D8);
  final result = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFFBFDBFE), width: 2.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.quiz_rounded, color: blue, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ทำแบบทดสอบต่อไหม ?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'หมวดนี้มีแบบทดสอบที่ทำค้างไว้ ทำต่อจากข้อที่ค้างได้เลย',
            style: TextStyle(
              fontSize: 15.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: blue,
                      side: const BorderSide(color: Color(0xFF93C5FD), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text(
                      'เรียนใหม่',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text(
                      'ทำต่อ',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
  );
  return result ?? true;
}
