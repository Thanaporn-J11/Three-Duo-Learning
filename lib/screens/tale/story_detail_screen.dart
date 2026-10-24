import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'tale_api_service.dart';

class StoryDetailScreen extends StatefulWidget {
  final String title;

  // Stable IDs shared by tale favorites and reading progress.
  static const Map<String, String> taleIds = {
    'Little Red Riding Hood': 'little_red_riding_hood',
    'The Ant and the Grasshopper': 'the_ant_and_the_grasshopper',
    'The Boy Who Cried Wolf': 'the_boy_who_cried_wolf',
    'The Fox and the Stork': 'the_fox_and_the_stork',
    'The Goose That Laid the Golden Eggs': 'the_goose_that_laid_the_golden_eggs',
    'The Lion and the Fox': 'the_lion_and_the_fox',
    'The Lion and the Mouse': 'the_lion_and_the_mouse',
    'The Three Little Pigs': 'the_three_little_pigs',
    'The Tortoise and the Hare': 'the_tortoise_and_the_hare',
    'The Ugly Duckling': 'the_ugly_duckling',
  };

  static String? taleIdForTitle(String title) => taleIds[title];

  const StoryDetailScreen({Key? key, this.title = 'Little Red Riding Hood'})
      : super(key: key);

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  late AudioPlayer _audioPlayer;
  bool _isPlayingAudio = false;

  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  String _lastSpokenWords = '';

  bool isTranslated = false;

  bool _isRewinding = false;
  bool _isForwarding = false;

  int currentStoryIndex = 0;
  bool _isRestoringProgress = true;
  bool _progressLoaded = false;
  int _savedVideoPositionMs = 0;
  DateTime _lastVideoSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isSavingProgress = false;

  late List<Map<String, String>> storySteps;
  late String videoAssetPath;

  List<Map<String, dynamic>> spokenWords = [];
  List<String> incorrectWords = [];
  bool hasEvaluated = false;

  static const Map<String, String> storyThaiTitles = {
    'Little Red Riding Hood': 'หนูน้อยหมวกแดง',
    'The Ant and the Grasshopper': 'มดกับตั๊กแตน',
    'The Boy Who Cried Wolf': 'เด็กเลี้ยงแกะ',
    'The Fox and the Stork': 'หมาจิ้งจอกกับนกกระสา',
    'The Goose That Laid the Golden Eggs': 'ห่านกับไข่ทองคำ',
    'The Lion and the Fox': 'สิงโตกับหมาจิ้งจอก',
    'The Lion and the Mouse': 'ราชสีห์กับหนู',
    'The Three Little Pigs': 'ลูกหมูสามตัว',
    'The Tortoise and the Hare': 'กระต่ายกับเต่า',
    'The Ugly Duckling': 'ลูกเป็ดขี้เหร่',
  };

