import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/app_usage_sync.dart';
import '../../services/karaoke_recordings.dart';
import '../../services/parental_api_service.dart';
import '../listen/karaoke_record_screen.dart' show SongItem, karaokeShareText, karaokeSongs;

const Color _ink = Color(0xFF26314F);
const Color _brand = Color(0xFF4D7CFE);
const Color _border = Color(0xFFDCE9FF);

/// Parent learning report built from real data:
/// words, exercises, categories, weak spots and streak from the server
/// (GET /api/parent/report) and app usage time counted on this device.
void showLearningReportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LearningReportSheet(),
  );
}

class _ReportData {
  const _ReportData(this.report, this.usage, this.songs);

  final LearningReport report;
  final List<({DateTime day, int seconds})> usage;
  final List<({SongItem song, KaraokeRecording recording})> songs;
}

/// Latest karaoke take of every song (per account; takes backed up on the
/// server are downloaded first, e.g. after reinstalling the app).
Future<List<({SongItem song, KaraokeRecording recording})>> _loadSongs() async {
  await KaraokeRecordings.syncWithServer([for (final s in karaokeSongs()) s.id]);
  final list = <({SongItem song, KaraokeRecording recording})>[];
  for (final song in karaokeSongs()) {
    final recording = await KaraokeRecordings.latest(song.id);
    if (recording != null) list.add((song: song, recording: recording));
  }
  list.sort((a, b) => b.recording.savedAt.compareTo(a.recording.savedAt));
  return list;
}

class _LearningReportSheet extends StatefulWidget {
  const _LearningReportSheet();

  @override
  State<_LearningReportSheet> createState() => _LearningReportSheetState();
}

class _LearningReportSheetState extends State<_LearningReportSheet> {
  late Future<_ReportData> _future = _load();

