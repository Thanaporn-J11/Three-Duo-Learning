import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'translation_history_screen.dart';
import '../../config/api_config.dart';
import '../../services/word_speaker.dart';

// ============================================================
// COLORS & THEME (ฟ้า เขียว ชมพู ม่วง เหลืองอ่อน)
// ============================================================

// ฟ้า
const Color _primaryBlue = Color(0xff3B9EFF);
const Color _primaryBlueDark = Color(0xff1C7ED6);
const Color _primaryBlueLight = Color(0xffEAF4FF);

// เขียวมิ้นต์
const Color _mintGreen = Color(0xff2EC4B6);

// ชมพูพาสเทล
const Color _pastelPink = Color(0xffFF6B8B);
const Color _pastelPinkLight = Color(0xffFFF0F3);

// ม่วงพาสเทล
const Color _softPurple = Color(0xff845EC2);
const Color _softPurpleLight = Color(0xffF3EDF9);

// เหลืองอ่อน
const Color _softYellow = Color(0xffFFD166);
const Color _softYellowLight = Color(0xffFFF9EB);
const Color _softYellowBorder = Color(0xffFFEAA7);

// สีตัวอักษรและเส้นขอบ
const Color _ink = Color(0xff2A324B);
const Color _muted = Color(0xff7A869A);
const Color _line = Color(0xffE9EEF7);
const Color _danger = Color(0xffFF5252);

// ============================================================
// HELPERS
// ============================================================

String _langLabel(String lang) {
  return lang == 'Thai' ? 'ไทย' : 'อังกฤษ';
}

String _langCode(String lang) {
  return lang == 'Thai' ? 'TH' : 'EN';
}

