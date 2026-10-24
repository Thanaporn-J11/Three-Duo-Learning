import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/karaoke_recordings.dart';
import '../../services/listening_results_service.dart';
import '../../widgets/parent_pin_prompt.dart';

// -------------------------------------------------------------
// 1. Data Models
// -------------------------------------------------------------
class LyricLine {
  final String text;
  final String translation;
  final Color dotColor;

  /// When this line starts in the song's audio file (ms). Only needed for
  /// songs with [SongItem.audioAsset]; drives the karaoke highlight.
  final int? startMs;

  const LyricLine({
    required this.text,
    required this.translation,
    required this.dotColor,
    this.startMs,
  });
}

class SongItem {
  final String id;
  final String letter;
  final String imageAsset;
  final List<Color> gradientColors;
  final Color shadowColor;
  final Color buttonColor;
  final Color buttonShadowColor;
  final Color badgeTextColor;
  final String titleEn;
  final String titleTh;
  final String difficulty;
  final String duration;
  final List<LyricLine> lyrics;

  /// Real song file under assets/ (e.g. 'audio/karaoke/twinkle.mp3').
  /// Null = no file yet: the lyrics are read out with text-to-speech.
  final String? audioAsset;

  /// Same song with the singing removed, played while the child records so
  /// the take holds only their voice over the music. Must line up in time
  /// with [audioAsset] (same startMs). Null = record over [audioAsset].
  final String? instrumentalAsset;

  bool get hasAudio => audioAsset != null;

  const SongItem({
    required this.id,
    required this.letter,
    required this.imageAsset,
    required this.gradientColors,
    required this.shadowColor,
    required this.buttonColor,
    required this.buttonShadowColor,
    required this.badgeTextColor,
    required this.titleEn,
    required this.titleTh,
    required this.difficulty,
    required this.duration,
    required this.lyrics,
    this.audioAsset,
    this.instrumentalAsset,
  });
}

/// All karaoke songs (used by the song list and the parent report).
List<SongItem> karaokeSongs() => _KaraokeRecordScreenState.allSongs();

/// Neutral share message (works for boys and girls).
String karaokeShareText(SongItem song) =>
    'มาฟังหนูร้องเพลง ${song.titleEn} (${song.titleTh}) กันนะ ! 🎶 '
    'จากแอป ThreeDuo Learning';

// -------------------------------------------------------------
// 2. หน้าเลือกเพลงคาราโอเกะ (Song Selection Screen)
// -------------------------------------------------------------
class KaraokeRecordScreen extends StatefulWidget {
  const KaraokeRecordScreen({super.key});

  @override
  State<KaraokeRecordScreen> createState() => _KaraokeRecordScreenState();
}

class _KaraokeRecordScreenState extends State<KaraokeRecordScreen> {
  // Songs that have a saved take ("อัดแล้ว" badge).
  Set<String> _recorded = {};

  @override
  void initState() {
    super.initState();
    KaraokeRecordings.cleanUpOldVersionFiles();
    _loadRecorded();
  }

  Future<void> _loadRecorded() async {
    final ids = allSongs().map((s) => s.id).toList();
    final recorded = await KaraokeRecordings.songsWithRecordings(ids);
    if (mounted) setState(() => _recorded = recorded);
    // Takes backed up on the server (e.g. after reinstalling the app).
    if (await KaraokeRecordings.syncWithServer(ids)) {
      final synced = await KaraokeRecordings.songsWithRecordings(ids);
      if (mounted) setState(() => _recorded = synced);
    }
  }