  static final Map<String, Map<String, dynamic>> storyDatabase = {
    'Little Red Riding Hood': {
      'video': 'assets/videos/red_riding_hood.mp4',
      'steps': [
        {
          'en': 'Once upon a time, there was a kind girl.',
          'th': 'กาลครั้งหนึ่งนานมาแล้ว มีเด็กหญิงใจดีคนหนึ่ง',
        },
        {
          'en': 'She wore a bright red hood.',
          'th': 'เธอสวมหมวกคลุมสีแดงสดใส',
        },
        {
          'en': 'Everyone called her Little Red Riding Hood.',
          'th': 'ทุกคนเรียกเธอว่า หนูน้อยหมวกแดง',
        },
        {
          'en': 'Her mother gave her a basket of cakes.',
          'th': 'คุณแม่มอบตะกร้าขนมเค้กให้เธอ',
        },
        {
          'en': 'Please visit your grandma in the forest.',
          'th': 'ช่วยไปเยี่ยมคุณยายในป่าหน่อยนะจ๊ะ',
        },
        {
          'en': 'Do not talk to strangers on the way.',
          'th': 'อย่าคุยกับคนแปลกหน้าระหว่างทางเด็ดขาด',
        },
        {
          'en': 'A hungry wolf was watching her closely.',
          'th': 'หมาป่าตัวร้ายแอบมองเธออยู่อย่างใกล้ชิด',
        },
        {
          'en': 'The brave girl reached home safely.',
          'th': 'เด็กหญิงผู้กล้าหาญเดินทางถึงบ้านอย่างปลอดภัย',
        },
      ],
    },
    'The Ant and the Grasshopper': {
      'video': 'assets/videos/TheAnt_and_theGrasshopper.mp4',
      'steps': [
        {
          'en': 'A little ant worked hard all summer.',
          'th': 'มดตัวน้อยทำงานหนักตลอดฤดูร้อน',
        },
        {
          'en': 'He gathered plenty of food for winter.',
          'th': 'เขาเก็บสะสมอาหารไว้มากมายสำหรับฤดูหนาว',
        },
        {
          'en': 'The playful grasshopper was only singing.',
          'th': 'ตั๊กแตนผู้รักความสนุกเอาแต่ร้องเพลง',
        },
        {
          'en': 'Winter came and snow covered the ground.',
          'th': 'ฤดูหนาวมาถึงและหิมะปกคลุมพื้นดิน',
        },
        {
          'en': 'The grasshopper had nothing to eat.',
          'th': 'ตั๊กแตนไม่มีอาหารกินแม้แต่น้อย',
        },
        {
          'en': 'He asked the kind ant for help.',
          'th': 'เขาจึงไปขอความช่วยเหลือจากมดใจดี',
        },
        {
          'en': 'The ant shared his food generously.',
          'th': 'มดแบ่งปันอาหารให้ด้วยความเอื้อเฟื้อ',
        },
        {
          'en': 'Work hard today to enjoy tomorrow.',
          'th': 'จงขยันทำงานในวันนี้เพื่อความสุขในวันข้างหน้า',
        },
      ],
    },
    'The Boy Who Cried Wolf': {
      'video': 'assets/videos/TheBoy_WhoCriedWolf.mp4',
      'steps': [
        {
          'en': 'A shepherd boy watched his sheep near a village.',
          'th': 'เด็กเลี้ยงแกะดูแลฝูงแกะอยู่ใกล้กับหมู่บ้าน',
        },
        {
          'en': 'He felt bored and decided to play a trick.',
          'th': 'เขารู้สึกเบื่อจึงคิดจะเล่นตลกแกล้งคนอื่น',
        },
        {
          'en': 'Wolf, wolf, please help me!',
          'th': 'หมาป่ามาแล้ว ช่วยด้วยครับ!',
        },
        {
          'en': 'The villagers ran quickly to help him.',
          'th': 'ชาวบ้านต่างรีบวิ่งมาช่วยเหลือเขา',
        },
        {
          'en': 'The boy laughed because there was no wolf.',
          'th': 'เด็กชายหัวเราะชอบใจเพราะไม่มีหมาป่าจริงๆ',
        },
        {
          'en': 'One day, a real wolf attacked the flock.',
          'th': 'วันหนึ่ง หมาป่าตัวจริงได้บุกเข้ามาทำร้ายฝูงแกะ',
        },
        {
          'en': 'Nobody believed his cries for help.',
          'th': 'ไม่มีใครเชื่อเสียงร้องขอความช่วยเหลือของเขาอีกต่อไป',
        },
        {
          'en': 'Always tell the truth to build trust.',
          'th': 'จงพูดความจริงเสมอเพื่อสร้างความไว้วางใจ',
        },
      ],
    },
    'The Fox and the Stork': {
      'video': 'assets/videos/TheFox_and_theStork.mp4',
      'steps': [
        {
          'en': 'A sly fox invited a stork for dinner.',
          'th': 'สุนัขจิ้งจอกเจ้าเล่ห์เชิญนกกระสามากินอาหารเย็น',
        },
        {
          'en': 'He served delicious soup in a shallow dish.',
          'th': 'เขาเสิร์ฟซุปแสนอร่อยในจานก้นแบน',
        },
        {
          'en': 'The stork could not eat with her long beak.',
          'th': 'นกกระสาไม่สามารถกินได้เพราะมีจะงอยปากยาว',
        },
        {
          'en': 'Next day, the stork invited the fox over.',
          'th': 'วันต่อมา นกกระสาจึงเชิญสุนัขจิ้งจอกมาที่บ้านบ้าง',
        },
        {
          'en': 'She served soup in a tall, narrow jar.',
          'th': 'เธอเสิร์ฟซุปในเหยือกทรงสูงและแคบ',
        },
        {
          'en': 'The fox could not reach the food.',
          'th': 'สุนัขจิ้งจอกไม่สามารถกินอาหารได้เลย',
        },
        {
          'en': 'Treat others the way you want to be treated.',
          'th': 'จงปฏิบัติต่อผู้อื่นเช่นเดียวกับที่คุณอยากให้เขาปฏิบัติต่อคุณ',
        },
      ],
    },
    'The Goose That Laid the Golden Eggs': {
      'video': 'assets/videos/TheGoose_ThatLaid_theGoldenEggs.mp4',
      'steps': [
        {
          'en': 'A poor countryman owned a wonderful goose.',
          'th': 'ชาวชนบทผู้ยากจนเป็นเจ้าของห่านวิเศษตัวหนึ่ง',
        },
        {
          'en': 'Every morning, she laid a shining golden egg.',
          'th': 'ทุกๆ เช้า มันจะออกไข่เป็นทองคำสุกปลั่ง',
        },
        {
          'en': 'The man became rich very quickly.',
          'th': 'ชายคนนั้นร่ำรวยขึ้นมาอย่างรวดเร็ว',
        },
        {
          'en': 'He grew greedy and wanted all the gold at once.',
          'th': 'เขาเกิดความโลภและอยากได้ทองคำทั้งหมดในคราวเดียว',
        },
        {
          'en': 'He cut the goose open to find more gold.',
          'th': 'เขาจึงผ่าท้องห่านเพื่อหาทองคำเพิ่มเติม',
        },
        {
          'en': 'There was no gold inside the poor goose.',
          'th': 'แต่กลับไม่มีทองคำใดๆ อยู่ข้างในเลย',
        },
        {
          'en': 'Greed often leads to great loss.',
          'th': 'ความโลภมากมักนำมาซึ่งความสูญเสีย',
        },
      ],
    },
    'The Lion and the Fox': {
      'video': 'assets/videos/TheLion_and_theFox.mp4',
      'steps': [
        {
          'en': 'An old lion pretended to be very sick.',
          'th': 'สิงโตชราแกล้งทำเป็นป่วยหนัก',
        },
        {
          'en': 'He stayed inside his dark, deep cave.',
          'th': 'มันนอนนิ่งอยู่ภายในถ้ำที่มืดและลึก',
        },
        {
          'en': 'Many animals visited him and got eaten.',
          'th': 'สัตว์หลายตัวเข้าไปเยี่ยมและถูกจับกิน',
        },
        {
          'en': 'A clever fox stood outside the cave.',
          'th': 'สุนัขจิ้งจอกผู้ฉลาดหลักแหลมยืนดูอยู่หน้าถ้ำ',
        },
        {
          'en': 'I see many footprints going in.',
          'th': 'ฉันเห็นรอยเท้าสัตว์มากมายเดินเข้าไป',
        },
        {
          'en': 'None of the footprints are coming back out.',
          'th': 'แต่ไม่มีรอยเท้าใดเดินกลับออกมาเลย',
        },
        {
          'en': 'Wisdom and careful observation keep us safe.',
          'th': 'ความรอบคอบและช่างสังเกตช่วยให้เราปลอดภัย',
        },
      ],
    },
    'The Lion and the Mouse': {
      'video': 'assets/videos/TheLion_and_theMouse.mp4',
      'steps': [
        {
          'en': 'A giant lion was sleeping under a tree.',
          'th': 'สิงโตตัวใหญ่กำลังนอนหลับอยู่ใต้ต้นไม้',
        },
        {
          'en': 'A tiny mouse ran across his big nose.',
          'th': 'หนูตัวจิ๋ววิ่งซุกซนข้ามจมูกโตของมัน',
        },
        {
          'en': 'The lion caught the mouse with his paw.',
          'th': 'สิงโตตะปบจับหนูตัวนั้นไว้ได้ทันควัน',
        },
        {
          'en': 'Please spare me and I will help you one day.',
          'th': 'โปรดไว้ชีวิตข้าเถิด แล้วข้าจะตอบแทนท่านในวันหนึ่ง',
        },
        {
          'en': 'Later, the lion was trapped in a hunter net.',
          'th': 'ต่อมา สิงโตติดกับดักตาข่ายของนายพราน',
        },
        {
          'en': 'The little mouse chewed the ropes quickly.',
          'th': 'เจ้าหนูน้อยรีบวิ่งมากัดแทะเชือกจนขาด',
        },
        {
          'en': 'Even the smallest friend can be of great help.',
          'th': 'แม้แต่เพื่อนตัวเล็กที่สุดก็สามารถช่วยเหลือเราได้อย่างยิ่งใหญ่',
        },
      ],
    },
    'The Three Little Pigs': {
      'video': 'assets/videos/ThreeLittlePigs.mp4',
      'steps': [
        {
          'en': 'Three little pigs built their own houses.',
          'th': 'ลูกหมูสามตัวสร้างบ้านของตัวเอง',
        },
        {
          'en': 'The first pig built a house of straw.',
          'th': 'ลูกหมูตัวแรกสร้างบ้านด้วยฟางข้าว',
        },
        {
          'en': 'The second pig built a house of sticks.',
          'th': 'ลูกหมูตัวที่สองสร้างบ้านด้วยเศษไม้',
        },
        {
          'en': 'The third pig built a strong brick house.',
          'th': 'ลูกหมูตัวที่สามสร้างบ้านอิฐอันแข็งแรง',
        },
        {
          'en': 'The big bad wolf blew the weak houses down.',
          'th': 'หมาป่าตัวร้ายเป่าบ้านที่ไม่แข็งแรงจนพังทลาย',
        },
        {
          'en': 'He could not blow down the solid brick house.',
          'th': 'แต่มันไม่สามารถเป่าบ้านอิฐที่มั่นคงให้พังได้',
        },
        {
          'en': 'Hard work and patience ensure safety.',
          'th': 'ความพยายามและความอดทนนำมาซึ่งความปลอดภัย',
        },
      ],
    },
    'The Tortoise and the Hare': {
      'video': 'assets/videos/TheTortoise_and_theHare.mp4',
      'steps': [
        {
          'en': 'A speedy hare laughed at a slow tortoise.',
          'th': 'กระต่ายผู้วิ่งเร็วหัวเราะเยาะเต่าที่เดินชักช้า',
        },
        {
          'en': 'They decided to have a running race.',
          'th': 'พวกมันจึงตกลงที่จะแข่งวิ่งกัน',
        },
        {
          'en': 'The hare ran fast and took a nap.',
          'th': 'กระต่ายวิ่งนำไปไกลแล้วแวะนอนหลับพักผ่อน',
        },
        {
          'en': 'The tortoise walked slowly but never stopped.',
          'th': 'เจ้าเต่าเดินอย่างช้าๆ แต่ไม่เคยหยุดพักเลย',
        },
        {
          'en': 'The tortoise crossed the finish line first.',
          'th': 'ในที่สุด เจ้าเต่าก็เดินเข้าเส้นชัยเป็นตัวแรก',
        },
        {
          'en': 'Slow and steady always wins the race.',
          'th': 'ความสม่ำเสมอและความพยายามนำไปสู่ชัยชนะเสมอ',
        },
      ],
    },
    'The Ugly Duckling': {
      'video': 'assets/videos/The_Ugly_Duckling.mp4',
      'steps': [
        {
          'en': 'A little bird looked different from the others.',
          'th': 'ลูกนกตัวน้อยมีรูปร่างหน้าตาแตกต่างจากพี่น้อง',
        },
        {
          'en': 'Everyone called him an ugly duckling.',
          'th': 'ทุกคนต่างพากันเรียกเขาว่าลูกเป็ดขี้เหร่',
        },
        {
          'en': 'He felt sad and walked away alone.',
          'th': 'เขารู้สึกเศร้าใจจึงเดินจากไปตามลำพัง',
        },
        {
          'en': 'He survived the cold and harsh winter.',
          'th': 'เขาอดทนผ่านพ้นฤดูหนาวอันหนาวเหน็บมาได้',
        },
        {
          'en': 'In spring, he saw his reflection in the water.',
          'th': 'ในฤดูใบไม้ผลิ เขามองเห็นเงาสะท้อนของตัวเองในน้ำ',
        },
        {
          'en': 'He had grown into a beautiful white swan.',
          'th': 'เขาได้เติบโตกลายเป็นหงส์ขาวที่สง่างาม',
        },
        {
          'en': 'True beauty shines from within.',
          'th': 'ความงดงามที่แท้จริงจะเปล่งประกายจากข้างใน',
        },
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final storyData = storyDatabase[widget.title] ??
        storyDatabase['Little Red Riding Hood']!;

    videoAssetPath = storyData['video'] as String;
    storySteps = (storyData['steps'] as List)
        .map((item) => Map<String, String>.from(item as Map))
        .toList();

    _restoreProgress();

    _controller = VideoPlayerController.asset(
      videoAssetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) async {
  if (mounted) {
    setState(() {
      _isInitialized = true;
    });

    // Restore the saved video position after initialization.
    await _restoreVideoPositionIfReady();
  }
});

    _controller.addListener(_videoListener);

    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });

    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _restoreProgress() async {
    final taleId = StoryDetailScreen.taleIdForTitle(widget.title);
    if (taleId == null) {
      _progressLoaded = true;
      await _restoreVideoPositionIfReady();
      return;
    }

    try {
      final progressList = await TaleApiService.getProgress();
      Map<String, dynamic>? saved;
      for (final item in progressList) {
        if (item['tale_id']?.toString() == taleId) {
          saved = item;
          break;
        }
      }

      if (saved != null && mounted) {
        final savedIndex = int.tryParse(
              saved['current_sentence_index']?.toString() ?? '',
            ) ?? 0;
        _savedVideoPositionMs = int.tryParse(
              saved['current_video_position_ms']?.toString() ?? '',
            ) ?? 0;
        setState(() {
          currentStoryIndex = savedIndex.clamp(0, storySteps.length - 1).toInt();
        });
      }
    } catch (e) {
      // Keep the story usable even when the server is temporarily unavailable.
      debugPrint('Restore tale progress failed: $e');
    } finally {
      _progressLoaded = true;
      await _restoreVideoPositionIfReady();
    }
  }