// ============================================================
// TRANSLATE SCREEN
// ============================================================

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AudioPlayer _audioPlayer;
  late final stt.SpeechToText _speech;

  bool _speechAvailable = false;

  /// Longest text a child can translate at once.
  static const int _maxChars = 500;
  static const Duration _netTimeout = Duration(seconds: 10);
  bool _isListening = false;
  bool _isLoading = false;
  bool _hasResult = false;

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Thai';
  String _translatedText = '';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _speech = stt.SpeechToText();
    // The microphone is set up on the first tap of the mic button, so
    // opening this page doesn't ask for microphone permission right away.
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('STT Error: $error');
          if (!mounted) return;
          setState(() {
            _isListening = false;
          });
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (!mounted) return;
            setState(() {
              _isListening = false;
            });

            if (_textController.text.trim().isNotEmpty &&
                !_hasResult &&
                !_isLoading) {
              _translate();
            }
          }
        },
      );
    } catch (e) {
      debugPrint('STT Init Error: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    if (_speechAvailable) _speech.stop();
    super.dispose();
  }

  Future<void> _translate() async {
    final input = _textController.text.trim();
    if (input.isEmpty || _isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasResult = false;
    });

    final sl = _sourceLanguage == 'English' ? 'en' : 'th';
    final tl = _targetLanguage == 'Thai' ? 'th' : 'en';

    String? result;
    try {
      result = await _translateWithGoogle(input, sl, tl);
    } catch (e) {
      debugPrint('Google translate error: $e');
    }
    if (result == null) {
      try {
        result = await _translateWithMyMemory(input, sl, tl);
      } catch (e) {
        debugPrint('MyMemory translate error: $e');
      }
    }

    if (!mounted) return;
    if (result == null) {
      // Previously the original text was shown (and saved to history) as if
      // it were the translation. Now the child is told it didn't work.
      setState(() => _isLoading = false);
      _showSnack('แปลไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่อีกครั้งนะ');
      return;
    }
    await _showTranslationResult(result);
  }

  /// Returns null when there's no usable translation.
  Future<String?> _translateWithGoogle(String input, String sl, String tl) async {
    final googleUrl = Uri.parse(
      'https://translate.googleapis.com/translate_a/single'
      '?client=gtx'
      '&sl=$sl'
      '&tl=$tl'
      '&dt=t'
      '&q=${Uri.encodeComponent(input)}',
    );
    final response = await http
        .get(
          googleUrl,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 '
                '(KHTML, like Gecko) '
                'Chrome/110.0.0.0 Safari/537.36',
          },
        )
        .timeout(_netTimeout);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final buffer = StringBuffer();
    if (data is List && data.isNotEmpty && data[0] is List) {
      for (final item in data[0]) {
        if (item is List && item.isNotEmpty && item[0] != null) {
          buffer.write(item[0].toString());
        }
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  /// Backup translator. It sometimes answers with a warning (daily quota
  /// used up, text too long) instead of a translation: treat that as failed.
  Future<String?> _translateWithMyMemory(String input, String sl, String tl) async {
    final fallbackUrl = Uri.parse(
      'https://api.mymemory.translated.net/get'
      '?q=${Uri.encodeComponent(input)}'
      '&langpair=$sl|$tl',
    );
    final response = await http.get(fallbackUrl).timeout(_netTimeout);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) return null;
    if (data['responseStatus']?.toString() != '200') return null;
    final responseData = data['responseData'];
    final translated =
        responseData is Map ? responseData['translatedText']?.toString().trim() : null;
    if (translated == null || translated.isEmpty) return null;
    final upper = translated.toUpperCase();
    if (upper.contains('MYMEMORY WARNING') ||
        upper.contains('QUERY LENGTH LIMIT') ||
        upper.contains('INVALID LANGUAGE PAIR') ||
        upper.contains('PLEASE SELECT TWO DISTINCT LANGUAGES')) {
      return null;
    }
    return translated;
  }

  Future<void> _showTranslationResult(String result) async {
    if (!mounted) return;
    setState(() {
      _translatedText = result;
      _hasResult = true;
      _isLoading = false;
    });
    await _saveTranslationHistory(result);
  }

  Future<void> _saveTranslationHistory(String translatedText) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.api}/translation-history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'sourceLanguage': _sourceLanguage,
          'targetLanguage': _targetLanguage,
          'sourceText': _textController.text.trim(),
          'translatedText': translatedText,
        }),
      ).timeout(_netTimeout);

      if (response.statusCode == 201) {
        debugPrint('Translation history saved');
      }
    } catch (e) {
      debugPrint('Save history error: $e');
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TranslationHistoryScreen()),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      setState(() {
        _isListening = false;
      });
      await _speech.stop();
      if (_textController.text.trim().isNotEmpty) {
        await _translate();
      }
      return;
    }

    if (!_speechAvailable) {
      // First tap asks for microphone permission; later taps retry in case
      // it was allowed in the phone's Settings meanwhile.
      await _initSpeech();
    }
    if (!mounted) return;

    if (!_speechAvailable) {
      _showSnack('ใช้ไมโครโฟนไม่ได้ ลองอนุญาตไมโครโฟนให้แอปในการตั้งค่าเครื่องนะ');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isListening = true;
      _hasResult = false;
      _translatedText = '';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            final words = result.recognizedWords;
            _textController.text =
                words.length > _maxChars ? words.substring(0, _maxChars) : words;
            _textController.selection = TextSelection.collapsed(
              offset: _textController.text.length,
            );
          });
        },
        localeId: _sourceLanguage == 'Thai' ? 'th_TH' : 'en_US',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('STT Listen Error: $e');
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
    }
  }

  void _swapLanguages() {
    setState(() {
      final tempLanguage = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = tempLanguage;

      if (_hasResult) {
        final tempText = _textController.text;
        _textController.text = _translatedText;
        _translatedText = tempText;
      }
    });
  }

  Future<void> _pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    final clipped = text.length > _maxChars ? text.substring(0, _maxChars) : text;
    if (clipped.length < text.length) {
      _showSnack('ข้อความยาวเกินไป ตัดให้เหลือ $_maxChars ตัวอักษรนะ');
    }

    setState(() {
      _textController.text = clipped;
      _textController.selection = TextSelection.collapsed(offset: clipped.length);
      _hasResult = false;
    });
  }

  void _clearText() {
    setState(() {
      _textController.clear();
      _translatedText = '';
      _hasResult = false;
      _isLoading = false;
    });
    _focusNode.requestFocus();
  }

  void _useSuggestion(String text) {
    setState(() {
      _textController.text = text;
      _textController.selection = TextSelection.collapsed(offset: text.length);
    });
    _translate();
  }

  void _startNewTranslation() {
    setState(() {
      _hasResult = false;
      _isLoading = false;
      _translatedText = '';
      _textController.clear();
      _isListening = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _speak(String text, String lang) async {
    if (text.trim().isEmpty) return;
    final langCode = lang == 'Thai' ? 'th' : 'en';
    try {
      final audioUrl =
          'https://translate.google.com/translate_tts'
          '?ie=UTF-8'
          '&client=tw-ob'
          '&tl=$langCode'
          '&q=${Uri.encodeComponent(text)}';

      await _audioPlayer.stop();
      await WordSpeaker.stop();
      await _audioPlayer
          .play(UrlSource(audioUrl))
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      // Online voice unavailable: use the phone's own voice.
      debugPrint('Audio Error: $e');
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      await WordSpeaker.speak(
        text,
        language: langCode == 'th' ? 'th-TH' : 'en-US',
      );
    }
  }

  void _copyToClipboard(String text) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('คัดลอกข้อความแล้ว');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        // พื้นหลังไล่เฉดสีอ่อนเป็นฐาน
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xffF2F8FF),
              Color(0xffF5FCF9),
              Color(0xffFFF5F8),
            ],
          ),
        ),
        child: Stack(
          children: [
            // ========================================================
            // วงกลมสีพาสเทลตกแต่งพื้นหลัง (ฟ้า ชมพู เขียว ม่วง เหลืองอ่อน)
            // ========================================================
            
            // 1. วงกลมสีฟ้าพาสเทล (มุมบนขวา)
            Positioned(
              top: -40,
              right: -50,
              child: _buildBlurBubble(
                size: 190,
                color: const Color(0xff3B9EFF).withValues(alpha: 0.18),
              ),
            ),

            // 2. วงกลมสีเหลืองอ่อน (ฝั่งซ้ายช่วงบน ใต้ช่องกรอกข้อความ)
            Positioned(
              top: 180,
              left: -40,
              child: _buildBlurBubble(
                size: 140,
                color: const Color(0xffFFD166).withValues(alpha: 0.22),
              ),
            ),

            // 3. วงกลมสีม่วงพาสเทล (ฝั่งขวาช่วงกลาง)
            Positioned(
              top: 360,
              right: -30,
              child: _buildBlurBubble(
                size: 130,
                color: const Color(0xff845EC2).withValues(alpha: 0.15),
              ),
            ),

            // 4. วงกลมสีเขียวมิ้นต์ (ฝั่งซ้ายช่วงล่าง)
            Positioned(
              bottom: 160,
              left: -35,
              child: _buildBlurBubble(
                size: 160,
                color: const Color(0xff2EC4B6).withValues(alpha: 0.18),
              ),
            ),

            // 5. วงกลมสีชมพูหวานละมุน (มุมล่างขวา ใกล้รูปแก๊งเพื่อน)
            Positioned(
              bottom: 80,
              right: -40,
              child: _buildBlurBubble(
                size: 170,
                color: const Color(0xffFF6B8B).withValues(alpha: 0.16),
              ),
            ),

            // ========================================================
            // เนื้อหาหลักของหน้า (Header + การ์ดข้อความ + รูปภาพ + ปุ่มล่าง)
            // ========================================================
            Column(
              children: [
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                            child: Column(
                              children: [
                                if (!keyboardOpen && !_hasResult) _buildHero(),
                                _buildLanguageSelector(),
                                const SizedBox(height: 12),
                                _hasResult
                                    ? _buildResultSection()
                                    : _buildInputSection(),
                                if (!_hasResult &&
                                    !_isListening &&
                                    _textController.text.trim().isEmpty) ...[
                                  _buildSuggestions(),
                                  _buildTipCard(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (!keyboardOpen)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                      border: const Border(
                        top: BorderSide(color: _line, width: 1.2),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: _buildBottomAction(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Container(
      height: 60,
      width: double.infinity,
      color: _primaryBlue,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const Text(
            'แปลภาษา',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Positioned(
            right: 4,
            child: IconButton(
              onPressed: _openHistory,
              icon: const Icon(
                Icons.history_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HERO
  // ==========================================================

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'แปลได้ง่าย ๆ',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'พิมพ์หรือพูด แล้วแปลได้ทันที',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            height: 85,
            child: Image.asset(
              'assets/images/character/translate.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.translate_rounded,
                size: 52,
                color: _primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LANGUAGE SELECTOR
  // ==========================================================

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _LanguagePill(
              language: _sourceLanguage,
              active: true,
              badgeColor: _mintGreen,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _swapLanguages,
                child: Ink(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryBlue,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _LanguagePill(
              language: _targetLanguage,
              active: false,
              badgeColor: _primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // INPUT SECTION
  // ==========================================================

  Widget _buildInputSection() {
    final text = _textController.text.trim();
    final hasText = text.isNotEmpty;

    return _MainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LanguageBadge(
                code: _langCode(_sourceLanguage),
                color: _mintGreen,
              ),
              const SizedBox(width: 8),
              Text(
                '${_langLabel(_sourceLanguage)} · ต้นทาง',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const Spacer(),
              if (hasText)
                _CircleIconButton(
                  icon: Icons.close_rounded,
                  onTap: _clearText,
                  bgColor: _pastelPinkLight,
                  iconColor: _pastelPink,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            minLines: 4,
            maxLines: 7,
            inputFormatters: [LengthLimitingTextInputFormatter(_maxChars)],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontSize: 18,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: _ink,
            ),
            decoration: const InputDecoration(
              hintText: 'พิมพ์ข้อความที่ต้องการแปล',
              hintStyle: TextStyle(
                fontSize: 16,
                color: Color(0xffBDC6D8),
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _translate(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${_textController.text.length} ตัวอักษร',
                style: const TextStyle(fontSize: 11.5, color: _muted),
              ),
              const Spacer(),
              _CircleIconButton(
                icon: Icons.content_paste_rounded,
                onTap: _pasteText,
                bgColor: _primaryBlueLight,
                iconColor: _primaryBlue,
              ),
              const SizedBox(width: 6),
              _CircleIconButton(
                icon: Icons.volume_up_rounded,
                onTap:
                    hasText
                        ? () => _speak(_textController.text, _sourceLanguage)
                        : null,
                bgColor: _primaryBlueLight,
                iconColor: _primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PrimaryButton(
            label: _isLoading ? 'กำลังแปล...' : 'แปลข้อความ',
            color: _pastelPink,
            icon:
                _isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.arrow_forward_rounded,
            onTap: hasText && !_isLoading ? _translate : null,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SUGGESTIONS
  // ==========================================================

  Widget _buildSuggestions() {
    final suggestions =
        _sourceLanguage == 'Thai'
            ? const ['สวัสดี', 'ขอบคุณ', 'อรุณสวัสดิ์', 'ราคาเท่าไหร่?']
            : const ['Hello', 'Thank you', 'Good morning', 'How much is it?'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _softPurpleLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _softPurple,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ประโยคแนะนำ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: suggestions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 5.2,
            ),
            itemBuilder: (context, index) {
              final text = suggestions[index];
              return Material(
                color: const Color(0xffF8FAFD),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _useSuggestion(text),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffE5EAF2)),
                    ),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TIP CARD (เคล็ดลับน่ารู้ - โทนเหลืองอ่อนพาสเทล)
  // ==========================================================

  Widget _buildTipCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _softYellowLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softYellowBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'เคล็ดลับน่ารู้',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'แตะปุ่มไมค์ด้านล่าง เพื่อฝึกออกเสียงภาษาและแปลคำพูดได้ทันที !',
                  style: TextStyle(
                    fontSize: 12,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            height: 52,
            child: Image.asset(
              'assets/images/character/tip.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.lightbulb_rounded,
                color: _softYellow,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RESULT SECTION
  // ==========================================================

  Widget _buildResultSection() {
    return Column(
      children: [
        _TranslationCard(
          language: _sourceLanguage,
          text: _textController.text,
          highlighted: false,
          badgeColor: _mintGreen,
          onSpeak: () => _speak(_textController.text, _sourceLanguage),
          onCopy: () => _copyToClipboard(_textController.text),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_downward_rounded,
              color: _primaryBlue,
              size: 20,
            ),
          ),
        ),
        _TranslationCard(
          language: _targetLanguage,
          text: _translatedText,
          highlighted: true,
          badgeColor: _primaryBlue,
          loading: _isLoading,
          onSpeak: () => _speak(_translatedText, _targetLanguage),
          onCopy: () => _copyToClipboard(_translatedText),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Center(
            child: Image.asset(
              'assets/images/character/friend_2.png',
              width: MediaQuery.of(context).size.width * 0.9,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // BOTTOM ACTION
  // ==========================================================

  Widget _buildBottomAction() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child:
          _hasResult
              ? _PrimaryButton(
                label: 'แปลใหม่',
                icon: Icons.add_rounded,
                color: _pastelPink,
                onTap: _startNewTranslation,
              )
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleListening,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? _danger : _primaryBlue,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? _danger : _primaryBlue)
                                .withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isListening ? 'กำลังฟัง... แตะเพื่อหยุด' : 'แตะเพื่อพูด',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _isListening ? _danger : _muted,
                    ),
                  ),
                ],
              ),
    );
  }
}

// ============================================================
// LANGUAGE PILL
// ============================================================

class _LanguagePill extends StatelessWidget {
  final String language;
  final bool active;
  final Color badgeColor;

  const _LanguagePill({
    required this.language,
    required this.active,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: active ? _primaryBlueLight : const Color(0xffF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? _primaryBlue.withValues(alpha: 0.35) : _line,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LanguageBadge(code: _langCode(language), color: badgeColor),
          const SizedBox(width: 8),
          Text(
            _langLabel(language),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LANGUAGE BADGE
// ============================================================

class _LanguageBadge extends StatelessWidget {
  final String code;
  final Color color;

  const _LanguageBadge({required this.code, this.color = _primaryBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================================================
// MAIN CARD
// ============================================================

class _MainCard extends StatelessWidget {
  final Widget child;

  const _MainCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================
// TRANSLATION CARD
// ============================================================

class _TranslationCard extends StatelessWidget {
  final String language;
  final String text;
  final bool highlighted;
  final bool loading;
  final Color badgeColor;
  final VoidCallback onSpeak;
  final VoidCallback onCopy;

  const _TranslationCard({
    required this.language,
    required this.text,
    required this.highlighted,
    required this.onSpeak,
    required this.onCopy,
    this.badgeColor = _primaryBlue,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 135),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? _primaryBlueLight : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? _primaryBlue : _line,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LanguageBadge(code: _langCode(language), color: badgeColor),
                  const SizedBox(width: 9),
                  Text(
                    _langLabel(language),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: highlighted ? _primaryBlueDark : _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
                )
              else
                SelectableText(
                  text,
                  style: TextStyle(
                    fontSize: highlighted ? 22 : 18,
                    height: 1.35,
                    fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                    color: highlighted ? _primaryBlueDark : _ink,
                  ),
                ),
            ],
          ),
          if (!loading) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _CircleIconButton(
                  icon: Icons.volume_up_rounded,
                  onTap: onSpeak,
                  bgColor: highlighted ? Colors.white : _primaryBlueLight,
                  iconColor: _primaryBlueDark,
                ),
                const SizedBox(width: 8),
                _CircleIconButton(
                  icon: Icons.copy_rounded,
                  onTap: onCopy,
                  bgColor: highlighted ? Colors.white : _primaryBlueLight,
                  iconColor: _primaryBlueDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// CIRCLE ICON BUTTON
// ============================================================

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color bgColor;
  final Color iconColor;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.bgColor = _primaryBlueLight,
    this.iconColor = _primaryBlueDark,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 17, color: iconColor),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRIMARY BUTTON
// ============================================================

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = _primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HELPER: ฟองสีฟุ้งพื้นหลัง
// ============================================================

Widget _buildBlurBubble({required double size, required Color color}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(
          color: color,
          blurRadius: 40,
          spreadRadius: 10,
        ),
      ],
    ),
  );
}