  static List<SongItem> allSongs() {
    return const [
      // 1. Twinkle Twinkle Little Star (ชมพูพีช)
      SongItem(
        id: 'twinkle',
        letter: 'T',
        imageAsset: 'assets/images/Background/Star.png',
        gradientColors: [Color(0xFFFF9EB5), Color(0xFFFF85A1)],
        shadowColor: Color(0xFFE85D7F),
        buttonColor: Color(0xFFE11D48),
        buttonShadowColor: Color(0xFF9F1239),
        badgeTextColor: Color(0xFF059669),
        titleEn: 'Twinkle, Twinkle, Little Star',
        titleTh: 'ดาวระยิบระยับ',
        difficulty: 'ง่าย',
        duration: '0:23',
        audioAsset: 'audio/karaoke/twinkle.mp3',
        instrumentalAsset: 'audio/karaoke/twinkle_instrumental.mp3',
        // startMs measured from twinkle.mp3 (22.7 s, 4 lines, no intro;
        // highlight ~0.1 s before singing)
        lyrics: [
          LyricLine(text: 'Twinkle, twinkle, little star,', translation: 'ดวงดาวส่องประกายระยิบระยับ', dotColor: Color(0xFFFF8DA1), startMs: 800),
          LyricLine(text: 'How I wonder what you are!', translation: 'ฉันสงสัยจังว่าเธอคืออะไร', dotColor: Color(0xFFFFCA28), startMs: 6300),
          LyricLine(text: 'Up above the world so high,', translation: 'ลอยเหนือโลกสูงลิบ', dotColor: Color(0xFF42A5F5), startMs: 11700),
          LyricLine(text: 'Like a diamond in the sky.', translation: 'ราวกับเพชรเม็ดงามบนฟากฟ้า', dotColor: Color(0xFF66BB6A), startMs: 17200),
        ],
      ),

      // 2. Row, Row, Row Your Boat (เหลืองอบอุ่น)
      SongItem(
        id: 'row_boat',
        letter: 'R',
        imageAsset: 'assets/images/Background/RowBoat.png',
        gradientColors: [Color(0xFFFFD15C), Color(0xFFFFBF29)],
        shadowColor: Color(0xFFE59E00),
        buttonColor: Color(0xFFD97706),
        buttonShadowColor: Color(0xFF92400E),
        badgeTextColor: Color(0xFF059669),
        titleEn: 'Row, Row, Row Your Boat',
        titleTh: 'พายเรือเบา ๆ',
        difficulty: 'ง่าย',
        duration: '0:12',
        audioAsset: 'audio/karaoke/row_boat.mp3',
        instrumentalAsset: 'audio/karaoke/row_boat_instrumental.mp3',
        // startMs measured from row_boat.mp3 (highlight ~0.1 s before singing)
        lyrics: [
          LyricLine(text: 'Row, row, row your boat,', translation: 'พายเรือของเธอไปข้างหน้า', dotColor: Color(0xFFFF8DA1), startMs: 300),
          LyricLine(text: 'Gently down the stream,', translation: 'ล่องลอยเบาๆ ไปตามลำธาร', dotColor: Color(0xFFFFCA28), startMs: 2200),
          LyricLine(text: 'Merrily, merrily, merrily, merrily,', translation: 'อย่างเบิกบานและสดใส', dotColor: Color(0xFF42A5F5), startMs: 5100),
          LyricLine(text: 'Life is but a dream.', translation: 'ชีวิตเปรียบดั่งความฝันอันงดงาม', dotColor: Color(0xFF66BB6A), startMs: 7700),
        ],
      ),

      // 3. The Wheels on the Bus (ฟ้าสดใส)
      SongItem(
        id: 'wheels_bus',
        letter: 'W',
        imageAsset: 'assets/images/Background/SchoolBus.png',
        gradientColors: [Color(0xFF5ED1FF), Color(0xFF38BDF8)],
        shadowColor: Color(0xFF0284C7),
        buttonColor: Color(0xFF0284C7),
        buttonShadowColor: Color(0xFF075985),
        badgeTextColor: Color(0xFFD97706),
        titleEn: 'The Wheels on the Bus',
        titleTh: 'ล้อรถบัสหมุนไป',
        difficulty: 'ปานกลาง',
        duration: '0:16',
        audioAsset: 'audio/karaoke/wheels_bus.mp3',
        instrumentalAsset: 'audio/karaoke/wheels_bus_instrumental.mp3',
        // startMs measured from wheels_bus.mp3 (highlight ~0.1 s before singing)
        lyrics: [
          LyricLine(text: 'The wheels on the bus go round and round,', translation: 'ล้อของรถบัสหมุนวนไปรอบ ๆ', dotColor: Color(0xFFFF8DA1), startMs: 700),
          LyricLine(text: 'Round and round, round and round,', translation: 'หมุนวนไปและหมุนวนไป', dotColor: Color(0xFFFFCA28), startMs: 4950),
          LyricLine(text: 'The wheels on the bus go round and round,', translation: 'ล้อของรถบัสหมุนวนไปรอบ ๆ', dotColor: Color(0xFF42A5F5), startMs: 8400),
          LyricLine(text: 'All through the town.', translation: 'แล่นผ่านไปทั่วทั้งเมือง', dotColor: Color(0xFF66BB6A), startMs: 12700),
        ],
      ),

      // 4. Head, Shoulders, Knees and Toes (เขียวมิ้นต์)
      SongItem(
        id: 'head_shoulders',
        letter: 'H',
        imageAsset: 'assets/images/Background/Dancing.png',
        gradientColors: [Color(0xFF6EE7B7), Color(0xFF4ADE80)],
        shadowColor: Color(0xFF16A34A),
        buttonColor: Color(0xFF16A34A),
        buttonShadowColor: Color(0xFF14532D),
        badgeTextColor: Color(0xFFD97706),
        titleEn: 'Head, Shoulders, Knees and Toes',
        titleTh: 'หัว ไหล่ เข่า เท้า',
        difficulty: 'ปานกลาง',
        duration: '0:25',
        audioAsset: 'audio/karaoke/head_shoulders.mp3',
        instrumentalAsset: 'audio/karaoke/head_shoulders_instrumental.mp3',
        // startMs measured from head_shoulders.mp3 (highlight ~0.1 s before singing)
        lyrics: [
          LyricLine(text: 'Head, shoulders, knees and toes, knees and toes,', translation: 'หัว ไหล่ เข่า และนิ้วเท้า เข่าและนิ้วเท้า', dotColor: Color(0xFFFF8DA1), startMs: 700),
          LyricLine(text: 'Head, shoulders, knees and toes, knees and toes,', translation: 'หัว ไหล่ เข่า และนิ้วเท้า เข่าและนิ้วเท้า', dotColor: Color(0xFFFFCA28), startMs: 6700),
          LyricLine(text: 'And eyes, and ears, and mouth, and nose,', translation: 'ดวงตา หู ปาก และจมูก', dotColor: Color(0xFF42A5F5), startMs: 11200),
          LyricLine(text: 'Head, shoulders, knees and toes, knees and toes!', translation: 'หัว ไหล่ เข่า และนิ้วเท้า เข่าและนิ้วเท้า', dotColor: Color(0xFF66BB6A), startMs: 13500),
        ],
      ),

      // 5. Old MacDonald Had a Farm (ส้มสดใส)
      SongItem(
        id: 'old_macdonald',
        letter: 'O',
        imageAsset: 'assets/images/Background/Farm.png',
        gradientColors: [Color(0xFFFFA654), Color(0xFFFB923C)],
        shadowColor: Color(0xFFEA580C),
        buttonColor: Color(0xFFEA580C),
        buttonShadowColor: Color(0xFF9A3412),
        badgeTextColor: Color(0xFFE11D48),
        titleEn: 'Old MacDonald Had a Farm',
        titleTh: 'ลุงแมคโดนัลด์มีฟาร์ม',
        difficulty: 'ยาก',
        duration: '0:21',
        audioAsset: 'audio/karaoke/old_macdonald.mp3',
        instrumentalAsset: 'audio/karaoke/old_macdonald_instrumental.mp3',
        // startMs measured from old_macdonald.mp3 (highlight ~0.1 s before singing)
        lyrics: [
          LyricLine(text: 'Old MacDonald had a farm,', translation: 'คุณลุงแมคโดนัลด์มีฟาร์มแห่งหนึ่ง', dotColor: Color(0xFFFF8DA1), startMs: 1000),
          LyricLine(text: 'E-I-E-I-O,', translation: 'อี-ไอ-อี-ไอ-โอ', dotColor: Color(0xFFFFCA28), startMs: 3900),
          LyricLine(text: 'And on his farm he had a cow,', translation: 'และในฟาร์มของเขามีแม่วัวตัวหนึ่ง', dotColor: Color(0xFF42A5F5), startMs: 6000),
          LyricLine(text: 'E-I-E-I-O,', translation: 'อี-ไอ-อี-ไอ-โอ', dotColor: Color(0xFF66BB6A), startMs: 8700),
          LyricLine(text: 'With a moo-moo here and a moo-moo there,', translation: 'ส่งเสียง มอมอ ตรงนี้และ มอมอ ตรงนั้น', dotColor: Color(0xFFFF8DA1), startMs: 10800),
          LyricLine(text: 'Here a moo, there a moo, everywhere a moo-moo,', translation: 'มอตรงนี้ มอตรงนั้น มอมอไปทั่วเลย', dotColor: Color(0xFFFFCA28), startMs: 13500),
          LyricLine(text: 'Old MacDonald had a farm,', translation: 'คุณลุงแมคโดนัลด์มีฟาร์มแห่งหนึ่ง', dotColor: Color(0xFF42A5F5), startMs: 16400),
          LyricLine(text: 'E-I-E-I-O!', translation: 'อี-ไอ-อี-ไอ-โอ', dotColor: Color(0xFF66BB6A), startMs: 18300),
        ],
      ),

      // 6. Baa, Baa, Black Sheep (ม่วงลาเวนเดอร์)
      SongItem(
        id: 'baa_black_sheep',
        letter: 'B',
        imageAsset: 'assets/images/Background/sheep.png',
        gradientColors: [Color(0xFFBFA6FF), Color(0xFFA78BFA)],
        shadowColor: Color(0xFF7C3AED),
        buttonColor: Color(0xFF7C3AED),
        buttonShadowColor: Color(0xFF5B21B6),
        badgeTextColor: Color(0xFF059669),
        titleEn: 'Baa, Baa, Black Sheep',
        titleTh: 'แกะดำขนฟู',
        difficulty: 'ง่าย',
        duration: '0:15',
        audioAsset: 'audio/karaoke/baa_black_sheep.mp3',
        instrumentalAsset: 'audio/karaoke/baa_black_sheep_instrumental.mp3',
        // startMs measured from baa_black_sheep.mp3 (highlight ~0.1 s before singing)
        lyrics: [
          LyricLine(text: 'Baa, baa, black sheep,', translation: 'แบะ แบะ เจ้าแกะดำตัวน้อย', dotColor: Color(0xFFFF8DA1), startMs: 600),
          LyricLine(text: 'Have you any wool?', translation: 'เธอมีขนแกะนุ่ม ๆ บ้างไหม', dotColor: Color(0xFFFFCA28), startMs: 3000),
          LyricLine(text: 'Yes, sir, yes, sir, three bags full,', translation: 'มีครับ มีครับ เต็มสามถุงเลย', dotColor: Color(0xFF42A5F5), startMs: 5300),
          LyricLine(text: 'One for the master, one for the dame.', translation: 'หนึ่งถุงให้เจ้านาย หนึ่งถุงให้คุณนาย', dotColor: Color(0xFF66BB6A), startMs: 10100),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final songs = allSongs();
    const purpleHeader = Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2FF),
      body: Column(
        children: [
          // 1. Header สีม่วงสดใส
          Container(
            color: purpleHeader,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'คาราโอเกะเพลง',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // 2. ส่วนหัวคำอธิบาย
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'พร้อมร้องเพลงกันหรือยัง ?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2E1065),
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'แตะเพลงที่อยากร้องได้เลย',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. รายการการ์ดเพลงสไตล์ 3D
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final song = songs[index];
                return _buildSampleSongCard(context, song);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleSongCard(BuildContext context, SongItem song) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KaraokeDetailScreen(song: song),
          ),
        );
        _loadRecorded(); // refresh the "อัดแล้ว" badges
      },
      child: Container(
        decoration: BoxDecoration(
          color: song.shadowColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: song.shadowColor.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 5.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: song.gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.8,
            ),
          ),
          child: Row(
            children: [
              // 1. รูปภาพไอคอน
              SizedBox(
                width: 52,
                height: 52,
                child: Image.asset(
                  song.imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      song.letter,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 2. ข้อมูลเพลงตรงกลาง
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.titleEn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.titleTh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // ป้ายระดับความยาก (กว้างเท่ากันทุกเพลง ป้ายถัดไปจะได้ตรงกัน)
                        Container(
                          width: 62,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            song.difficulty,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: song.badgeTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // เวลาความยาว (กว้างคงที่)
                        SizedBox(
                          width: 32,
                          child: Text(
                          song.duration,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                        ),
                        if (_recorded.contains(song.id)) ...[
                          const SizedBox(width: 8),
                          // Same pill style as the difficulty badge
                          Container(
                            padding: const EdgeInsets.fromLTRB(6, 2, 9, 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  size: 12,
                                  color: song.buttonColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'อัดแล้ว',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: song.buttonColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 3. ปุ่ม "ร้อง" 3D (ปรับสีเข้มชัดเจนตามหมวดเพลง)[cite: 19]
              Container(
                decoration: BoxDecoration(
                  color: song.buttonShadowColor, // ฐานขอบล่าง 3D สีเข้ม
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 3.5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(bottom: 3.5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: song.buttonColor, // สีปุ่มเข้มสดใส
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65), // ขอบแสงไฮไลต์สีขาว
                      width: 1.4,
                    ),
                  ),
                  child: const Text(
                    'ร้อง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. หน้าร้องเพลงและบันทึกเสียง (Detail Screen)
// -------------------------------------------------------------
class KaraokeDetailScreen extends StatefulWidget {
  final SongItem song;

  const KaraokeDetailScreen({super.key, required this.song});

  @override
  State<KaraokeDetailScreen> createState() => _KaraokeDetailScreenState();
}

class _KaraokeDetailScreenState extends State<KaraokeDetailScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isDemoPlaying = false;
  bool _hasDemoFinished = false;
  bool _isRecording = false;
  bool _isPaused = false; // recording, but on hold ("พัก")
  bool _hasSavedTake = false; // a previous take exists for this song
  bool _isPlayingRecord = false;
  String? _recordedFilePath;

  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  // Loudest mic level heard during the current take (dBFS, -160 = silence).
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<RecordState>? _recStateSub;
  double _maxAmplitude = -160;
  int currentLyricIndex = -1;

  // How long each lyric line took in the demo, so the highlight can follow
  // along at the same pace while the child records.
  final Map<int, Duration> _lineDurations = {};
  Timer? _lyricGuideTimer;

  // Real song playback (songs with an audio file): demo and backing track.
  final AudioPlayer _songPlayer = AudioPlayer();
  final List<GlobalKey> _lineKeys = [];

  // Debug-only helper to measure startMs: tap when each line starts.
  bool _syncMode = false;
  final List<int> _syncTimes = [];
  int _songPositionMs = 0;

  static const Color purplePrimary = Color(0xFF8B5CF6);

  /// Recording stops by itself after this long (in case a child forgets).
  static const int maxRecordingSeconds = 120;

  @override
  void initState() {
    super.initState();
    _initTts();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingRecord = false);
    });
    // Keep the button in sync with what the player really does.
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint('[karaoke] take player state: $state');
      if (!mounted) return;
      if (state == PlayerState.playing && !_isPlayingRecord) {
        setState(() => _isPlayingRecord = true);
      } else if (state == PlayerState.completed && _isPlayingRecord) {
        setState(() => _isPlayingRecord = false);
      }
    });
    _loadLatestRecording();
    _lineKeys.addAll(
      List.generate(widget.song.lyrics.length, (_) => GlobalKey()),
    );
    // The recorder pauses itself whenever another player takes the audio
    // focus. The backing song must therefore play WITHOUT asking for focus,
    // otherwise the take is silent from the moment the song starts.
    // Listen ONCE for the whole screen: the recorder hands out a
    // single-listener stream, so listening again for a second take throws
    // "Stream has already been listened to" (that broke "อัดใหม่").
    _ampSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 300))
        .listen((a) {
      if (a.current > _maxAmplitude) _maxAmplitude = a.current;
    });
    _recStateSub = _audioRecorder.onStateChanged().listen((state) {
      debugPrint('[karaoke] recorder state: $state');
      if (state == RecordState.pause && _isRecording && !_isPaused) {
        // Paused by the system, not by the child: carry on recording.
        _audioRecorder.resume().catchError((e) {
          debugPrint('[karaoke] auto-resume failed: $e');
        });
      }
    });
    if (widget.song.hasAudio) {
      _songPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {AVAudioSessionOptions.defaultToSpeaker},
          ),
        ),
      );
      _songPlayer.onPositionChanged.listen(_onSongPosition);
      _songPlayer.onPlayerComplete.listen((_) => _onSongComplete());
    }
  }

  /// Index of the line being sung at [ms] (-1 during the intro).
  int _lineAt(int ms) {
    var index = -1;
    final lines = widget.song.lyrics;
    for (var i = 0; i < lines.length; i++) {
      final start = lines[i].startMs;
      if (start != null && ms >= start) index = i;
    }
    return index;
  }

  void _onSongPosition(Duration position) {
    _songPositionMs = position.inMilliseconds;
    if (!mounted || _syncMode) return;
    if (!_isDemoPlaying && !_isRecording) return;
    final index = _lineAt(_songPositionMs);
    if (index != currentLyricIndex) {
      setState(() => currentLyricIndex = index);
      _scrollToCurrentLine();
    }
  }

  void _onSongComplete() {
    if (!mounted) return;
    if (_syncMode) {
      _finishSync();
      return;
    }
    if (_isDemoPlaying) {
      setState(() {
        _isDemoPlaying = false;
        _hasDemoFinished = true;
        currentLyricIndex = -1;
      });
    } else if (_isRecording) {
      // Song is over; the child can still finish and press "เสร็จแล้ว".
      setState(() => currentLyricIndex = -1);
    }
  }

  /// Keeps the highlighted line on screen (songs can have 6+ lines).
  void _scrollToCurrentLine() {
    final i = currentLyricIndex;
    if (i < 0 || i >= _lineKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineKeys[i].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  /// Stops the song only if it is actually playing/paused. Stopping a player
  /// that never loaded a file throws on Android, which used to abort whatever
  /// called it (e.g. the "ฟังเสียงที่อัด" button did nothing).
  Future<void> _stopSong() async {
    final state = _songPlayer.state;
    if (state != PlayerState.playing && state != PlayerState.paused) return;
    try {
      await _songPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping song: $e');
    }
  }

  /// [instrumental]: play the version without singing (used while recording).
  Future<void> _playSongFrom(int ms, {bool instrumental = false}) async {
    await _stopSong();
    final asset = instrumental
        ? (widget.song.instrumentalAsset ?? widget.song.audioAsset!)
        : widget.song.audioAsset!;
    await _songPlayer.play(
      AssetSource(asset),
      position: Duration(milliseconds: ms),
    );
  }

  // ---------- debug: measure startMs by tapping ----------
  Future<void> _startSync() async {
    await _audioPlayer.stop();
    setState(() {
      _syncMode = true;
      _syncTimes.clear();
      currentLyricIndex = -1;
    });
    _showSnack(
      'โหมดจับเวลา: แตะเนื้อเพลงทุกครั้งที่บรรทัดใหม่เริ่มร้อง',
      color: purplePrimary,
    );
    await _playSongFrom(0);
  }

  void _recordSyncTap() {
    if (_syncTimes.length >= widget.song.lyrics.length) return;
    setState(() {
      _syncTimes.add(_songPositionMs);
      currentLyricIndex = _syncTimes.length - 1;
    });
    _scrollToCurrentLine();
    if (_syncTimes.length == widget.song.lyrics.length) _finishSync();
  }

  Future<void> _finishSync() async {
    if (!_syncMode) return;
    await _stopSong();
    final lines = <String>[];
    for (var i = 0; i < _syncTimes.length; i++) {
      // Show the highlight a little before the singing starts.
      final ms = (_syncTimes[i] - 150).clamp(0, 1 << 30);
      lines.add("startMs: $ms, // ${widget.song.lyrics[i].text}");
    }
    final text = lines.join('\n');
    debugPrint('Karaoke timings for ${widget.song.id}:\n$text');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() {
      _syncMode = false;
      currentLyricIndex = -1;
    });
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('จับเวลาเสร็จแล้ว (คัดลอกให้แล้ว)'),
        content: SelectableText(
          text.isEmpty ? 'ยังไม่ได้แตะเลย' : text,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  /// Shows the child's last take of this song, so they can listen or share
  /// it again (or record a new one).
  Future<void> _loadLatestRecording() async {
    // Not on this phone: maybe backed up on the server.
    final latest =
        await KaraokeRecordings.latest(widget.song.id) ??
        await KaraokeRecordings.syncWithServer([widget.song.id]).then(
          (_) => KaraokeRecordings.latest(widget.song.id),
        );
    if (!mounted) return;
    setState(() => _hasSavedTake = latest != null);
    if (latest == null || _isRecording) return;
    setState(() {
      _recordedFilePath = latest.path;
      _recordingSeconds = latest.seconds;
      _hasDemoFinished = true; // they've sung this before
    });
  }

  void _showSnack(String message, {Color color = const Color(0xFFDC2626)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _showMicPermissionHelp() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFDDD6FE), width: 2.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.mic_off_rounded, color: purplePrimary, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยังใช้ไมโครโฟนไม่ได้',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'แอปยังไม่ได้รับอนุญาตให้ใช้ไมโครโฟน ให้ผู้ปกครองช่วยเปิดสิทธิ์ที่\n\n'
          'การตั้งค่าโทรศัพท์ > แอป > ThreeDuo Learning > สิทธิ์ > ไมโครโฟน > อนุญาต\n\n'
          'แล้วกลับมากดอัดเสียงอีกครั้งนะ',
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: purplePrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'เข้าใจแล้ว',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.33);
    await _flutterTts.setPitch(1.22);
  }

  Future<void> _togglePlayDemo() async {
    if (_syncMode) return;
    if (_isDemoPlaying) {
      await _flutterTts.stop();
      await _stopSong();
      setState(() {
        _isDemoPlaying = false;
        currentLyricIndex = -1;
      });
    } else {
      if (_isPlayingRecord) {
        await _audioPlayer.stop();
        setState(() => _isPlayingRecord = false);
      }

      if (widget.song.hasAudio) {
        // Real song: the highlight follows the music (see _onSongPosition).
        setState(() {
          _isDemoPlaying = true;
          currentLyricIndex = -1;
        });
        try {
          await _playSongFrom(0);
        } catch (e) {
          debugPrint('Error playing song: $e');
          if (mounted) setState(() => _isDemoPlaying = false);
          _showSnack('เปิดเพลงไม่สำเร็จ ลองใหม่อีกครั้งนะ');
        }
        return;
      }

      setState(() {
        _isDemoPlaying = true;
        currentLyricIndex = 0;
      });

      for (int i = 0; i < widget.song.lyrics.length; i++) {
        if (!_isDemoPlaying || !mounted) break;

        setState(() {
          currentLyricIndex = i;
        });

        final Completer<void> lineCompleter = Completer<void>();
        _flutterTts.setCompletionHandler(() {
          if (!lineCompleter.isCompleted) {
            lineCompleter.complete();
          }
        });

        final lineTimer = Stopwatch()..start();
        await _flutterTts.speak(widget.song.lyrics[i].text);
        await lineCompleter.future;

        await Future.delayed(const Duration(milliseconds: 300));
        _lineDurations[i] = lineTimer.elapsed;
      }

      if (mounted) {
        setState(() {
          _isDemoPlaying = false;
          _hasDemoFinished = true;
          currentLyricIndex = -1;
        });
      }
    }
  }

  /// Time to show [index] while recording: the demo's pace, a bit slower
  /// for singing; or an estimate from the number of words if the demo
  /// wasn't played this time (e.g. re-recording a song sung before).
  Duration _guideDurationFor(int index) {
    final measured = _lineDurations[index];
    if (measured != null) {
      return Duration(milliseconds: (measured.inMilliseconds * 1.25).round());
    }
    final words = widget.song.lyrics[index].text.trim().split(RegExp(r'\s+')).length;
    return Duration(milliseconds: 1200 + words * 700);
  }

  /// Highlights lyric [index] and moves on by itself; after the last line
  /// the highlight goes away.
  void _guideLyric(int index) {
    _lyricGuideTimer?.cancel();
    if (!mounted || !_isRecording || _isPaused) return;
    if (index >= widget.song.lyrics.length) {
      setState(() => currentLyricIndex = -1);
      return;
    }
    setState(() => currentLyricIndex = index);
    _lyricGuideTimer = Timer(_guideDurationFor(index), () => _guideLyric(index + 1));
  }

  /// Tap a lyric while recording: jump there (song) or move the guide.
  void _jumpToLine(int index) {
    if (widget.song.hasAudio) {
      final start = widget.song.lyrics[index].startMs ?? 0;
      _songPlayer.seek(Duration(milliseconds: start));
      setState(() => currentLyricIndex = index);
    } else {
      _guideLyric(index);
    }
  }

  void _stopLyricGuide() {
    _lyricGuideTimer?.cancel();
    _lyricGuideTimer = null;
    if (widget.song.hasAudio && !_isDemoPlaying) _stopSong();
    if (mounted && currentLyricIndex != -1 && !_isDemoPlaying) {
      setState(() => currentLyricIndex = -1);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        // Previously this did nothing at all; explain what to do instead.
        await _showMicPermissionHelp();
        _loadLatestRecording(); // keep showing the last take, if any
        return;
      }

      final path = await KaraokeRecordings.newRecordingPath(widget.song.id);

      if (_isDemoPlaying) {
        await _flutterTts.stop();
        setState(() {
          _isDemoPlaying = false;
          currentLyricIndex = -1;
        });
      }

      // Stop anything still holding the audio (a previous take that never
      // closed, or the take being listened to) before opening the mic.
      try {
        await _audioPlayer.stop();
        if (await _audioRecorder.isRecording() ||
            await _audioRecorder.isPaused()) {
          await _audioRecorder.cancel();
        }
      } catch (e) {
        debugPrint('[karaoke] pre-record cleanup: $e');
      }
      if (mounted) setState(() => _isPlayingRecord = false);

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      _recordingSeconds = 0;
      _startRecordingTimer();
      _maxAmplitude = -160;

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordedFilePath = null;
      });
      if (widget.song.hasAudio) {
        // Backing track while singing; the highlight follows it.
        currentLyricIndex = -1;
        _playSongFrom(0, instrumental: true);
      } else {
        _guideLyric(0); // karaoke-style highlight while singing
      }
    } catch (e, st) {
      debugPrint('Error starting record: $e\n$st');
      _recordingTimer?.cancel();
      // Don't leave the mic open after a half-started take.
      try {
        await _audioRecorder.cancel();
      } catch (_) {}
      _stopLyricGuide();
      if (mounted) setState(() => _isRecording = false);
      _showSnack(kDebugMode
          ? 'เริ่มอัดเสียงไม่สำเร็จ (debug: $e)'
          : 'เริ่มอัดเสียงไม่สำเร็จ ลองใหม่อีกครั้งนะ');
      _loadLatestRecording();
    }
  }

  /// Counts recording time (only while actually recording, not paused).
  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isPaused) return;
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= maxRecordingSeconds) {
        _stopRecording();
        _showSnack(
          'ครบ ${maxRecordingSeconds ~/ 60} นาทีแล้ว หยุดอัดให้อัตโนมัตินะ',
          color: purplePrimary,
        );
      }
    });
  }

  /// "พัก": hold the recording; "อัดต่อ": carry on in the same file.
  Future<void> _togglePauseRecording() async {
    if (!_isRecording) return;
    try {
      if (_isPaused) {
        await _audioRecorder.resume();
        if (!mounted) return;
        setState(() => _isPaused = false);
        _startRecordingTimer();
        if (widget.song.hasAudio) {
          await _songPlayer.resume();
        } else {
          _guideLyric(currentLyricIndex < 0 ? 0 : currentLyricIndex);
        }
      } else {
        // Set first, so the recorder listener knows this pause is on purpose.
        _isPaused = true;
        await _audioRecorder.pause();
        _recordingTimer?.cancel();
        _lyricGuideTimer?.cancel(); // keep the current line highlighted
        if (widget.song.hasAudio) await _songPlayer.pause();
        if (mounted) setState(() => _isPaused = true);
      }
    } catch (e) {
      debugPrint('Error pausing/resuming record: $e');
      _showSnack('พัก/อัดต่อไม่สำเร็จ ลองกด เสร็จแล้ว เพื่อบันทึกนะ');
    }
  }

  Future<void> _deleteRecording() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFFECDD3), width: 2.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_rounded, color: Color(0xFFE11D48), size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ลบเสียงที่อัดไว้ ?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'ลบแล้วจะเอากลับมาไม่ได้นะ',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'ลบเลย',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _audioPlayer.stop();
    await KaraokeRecordings.deleteLatest(widget.song.id);
    if (!mounted) return;
    setState(() {
      _recordedFilePath = null;
      _isPlayingRecord = false;
      _recordingSeconds = 0;
      _hasSavedTake = false;
    });
    _showSnack('ลบเสียงเรียบร้อยแล้ว', color: purplePrimary);
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _stopLyricGuide();
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      debugPrint('[karaoke] take saved: $path, loudest mic level '
          '${_maxAmplitude.toStringAsFixed(1)} dBFS');
      if (path != null) {
        // Keep only this take; the previous one of this song is deleted.
        await KaraokeRecordings.saveLatest(
          widget.song.id,
          path,
          _recordingSeconds,
        );
        // Count the take in the parent report (the audio stays on the phone).
        ListeningResults.submit(
          game: 'karaoke',
          topic: widget.song.id,
          durationSeconds: _recordingSeconds,
        );
      }
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordedFilePath = path;
        if (path != null) _hasSavedTake = true;
      });
      if (path == null) {
        _showSnack('บันทึกเสียงไม่สำเร็จ ลองอัดใหม่อีกครั้งนะ');
      } else if (_maxAmplitude < -50) {
        // The file plays, but the mic heard nothing (blocked/muted mic, or an
        // emulator whose virtual microphone is off).
        _showSnack('ไมโครโฟนไม่ได้ยินเสียงเลย เสียงที่อัดอาจเงียบ ลองตรวจไมโครโฟนแล้วอัดใหม่นะ');
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
        });
      }
      _showSnack('บันทึกเสียงไม่สำเร็จ ลองอัดใหม่อีกครั้งนะ');
      _loadLatestRecording();
    }
  }

  Future<void> _togglePlayRecordedAudio() async {
    final path = _recordedFilePath;
    debugPrint('[karaoke] play tapped: playing=$_isPlayingRecord path=$path');
    if (path == null) return;

    // Tapped while playing -> stop.
    if (_isPlayingRecord) {
      setState(() => _isPlayingRecord = false);
      try {
        await _audioPlayer.stop();
      } catch (e) {
        debugPrint('Error stopping recording playback: $e');
      }
      return;
    }

    final file = File(path);
    final size = file.existsSync() ? file.lengthSync() : -1;
    debugPrint('[karaoke] take file size: $size bytes');
    if (size < 0) {
      setState(() => _recordedFilePath = null);
      _showSnack('ไม่พบไฟล์เสียงที่อัดไว้ ลองอัดใหม่อีกครั้งนะ');
      return;
    }
    if (size < 1024) {
      _showSnack('ไฟล์เสียงที่อัดว่างเปล่า ลองอัดใหม่อีกครั้งนะ');
      return;
    }

    // Show "หยุดฟัง" right away so the tap always visibly does something.
    setState(() {
      _isPlayingRecord = true;
      _isDemoPlaying = false;
      currentLyricIndex = -1;
    });
    await _stopSong();
    try {
      await _flutterTts.stop();
    } catch (_) {}

    try {
      await _audioPlayer.stop();
      await _audioPlayer
          .play(DeviceFileSource(path))
          .timeout(const Duration(seconds: 6));
      debugPrint('[karaoke] take duration: ${await _audioPlayer.getDuration()}');
    } catch (e) {
      debugPrint('Error playing recording: $e');
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      if (mounted) setState(() => _isPlayingRecord = false);
      _showSnack('เปิดเสียงที่อัดไม่สำเร็จ ลองอัดใหม่อีกครั้งนะ');
    }
  }

  /// The parent sends it: ask for the parent PIN first, so a child can't
  /// send their voice to anyone by themselves. (No PIN set yet -> allowed.)
  Future<void> _shareRecordedFile() async {
    final path = _recordedFilePath;
    if (path == null || !File(path).existsSync()) return;
    final allowed = await showParentPinPrompt(
      context,
      title: 'ผู้ปกครองยืนยันก่อนส่ง',
    );
    if (!allowed || !mounted) return;
    await Share.shareXFiles([XFile(path)], text: karaokeShareText(widget.song));
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(1, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _lyricGuideTimer?.cancel();
    _flutterTts.stop();
    final recorder = _audioRecorder;
    if (_isRecording) {
      // Left in the middle of a take: throw the unfinished file away.
      recorder
          .stop()
          .then((path) {
            if (path != null) KaraokeRecordings.deleteFile(path);
          })
          .catchError((_) {})
          .whenComplete(recorder.dispose);
    } else {
      recorder.dispose();
    }
    _ampSub?.cancel();
    _recStateSub?.cancel();
    _audioPlayer.dispose();
    _songPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2FF),
      body: Column(
        children: [
          // 1. Header สีม่วง
          Container(
            color: purplePrimary,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'คาราโอเกะเพลง',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // 2. ส่วนหัวชื่อเพลง
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.titleEn.replaceAll('...', ''),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.song.titleTh,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. กรอบเนื้อเพลงคาราโอเกะสีขาว ตัวอักษรใหญ่
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFEDE9FE), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: Color(0xFFFFCA28), shape: BoxShape.circle),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: Color(0xFFFFCA28), shape: BoxShape.circle),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: Color(0xFFFFCA28), shape: BoxShape.circle),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      right: 14,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: Color(0xFFFFCA28), shape: BoxShape.circle),
                      ),
                    ),

                    Center(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: widget.song.lyrics.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemBuilder: (context, index) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // While recording, tap a line to move the highlight there.
                          onTap: _syncMode
                              ? _recordSyncTap
                              : (_isRecording ? () => _jumpToLine(index) : null),
                          child: KeyedSubtree(
                            key: _lineKeys[index],
                            child: Builder(builder: (context) {
                          final line = widget.song.lyrics[index];
                          final bool isCurrent = (index == currentLyricIndex);

                          if (isCurrent) {
                            return TweenAnimationBuilder<double>(
                              key: ValueKey('current-$index'),
                              tween: Tween(begin: 0.94, end: 1.0),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutBack,
                              builder: (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                // Light sky blue, same family as the "ฟังเสียงที่อัด" button.
                                color: const Color(0xFFEAF6FF),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFF9ED8FB), width: 2.0),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    line.text,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.fredoka(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E40AF), // deep blue on the sky-blue box
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    line.translation,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.mitr(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w300,
                                      color: const Color(0xFF4A6491),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            );
                          }

                          // Same box/padding as the highlighted line, so every
                          // line sits on the same centre (no dots in front).
                          // All lines in one deep pink; while a line is
                          // being sung the others fade back a little.
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: currentLyricIndex >= 0 ? 0.5 : 1.0,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Text(
                                line.text,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.fredoka(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFDB2777), // one deep pink for all lines
                                  height: 1.3,
                                ),
                              ),
                            ),
                          );
                          }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 4. แผงควบคุมด้านล่าง (สลับตามสถานะ)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _recordedFilePath != null && !_isRecording
                ? _buildCompletedBottomPanel()
                : _buildStepControlBottomPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepControlBottomPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE9FE), width: 2),
      ),
      child: Column(
        children: [
          // ขั้นที่ 1: ฟังเสียงตัวอย่างก่อน
          GestureDetector(
            onTap: _togglePlayDemo,
            // Debug builds only: long-press to measure lyric timings.
            onLongPress:
                kDebugMode && widget.song.hasAudio && !_isRecording ? _startSync : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isDemoPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ขั้นที่ 1',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                        ),
                        Text(
                          _isDemoPlaying ? 'กำลังเปิดเสียงตัวอย่าง' : 'ฟังเสียงตัวอย่างก่อน',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _isDemoPlaying && currentLyricIndex >= 0
                        ? 'บรรทัด ${currentLyricIndex + 1} / ${widget.song.lyrics.length}'
                        : _hasDemoFinished
                        ? 'ฟังจบแล้ว'
                        : '${widget.song.lyrics.length} บรรทัด',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ขั้นที่ 2: อัดเสียงร้องของหนู
          GestureDetector(
            onTap: () {
              if (!_hasDemoFinished && !_isDemoPlaying) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('กดฟังเสียงตัวอย่างในขั้นที่ 1 ให้จบก่อนนะจ๊ะ! 🎵'),
                    backgroundColor: const Color(0xFF7C3AED),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                );
                return;
              }
              _isRecording ? _togglePauseRecording() : _startRecording();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isRecording
                    ? (_isPaused ? const Color(0xFFFFF7ED) : const Color(0xFFFEF2F2))
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isRecording
                      ? (_isPaused ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
                      : (_hasDemoFinished ? const Color(0xFFDDD6FE) : const Color(0xFFE2E8F0)),
                  width: 1.5,
                  style: _hasDemoFinished ? BorderStyle.solid : BorderStyle.none,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? (_isPaused ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
                          : (_hasDemoFinished ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording && !_isPaused ? Icons.pause_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ขั้นที่ 2',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isRecording ? Colors.red : const Color(0xFF7C3AED),
                          ),
                        ),
                        Text(
                          _isRecording
                              ? '${_isPaused ? 'พักไว้' : 'กำลังบันทึกเสียง'} ${_formatDuration(_recordingSeconds)} / ${_formatDuration(maxRecordingSeconds)}'
                              : 'แตะเพื่อเริ่มอัดเสียง',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _hasDemoFinished || _isRecording ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (!_hasDemoFinished && !_isRecording)
                          const Text(
                            'ฟังเสียงตัวอย่างจบก่อน ปุ่มอัดจึงจะเปิด',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                          ),
                        if (_isRecording)
                          Text(
                            _isPaused
                                ? 'แตะไมค์เพื่ออัดต่อ หรือกด เสร็จแล้ว เพื่อบันทึก'
                                : 'แตะเพื่อพัก • ร้องตามบรรทัดสีชมพู',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                          ),
                        if (!_isRecording && _hasSavedTake)
                          GestureDetector(
                            onTap: _loadLatestRecording,
                            child: const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                'ยกเลิก กลับไปฟังเสียงเดิม',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7C3AED),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isRecording)
                    // Finish and save (works while recording or paused)
                    GestureDetector(
                      onTap: _stopRecording,
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text(
                                'เสร็จแล้ว',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedBottomPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE9FE), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'อัดเสียงเสร็จแล้ว ความยาว ${_formatDuration(_recordingSeconds)}',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    // Back to step 2; the child starts recording themselves.
                    // The old take stays until a new one is saved.
                    await _audioPlayer.stop();
                    setState(() {
                      _recordedFilePath = null;
                      _isPlayingRecord = false;
                    });
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDA4AF),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFDA4AF).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFDA4AF), width: 1.4),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'อัดใหม่',
                        style: TextStyle(
                          color: Color(0xFFE11D48),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _togglePlayRecordedAudio,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7DD3FC),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7DD3FC).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF7DD3FC), width: 1.4),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPlayingRecord ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: const Color(0xFF0284C7),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isPlayingRecord ? 'หยุดฟัง' : 'ฟังเสียงที่อัด',
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _shareRecordedFile,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(bottom: 3.5),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.6),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'ส่งให้ผู้ปกครอง',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _deleteRecording,
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 20),
            label: const Text(
              'ลบเสียงนี้',
              style: TextStyle(
                color: Color(0xFFE11D48),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}