  Future<void> _restoreVideoPositionIfReady() async {
    if (!_progressLoaded || !_isInitialized || !mounted) return;

    try {
      final duration = _controller.value.duration;
      final requestedPosition = Duration(milliseconds: _savedVideoPositionMs);
      final safePosition = requestedPosition > duration ? duration : requestedPosition;
      if (safePosition > Duration.zero) {
        await _controller.seekTo(safePosition);
      }
    } catch (e) {
      debugPrint('Restore video position failed: $e');
    } finally {
      if (mounted && _isRestoringProgress) {
        setState(() => _isRestoringProgress = false);
      }
    }
  }

  Future<void> _saveCurrentProgress({bool force = false}) async {
    if (_isRestoringProgress || !_isInitialized || _isSavingProgress) return;
    final taleId = StoryDetailScreen.taleIdForTitle(widget.title);
    if (taleId == null) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastVideoSaveAt).inSeconds < 5) return;
    _lastVideoSaveAt = now;
    _isSavingProgress = true;

    try {
      await TaleApiService.saveProgress(
        taleId: taleId,
        currentSentenceIndex: currentStoryIndex,
        currentVideoPositionMs: _controller.value.position.inMilliseconds,
      );
    } catch (e) {
      // Do not interrupt reading if saving fails.
      debugPrint('Save tale progress failed: $e');
    } finally {
      _isSavingProgress = false;
    }
  }

  void _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) {
          debugPrint('Speech Error: $val');
          if (mounted) {
            setState(() => _isListening = false);
            _evaluateSpeech(_lastSpokenWords);
          }
        },
        onStatus: (status) {
          debugPrint('Speech Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
              _evaluateSpeech(_lastSpokenWords);
            }
          }
        },
      );
    } catch (e) {
      debugPrint("STT Init Exception: $e");
    }
  }

  Future<void> _speakSingleWord(String word) async {
    if (_isInitialized && _controller.value.isPlaying) {
      await _controller.pause();
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    try {
      String cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();
      String audioUrl =
          "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=${Uri.encodeComponent(cleanWord)}";

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
    } catch (e) {
      debugPrint("Single Word Audio Error: $e");
    }
  }

  void _toggleListening() async {
    if (_isInitialized && _controller.value.isPlaying) {
      await _controller.pause();
    }
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
    }

    if (!_isListening) {
      bool available = _speechAvailable;
      if (!available) {
        available = await _speech.initialize();
      }

      if (!mounted) return;

      if (available) {
        setState(() {
          _isListening = true;
          _lastSpokenWords = '';
          spokenWords.clear();
          incorrectWords.clear();
          hasEvaluated = false;
        });

        _speech.listen(
          onResult: (val) {
            setState(() {
              _lastSpokenWords = val.recognizedWords;
            });
          },
          localeId: 'en_US',
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาอนุญาตสิทธิ์การใช้งานไมโครโฟนเพื่อฝึกพูด'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
      _evaluateSpeech(_lastSpokenWords);
    }
  }

  void _evaluateSpeech(String recognizedText) {
    String currentTarget = storySteps[currentStoryIndex]['en']!;

    List<String> targetWords = currentTarget
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .split(RegExp(r'\s+'));

    List<String> spokenWordsList = recognizedText
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .split(RegExp(r'\s+'));

    List<Map<String, dynamic>> evaluated = [];
    List<String> wrong = [];

    for (int i = 0; i < targetWords.length; i++) {
      String rawTarget = targetWords[i];
      String cleanTarget = rawTarget.toLowerCase();

      bool isMatch = false;

      if (i < spokenWordsList.length && spokenWordsList[i] == cleanTarget) {
        isMatch = true;
      } else if (spokenWordsList.contains(cleanTarget)) {
        isMatch = true;
      }

      if (!isMatch) {
        wrong.add(rawTarget);
      }

      evaluated.add({
        'word': rawTarget,
        'isCorrect': isMatch,
      });
    }

    setState(() {
      spokenWords = evaluated;
      incorrectWords = wrong;
      hasEvaluated = true;
    });
  }

  Future<void> _speakCurrentSentence() async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isPlayingAudio = false);
      return;
    }

    if (_isInitialized && _controller.value.isPlaying) {
      await _controller.pause();
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    try {
      setState(() => _isPlayingAudio = true);

      String text = storySteps[currentStoryIndex]['en']!;
      String audioUrl =
          "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=${Uri.encodeComponent(text)}";

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
    } catch (e) {
      debugPrint("Audio Play Error: $e");
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  void _videoListener() {
    if (mounted) setState(() {});
    // The controller notifies on every frame; persist only about every 5 seconds.
    _saveCurrentProgress();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveCurrentProgress(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentProgress(force: true);
    _speech.stop();
    _audioPlayer.dispose();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  void toggleTranslation() {
    setState(() => isTranslated = !isTranslated);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void prevStoryStep() {
    _audioPlayer.stop();
    if (_isListening) _speech.stop();

    if (currentStoryIndex > 0) {
      setState(() {
        currentStoryIndex--;
        spokenWords.clear();
        incorrectWords.clear();
        _lastSpokenWords = '';
        hasEvaluated = false;
        isTranslated = false;
        _isListening = false;
        _isPlayingAudio = false;
      });
      _saveCurrentProgress(force: true);
    }
  }

  void nextStoryStep() {
    _audioPlayer.stop();
    if (_isListening) _speech.stop();

    if (currentStoryIndex < storySteps.length - 1) {
      setState(() {
        currentStoryIndex++;
        spokenWords.clear();
        incorrectWords.clear();
        _lastSpokenWords = '';
        hasEvaluated = false;
        isTranslated = false;
        _isListening = false;
        _isPlayingAudio = false;
      });
      _saveCurrentProgress(force: true);
    } else {
      _saveCurrentProgress(force: true);
      _showCompletionDialog();
    }
  }

  // ================= POPUP จบเรื่อง ปรับแต่งเฉดสีม่วงใหม่ + เส้นขอบคมชัด + ตัวอักษรสีดำ =================
  void _showCompletionDialog() {
    final displayTitle = storyThaiTitles[widget.title] ?? widget.title;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 1. กล่องการ์ดหลัก เฉดสีม่วงไวโอเลตคมชัด 3D
              Container(
                margin: const EdgeInsets.only(top: 26, bottom: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E1065), // สันเงา 3D ด้านล่าง
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 42, 20, 36),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF6D28D9), // ม่วงไวโอเลตสว่างสวย
                        Color(0xFF4C1D95), // ม่วงน้ำเงินเข้มหรู
                      ],
                    ),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6), // ขอบสีม่วงสดใส
                      width: 3.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ดาว 3D ขยายใหญ่พิเศษ (ดาวกลาง 76px, ดาวข้าง 56px)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Transform.rotate(
                            angle: -0.22,
                            child: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFD166),
                              size: 56,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFB45309),
                                  offset: Offset(0, 4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB703),
                              size: 76,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFB45309),
                                  offset: Offset(0, 6),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Transform.rotate(
                            angle: 0.22,
                            child: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFD166),
                              size: 56,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFB45309),
                                  offset: Offset(0, 4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // รูปวงกลมมาสคอต: เส้นขอบสีเข้มคมชัด ไม่เอาเงาฟุ้งๆ
                      Container(
                        width: 122,
                        height: 122,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2E1065),
                          border: Border.all(
                            color: const Color(0xFF1E1B4B),
                            width: 3.5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 108,
                            height: 108,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF5EEFF),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/tale/bravo.png',
                                width: 88,
                                height: 88,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.emoji_events_rounded,
                                    color: Color(0xFFFFB703),
                                    size: 58,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ข้อความ EXCELLENT! สีเหลืองทอง
                      const Text(
                        'EXCELLENT!',
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFC02E),
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Color(0xFFB45309),
                              offset: Offset(0, 3),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'คุณเรียนนิทานเรื่องนี้จบแล้ว!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF3E8FF),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // กล่องการ์ดข้อมูลนิทาน พื้นหลังสีเหลืองทองสดใส
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC02E),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              displayTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2E1065),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4C1D95),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ปุ่มสรุปประโยคสีเขียว: ตัวอักษรสีดำ
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4D7C0F),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFA3E635), Color(0xFF84CC16)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'อ่านและฝึกพูดครบทั้ง ${storySteps.length} ประโยค',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. ป้ายริบบิ้นมีปีก VICTORY! ลอยเด่นเหนือหัวการ์ด
              Positioned(
                top: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform(
                      transform: Matrix4.skewY(0.15),
                      child: Container(
                        width: 14,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF9F1239),
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF9F1239),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF4D8D), Color(0xFFF43F5E)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'VICTORY!',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.8,
                            shadows: [
                              Shadow(
                                color: Color(0xFF881337),
                                offset: Offset(0, 2),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Transform(
                      transform: Matrix4.skewY(-0.15),
                      child: Container(
                        width: 14,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF9F1239),
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. ปุ่มกด 3D Game Buttons ทรงกลมลอยเด่นด้านล่าง
              Positioned(
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ปุ่มรีเพลย์ (ฝึกอีกครั้ง)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          currentStoryIndex = 0;
                          spokenWords.clear();
                          incorrectWords.clear();
                          _lastSpokenWords = '';
                          hasEvaluated = false;
                          isTranslated = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0369A1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.replay_rounded,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // ปุ่มลูกศรไปต่อ (สำเร็จ)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E7490),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _rewind5Seconds() {
    if (_isInitialized) {
      setState(() => _isRewinding = true);
      final current = _controller.value.position;
      final target = current - const Duration(seconds: 5);
      _controller.seekTo(target < Duration.zero ? Duration.zero : target);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _isRewinding = false);
      });
    }
  }

  void _forward5Seconds() {
    if (_isInitialized) {
      setState(() => _isForwarding = true);
      final current = _controller.value.position;
      final total = _controller.value.duration;
      final target = current + const Duration(seconds: 5);
      _controller.seekTo(target > total ? total : target);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _isForwarding = false);
      });
    }
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenVideoPlayer(controller: _controller),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color purpleNormalColor = Color(0xFF7C3AED);
    const Color purpleNormalBevel = Color(0xFF3B0764);

    const Color orangeActiveColor = Color(0xFFF97316);
    const Color orangeActiveBevel = Color(0xFFC2410C);

    const Color tvFrameBevel = Color(0xFF6D28D9);

    final position =
        _isInitialized ? _controller.value.position : Duration.zero;
    final duration =
        _isInitialized ? _controller.value.duration : Duration.zero;
    final currentStory = storySteps[currentStoryIndex];
    final displayTitle = storyThaiTitles[widget.title] ?? widget.title;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5EEFF),
              Color(0xFFFAF5FF),
              Color(0xFFFDFBFE),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              AppBar(
                backgroundColor: purpleNormalColor,
                elevation: 2,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  displayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(
                    children: [
                      // ================= TV FRAME DESIGN =================
                      SizedBox(
                        height: 20,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Transform.rotate(
                                  angle: -0.45,
                                  child: Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: purpleNormalColor,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Transform.rotate(
                                  angle: 0.45,
                                  child: Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: purpleNormalColor,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 14,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: tvFrameBevel,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          color: tvFrameBevel,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: tvFrameBevel.withOpacity(0.22),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: purpleNormalColor, width: 3.5),
                          ),
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1B4B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFE9D5FF),
                                    width: 3.0,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      SizedBox(
                                        height: 200,
                                        width: double.infinity,
                                        child: _isInitialized
                                            ? AspectRatio(
                                                aspectRatio: _controller.value.aspectRatio,
                                                child: VideoPlayer(_controller),
                                              )
                                            : const Center(
                                                child: CircularProgressIndicator(
                                                  color: purpleNormalColor,
                                                ),
                                              ),
                                      ),
                                      if (_isInitialized)
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: CircleAvatar(
                                            backgroundColor: Colors.black.withOpacity(0.6),
                                            radius: 17,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(
                                                Icons.fullscreen_rounded,
                                                color: Colors.white,
                                                size: 21,
                                              ),
                                              onPressed: _openFullScreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              if (_isInitialized) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                                  child: Column(
                                    children: [
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: purpleNormalColor,
                                          inactiveTrackColor: const Color(0xFFE9D5FF),
                                          thumbColor: purpleNormalColor,
                                          trackHeight: 4.0,
                                          thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                          ),
                                          overlayShape: const RoundSliderOverlayShape(
                                            overlayRadius: 12,
                                          ),
                                        ),
                                        child: Slider(
                                          value: position.inMilliseconds
                                              .toDouble()
                                              .clamp(0.0, duration.inMilliseconds.toDouble()),
                                          max: duration.inMilliseconds.toDouble() > 0
                                              ? duration.inMilliseconds.toDouble()
                                              : 1.0,
                                          onChanged: (value) {
                                            _controller.seekTo(
                                              Duration(milliseconds: value.toInt()),
                                            );
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDuration(position),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              _formatDuration(duration),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                                child: Row(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: _isInitialized ? Colors.greenAccent.shade700 : Colors.amber,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.greenAccent.withOpacity(0.5),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: List.generate(
                                            3,
                                            (index) => Container(
                                              margin: const EdgeInsets.symmetric(vertical: 1.5),
                                              width: 24,
                                              height: 2.5,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD8B4FE),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const Spacer(),

                                    IconButton(
                                      onPressed: _rewind5Seconds,
                                      icon: Icon(
                                        Icons.replay_5_rounded,
                                        size: 34,
                                        color: _isRewinding
                                            ? const Color(0xFFFF9800)
                                            : purpleNormalColor,
                                      ),
                                    ),

                                    GestureDetector(
                                      onTap: () {
                                        if (_isInitialized) {
                                          _controller.value.isPlaying
                                              ? _controller.pause()
                                              : _controller.play();
                                        }
                                      },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF5B21B6),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: const BoxDecoration(
                                            color: purpleNormalColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _controller.value.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 32,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),

                                    IconButton(
                                      onPressed: _forward5Seconds,
                                      icon: Icon(
                                        Icons.forward_5_rounded,
                                        size: 34,
                                        color: _isForwarding
                                            ? const Color(0xFFFF9800)
                                            : purpleNormalColor,
                                      ),
                                    ),

                                    const Spacer(),

                                    Column(
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE9D5FF),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: purpleNormalColor, width: 2),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE9D5FF),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: purpleNormalColor, width: 2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 46),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Transform.rotate(
                              angle: 0.35,
                              child: Container(
                                width: 14,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: tvFrameBevel,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: -0.35,
                              child: Container(
                                width: 14,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: tvFrameBevel,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ================= END TV DESIGN =================

                      const SizedBox(height: 16),

                      // ================= กล่องประโยคภาษาอังกฤษ 3D Card =================
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B21B6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.only(bottom: 4.5),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: purpleNormalColor, width: 2.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // แถบความคืบหน้าประโยค โทนสีเหลืองทอง คมชัด ไม่มีเงาฟุ้ง
                              Row(
                                children: [
                                  Text(
                                    'ประโยคที่ ${currentStoryIndex + 1} จาก ${storySteps.length}',
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color.fromARGB(255, 218, 156, 0),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(storySteps.length, (stepIndex) {
                                      final bool isCurrent = stepIndex == currentStoryIndex;
                                      final bool isPassed = stepIndex < currentStoryIndex;

                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: isCurrent ? 38 : 12,
                                        height: 13,
                                        decoration: BoxDecoration(
                                          color: (isCurrent || isPassed)
                                              ? const Color(0xFFFFB703)
                                              : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              Divider(height: 1, color: Colors.purple.shade50, thickness: 1.2),
                              const SizedBox(height: 14),

                              // เนื้อหาประโยคภาษาอังกฤษ
                              spokenWords.isEmpty
                                  ? Text(
                                      currentStory['en']!,
                                      style: const TextStyle(
                                        fontSize: 18.5,
                                        height: 1.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: spokenWords.map((item) {
                                        return GestureDetector(
                                          onTap: () {
                                            if (!item['isCorrect']) {
                                              _speakSingleWord(item['word']);
                                            }
                                          },
                                          child: Text(
                                            "${item['word']} ",
                                            style: TextStyle(
                                              fontSize: 18.5,
                                              height: 1.5,
                                              fontWeight: FontWeight.w800,
                                              color: item['isCorrect']
                                                  ? Colors.green.shade600
                                                  : Colors.red.shade600,
                                              decoration: !item['isCorrect']
                                                  ? TextDecoration.underline
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),

                              if (_isListening && _lastSpokenWords.isNotEmpty) ...[
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    const Icon(Icons.graphic_eq, size: 18, color: Colors.red),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'ได้ยิน: "$_lastSpokenWords"',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              if (hasEvaluated && !_isListening) ...[
                                const SizedBox(height: 16),
                                if (incorrectWords.isEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            color: Colors.green.shade700, size: 22),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ยอดเยี่ยมมาก! คุณออกเสียงถูกต้องครบทุกคำ 🎉',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.highlight_off_rounded,
                                                color: Colors.red.shade700, size: 20),
                                            const SizedBox(width: 6),
                                            Text(
                                              'คำที่ออกเสียงไม่ชัด (แตะที่คำเพื่อฟังเสียง):',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: incorrectWords.map((word) {
                                            return ActionChip(
                                              avatar: const Icon(
                                                Icons.volume_up,
                                                color: Colors.white,
                                                size: 15,
                                              ),
                                              label: Text(
                                                word,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              backgroundColor: Colors.red.shade600,
                                              onPressed: () => _speakSingleWord(word),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize.shrinkWrap,
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: _toggleListening,
                                            icon: const Icon(Icons.refresh, size: 18),
                                            label: const Text(
                                              'กดตรงนี้เพื่อลองพูดใหม่อีกครั้ง',
                                              style: TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red.shade700,
                                              side: BorderSide(
                                                  color: Colors.red.shade400, width: 1.2),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ================= 3 ปุ่มคำสั่ง =================
                      Row(
                        children: [
                          Expanded(
                            child: _buildAction3DButton(
                              icon: _isPlayingAudio
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              label: _isPlayingAudio ? 'หยุดพูด' : 'ฟังตัวอย่าง',
                              color: _isPlayingAudio
                                  ? orangeActiveColor
                                  : purpleNormalColor,
                              bevelColor: _isPlayingAudio
                                  ? orangeActiveBevel
                                  : const Color.fromRGBO(59, 7, 100, 1),
                              onTap: _speakCurrentSentence,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildAction3DButton(
                              icon: Icons.translate_rounded,
                              label: isTranslated ? 'ซ่อนแปล' : 'แปลภาษา',
                              color: isTranslated
                                  ? orangeActiveColor
                                  : purpleNormalColor,
                              bevelColor: isTranslated
                                  ? orangeActiveBevel
                                  : purpleNormalBevel,
                              onTap: toggleTranslation,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildAction3DButton(
                              icon: _isListening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              label: _isListening ? 'หยุดฟัง' : 'ลองพูดเลย',
                              color: _isListening
                                  ? orangeActiveColor
                                  : purpleNormalColor,
                              bevelColor: _isListening
                                  ? orangeActiveBevel
                                  : purpleNormalBevel,
                              onTap: _toggleListening,
                            ),
                          ),
                        ],
                      ),

                      if (isTranslated) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B4B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: purpleNormalColor, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            currentStory['th']!,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // ปุ่มย้อนกลับ และ ปุ่มอ่านต่อ
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (currentStoryIndex > 0)
                            GestureDetector(
                              onTap: prevStoryStep,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: purpleNormalBevel,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: purpleNormalColor, width: 2.0),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.arrow_back_ios_new_rounded,
                                          size: 15, color: purpleNormalColor),
                                      SizedBox(width: 6),
                                      Text(
                                        'ย้อนกลับ',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: purpleNormalColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(),

                          GestureDetector(
                            onTap: nextStoryStep,
                            child: Container(
                              decoration: BoxDecoration(
                                color: purpleNormalBevel,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: purpleNormalColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentStoryIndex ==
                                              storySteps.length - 1
                                          ? 'จบเรื่อง'
                                          : 'อ่านต่อ (${currentStoryIndex + 1}/${storySteps.length})',
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction3DButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bevelColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bevelColor,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;

  const FullScreenVideoPlayer({Key? key, required this.controller})
      : super(key: key);

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    widget.controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final position = controller.value.position;
    final duration = controller.value.duration;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            if (_showControls) ...[
              Container(color: Colors.black45),
              Positioned(
                top: 20,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit,
                      color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.replay_5_rounded, color: Colors.white),
                    onPressed: () {
                      final target = position - const Duration(seconds: 5);
                      controller.seekTo(
                          target < Duration.zero ? Duration.zero : target);
                    },
                  ),
                  const SizedBox(width: 32),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white24,
                    child: IconButton(
                      iconSize: 48,
                      icon: Icon(
                        controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          controller.value.isPlaying
                              ? controller.pause()
                              : controller.play();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.forward_5_rounded, color: Colors.white),
                    onPressed: () {
                      final target = position + const Duration(seconds: 5);
                      controller.seekTo(target > duration ? duration : target);
                    },
                  ),
                ],
              ),
              Positioned(
                bottom: 20,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF7C3AED),
                        inactiveTrackColor: Colors.white30,
                        thumbColor: const Color(0xFF7C3AED),
                        trackHeight: 4,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: position.inMilliseconds
                            .toDouble()
                            .clamp(0.0, duration.inMilliseconds.toDouble()),
                        max: duration.inMilliseconds.toDouble() > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1.0,
                        onChanged: (value) {
                          controller.seekTo(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style:
                                const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            _formatDuration(duration),
                            style:
                                const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