  Future<_ReportData> _load() async {
    final results = await Future.wait<Object>([
      ParentalApiService.getReport(),
      AppUsageSync.lastDays(7),
      _loadSongs(),
    ]);
    return _ReportData(
      results[0] as LearningReport,
      results[1] as List<({DateTime day, int seconds})>,
      results[2] as List<({SongItem song, KaraokeRecording recording})>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'รายงานและพัฒนาการการเรียน',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สรุปจากการเรียนจริงของบัญชีนี้',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<_ReportData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorView(
                    message:
                        snapshot.error is ParentalApiException
                            ? snapshot.error.toString()
                            : 'โหลดรายงานไม่สำเร็จ กรุณาลองอีกครั้ง',
                    onRetry: () => setState(() => _future = _load()),
                  );
                }
                return _ReportBody(data: snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.data});

  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    final r = data.report;
    final active =
        r.categories.where((c) => c.wordsLearned > 0 || c.attempts > 0).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _SectionTitle('สรุปพัฒนาการ'),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'คำศัพท์ที่เรียนแล้ว',
                value: '${r.wordsLearned} / ${r.wordsTotal} คำ',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'แบบฝึกหัดที่ผ่าน',
                value: '${r.exercisesPassed} / ${r.exercisesTotal} ชุด',
                icon: Icons.verified_rounded,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'คะแนนเฉลี่ยแบบฝึกหัด',
                value: r.averageScore == null ? 'ยังไม่มี' : '${r.averageScore}%',
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'สตรีคเช็กอิน',
                value: '${r.currentStreak} วัน',
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'ทำแบบฝึกหัดไปแล้ว ${r.exerciseAttempts} ครั้ง • '
          'เช็กอิน ${r.checkinDaysLast7} / 7 วันล่าสุด • '
          'สตรีคสูงสุด ${r.longestStreak} วัน • '
          'ผ่าน = ได้ ${r.passPercent}% ขึ้นไป',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),

        const SizedBox(height: 22),
        const _SectionTitle('ความคืบหน้ารายหมวด'),
        if (active.isEmpty)
          const _Hint('ยังไม่มีการเรียนคำศัพท์หรือทำแบบฝึกหัด')
        else
          ...active.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryBar(category: c, passPercent: r.passPercent),
            ),
          ),

        const SizedBox(height: 10),
        const _SectionTitle('ฝึกฟัง'),
        if (r.listening.isEmpty)
          const _Hint('ยังไม่เคยเล่นเกมฝึกฟังจนจบ')
        else
          _ListeningSummaryView(summary: r.listening),

        const SizedBox(height: 22),
        const _SectionTitle('ฝึกออกเสียง (Phonics)'),
        if (r.phonics.practiced == 0)
          const _Hint('ยังไม่เคยฝึกการ์ดออกเสียง')
        else
          _PhonicsSummaryView(summary: r.phonics),

        const SizedBox(height: 22),
        const _SectionTitle('เกมฝึกภาษา'),
        _GameRow(
          icon: Icons.abc_rounded,
          color: const Color(0xFFE5334B),
          title: 'งูน้อยฉลาดเลือก',
          subtitle:
              r.alphabetLevelsPassed == 0
                  ? 'ยังไม่เคยผ่านด่าน'
                  : 'ผ่าน ${r.alphabetLevelsPassed} จาก 50 ด่าน • ได้ ${r.alphabetStars} / 150 ดาว',
        ),
        const SizedBox(height: 10),
        _GameRow(
          icon: Icons.sports_martial_arts_rounded,
          color: const Color(0xFFE9478F),
          title: 'สร้างมอนสเตอร์',
          subtitle:
              r.monsterLevelsPassed == 0
                  ? 'ยังไม่เคยผ่านด่าน'
                  : 'ผ่าน ${r.monsterLevelsPassed} จาก 40 ด่าน • ได้ ${r.monsterStars} / 120 ดาว • '
                      'ล้มมอนสเตอร์ ${r.monstersBeaten} ตัว',
        ),
        const SizedBox(height: 10),
        _GameRow(
          icon: Icons.storefront_rounded,
          color: const Color(0xFFF5B000),
          title: 'มินิมาร์เก็ต',
          subtitle:
              r.marketLevelsPassed == 0
                  ? 'ยังไม่เคยผ่านด่าน'
                  : 'ผ่าน ${r.marketLevelsPassed} จาก 28 ด่าน • ได้ ${r.marketStars} / 84 ดาว • '
                      'สะสมสินค้า ${r.marketItemsCollected} ชนิด',
        ),
        const SizedBox(height: 10),
        _GameRow(
          icon: Icons.construction_rounded,
          color: const Color(0xFF2F6FE0),
          title: 'สร้างสะพาน',
          subtitle:
              r.bridgeLevelsPassed == 0
                  ? 'ยังไม่เคยผ่านด่าน'
                  : 'ผ่าน ${r.bridgeLevelsPassed} จาก 50 ด่าน • ได้ ${r.bridgeStars} / 150 ดาว • '
                      'สติกเกอร์ ${r.bridgeStickers} ตัว',
        ),

        const SizedBox(height: 22),
        const _SectionTitle('เวลาใช้งานแอป 7 วันล่าสุด'),
        _UsageChart(usage: data.usage),
        const SizedBox(height: 6),
        Text(
          'นับเวลาที่เปิดแอปด้วยบัญชีนี้ รวมทุกเครื่อง',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),

        const SizedBox(height: 22),
        const _SectionTitle('ผลงานร้องเพลง'),
        if (data.songs.isEmpty)
          const _Hint('ยังไม่มีเสียงร้องเพลงที่อัดไว้')
        else
          _SongRecordings(items: data.songs),

        const SizedBox(height: 22),
        const _SectionTitle('⚠️ จุดที่ควรฝึกเพิ่ม'),
        if (r.weakCategories.isEmpty && r.weakWords.isEmpty)
          const _Hint('ยังไม่พบจุดอ่อน เก่งมาก !')
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.weakCategories.isNotEmpty) ...[
                  const Text(
                    'หมวดที่คะแนนเฉลี่ยยังไม่ผ่าน',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...r.weakCategories.map(
                    (c) => Text(
                      '• ${c.name}: เฉลี่ย ${c.averageScore}% (${c.attempts} ครั้ง)',
                      style: const TextStyle(fontSize: 12.5, color: _ink),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (r.weakWords.isNotEmpty) ...[
                  const Text(
                    'คำที่ตอบผิดบ่อย (30 วันล่าสุด)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...r.weakWords.map(
                    (w) => Text(
                      '• ${w.term}${w.translation.isEmpty ? '' : ' (${w.translation})'}'
                      ' — ผิด ${w.wrongCount} ครั้ง',
                      style: const TextStyle(fontSize: 12.5, color: _ink),
                    ),
                  ),
                ],
              ],
            ),
          ),

        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brand,
              side: const BorderSide(color: _border, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'ปิดหน้ารายงาน',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.bold,
        color: _ink,
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.passPercent});

  final CategoryProgress category;
  final int passPercent;

  @override
  Widget build(BuildContext context) {
    final c = category;
    final progress = c.wordsTotal == 0 ? 0.0 : c.wordsLearned / c.wordsTotal;
    final score = c.averageScore;
    final color =
        score == null
            ? _brand
            : score >= passPercent
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            Text(
              '${c.wordsLearned} / ${c.wordsTotal} คำ'
              '${score == null ? '' : ' • คะแนน $score%'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _UsageChart extends StatelessWidget {
  const _UsageChart({required this.usage});

  final List<({DateTime day, int seconds})> usage;

  static const List<String> _thaiDays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

  @override
  Widget build(BuildContext context) {
    final minutes = usage.map((u) => (u.seconds / 60).round()).toList();
    final total = minutes.fold<int>(0, (a, b) => a + b);
    final maxMinutes = minutes.fold<int>(1, (a, b) => b > a ? b : a);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(usage.length, (i) {
              final isToday = i == usage.length - 1;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${minutes[i]}m',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _brand,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 16,
                    height: 4 + 60 * minutes[i] / maxMinutes,
                    decoration: BoxDecoration(
                      color:
                          isToday
                              ? const Color(0xFF4D7CFE)
                              : const Color(0xFF93C5FD),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isToday
                        ? 'วันนี้'
                        : _thaiDays[usage[i].day.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            'รวม 7 วัน : ${total ~/ 60} ชั่วโมง ${total % 60} นาที '
            '(เฉลี่ยวันละ ${(total / 7).round()} นาที)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Parent listens to (and shares) the child's latest karaoke takes.
/// The parent zone is already behind the PIN, so sharing needs no extra step.
class _SongRecordings extends StatefulWidget {
  const _SongRecordings({required this.items});

  final List<({SongItem song, KaraokeRecording recording})> items;

  @override
  State<_SongRecordings> createState() => _SongRecordingsState();
}

class _SongRecordingsState extends State<_SongRecordings> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String path) async {
    await _player.stop();
    if (_playingPath == path) {
      setState(() => _playingPath = null);
      return;
    }
    await _player.play(DeviceFileSource(path));
    if (mounted) setState(() => _playingPath = path);
  }

  Future<void> _share(SongItem song, String path) async {
    await _player.stop();
    if (mounted) setState(() => _playingPath = null);
    await Share.shareXFiles([XFile(path)], text: karaokeShareText(song));
  }

  static String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year + 543} ${two(d.hour)}:${two(d.minute)}';
  }

  static String _length(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in widget.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  // Song letter on the song's colours (same as its card)
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: item.song.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      item.song.letter,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.song.titleTh,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'อัดเมื่อ ${_date(item.recording.savedAt)} • ${_length(item.recording.seconds)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _playingPath == item.recording.path ? 'หยุดฟัง' : 'ฟัง',
                    onPressed: () => _togglePlay(item.recording.path),
                    icon: Icon(
                      _playingPath == item.recording.path
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: _brand,
                      size: 32,
                    ),
                  ),
                  IconButton(
                    tooltip: 'ส่งต่อ',
                    onPressed: () => _share(item.song, item.recording.path),
                    icon: const Icon(
                      Icons.share_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "ฝึกฟัง": results of the listening games (sent to the server).
class _ListeningSummaryView extends StatelessWidget {
  const _ListeningSummaryView({required this.summary});

  final ListeningSummary summary;

  // Topic ids of "ฟังเสียงเติมคำ" -> Thai names shown on its cards.
  static const Map<String, String> _topicNames = {
    'activities': 'กิจกรรมยามว่าง',
    'animals': 'สัตว์น่ารักรอบตัว',
    'food': 'อาหารและของโปรด',
    'people': 'ครอบครัวและบุคคล',
    'places': 'สถานที่และธรรมชาติ',
  };

  static String _scoreLine(ListeningGameSummary g, String unit) {
    if (g.plays == 0) return 'ยังไม่เคยเล่นจบ';
    final parts = <String>['เล่นจบ ${g.plays} $unit'];
    if (g.averageScore != null) parts.add('เฉลี่ย ${g.averageScore}%');
    if (g.bestScore != null) parts.add('ดีที่สุด ${g.bestScore}%');
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final minutes = s.karaokeSeconds ~/ 60;
    final seconds = s.karaokeSeconds % 60;
    return Column(
      children: [
        _GameRow(
          icon: Icons.hearing_rounded,
          color: const Color(0xFFFF7E36),
          title: 'ฟังแยกเสียงคำศัพท์',
          subtitle: _scoreLine(s.minimalPairs, 'รอบ'),
        ),
        const SizedBox(height: 10),
        _GameRow(
          icon: Icons.edit_note_rounded,
          color: const Color(0xFFC2185B),
          title: 'ฟังเสียงเติมคำ',
          subtitle: _scoreLine(s.fillBlank, 'หมวด'),
          children: [
            for (final t in s.fillBlankTopics)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${_topicNames[t.topic] ?? t.topic} : '
                  'ล่าสุด ${t.lastScore ?? '-'}% • ดีที่สุด ${t.bestScore ?? '-'}% '
                  '(${t.plays} ครั้ง)',
                  style: const TextStyle(fontSize: 12, color: _ink),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _GameRow(
          icon: Icons.mic_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'คาราโอเกะเพลง',
          subtitle:
              s.karaokeRecordings == 0
                  ? 'ยังไม่เคยอัดเสียง'
                  : 'อัดเสียง ${s.karaokeRecordings} ครั้ง • ${s.karaokeSongs} เพลง • '
                      'รวม ${minutes > 0 ? '$minutes นาที ' : ''}$seconds วินาที',
        ),
        const SizedBox(height: 10),
        _GameRow(
          icon: Icons.pets_rounded,
          color: const Color(0xFFF59A1B),
          title: 'เกมเสียงสัตว์',
          subtitle: _scoreLine(s.animalSounds, 'รอบ'),
        ),
      ],
    );
  }
}

/// "ฝึกออกเสียง": phonics cards practiced per level.
class _PhonicsSummaryView extends StatelessWidget {
  const _PhonicsSummaryView({required this.summary});

  final PhonicsSummary summary;

  static const Color _color = Color(0xFF0288D1);

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final last = s.lastPracticedAt;
    return _GameRow(
      icon: Icons.record_voice_over_rounded,
      color: _color,
      title: 'ฝึกแล้ว ${s.practiced} / ${s.total} การ์ด',
      subtitle:
          'ครบ ${s.completedCategories} จาก ${s.categories.length} ด่าน'
          '${last == null ? '' : ' • ล่าสุด ${last.day}/${last.month}/${last.year + 543}'}',
      children: [
        const SizedBox(height: 6),
        for (final c in s.categories)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        style: const TextStyle(fontSize: 12, color: _ink),
                      ),
                    ),
                    Text(
                      c.practiced >= c.total && c.total > 0
                          ? 'ครบแล้ว ✓'
                          : '${c.practiced} / ${c.total}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color:
                            c.practiced >= c.total && c.total > 0
                                ? const Color(0xFF10B981)
                                : _color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value:
                        c.total == 0
                            ? 0
                            : (c.practiced / c.total).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      c.practiced >= c.total && c.total > 0
                          ? const Color(0xFF10B981)
                          : _color,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.children = const [],
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
