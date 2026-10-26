import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/coin_balance.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/avatar_api_service.dart';
import '../services/profile_api_service.dart';
import '../services/rewards_api_service.dart';
import '../services/user_account_preferences.dart';
import 'home_screen.dart';
import 'checkin_screen.dart';
import 'edit_profile_screen.dart';
import 'setting_screen.dart';
import 'avatar_art.dart';
export 'avatar_art.dart';

final RouteObserver<ModalRoute<dynamic>> profileRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();


// ============================================================
// CUSTOM PAINTERS
// ============================================================

class AvatarPainter extends CustomPainter {
  final String gender;
  final Color skinColor;
  final int hairStyle;
  final Color hairColor;
  final OutfitItem outfit;
  final int glassesStyle;
  final int hatStyle;
  final int clipStyle;
  final int earringStyle;
  final int neckStyle;
  final int extraStyle;

  AvatarPainter({
    required this.gender,
    required this.skinColor,
    required this.hairStyle,
    required this.hairColor,
    required this.outfit,
    required this.glassesStyle,
    required this.hatStyle,
    this.clipStyle = 0,
    this.earringStyle = 0,
    this.neckStyle = 0,
    this.extraStyle = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    final double clipY = AvatarArt.hatHairClip(hatStyle);

    // Hair is trimmed under hats that cover it, so buns/spikes never poke through.
    void hair(bool back) {
      canvas.save();
      if (clipY > 0) {
        canvas.clipRect(
          Rect.fromLTRB(
            r.left - r.width,
            r.top + clipY * r.height,
            r.right + r.width,
            r.bottom + r.height,
          ),
        );
      }
      if (back) {
        AvatarArt.drawHairBack(canvas, r, hairStyle, hairColor, gender);
      } else {
        AvatarArt.drawHairFront(canvas, r, hairStyle, hairColor, gender);
      }
      canvas.restore();
    }

    hair(true);
    AvatarArt.drawBodyAndOutfit(canvas, r, skinColor, hairColor, outfit);
    AvatarArt.drawNeckItem(canvas, r, neckStyle, skinColor, hairColor);
    AvatarArt.drawHead(canvas, r, skinColor, hairColor);
    AvatarArt.drawFace(canvas, r, gender, skinColor, hairColor);
    hair(false);
    AvatarArt.drawGlasses(canvas, r, glassesStyle, skinColor, hairColor);
    AvatarArt.drawEarrings(canvas, r, earringStyle, skinColor, hairColor);
    AvatarArt.drawHairClip(canvas, r, clipStyle, skinColor, hairColor);
    AvatarArt.drawFaceExtra(canvas, r, extraStyle, skinColor, hairColor);
    AvatarArt.drawHat(canvas, r, hatStyle, skinColor, hairColor);
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) => true;
}

class HairThumbPainter extends CustomPainter {
  final int hairId;
  final Color color;
  final Color skin;
  final String gender;

  HairThumbPainter(this.hairId, this.color, this.skin, this.gender);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    AvatarArt.drawHairBack(canvas, r, hairId, color, gender);
    AvatarArt.drawHead(canvas, r, skin, color);
    AvatarArt.drawFace(canvas, r, gender, skin, color);
    AvatarArt.drawHairFront(canvas, r, hairId, color, gender);
  }

  @override
  bool shouldRepaint(covariant HairThumbPainter old) => true;
}

class AvatarProfile extends ChangeNotifier {
  AvatarProfile._internal() {
    UserAccountPreferences.registerMemoryResetter(resetInMemory);
  }
  static final AvatarProfile instance = AvatarProfile._internal();

  String gender = 'female';
  int skinIndex = 3;
  int hairStyle = 0;
  int hairColorIndex = 3;
  int outfitIndex = 0;
  int glasses = 0;
  int hat = 0;
  int clip = 0;
  int earring = 0;
  int neck = 0;
  int extra = 0;

  bool _loaded = false;
  String? _userId;
  bool get isLoaded => _loaded;

  // Server sync. The server (GET/PUT /api/profile/avatar) is the source of
  // truth; SharedPreferences is only a cache so the avatar shows instantly and
  // survives being offline. Unsent local changes are marked "pending" and
  // uploaded on the next load.
  static const String _kPendingSync = 'avatar_pending_server_sync';
  bool _serverSynced = false;
  Future<void>? _syncing;
  Timer? _uploadTimer;
  int _changeVersion = 0; // bumped on every local change

  static const String _kGender = 'avatar_gender';
  static const String _kSkin = 'avatar_skin_index';
  static const String _kHairStyle = 'avatar_hair_style';
  static const String _kHairColor = 'avatar_hair_color_index';
  static const String _kOutfit = 'avatar_outfit_index';
  static const String _kGlasses = 'avatar_glasses';
  static const String _kHat = 'avatar_hat';
  static const String _kClip = 'avatar_clip';
  static const String _kEarring = 'avatar_earring';
  static const String _kNeck = 'avatar_neck';
  static const String _kExtra = 'avatar_extra';

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? userId = await UserAccountPreferences.currentUserId();
      if (userId != _userId) {
        _userId = userId;
        _resetValues();
        _loaded = false;
        _serverSynced = false;
        _uploadTimer?.cancel();
        _changeVersion++;
        notifyListeners();
      }
      if (_loaded) {
        if (!_serverSynced) unawaited(_syncWithServer());
        return;
      }
      if (userId == null) {
        _loaded = true;
        notifyListeners();
        return;
      }

      final bool isLegacyOwner = await UserAccountPreferences.claimLegacyData(
        'avatar_legacy_profile_owner_user_id',
        userId,
      );
      if (userId != await UserAccountPreferences.currentUserId()) return;
      String key(String base) => UserAccountPreferences.keyFor(base, userId);
      String? readString(String base) =>
          prefs.getString(key(base)) ??
          (isLegacyOwner ? prefs.getString(base) : null);
      int? readInt(String base) =>
          prefs.getInt(key(base)) ??
          (isLegacyOwner ? prefs.getInt(base) : null);
      gender = readString(_kGender) ?? gender;
      skinIndex = readInt(_kSkin) ?? skinIndex;
      hairStyle = readInt(_kHairStyle) ?? hairStyle;
      hairColorIndex = readInt(_kHairColor) ?? hairColorIndex;
      outfitIndex = readInt(_kOutfit) ?? outfitIndex;
      glasses = readInt(_kGlasses) ?? glasses;
      hat = readInt(_kHat) ?? hat;
      clip = readInt(_kClip) ?? clip;
      earring = readInt(_kEarring) ?? earring;
      neck = readInt(_kNeck) ?? neck;
      extra = readInt(_kExtra) ?? extra;
      // Materialize the one-account migration in scoped keys; leave old keys intact.
      if (isLegacyOwner) await _saveForUser(prefs, userId);
    } catch (_) {}
    _loaded = true;
    notifyListeners();
    if (_userId != null) unawaited(_syncWithServer());
  }

  AvatarData _snapshot() => AvatarData(
    gender: gender,
    skinIndex: skinIndex,
    hairStyle: hairStyle,
    hairColorIndex: hairColorIndex,
    outfitIndex: outfitIndex,
    glasses: glasses,
    hat: hat,
    clip: clip,
    earring: earring,
    neck: neck,
    extra: extra,
  );

  void _apply(AvatarData d) {
    gender = d.gender;
    skinIndex = d.skinIndex;
    hairStyle = d.hairStyle;
    hairColorIndex = d.hairColorIndex;
    outfitIndex = d.outfitIndex;
    glasses = d.glasses;
    hat = d.hat;
    clip = d.clip;
    earring = d.earring;
    neck = d.neck;
    extra = d.extra;
  }

  /// Puts the free item back on every field the server says isn't owned.
  void _resetFields(List<String> fields) {
    for (final String field in fields) {
      switch (field) {
        case 'outfitIndex':
          outfitIndex = 0;
        case 'glasses':
          glasses = 0;
        case 'hat':
          hat = 0;
        case 'clip':
          clip = 0;
        case 'earring':
          earring = 0;
        case 'neck':
          neck = 0;
        case 'extra':
          extra = 0;
      }
    }
  }

  Future<void> _setPending(String userId, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        UserAccountPreferences.keyFor(_kPendingSync, userId),
        value,
      );
    } catch (_) {}
  }

  Future<void> _syncWithServer() {
    final Future<void>? running = _syncing;
    if (running != null) return running;
    final Future<void> future = _doSync().whenComplete(() => _syncing = null);
    _syncing = future;
    return future;
  }

  Future<void> _doSync() async {
    final String? userId = _userId;
    if (userId == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool pending =
          prefs.getBool(UserAccountPreferences.keyFor(_kPendingSync, userId)) ??
          false;
      if (!pending) {
        final int versionBefore = _changeVersion;
        final AvatarData? remote = await AvatarApiService.getAvatar();
        if (userId != _userId) return;
        if (remote != null) {
          // Don't overwrite a change the user made while we were loading.
          if (versionBefore == _changeVersion) {
            _apply(remote);
            notifyListeners();
            await _saveForUser(prefs, userId);
          }
          _serverSynced = true;
          return;
        }
      }
      // Nothing on the server yet (first sync, e.g. an avatar made before the
      // server stored avatars) or unsent local changes: upload the local avatar.
      await _upload();
    } catch (_) {
      // Offline or server down: keep the cached avatar, retry on next load.
    }
  }

  Future<void> _upload({bool retried = false}) async {
    final String? userId = _userId;
    if (userId == null) return;
    final int version = _changeVersion;
    try {
      await AvatarApiService.saveAvatar(_snapshot());
      if (userId != _userId) return;
      _serverSynced = true;
      if (version == _changeVersion) await _setPending(userId, false);
    } on AvatarApiException catch (e) {
      if (userId != _userId) return;
      if (e.code == 'AVATAR_ITEM_NOT_OWNED' &&
          !retried &&
          version == _changeVersion) {
        // Wearing something the server has no purchase for (e.g. unlocked by
        // the old on-device wallet): switch those slots back to the free item.
        _resetFields(e.fields);
        _changeVersion++;
        notifyListeners();
        await _save();
        await _upload(retried: true);
        return;
      }
      final String code = e.code ?? '';
      if (code.startsWith('INVALID_AVATAR') ||
          code.startsWith('MISSING_AVATAR') ||
          code.startsWith('UNSUPPORTED_AVATAR')) {
        // The server will never accept this data; stop retrying it.
        await _setPending(userId, false);
      }
      // Other errors (offline, timeout, signed out): stay pending, retry later.
    } catch (_) {}
  }

  void _resetValues() {
    gender = 'female';
    skinIndex = 3;
    hairStyle = 0;
    hairColorIndex = 3;
    outfitIndex = 0;
    glasses = hat = clip = earring = neck = extra = 0;
  }

  void resetInMemory() {
    _userId = null;
    _loaded = false;
    _serverSynced = false;
    _uploadTimer?.cancel();
    _changeVersion++;
    _resetValues();
    notifyListeners();
  }

  Future<void> _saveForUser(SharedPreferences prefs, String userId) async {
    final String savedGender = gender;
    final int savedSkinIndex = skinIndex;
    final int savedHairStyle = hairStyle;
    final int savedHairColorIndex = hairColorIndex;
    final int savedOutfitIndex = outfitIndex;
    final int savedGlasses = glasses;
    final int savedHat = hat;
    final int savedClip = clip;
    final int savedEarring = earring;
    final int savedNeck = neck;
    final int savedExtra = extra;
    String key(String base) => UserAccountPreferences.keyFor(base, userId);
    await prefs.setString(key(_kGender), savedGender);
    await prefs.setInt(key(_kSkin), savedSkinIndex);
    await prefs.setInt(key(_kHairStyle), savedHairStyle);
    await prefs.setInt(key(_kHairColor), savedHairColorIndex);
    await prefs.setInt(key(_kOutfit), savedOutfitIndex);
    await prefs.setInt(key(_kGlasses), savedGlasses);
    await prefs.setInt(key(_kHat), savedHat);
    await prefs.setInt(key(_kClip), savedClip);
    await prefs.setInt(key(_kEarring), savedEarring);
    await prefs.setInt(key(_kNeck), savedNeck);
    await prefs.setInt(key(_kExtra), savedExtra);
  }

  Future<void> _save() async {
    final String? userId = _userId;
    if (userId == null) return;
    final String savedGender = gender;
    final int savedSkinIndex = skinIndex;
    final int savedHairStyle = hairStyle;
    final int savedHairColorIndex = hairColorIndex;
    final int savedOutfitIndex = outfitIndex;
    final int savedGlasses = glasses;
    final int savedHat = hat;
    final int savedClip = clip;
    final int savedEarring = earring;
    final int savedNeck = neck;
    final int savedExtra = extra;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String key(String base) => UserAccountPreferences.keyFor(base, userId);
      await prefs.setString(key(_kGender), savedGender);
      await prefs.setInt(key(_kSkin), savedSkinIndex);
      await prefs.setInt(key(_kHairStyle), savedHairStyle);
      await prefs.setInt(key(_kHairColor), savedHairColorIndex);
      await prefs.setInt(key(_kOutfit), savedOutfitIndex);
      await prefs.setInt(key(_kGlasses), savedGlasses);
      await prefs.setInt(key(_kHat), savedHat);
      await prefs.setInt(key(_kClip), savedClip);
      await prefs.setInt(key(_kEarring), savedEarring);
      await prefs.setInt(key(_kNeck), savedNeck);
      await prefs.setInt(key(_kExtra), savedExtra);
    } catch (_) {}
  }

  void update({
    String? gender,
    int? skinIndex,
    int? hairStyle,
    int? hairColorIndex,
    int? outfitIndex,
    int? glasses,
    int? hat,
    int? clip,
    int? earring,
    int? neck,
    int? extra,
  }) {
    if (gender != null) this.gender = gender;
    if (skinIndex != null) this.skinIndex = skinIndex;
    if (hairStyle != null) this.hairStyle = hairStyle;
    if (hairColorIndex != null) this.hairColorIndex = hairColorIndex;
    if (outfitIndex != null) this.outfitIndex = outfitIndex;
    if (glasses != null) this.glasses = glasses;
    if (hat != null) this.hat = hat;
    if (clip != null) this.clip = clip;
    if (earring != null) this.earring = earring;
    if (neck != null) this.neck = neck;
    if (extra != null) this.extra = extra;
    _changeVersion++;
    notifyListeners();
    _saveAndQueueUpload(); // fire-and-forget: don't block the UI on I/O
  }

  Future<void> _saveAndQueueUpload() async {
    final String? userId = _userId;
    if (userId == null) return;
    await _save();
    await _setPending(userId, true);
    if (userId != _userId) return;
    // Taps come in bursts while dressing up; send one request after they stop.
    _uploadTimer?.cancel();
    _uploadTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_upload());
    });
  }
}

// ============================================================
// COIN WALLET + SHOP CATALOG
// เหรียญที่ได้จากการเล่นเกมในแอป (เก็บใน SharedPreferences key 'coins'
// ซึ่งเป็น key เดียวกับที่เกม Bridge Builder ใช้) ถูกนำมาแลกปลดล็อก
// ชุดและอุปกรณ์ตกแต่งอวตาร ของที่ปลดล็อกแล้วจะถูกจำไว้ถาวร
// ============================================================
class CoinWallet extends ChangeNotifier {
  CoinWallet._internal() {
    UserAccountPreferences.registerMemoryResetter(resetInMemory);
  }
  static final CoinWallet instance = CoinWallet._internal();

  static const String _kCoins = 'coins';
  static const String _kUnlocked = 'avatar_unlocked_items';
  static const String _kMigrated = 'avatar_shop_migrated_v1';

  int coins = 0;
  final Set<String> _unlocked = <String>{};
  bool _loaded = false;
  String? _userId;
  bool get isLoaded => _loaded;

  /// ของฟรี (ราคา 0) ถือว่าเป็นของผู้เล่นเสมอ
  bool owns(String key, int price) => price <= 0 || _unlocked.contains(key);

  Future<void> load({bool force = false}) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      final String? userId = await UserAccountPreferences.currentUserId();
      if (userId != _userId) {
        _userId = userId;
        coins = 0;
        _unlocked.clear();
        _loaded = false;
        notifyListeners();
      }
      if (userId == null) {
        _loaded = true;
        notifyListeners();
        return;
      }
      if (_loaded && !force) return;
      final String coinsKey = UserAccountPreferences.keyFor(_kCoins, userId);
      final String unlockedKey = UserAccountPreferences.keyFor(
        _kUnlocked,
        userId,
      );
      final bool isLegacyOwner = await UserAccountPreferences.claimLegacyData(
        'avatar_legacy_unlocks_owner_user_id',
        userId,
      );
      if (userId != await UserAccountPreferences.currentUserId()) return;
      coins = prefs.getInt(coinsKey) ?? 0; // Old global coins are never merged.
      _unlocked
        ..clear()
        ..addAll(
          prefs.getStringList(unlockedKey) ??
              (isLegacyOwner ? prefs.getStringList(_kUnlocked) : null) ??
              const <String>[],
        );
      if (isLegacyOwner && !prefs.containsKey(unlockedKey)) {
        await prefs.setStringList(unlockedKey, _unlocked.toList());
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  /// อ่านเหรียญล่าสุดจากเครื่อง (เผื่อเพิ่งไปเล่นเกมมา)
  Future<void> refreshCoins() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      final String? userId = await UserAccountPreferences.currentUserId();
      if (userId == null || userId != _userId) {
        await load(force: true);
        return;
      }
      final int latest =
          prefs.getInt(UserAccountPreferences.keyFor(_kCoins, userId)) ?? 0;
      if (latest != coins) {
        coins = latest;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// เกมอื่นในแอปเรียกใช้เพื่อให้เหรียญผู้เล่นได้
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    final String? requestedUserId = _userId;
    await refreshCoins();
    if (requestedUserId == null || requestedUserId != _userId) return;
    coins += amount;
    await _saveCoins();
    notifyListeners();
  }

  /// แลกของ: สำเร็จคืน true / เหรียญไม่พอคืน false
  Future<bool> purchase(String key, int price) async {
    final String? requestedUserId = _userId;
    await refreshCoins();
    if (requestedUserId == null || requestedUserId != _userId) return false;
    if (owns(key, price)) return true;
    if (coins < price) return false;
    coins -= price;
    _unlocked.add(key);
    await _saveCoins();
    await _saveUnlocked();
    notifyListeners();
    return true;
  }

  /// ครั้งแรกที่เปิดระบบร้านค้า: ของที่ผู้เล่นใส่อยู่แล้วให้ถือว่าปลดล็อกแล้ว
  /// (ผู้เล่นเดิมจะไม่เสียชุดที่เคยแต่งไว้)
  Future<void> grantEquippedOnce(AvatarProfile p) async {
    try {
      final String? userId = await UserAccountPreferences.currentUserId();
      if (userId == null || userId != _userId || userId != p._userId) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String migratedKey = UserAccountPreferences.keyFor(
        _kMigrated,
        userId,
      );
      if (prefs.getBool(migratedKey) ?? false) return;
      final bool legacyMigrationWasDone =
          await UserAccountPreferences.claimLegacyData(
            'avatar_legacy_unlocks_owner_user_id',
            userId,
          ) &&
          (prefs.getBool(_kMigrated) ?? false);
      if (legacyMigrationWasDone) {
        await prefs.setBool(migratedKey, true);
        return;
      }
      _unlocked
        ..add(ShopCatalog.outfitKey(p.gender, p.outfitIndex))
        ..add(ShopCatalog.accKey('hat', p.hat))
        ..add(ShopCatalog.accKey('glasses', p.glasses))
        ..add(ShopCatalog.accKey('clip', p.clip))
        ..add(ShopCatalog.accKey('earring', p.earring))
        ..add(ShopCatalog.accKey('neck', p.neck))
        ..add(ShopCatalog.accKey('extra', p.extra));
      await prefs.setBool(migratedKey, true);
      await _saveUnlocked();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveCoins() async {
    final String? userId = _userId;
    final int savedCoins = coins;
    if (userId == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        UserAccountPreferences.keyFor(_kCoins, userId),
        savedCoins,
      );
    } catch (_) {}
  }

  Future<void> _saveUnlocked() async {
    final String? userId = _userId;
    final List<String> savedUnlocked = _unlocked.toList();
    if (userId == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        UserAccountPreferences.keyFor(_kUnlocked, userId),
        savedUnlocked,
      );
    } catch (_) {}
  }

  void resetInMemory() {
    _userId = null;
    _loaded = false;
    coins = 0;
    _unlocked.clear();
    notifyListeners();
  }
}

class ShopCatalog {
  static String outfitKey(String gender, int index) => 'outfit:$gender:$index';
  static String accKey(String type, int id) => '$type:$id';

  // ราคาชุด (ลำดับตรงกับ kMaleOutfits / kFemaleOutfits) ตัวแรกฟรีเสมอ
  static const List<int> _maleOutfitPrices = [
    0,
    150,
    60,
    60,
    100,
    100,
    120,
    150,
    60,
    100,
    120,
    180,
    120,
    150,
    250,
    80,
  ];
  static const List<int> _femaleOutfitPrices = [
    0,
    100,
    60,
    100,
    80,
    120,
    100,
    150,
    100,
    220,
    80,
    120,
    80,
    250,
    150,
    80,
  ];

  static int outfitPrice(String gender, int index) {
    final List<int> table =
        gender == 'male' ? _maleOutfitPrices : _femaleOutfitPrices;
    if (index < 0 || index >= table.length) return 100;
    return table[index];
  }

  static const Map<String, int> _accBase = {
    'hat': 80,
    'glasses': 60,
    'clip': 40,
    'earring': 50,
    'neck': 70,
    'extra': 30,
  };

  // ไอเทมพิเศษที่ราคาสูงกว่าปกติ
  static const Map<String, int> _accOverride = {
    'hat:9': 250, // King Crown
    'hat:19': 250, // Tiara
    'hat:7': 150, // Top Hat
    'hat:14': 120, // Graduation
    'hat:12': 120, // Flower Crown
    'hat:5': 120, // Cowboy
    'hat:10': 100, // Bunny Ears
    'hat:11': 100, // Cat Ears
    'hat:8': 100, // Santa
    'neck:7': 150, // Gold Chain
    'glasses:5': 80, // Heart
    'glasses:7': 80, // Star
  };

  static int accessoryPrice(String type, int id) {
    if (id == 0) return 0;
    return _accOverride[accKey(type, id)] ?? _accBase[type] ?? 50;
  }
}

class _UnlockDialog extends StatefulWidget {
  final String itemKey;
  final int price;
  final String name;
  final int initialBalance;
  final Future<AvatarPurchaseResult> Function(String itemKey) onPurchase;
  final CustomPainter preview;
  final double zoom;
  final double focusY;

  const _UnlockDialog({
    required this.itemKey,
    required this.price,
    required this.name,
    required this.initialBalance,
    required this.onPurchase,
    required this.preview,
    this.zoom = 1.0,
    this.focusY = 0.0,
  });

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  // 0 = ยืนยันการแลก, 1 = เหรียญไม่พอ, 2 = แลกสำเร็จ
  int _phase = 0;
  bool _busy = false;
  int? _balance;
  int? _price;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _balance = widget.initialBalance;
    _price = widget.price;
  }

  Future<void> _buy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.onPurchase(widget.itemKey);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _phase = 2;
        _busy = false;
        _balance = result.balance;
        _price = result.price;
        _errorMessage = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop(true);
    } on RewardsApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.message;
        _balance = error.balance ?? _balance;
        _price = error.price ?? _price;
        _phase = error.code == 'INSUFFICIENT_COINS' ? 1 : 3;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = 'ซื้อไม่สำเร็จ กรุณาลองอีกครั้ง';
        _phase = 3;
      });
    }
  }

  Widget _button(
    String label,
    List<Color> colors,
    Color shadow,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 4))],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int balance = _balance ?? 0;
    final int price = _price ?? widget.price;
    final int missing = (price - balance).clamp(0, 1 << 30).toInt();
    final Color border =
        _phase == 2
            ? const Color(0xFF22C55E)
            : (_phase == 1 ? const Color(0xFFF97316) : const Color(0xFFFFB627));
    final String title =
        _phase == 2
            ? 'ปลดล็อกสำเร็จ !'
            : (_phase == 1 ? 'เหรียญยังไม่พอ' : 'ปลดล็อกไอเทมนี้ ?');

    return PopScope(
      canPop: !_busy && _phase != 2,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: border, width: 5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF26314F),
                ),
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                key: ValueKey<int>(_phase),
                tween: Tween<double>(begin: _phase == 2 ? 0.7 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                builder:
                    (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEAF2FF), Color(0xFFD6E6FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: const Color(0xFFDCE9FF),
                      width: 2.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Transform.scale(
                            scale: widget.zoom,
                            alignment: Alignment(0, widget.focusY),
                            child: CustomPaint(painter: widget.preview),
                          ),
                        ),
                      ),
                      if (_phase == 2)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Text('✨', style: TextStyle(fontSize: 26)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D4FD1),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniStat('ราคา', '$price'),
                  const SizedBox(width: 10),
                  _miniStat('เหรียญของคุณ', '$balance'),
                ],
              ),
              const SizedBox(height: 10),
              if (_phase == 0)
                Text(
                  'ระบบจะตรวจยอดและตัดเหรียญเมื่อ Backend ยืนยันการซื้อ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (_phase == 1)
                Text(
                  _errorMessage ??
                      'ต้องการอีก $missing เหรียญ\nเล่นเกมผ่านด่านเพื่อสะสมเหรียญเพิ่มนะ!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC2410C),
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              if (_phase == 2)
                Text(
                  'ซื้อสำเร็จ เหลือ $balance เหรียญ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (_phase == 3 && _errorMessage != null)
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC2410C),
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 14),
              if (_phase == 0) ...[
                _button(
                  _busy ? 'กำลังแลก...' : 'แลก $price เหรียญ',
                  const [Color(0xFF4ADE80), Color(0xFF22C55E)],
                  const Color(0xFF15803D),
                  _busy ? null : _buy,
                ),
                const SizedBox(height: 10),
                _button(
                  'ไว้ก่อน',
                  const [Color(0xFF94A3B8), Color(0xFF64748B)],
                  const Color(0xFF475569),
                  _busy ? null : () => Navigator.of(context).pop(false),
                ),
              ],
              if (_phase == 1)
                _button(
                  'เข้าใจแล้ว',
                  const [Color(0xFFFFB627), Color(0xFFFF8A3D)],
                  const Color(0xFFE56B1F),
                  () => Navigator.of(context).pop(false),
                ),
              if (_phase == 3) ...[
                _button(
                  'ลองอีกครั้ง',
                  const [Color(0xFF4ADE80), Color(0xFF22C55E)],
                  const Color(0xFF15803D),
                  _busy ? null : _buy,
                ),
                const SizedBox(height: 10),
                _button(
                  'ปิด',
                  const [Color(0xFF94A3B8), Color(0xFF64748B)],
                  const Color(0xFF475569),
                  _busy ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD43B), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFB627),
            size: 18,
          ),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const List<Color> kSkinTones = [
  Color(0xFF8D5524),
  Color(0xFFC68642),
  Color(0xFFE0AC69),
  Color(0xFFF1C27D),
  Color(0xFFFFDBAC),
];

const List<Color> kHairColors = [
  Color(0xFF1C1C1E),
  Color(0xFF3B2417),
  Color(0xFF6F4E37),
  Color(0xFF8B4513),
  Color(0xFFF5DEB3),
  Color(0xFFB0B0B0),
];

// 10 Male Hair Styles
const List<HairItem> kMaleHairStyles = [
  HairItem(name: 'Casual Spiky\nผมตั้งชี้', id: 0, gender: 'male'),
  HairItem(name: 'Two Block\nผมทูบล็อก', id: 1, gender: 'male'),
  HairItem(name: 'Short Cut\nผมสั้น', id: 2, gender: 'male'),
  HairItem(name: 'Undercut\nผมอันเดอร์คัต', id: 3, gender: 'male'),
  HairItem(name: 'Slick Back\nผมเสยเรียบ', id: 4, gender: 'male'),
  HairItem(name: 'Curly Top\nผมหยิกด้านบน', id: 5, gender: 'male'),
  HairItem(name: 'Messy Fringe\nผมหน้าม้ายุ่ง', id: 6, gender: 'male'),
  HairItem(name: 'Buzz Cut\nผมเกรียน', id: 7, gender: 'male'),
  HairItem(name: 'Man Bun\nผมมวยจุก', id: 8, gender: 'male'),
  HairItem(name: 'Side Part\nผมแสกข้าง', id: 9, gender: 'male'),
];

// 10 Female Hair Styles
const List<HairItem> kFemaleHairStyles = [
  HairItem(name: 'Long Straight\nผมยาวตรง', id: 0, gender: 'female'),
  HairItem(name: 'Long Wavy\nผมยาวลอน', id: 1, gender: 'female'),
  HairItem(name: 'Cute Bob\nผมบ็อบ', id: 2, gender: 'female'),
  HairItem(name: 'Twin Tails\nผมมัดสองข้าง', id: 3, gender: 'female'),
  HairItem(name: 'Pixie Cut\nผมสั้นพิกซี่', id: 4, gender: 'female'),
  HairItem(name: 'High Ponytail\nผมหางม้าสูง', id: 5, gender: 'female'),
  HairItem(name: 'Double Buns\nผมมวยคู่', id: 6, gender: 'female'),
  HairItem(name: 'Hime Cut\nผมทรงฮิเมะ', id: 7, gender: 'female'),
  HairItem(name: 'Braided Side\nผมถักเปียข้าง', id: 8, gender: 'female'),
  HairItem(name: 'Half-Up Knot\nผมมวยครึ่งหัว', id: 9, gender: 'female'),
];

// 15 Male Outfits
const List<OutfitItem> kMaleOutfits = [
  OutfitItem(
    name: 'Blue Tee & Jeans\nเสื้อยืดสีฟ้ากับกางเกงยีนส์',
    type: OutfitStyleType.maleCasualTee,
    primaryColor: Color(0xFF2563EB),
    secondaryColor: Color(0xFF1D4ED8),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Suit & Tie\nชุดสูทผูกเนกไท',
    type: OutfitStyleType.maleSuit,
    primaryColor: Color(0xFF1E293B),
    secondaryColor: Colors.white,
    gender: 'male',
  ),
  OutfitItem(
    name: 'Striped T-Shirt\nเสื้อยืดลายทาง',
    type: OutfitStyleType.maleStripedTee,
    primaryColor: Color(0xFF0F172A),
    secondaryColor: Colors.white,
    gender: 'male',
  ),
  OutfitItem(
    name: 'Classic Polo\nเสื้อโปโล',
    type: OutfitStyleType.malePolo,
    primaryColor: Color(0xFF059669),
    secondaryColor: Color(0xFF047857),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Street Hoodie\nเสื้อฮู้ดสตรีท',
    type: OutfitStyleType.maleHoodie,
    primaryColor: Color(0xFF7C3AED),
    secondaryColor: Color(0xFF4C1D95),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Denim Jacket\nแจ็กเก็ตยีนส์',
    type: OutfitStyleType.maleDenimJacket,
    primaryColor: Color(0xFF0284C7),
    secondaryColor: Color(0xFF38BDF8),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Sporty Tracksuit\nชุดวอร์มกีฬา',
    type: OutfitStyleType.maleSporty,
    primaryColor: Color(0xFFDC2626),
    secondaryColor: Colors.white,
    gender: 'male',
  ),
  OutfitItem(
    name: 'Winter Overcoat\nเสื้อโค้ตกันหนาว',
    type: OutfitStyleType.maleOvercoat,
    primaryColor: Color(0xFF78350F),
    secondaryColor: Color(0xFF451A03),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Casual V-Neck\nเสื้อคอวี',
    type: OutfitStyleType.maleVNeck,
    primaryColor: Color(0xFF4B5563),
    secondaryColor: Color(0xFF1F2937),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Knit Sweater\nสเวตเตอร์ไหมพรม',
    type: OutfitStyleType.maleSweater,
    primaryColor: Color(0xFFD97706),
    secondaryColor: Color(0xFF92400E),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Hawaiian Shirt\nเสื้อฮาวาย',
    type: OutfitStyleType.maleHawaiian,
    primaryColor: Color(0xFF06B6D4),
    secondaryColor: Color(0xFFFACC15),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Biker Leather\nแจ็กเก็ตหนังไบเกอร์',
    type: OutfitStyleType.maleBikerJacket,
    primaryColor: Color(0xFF18181B),
    secondaryColor: Color(0xFF27272A),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Denim Overalls\nชุดเอี๊ยมยีนส์',
    type: OutfitStyleType.maleOverall,
    primaryColor: Color(0xFF1E40AF),
    secondaryColor: Color(0xFF60A5FA),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Formal Vest\nเสื้อกั๊กทางการ',
    type: OutfitStyleType.maleVest,
    primaryColor: Color(0xFF334155),
    secondaryColor: Color(0xFFF8FAFC),
    gender: 'male',
  ),
  OutfitItem(
    name: 'Black Tuxedo\nชุดทักซิโดสีดำ',
    type: OutfitStyleType.maleTuxedo,
    primaryColor: Color(0xFF09090B),
    secondaryColor: Colors.white,
    gender: 'male',
  ),
  OutfitItem(
    name: 'School Uniform\nชุดนักเรียน',
    type: OutfitStyleType.schoolUniform,
    primaryColor: Colors.white,
    secondaryColor: Color(0xFF1E3A8A),
    gender: 'male',
  ),
];

// 15 Female Outfits
const List<OutfitItem> kFemaleOutfits = [
  OutfitItem(
    name: 'White Shirt & Skirt\nเสื้อเชิ้ตขาวกับกระโปรง',
    type: OutfitStyleType.femaleWhiteShirt,
    primaryColor: Colors.white,
    secondaryColor: Color(0xFF374151),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Pink Summer Dress\nเดรสฤดูร้อนสีชมพู',
    type: OutfitStyleType.femaleDress,
    primaryColor: Color(0xFFEC4899),
    secondaryColor: Colors.white,
    gender: 'female',
  ),
  OutfitItem(
    name: 'Casual Crop Top\nเสื้อครอป',
    type: OutfitStyleType.femaleCropTop,
    primaryColor: Color(0xFF8B5CF6),
    secondaryColor: Color(0xFFA78BFA),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Off-Shoulder Blouse\nเสื้อเปิดไหล่',
    type: OutfitStyleType.femaleOffShoulder,
    primaryColor: Color(0xFFF43F5E),
    secondaryColor: Color(0xFFFDA4AF),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Knit Turtleneck\nเสื้อคอเต่าไหมพรม',
    type: OutfitStyleType.femaleTurtleneck,
    primaryColor: Color(0xFF14B8A6),
    secondaryColor: Color(0xFF0D9488),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Floral Sundress\nเดรสลายดอกไม้',
    type: OutfitStyleType.femaleFloralDress,
    primaryColor: Color(0xFFF59E0B),
    secondaryColor: Color(0xFFFDE68A),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Cute Overalls\nชุดเอี๊ยม',
    type: OutfitStyleType.femaleOveralls,
    primaryColor: Color.fromARGB(255, 0, 98, 255),
    secondaryColor: Color(0xFF93C5FD),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Office Blazer\nเสื้อเบลเซอร์ทำงาน',
    type: OutfitStyleType.femaleBlazer,
    primaryColor: Color(0xFF475569),
    secondaryColor: Colors.white,
    gender: 'female',
  ),
  OutfitItem(
    name: 'Oversized Hoodie\nเสื้อฮู้ดโอเวอร์ไซซ์',
    type: OutfitStyleType.femaleHoodie,
    primaryColor: Color(0xFFA855F7),
    secondaryColor: Color(0xFFE9D5FF),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Traditional Kimono\nชุดกิโมโน',
    type: OutfitStyleType.femaleKimono,
    primaryColor: Color(0xFFE11D48),
    secondaryColor: Color(0xFFFDE047),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Cozy Cardigan\nเสื้อคาร์ดิแกน',
    type: OutfitStyleType.femaleCardigan,
    primaryColor: Color(0xFF10B981),
    secondaryColor: Color(0xFFA7F3D0),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Sporty Gym Set\nชุดออกกำลังกาย',
    type: OutfitStyleType.femaleSporty,
    primaryColor: Color(0xFF6366F1),
    secondaryColor: Color(0xFFC7D2FE),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Pastel Sweater\nสเวตเตอร์สีพาสเทล',
    type: OutfitStyleType.femalePastelTop,
    primaryColor: Color(0xFFF472B6),
    secondaryColor: Color(0xFFFBCFE8),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Evening Gown\nชุดราตรี',
    type: OutfitStyleType.femaleEveningGown,
    primaryColor: Color(0xFF4338CA),
    secondaryColor: Color(0xFF818CF8),
    gender: 'female',
  ),
  OutfitItem(
    name: 'Boho Chic Outfit\nชุดโบฮีเมียน',
    type: OutfitStyleType.femaleBoho,
    primaryColor: Color(0xFFD97706),
    secondaryColor: Color(0xFFFCD34D),
    gender: 'female',
  ),
  OutfitItem(
    name: 'School Uniform\nชุดนักเรียน',
    type: OutfitStyleType.schoolUniform,
    primaryColor: Colors.white,
    secondaryColor: Color(0xFF1E3A8A),
    gender: 'female',
  ),
];

// ============================================================
// PROFILE BACKGROUND  (animated English-study sky + card doodles)
// ============================================================

Path _starPath(Offset c, double r, {double rot = 0}) {
  final Path p = Path();
  for (int i = 0; i < 10; i++) {
    final double rad = i.isEven ? r : r * 0.48;
    final double a = rot - math.pi / 2 + i * math.pi / 5;
    final double x = c.dx + rad * math.cos(a);
    final double y = c.dy + rad * math.sin(a);
    if (i == 0) {
      p.moveTo(x, y);
    } else {
      p.lineTo(x, y);
    }
  }
  p.close();
  return p;
}

Path _sparklePath(Offset c, double r) {
  return Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
    ..close();
}

Path _heartPath(Offset c, double s) {
  return Path()
    ..moveTo(c.dx, c.dy + s * 0.9)
    ..cubicTo(
      c.dx - s * 1.4,
      c.dy + s * 0.1,
      c.dx - s * 0.9,
      c.dy - s * 0.9,
      c.dx,
      c.dy - s * 0.35,
    )
    ..cubicTo(
      c.dx + s * 0.9,
      c.dy - s * 0.9,
      c.dx + s * 1.4,
      c.dy + s * 0.1,
      c.dx,
      c.dy + s * 0.9,
    )
    ..close();
}

// Twinkling sparkle spec (position is a fraction of width / visible height)
class _Twinkler {
  final double x; // 0..1 across the width
  final double y; // 0..1 down the visible height
  final double size;
  final double phase;
  final bool sparkle; // true = white sparkle, false = golden sparkle
  final int cycles; // whole twinkles per loop
  const _Twinkler(
    this.x,
    this.y,
    this.size,
    this.phase,
    this.sparkle,
    this.cycles,
  );
}

class _ProfileBackdrop extends StatefulWidget {
  final double
  hidden; // height at the bottom that is covered by the content card
  final double haloY; // glow centre as a fraction of the height
  final bool
  laurelStyle; // true = ฟ้า 0xFF2F63EA + กรอบรูปแบบใหม่ (หน้าโปรไฟล์ & หน้าแต่งตัว)
  final bool
  skyless; // true = ไม่ทาสีพื้นท้องฟ้า วาดแค่ของตกแต่ง (ใช้สีพื้นของหัวหน้าแทน)

  const _ProfileBackdrop({
    this.hidden = 76,
    this.haloY = 0.43,
    this.laurelStyle = false,
    this.skyless = false,
  });

  @override
  State<_ProfileBackdrop> createState() => _ProfileBackdropState();
}

class _ProfileBackdropState extends State<_ProfileBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // One slow master clock drives every moving piece. All motion uses whole
    // numbers of cycles per loop, so the animation never "jumps" when it repeats.
    // Static background: the clock stays at 0 so nothing on the page moves.
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 48));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(
          time: _c,
          hidden: widget.hidden,
          haloY: widget.haloY,
          laurelStyle: widget.laurelStyle,
          skyless: widget.skyless,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// "English Study Sky": bright aqua sky, soft light beams, a glowing ring
// around the avatar and floating 3D-clay style study toys (ABC blocks,
// speech bubbles, books, globes, UK flag) with twinkling sparkles.
// ------------------------------------------------------------------
class _BackdropPainter extends CustomPainter {
  final Animation<double> time;
  final double hidden;
  final double haloY;
  final bool laurelStyle;
  final bool skyless;
  double _h = 0; // ความสูงของผืนผ้าใบ (ใช้ซ่อนของเล่นที่ตกขอบ)

  _BackdropPainter({
    required this.time,
    required this.hidden,
    required this.haloY,
    this.laurelStyle = false,
    this.skyless = false,
  }) : super(repaint: time);

  static const double _tau = math.pi * 2;

  // The avatar ring widget is a fixed 186 px, so the glow ring is fixed too.
  static const double _ringRadius = 106;

  static const List<_Twinkler> _stars = [
    _Twinkler(0.36, 0.05, 9, 0.00, true, 22),
    _Twinkler(0.62, 0.05, 8, 0.30, false, 26),
    _Twinkler(0.04, 0.30, 9, 0.55, true, 20),
    _Twinkler(0.97, 0.20, 9, 0.15, false, 24),
    _Twinkler(0.30, 0.64, 7, 0.60, true, 27),
    _Twinkler(0.72, 0.64, 8, 0.45, false, 25),
    _Twinkler(0.03, 0.78, 8, 0.85, false, 23),
    _Twinkler(0.96, 0.62, 8, 0.25, true, 19),
  ];

  // ---------- small helpers ----------

  static final Map<String, TextPainter> _tpCache = <String, TextPainter>{};

  static TextPainter _text(
    String s,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w900,
  }) {
    final String key =
        '$s|${size.toStringAsFixed(1)}|${color.toARGB32()}|${weight.index}';
    return _tpCache.putIfAbsent(key, () {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  // Text that is shrunk (never grown past maxSize) so it fits inside maxW.

  static void _drawText(Canvas canvas, TextPainter tp, Offset center) {
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  static Color _lighten(Color c, [double amt = 0.12]) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amt).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c, [double amt = 0.12]) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amt).clamp(0.0, 1.0)).toColor();
  }

  void _glow(Canvas canvas, Offset center, double r, Color color) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  // Cheap soft shadow (no blur filter): the same shape pushed down and
  // repeated with a few widening, fading strokes.
  void _dropShadow(Canvas canvas, Path path, double depth) {
    final Path sp = path.shift(Offset(0, depth));
    const Color ink = Color(0xFF0F2F8C);
    canvas.drawPath(sp, Paint()..color = ink.withValues(alpha: 0.10));
    canvas.drawPath(
      sp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = depth * 1.6
        ..color = ink.withValues(alpha: 0.07),
    );
    canvas.drawPath(
      sp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = depth * 3.2
        ..color = ink.withValues(alpha: 0.04),
    );
  }

  // "Clay" look: soft shadow + diagonal gradient + thin light rim.
  void _clay(Canvas canvas, Path path, Color base, {double depth = 4}) {
    _dropShadow(canvas, path, depth);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(base, 0.10), base, _darken(base, 0.08)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(path.getBounds()),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;
    _h = h;
    final double vb = math.max(
      1.0,
      h - hidden,
    ); // bottom edge of what is really seen
    final double t = time.value;
    final double s = (w / 360).clamp(0.85, 1.2).toDouble(); // item scale
    final Offset c = Offset(w / 2, h * haloY);
    final Rect full = Offset.zero & size;

    canvas.save();
    canvas.clipRect(full);
    if (!skyless) _paintSky(canvas, full, w, vb);
    _paintBeams(canvas, w, vb, t);
    _paintHalo(canvas, c, t);
    if (!laurelStyle) {
      // โหมดเดิม: วงแหวนเรืองแสง + ฝุ่นประกาย (โหมด laurelStyle ใช้กรอบรูปแบบใหม่แทน)
      _paintGlowRing(canvas, c, t);
      _paintDust(canvas, c, t);
    }
    _paintClouds(canvas, w, vb, t);
    _paintItems(canvas, c, w, s, t);
    _paintSparkles(canvas, w, vb, t);
    canvas.restore();
  }

  // ---------- sky, light beams, halo ----------

  void _paintSky(Canvas canvas, Rect full, double w, double vb) {
    if (laurelStyle) {
      canvas.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A8BFA), Color(0xFF2F63EA), Color(0xFF2556D6)],
            stops: [0.0, 0.50, 1.0],
          ).createShader(full),
      );
      _glow(
        canvas,
        Offset(w * 0.50, vb * 0.46),
        w * 0.72,
        Colors.white.withValues(alpha: 0.28),
      );
      _glow(
        canvas,
        Offset(w * 0.95, 0),
        w * 0.60,
        const Color(0xFF9DBBFF).withValues(alpha: 0.55),
      );
      _glow(
        canvas,
        Offset(w * 0.02, vb * 0.95),
        w * 0.70,
        const Color(0xFF7FA8FF).withValues(alpha: 0.35),
      );
      return;
    }
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F86FF),
            Color(0xFF3B73F5),
            Color(0xFF2D63E8),
            Color(0xFF2556D6),
          ],
          stops: [0.0, 0.40, 0.75, 1.0],
        ).createShader(full),
    );
    _glow(
      canvas,
      Offset(w * 0.04, vb * 0.92),
      w * 0.75,
      const Color(0xFF9DBBFF).withValues(alpha: 0.45),
    );
    _glow(
      canvas,
      Offset(w * 0.98, vb * 0.95),
      w * 0.65,
      const Color(0xFF9DBBFF).withValues(alpha: 0.40),
    );
    _glow(
      canvas,
      Offset(w * 0.88, vb * 0.04),
      w * 0.60,
      const Color(0xFF7FA8FF).withValues(alpha: 0.50),
    );
  }

  void _paintBeams(Canvas canvas, double w, double vb, double t) {
    final Paint p =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: laurelStyle ? 0.20 : 0.26),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, vb));
    for (int i = 0; i < 4; i++) {
      final double x0 = w * (0.10 + 0.27 * i);
      final double sway = math.sin(_tau * (t * 2 + i * 0.25)) * 18;
      final double lean = (i - 1.5) * 38 + sway;
      canvas.drawPath(
        Path()
          ..moveTo(x0 - 10, 0)
          ..lineTo(x0 + 22, 0)
          ..lineTo(x0 + lean + 95, vb)
          ..lineTo(x0 + lean - 40, vb)
          ..close(),
        p,
      );
    }
  }

  void _paintHalo(Canvas canvas, Offset c, double t) {
    final double breathe = 0.5 + 0.5 * math.sin(_tau * t * 12);
    final double r = 158 + 8 * breathe;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.62),
            const Color(0xFFD9E6FF).withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  // Glowing cream ring around the avatar (like the reference picture).
  void _paintGlowRing(Canvas canvas, Offset c, double t) {
    final double breathe = 0.5 + 0.5 * math.sin(_tau * t * 12);
    const Color cream = Color(0xFFFFF4CF);
    const List<double> widths = [38, 28, 19, 12, 7];
    const List<double> alphas = [0.05, 0.08, 0.13, 0.22, 0.40];
    for (int i = 0; i < widths.length; i++) {
      canvas.drawCircle(
        c,
        _ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = widths[i] + 4 * breathe
          ..color = cream.withValues(alpha: alphas[i] * (0.85 + 0.3 * breathe)),
      );
    }
    canvas.drawCircle(
      c,
      _ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  // Tiny glittering dust that slowly orbits the ring.
  void _paintDust(Canvas canvas, Offset c, double t) {
    for (int i = 0; i < 30; i++) {
      final double dir = i.isEven ? 1.0 : -1.0;
      final double a = (i / 30.0) * _tau + dir * t * _tau * 2;
      final double radius = 114.0 + ((i * 37) % 58).toDouble();
      final double size = 1.1 + ((i * 13) % 5) * 0.45;
      final double k =
          0.5 + 0.5 * math.sin(_tau * (t * (10 + i % 6) + i * 0.137));
      final Offset o =
          c + Offset(math.cos(a) * radius, math.sin(a) * radius * 0.96);
      final Color col = i % 5 == 0 ? const Color(0xFFFFE9A8) : Colors.white;
      canvas.drawCircle(
        o,
        size * (0.8 + 0.4 * k),
        Paint()..color = col.withValues(alpha: 0.25 + 0.70 * k),
      );
    }
  }

  // ---------- soft clouds at the bottom (blend into the content card) ----------

  void _softCloud(Canvas canvas, Offset c, double w, double a) {
    const List<Offset> puffs = [
      Offset(-0.30, 0.05),
      Offset(-0.10, -0.08),
      Offset(0.12, -0.04),
      Offset(0.32, 0.06),
    ];
    final double r = w * 0.28;
    for (final Offset f in puffs) {
      final Offset pc = Offset(c.dx + f.dx * w, c.dy + f.dy * w);
      final Rect rect = Rect.fromCircle(center: pc, radius: r);
      canvas.drawCircle(
        pc,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color.fromARGB(255, 184, 203, 255).withValues(alpha: a),
              const Color.fromARGB(255, 166, 188, 240).withValues(alpha: 0),
            ],
            stops: const [0.35, 1.0],
          ).createShader(rect),
      );
    }
  }

  void _paintClouds(Canvas canvas, double w, double vb, double t) {
    for (int i = 0; i < 3; i++) {
      final double x =
          w * (0.18 + 0.32 * i) + math.sin(_tau * (t * 2 + i / 3.0)) * 16;
      _softCloud(
        canvas,
        Offset(x, vb * (0.97 + 0.01 * i)),
        w * (0.40 + 0.06 * (i % 2)),
        laurelStyle ? 0.80 : 0.55,
      );
    }
    if (laurelStyle) {
      // เมฆนุ่มๆ ด้านบน (หลังคำทักทาย และมุมขวา)
      _softCloud(
        canvas,
        Offset(w * 0.14 + math.sin(_tau * (t * 3)) * 8, vb * 0.07),
        w * 0.34,
        0.55,
      );
      _softCloud(
        canvas,
        Offset(w * 0.84 + math.sin(_tau * (t * 3 + 0.5)) * 8, vb * 0.13),
        w * 0.30,
        0.45,
      );
      _softCloud(canvas, Offset(w * 0.46, vb * 0.60), w * 0.26, 0.28);
    }
  }

  // ---------- sparkles ----------

  void _paintSparkles(Canvas canvas, double w, double vb, double t) {
    for (int i = 0; i < _stars.length; i++) {
      final _Twinkler s = _stars[i];
      final double k = 0.5 + 0.5 * math.sin(_tau * (t * s.cycles + s.phase));
      final double r = s.size * (0.70 + 0.50 * k);
      final Offset o = Offset(s.x * w, s.y * vb);
      final Color col =
          s.sparkle
              ? Colors.white
              : (i.isEven ? const Color(0xFFFFC76B) : const Color(0xFFFFB27A));
      canvas.drawCircle(
        o,
        r * 1.7,
        Paint()..color = col.withValues(alpha: 0.10 + 0.10 * k),
      );
      canvas.drawPath(
        _sparklePath(o, r * 1.3),
        Paint()..color = col.withValues(alpha: 0.50 + 0.50 * k),
      );
    }
  }

  // ---------- floating study toys ----------

  void _paintItems(Canvas canvas, Offset c, double w, double s, double t) {
    // Toys are drawn in a fixed position (float animation removed).
    Offset at(double fx, double dy, double cycles, double phase, double amp) {
      return Offset(
        w * fx,
        c.dy + dy * s, // static: no up/down float
      );
    }

    double tilt(double base, double cycles, double phase) =>
        base; // static: no rocking

    if (laurelStyle) {
      _paintItemsLight(canvas, c, w, s, t, at, tilt);
      return;
    }
    // Balanced layout: 4 toys per side, staggered so neither side feels empty.
    // left column
    _block(
      canvas,
      at(0.090, -34, 9, 0.30, 4),
      42 * s,
      tilt(-0.22, 9, 0.3),
      'A',
      const Color(0xFFF2A99F),
    );
    _block(
      canvas,
      at(0.205, 36, 12, 0.55, 4),
      46 * s,
      tilt(0.12, 12, 0.55),
      'B',
      const Color(0xFFA78BFA),
    );
    _block(
      canvas,
      at(0.070, 98, 10, 0.05, 3),
      28 * s,
      tilt(-0.10, 10, 0.05),
      'E',
      const Color(0xFFF2A99F),
    );
    _globe(canvas, at(0.185, 150, 11, 0.70, 3), 14 * s, (t * 2 + 0.70) % 1.0);
    // right column
    _globe(canvas, at(0.930, -62, 9, 0.40, 4), 15 * s, (t * 2 + 0.40) % 1.0);
    _bookOpen(
      canvas,
      at(0.850, 4, 8, 0.45, 3),
      66 * s,
      50 * s,
      tilt(-0.12, 8, 0.45),
    );
    _block(
      canvas,
      at(0.920, 76, 11, 0.80, 4),
      42 * s,
      tilt(0.20, 11, 0.8),
      'C',
      const Color(0xFF5ED3B0),
    );
    _block(
      canvas,
      at(0.815, 142, 9, 0.15, 4),
      46 * s,
      tilt(-0.16, 9, 0.15),
      'D',
      const Color(0xFFF1C068),
    );
  }

  // เลย์เอาต์ของโหมด laurelStyle: A / B / E + ลูกโลกใหญ่ทางซ้าย, ลูกโลกเล็ก + หนังสือบนโต๊ะ + C / D ทางขวา
  void _paintItemsLight(
    Canvas canvas,
    Offset c,
    double w,
    double s,
    double t,
    Offset Function(
      double fx,
      double dy,
      double cycles,
      double phase,
      double amp,
    )
    at,
    double Function(double base, double cycles, double phase) tilt,
  ) {
    // ข้ามของที่จะตกขอบล่าง (พื้นที่หน้าแต่งตัวเตี้ยกว่าหน้าโปรไฟล์)
    bool fits(Offset o, double r) => o.dy - r * 0.5 < _h - 24;

    // left column
    _block(
      canvas,
      at(0.090, -40, 9, 0.30, 4),
      42 * s,
      tilt(-0.22, 9, 0.3),
      'A',
      const Color(0xFFF2A99F),
    );
    _block(
      canvas,
      at(0.205, 30, 12, 0.55, 4),
      44 * s,
      tilt(0.12, 12, 0.55),
      'B',
      const Color(0xFFA78BFA),
    );
    final Offset eO = at(0.070, 92, 10, 0.05, 3);
    if (fits(eO, 28 * s)) {
      _block(
        canvas,
        eO,
        28 * s,
        tilt(-0.10, 10, 0.05),
        'E',
        const Color(0xFFF2A99F),
      );
    }
    final Offset gO = at(0.085, 160, 11, 0.70, 3);
    if (fits(gO, 40 * s)) _globe(canvas, gO, 40 * s, (t * 2 + 0.70) % 1.0);
    // right column
    _globe(canvas, at(0.935, -66, 9, 0.40, 4), 15 * s, (t * 2 + 0.40) % 1.0);
    final Offset bookO = at(0.850, 2, 8, 0.45, 3);
    _desk(canvas, bookO + Offset(0, 25 * s), 92 * s);
    _bookOpen(canvas, bookO, 66 * s, 50 * s, tilt(-0.12, 8, 0.45));
    final Offset cO = at(0.920, 88, 11, 0.80, 4);
    if (fits(cO, 40 * s)) {
      _block(
        canvas,
        cO,
        40 * s,
        tilt(0.20, 11, 0.8),
        'C',
        const Color(0xFF5ED3B0),
      );
    }
    final Offset dO = at(0.815, 150, 9, 0.15, 4);
    if (fits(dO, 44 * s)) {
      _block(
        canvas,
        dO,
        44 * s,
        tilt(-0.16, 9, 0.15),
        'D',
        const Color(0xFFF1C068),
      );
    }
  }

  // โต๊ะไม้ตัวเล็กไว้วางหนังสือ (o = กึ่งกลางหน้าโต๊ะ)
  void _desk(Canvas canvas, Offset o, double w) {
    final Paint leg = Paint()..color = const Color(0xFF9C6A41);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx - w * 0.40, o.dy + w * 0.05, w * 0.07, w * 0.24),
        Radius.circular(w * 0.02),
      ),
      leg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx + w * 0.33, o.dy + w * 0.05, w * 0.07, w * 0.24),
        Radius.circular(w * 0.02),
      ),
      leg,
    );
    final RRect top = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: w, height: w * 0.13),
      Radius.circular(w * 0.05),
    );
    _clay(canvas, Path()..addRRect(top), const Color(0xFFCB915F), depth: 3);
  }

  // ---------- toys ----------

  void _block(
    Canvas canvas,
    Offset o,
    double size,
    double rot,
    String ch,
    Color base,
  ) {
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(rot);
    final RRect rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      Radius.circular(size * 0.24),
    );
    _clay(canvas, Path()..addRRect(rr), base, depth: size * 0.10);
    // inner bevel + gloss
    canvas.drawRRect(
      rr.deflate(size * 0.07),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.035
        ..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-size * 0.40, -size * 0.42, size * 0.50, size * 0.14),
        Radius.circular(size * 0.07),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    final double fs = size * 0.58;
    _drawText(
      canvas,
      _text(ch, fs, _darken(base, 0.16).withValues(alpha: 0.55)),
      Offset(size * 0.02, size * 0.05),
    );
    _drawText(canvas, _text(ch, fs, Colors.white), Offset(0, size * 0.02));
    canvas.restore();
  }

  void _globe(Canvas canvas, Offset o, double r, double spin) {
    final Rect rect = Rect.fromCircle(center: o, radius: r);
    final Path circle = Path()..addOval(rect);
    _dropShadow(canvas, circle, r * 0.22);
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.40),
          radius: 1.0,
          colors: [Color(0xFF9AD8FF), Color(0xFF4F9FE8), Color(0xFF2F6FCB)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(circle);
    final Paint land =
        Paint()..color = const Color(0xFF8ED88B).withValues(alpha: 0.95);
    for (int i = 0; i < 3; i++) {
      final double a = (spin + i / 3.0) % 1.0;
      final double x = o.dx - r * 1.4 + a * r * 2.8;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, o.dy + (i - 1) * r * 0.42),
          width: r * (0.95 - i * 0.12),
          height: r * 0.50,
        ),
        land,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      o + Offset(-r * 0.35, -r * 0.40),
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.40),
    );
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  void _bookOpen(Canvas canvas, Offset o, double w, double h, double rot) {
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(rot);
    final Path left =
        Path()
          ..moveTo(-w * 0.50, -h * 0.30)
          ..quadraticBezierTo(-w * 0.25, -h * 0.46, 0, -h * 0.30)
          ..lineTo(0, h * 0.40)
          ..quadraticBezierTo(-w * 0.25, h * 0.24, -w * 0.50, h * 0.40)
          ..close();
    final Path right =
        Path()
          ..moveTo(w * 0.50, -h * 0.30)
          ..quadraticBezierTo(w * 0.25, -h * 0.46, 0, -h * 0.30)
          ..lineTo(0, h * 0.40)
          ..quadraticBezierTo(w * 0.25, h * 0.24, w * 0.50, h * 0.40)
          ..close();
    final Path both = Path.combine(PathOperation.union, left, right);
    // blue cover peeking out underneath
    final Path under = both
        .transform(Matrix4.diagonal3Values(1.08, 1.12, 1.0).storage)
        .shift(Offset(0, h * 0.04));
    _clay(canvas, under, const Color(0xFF9CB6FF), depth: 5);
    final Paint page =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFE6F0FF)],
          ).createShader(both.getBounds());
    canvas.drawPath(left, page);
    canvas.drawPath(right, page);
    canvas.drawLine(
      Offset(0, -h * 0.30),
      Offset(0, h * 0.40),
      Paint()
        ..color = const Color(0xFFBFD0F0)
        ..strokeWidth = 1.2,
    );
    final Paint line =
        Paint()
          ..color = const Color(0xFF9DB6F0)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final double y = -h * 0.04 + i * h * 0.12;
      canvas.drawLine(Offset(-w * 0.42, y), Offset(-w * 0.07, y), line);
      canvas.drawLine(Offset(w * 0.07, y), Offset(w * 0.42, y), line);
    }
    _drawText(
      canvas,
      _text('VOCAB', w * 0.10, const Color(0xFF5A78D6)),
      Offset(-w * 0.25, -h * 0.12),
    );
    _drawText(
      canvas,
      _text('GRAMMAR', w * 0.075, const Color(0xFF5A78D6)),
      Offset(w * 0.25, -h * 0.12),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.time != time ||
      old.hidden != hidden ||
      old.haloY != haloY ||
      old.laurelStyle != laurelStyle ||
      old.skyless != skyless;
}

// ------------------------------------------------------------------
// กรอบพวงใบลอเรลสีทองรอบรูปอวตาร (ใช้ในหน้าโปรไฟล์หลัก)
// ------------------------------------------------------------------
// กรอบรูปอวตาร: วงแหวนสีขาวโปร่งแสงซ้อนกันหลายชั้น (เหมือนแสงเรืองรอบรูป)
class _AvatarFramePainter extends CustomPainter {
  const _AvatarFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final Offset c = size.center(Offset.zero);

    // แผ่นโปร่งแสงด้านนอกสุด
    canvas.drawCircle(
      c,
      w * 0.49,
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    void ring(double r, double width, double opacity) {
      canvas.drawCircle(
        c,
        w * r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = Colors.white.withValues(alpha: opacity),
      );
    }

    ring(0.475, 2.0, 0.85); // เส้นบางนอกสุด
    ring(0.435, 7.0, 0.45); // แถบโปร่งแสงกว้าง
    ring(0.398, 2.5, 0.95); // เส้นขาวชิดรูป
  }

  @override
  bool shouldRepaint(covariant _AvatarFramePainter oldDelegate) => false;
}

// Soft sky glow + sunbeams behind the avatar in the avatar-customizer header.
// Static on purpose (no animation controller): the floating clouds, stars and
// letter chips drawn on top of it already provide the motion.
// ignore: unused_element
class _SkyPainter extends CustomPainter {
  final double haloY; // glow centre as a fraction of the height
  final double hidden; // height at the bottom that is covered by something else

  const _SkyPainter(this.haloY, this.hidden);

  static const double _tau = math.pi * 2;

  void _glow(Canvas canvas, Offset center, double r, Color color) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    final double vb = math.max(1.0, h - hidden); // visible bottom edge
    final Offset c = Offset(w / 2, vb * haloY);
    final Rect full = Offset.zero & size;

    canvas.save();
    canvas.clipRect(full);

    // 1) soft colour glows in the corners so the header is not flat
    _glow(
      canvas,
      Offset(0, vb * 0.85),
      w * 0.65,
      const Color(0xFF8FB4FF).withValues(alpha: 0.35),
    );
    _glow(
      canvas,
      Offset(w, vb * 0.10),
      w * 0.60,
      const Color(0xFF6C9BFF).withValues(alpha: 0.35),
    );

    // 2) sunbeams fanning out from behind the avatar
    const int rays = 14;
    final double len = math.sqrt(w * w + h * h);
    final Path beams = Path();
    for (int i = 0; i < rays; i++) {
      final double a0 = _tau * i / rays;
      final double a1 = a0 + _tau / rays * 0.5;
      beams
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a0) * len, c.dy + math.sin(a0) * len)
        ..lineTo(c.dx + math.cos(a1) * len, c.dy + math.sin(a1) * len)
        ..close();
    }
    canvas.drawPath(
      beams,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: c, radius: math.min(w * 0.75, len)),
        ),
    );

    // 3) warm halo right behind the avatar
    _glow(canvas, c, 112, Colors.white.withValues(alpha: 0.55));
    _glow(canvas, c, 84, const Color(0xFFD3E2FF).withValues(alpha: 0.45));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.haloY != haloY || old.hidden != hidden;
}

// Very soft pastel doodles (stars, hearts, rings...) behind the content card.
// ignore: unused_element
class _DoodlePainter extends CustomPainter {
  const _DoodlePainter();

  static const List<Color> _cols = [
    Color(0xFF3B73F5),
    Color(0xFFFF6FA5),
    Color(0xFFFFB627),
    Color(0xFF2EC4B6),
    Color(0xFFA78BFA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 96;
    final int rows = (size.height / cell).ceil() + 1;
    final int cols = (size.width / cell).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int q = 0; q < cols; q++) {
        final int seed = r * 31 + q * 17 + (r * q) * 5;
        final double jx = ((seed * 37) % 61) / 61.0 - 0.5;
        final double jy = ((seed * 53) % 59) / 59.0 - 0.5;
        final Offset o = Offset(
          q * cell + (r.isOdd ? cell / 2 : 0) + cell / 2 + jx * 36,
          r * cell + cell / 2 + jy * 36,
        );
        if (o.dx < 12 ||
            o.dx > size.width - 12 ||
            o.dy < 12 ||
            o.dy > size.height - 12) {
          continue;
        }

        final Color col = _cols[seed % _cols.length];
        final double alpha = 0.10 + ((seed * 7) % 5) * 0.012;
        final Paint fill = Paint()..color = col.withValues(alpha: alpha);
        final Paint line =
            Paint()
              ..color = col.withValues(alpha: alpha + 0.03)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round;
        final double rot = (((seed * 11) % 40) - 20) / 100;

        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(rot);
        switch ((seed ~/ 3 + r + q) % 6) {
          case 0:
            final Path star = _starPath(Offset.zero, 11);
            canvas.drawPath(star, fill);
            canvas.drawPath(star, line..strokeWidth = 3);
            break;
          case 1:
            canvas.drawPath(_heartPath(Offset.zero, 10), fill);
            break;
          case 2:
            canvas.drawCircle(Offset.zero, 8, line);
            break;
          case 3:
            canvas.drawPath(_sparklePath(Offset.zero, 12), fill);
            break;
          case 4:
            canvas.drawCircle(const Offset(-10, 4), 3, fill);
            canvas.drawCircle(const Offset(0, -4), 3, fill);
            canvas.drawCircle(const Offset(10, 4), 3, fill);
            break;
          default:
            final Path wave =
                Path()
                  ..moveTo(-14, 0)
                  ..quadraticBezierTo(-7, -9, 0, 0)
                  ..quadraticBezierTo(7, 9, 14, 0);
            canvas.drawPath(wave, line);
            break;
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => false;
}

// Gently floats its child (letters, clouds) back and forth.
class _Floaty extends StatefulWidget {
  final Widget child;
  final double dx;
  final double dy;
  final double seconds;

  final dynamic childs;

  const _Floaty({
    required this.childs,
    required this.dx,
    required this.child,
    required this.dy,
    required this.seconds,
  });

  @override
  State<_Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<_Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.seconds * 1000).round()),
    );
    _c.value =
        (widget.seconds * 0.37) % 1.0; // different start phase for each piece
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(_c.value) - 0.5;
        return Transform.translate(
          offset: Offset(widget.dx * t, widget.dy * t),
          child: child,
        );
      },
    );
  }
}

// Twinkling stars and sparkles.
class _Twinkle extends StatefulWidget {
  final Widget child;
  final double seconds;

  const _Twinkle({required this.child, required this.seconds});

  @override
  State<_Twinkle> createState() => _TwinkleState();
}

class _TwinkleState extends State<_Twinkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.seconds * 1000).round()),
    );
    _c.value = (widget.seconds * 0.61) % 1.0;
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(_c.value);
        return Opacity(
          opacity: 0.55 + 0.45 * t,
          child: Transform.scale(scale: 0.85 + 0.25 * t, child: child),
        );
      },
    );
  }
}

/// Hair style, outfit and accessories one gender was wearing.
typedef _GenderLook = ({
  int hairStyle,
  int outfit,
  int glasses,
  int hat,
  int clip,
  int earring,
  int neck,
  int extra,
});

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RouteAware {
  int currentIndex = 3;
  final CoinWallet _wallet = CoinWallet.instance;
  ProfileData? _profile;
  bool _isProfileLoading = true;
  String? _profileError;
  int? _serverCoinBalance;
  bool _isCoinBalanceLoading = true;
  // Bumped on every setState so open bottom sheets rebuild too.
  final ValueNotifier<int> _sheetRefresh = ValueNotifier<int>(0);
  String? _coinBalanceError;
  Set<String> _serverAvatarKeys = <String>{};
  ModalRoute<dynamic>? _subscribedRoute;

  // While the "แต่งตัวอวตาร" sheet is open, choices only change what this
  // screen shows (a draft). They are saved to the account when the child
  // taps "เสร็จสิ้น"; closing the sheet any other way throws them away.
  bool _avatarSheetOpen = false;
  bool _avatarCommitted = false;

  /// What each gender was wearing earlier in this sheet, so switching to the
  /// other gender and back does not lose the outfit.
  final Map<String, _GenderLook> _looks = <String, _GenderLook>{};

  String selectedGender = 'female';
  int selectedSkin = 3;
  int selectedHairStyle = 0;
  int selectedHairColor = 3;
  int selectedOutfit = 0;
  int selectedGlasses = 0;
  int selectedHat = 0;
  int selectedClip = 0;
  int selectedEarring = 0;
  int selectedNeck = 0;
  int selectedExtra = 0;

  @override
  void initState() {
    super.initState();
    AvatarProfile.instance.addListener(_onGlobalAvatarChanged);
    AvatarProfile.instance.load().then((_) {
      if (mounted) setState(_pullFromGlobal);
    });
    _wallet.addListener(_onWalletChanged);
    _initShop();
    _loadProfile();
    _loadRewards();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        profileRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      if (route != null) profileRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadRewards();
  }

  @override
  void dispose() {
    profileRouteObserver.unsubscribe(this);
    _wallet.removeListener(_onWalletChanged);
    AvatarProfile.instance.removeListener(_onGlobalAvatarChanged);
    _sheetRefresh.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _sheetRefresh.value++;
  }

  void _onGlobalAvatarChanged() {
    if (!mounted || _avatarSheetOpen) return; // keep the draft
    setState(_pullFromGlobal);
  }

  void _pullFromGlobal() {
    final AvatarProfile p = AvatarProfile.instance;
    selectedGender = p.gender;
    selectedSkin = p.skinIndex;
    selectedHairStyle = p.hairStyle;
    selectedHairColor = p.hairColorIndex;
    selectedOutfit = p.outfitIndex;
    selectedGlasses = p.glasses;
    selectedHat = p.hat;
    selectedClip = p.clip;
    selectedEarring = p.earring;
    selectedNeck = p.neck;
    selectedExtra = p.extra;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isProfileLoading = true;
      _profileError = null;
    });
    try {
      final profile = await ProfileApiService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isProfileLoading = false;
      });
    } on ProfileApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _profileError = error.message;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _profileError = 'โหลดข้อมูลโปรไฟล์ไม่สำเร็จ กรุณาลองอีกครั้ง';
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final ProfileData? current = _profile;
    if (current == null) return;
    final ProfileData? updated = await Navigator.push<ProfileData>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(profile: current),
      ),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _loadRewards() async {
    final String? requestedUserId =
        await UserAccountPreferences.currentUserId();
    if (mounted) {
      setState(() {
        _isCoinBalanceLoading = true;
        _coinBalanceError = null;
        _serverCoinBalance = null;
        _serverAvatarKeys = <String>{};
      });
    }
    try {
      final values = await Future.wait<Object>([
        RewardsApiService.getBalance(),
        RewardsApiService.getAvatarPurchases(),
      ]);
      final balance = values[0] as int;
      final purchases = values[1] as AvatarPurchases;
      if (requestedUserId != await UserAccountPreferences.currentUserId()) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _serverCoinBalance = balance;
        _serverAvatarKeys = purchases.itemKeys;
        _isCoinBalanceLoading = false;
      });
    } on RewardsApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _coinBalanceError = error.message;
        _isCoinBalanceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coinBalanceError = 'โหลด Coins ไม่สำเร็จ กรุณาลองอีกครั้ง';
        _isCoinBalanceLoading = false;
      });
    }
  }

  String get _coinBalanceLabel {
    if (_serverCoinBalance != null) return '$_serverCoinBalance';
    return _isCoinBalanceLoading ? '…' : '—';
  }

  bool _ownsAvatar(String key, int price) {
    // Ownership comes only from the server (GET /api/rewards/avatar-purchases).
    return price <= 0 || _serverAvatarKeys.contains(key);
  }

  Future<AvatarPurchaseResult> _purchaseAvatar(String key) async {
    try {
      final result = await RewardsApiService.purchaseAvatar(key);
      CoinBalance.set(result.balance); // coins at the top of other screens
      if (mounted) {
        setState(() {
          _serverCoinBalance = result.balance;
          _serverAvatarKeys = result.itemKeys;
          _coinBalanceError = null;
        });
      }
      return result;
    } on RewardsApiException catch (error) {
      if (error.code == 'INSUFFICIENT_COINS' && error.balance != null) {
        if (mounted) setState(() => _serverCoinBalance = error.balance);
        rethrow;
      }
      if (error.code != 'AVATAR_ALREADY_OWNED') rethrow;
      final purchases = await RewardsApiService.getAvatarPurchases();
      if (!purchases.itemKeys.contains(key)) rethrow;
      if (mounted) {
        setState(() {
          _serverCoinBalance = purchases.balance;
          _serverAvatarKeys = purchases.itemKeys;
          _coinBalanceError = null;
        });
      }
      return AvatarPurchaseResult(
        itemKey: key,
        price: error.price ?? 0,
        balance: purchases.balance,
        itemKeys: purchases.itemKeys,
      );
    }
  }

  String _formatJoinedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year + 543}';
  }

  /// A choice in the avatar sheet: kept as a draft until "เสร็จสิ้น".
  void _syncProfile() {
    if (_avatarSheetOpen) return;
    _commitProfile();
  }

  /// Saves what is chosen to the account (and to the avatar everywhere).
  void _commitProfile() {
    final int safeOutfit =
        selectedOutfit < currentOutfits.length ? selectedOutfit : 0;
    AvatarProfile.instance.update(
      gender: selectedGender,
      skinIndex: selectedSkin,
      hairStyle: selectedHairStyle,
      hairColorIndex: selectedHairColor,
      outfitIndex: safeOutfit,
      glasses: selectedGlasses,
      hat: selectedHat,
      clip: selectedClip,
      earring: selectedEarring,
      neck: selectedNeck,
      extra: selectedExtra,
    );
  }

  List<Color> get skinTones => kSkinTones;
  List<Color> get hairColors => kHairColors;
  List<HairItem> get maleHairStyles => kMaleHairStyles;
  List<HairItem> get femaleHairStyles => kFemaleHairStyles;
  List<OutfitItem> get maleOutfits => kMaleOutfits;
  List<OutfitItem> get femaleOutfits => kFemaleOutfits;

  static const List<AccessoryItem> _femaleGlasses = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'glasses'),
    AccessoryItem(name: 'Cat Eye\nแว่นตาแมว', id: 3, type: 'glasses'),
    AccessoryItem(name: 'Heart\nแว่นรูปหัวใจ', id: 5, type: 'glasses'),
    AccessoryItem(name: 'Gold Round\nแว่นกลมกรอบทอง', id: 6, type: 'glasses'),
    AccessoryItem(name: 'Star\nแว่นรูปดาว', id: 7, type: 'glasses'),
    AccessoryItem(name: 'Pastel Round\nแว่นกลมสีพาสเทล', id: 11, type: 'glasses'),
    AccessoryItem(name: 'Butterfly\nแว่นผีเสื้อ', id: 12, type: 'glasses'),
  ];
  static const List<AccessoryItem> _maleGlasses = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'glasses'),
    AccessoryItem(name: 'Round\nแว่นกลม', id: 1, type: 'glasses'),
    AccessoryItem(name: 'Thick Square\nแว่นเหลี่ยมกรอบหนา', id: 2, type: 'glasses'),
    AccessoryItem(name: 'Aviator\nแว่นนักบิน', id: 4, type: 'glasses'),
    AccessoryItem(name: 'Wayfarer\nแว่นเวย์ฟาเรอร์', id: 8, type: 'glasses'),
    AccessoryItem(name: 'Browline\nแว่นกรอบคิ้ว', id: 9, type: 'glasses'),
    AccessoryItem(name: 'Sport Wrap\nแว่นกีฬา', id: 10, type: 'glasses'),
  ];
  List<AccessoryItem> get glassesList =>
      selectedGender == 'male' ? _maleGlasses : _femaleGlasses;

  static const List<AccessoryItem> _femaleHat = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'hat'),
    AccessoryItem(name: 'Yellow Cap\nหมวกแก๊ปสีเหลือง', id: 1, type: 'hat'),
    AccessoryItem(name: 'Pink Beanie\nหมวกไหมพรมสีชมพู', id: 22, type: 'hat'),
    AccessoryItem(name: 'Beret\nหมวกเบเร่ต์', id: 4, type: 'hat'),
    AccessoryItem(name: 'Straw Hat\nหมวกฟาง', id: 6, type: 'hat'),
    AccessoryItem(name: 'Pastel Bucket\nหมวกบักเก็ตสีพาสเทล', id: 23, type: 'hat'),
    AccessoryItem(name: 'Bunny Ears\nที่คาดหูกระต่าย', id: 10, type: 'hat'),
    AccessoryItem(name: 'Cat Ears\nที่คาดหูแมว', id: 11, type: 'hat'),
    AccessoryItem(name: 'Flower Crown\nมงกุฎดอกไม้', id: 12, type: 'hat'),
    AccessoryItem(name: 'Bow Headband\nที่คาดผมโบว์', id: 18, type: 'hat'),
    AccessoryItem(name: 'Tiara\nมงกุฎเจ้าหญิง', id: 19, type: 'hat'),
    AccessoryItem(name: 'Floral Bonnet\nหมวกบอนเน็ตลายดอกไม้', id: 20, type: 'hat'),
    AccessoryItem(name: 'Santa\nหมวกซานตา', id: 8, type: 'hat'),
    AccessoryItem(name: 'Headphones\nหูฟัง', id: 13, type: 'hat'),
  ];
  static const List<AccessoryItem> _maleHat = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'hat'),
    AccessoryItem(name: 'Sport Cap\nหมวกแก๊ปกีฬา', id: 21, type: 'hat'),
    AccessoryItem(name: 'Beanie\nหมวกไหมพรม', id: 2, type: 'hat'),
    AccessoryItem(name: 'Bucket\nหมวกบักเก็ต', id: 3, type: 'hat'),
    AccessoryItem(name: 'Cowboy\nหมวกคาวบอย', id: 5, type: 'hat'),
    AccessoryItem(name: 'Top Hat\nหมวกทรงสูง', id: 7, type: 'hat'),
    AccessoryItem(name: 'Fedora\nหมวกเฟดอรา', id: 15, type: 'hat'),
    AccessoryItem(name: 'Newsboy\nหมวกนิวส์บอย', id: 16, type: 'hat'),
    AccessoryItem(name: 'Sport Band\nผ้าคาดหัวกีฬา', id: 17, type: 'hat'),
    AccessoryItem(name: 'Headphones\nหูฟัง', id: 24, type: 'hat'),
    AccessoryItem(name: 'Graduation\nหมวกรับปริญญา', id: 14, type: 'hat'),
    AccessoryItem(name: 'King Crown\nมงกุฎพระราชา', id: 9, type: 'hat'),
  ];
  List<AccessoryItem> get hatList =>
      selectedGender == 'male' ? _maleHat : _femaleHat;

  static const List<AccessoryItem> _femaleClip = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'clip'),
    AccessoryItem(name: 'Star\nกิ๊บรูปดาว', id: 1, type: 'clip'),
    AccessoryItem(name: 'Daisy\nกิ๊บดอกเดซี่', id: 2, type: 'clip'),
    AccessoryItem(name: 'Hearts\nกิ๊บรูปหัวใจ', id: 3, type: 'clip'),
    AccessoryItem(name: 'Cherry\nกิ๊บเชอร์รี่', id: 4, type: 'clip'),
    AccessoryItem(name: 'Butterfly\nกิ๊บผีเสื้อ', id: 5, type: 'clip'),
    AccessoryItem(name: 'Bow\nกิ๊บโบว์', id: 6, type: 'clip'),
    AccessoryItem(name: 'Cross Pins\nกิ๊บไขว้', id: 7, type: 'clip'),
    AccessoryItem(name: 'Pearls\nกิ๊บมุก', id: 8, type: 'clip'),
    AccessoryItem(name: 'Sakura\nกิ๊บดอกซากุระ', id: 14, type: 'clip'),
    AccessoryItem(name: 'Strawberry\nกิ๊บสตรอว์เบอร์รี', id: 15, type: 'clip'),
    AccessoryItem(name: 'Kitty\nกิ๊บแมวเหมียว', id: 16, type: 'clip'),
  ];
  static const List<AccessoryItem> _maleClip = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'clip'),
    AccessoryItem(name: 'Lightning\nกิ๊บสายฟ้า', id: 10, type: 'clip'),
    AccessoryItem(name: 'Bar Pins\nกิ๊บแท่ง', id: 11, type: 'clip'),
    AccessoryItem(name: 'X Pins\nกิ๊บกากบาท', id: 12, type: 'clip'),
    AccessoryItem(name: 'Shooting Star\nกิ๊บดาวตก', id: 13, type: 'clip'),
    AccessoryItem(name: 'Moon\nกิ๊บพระจันทร์', id: 9, type: 'clip'),
  ];
  List<AccessoryItem> get clipList =>
      selectedGender == 'male' ? _maleClip : _femaleClip;

  static const List<AccessoryItem> _femaleEarring = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'earring'),
    AccessoryItem(name: 'Pearl\nต่างหูมุก', id: 1, type: 'earring'),
    AccessoryItem(name: 'Gold Hoops\nต่างหูห่วงทอง', id: 2, type: 'earring'),
    AccessoryItem(name: 'Star\nต่างหูรูปดาว', id: 3, type: 'earring'),
    AccessoryItem(name: 'Heart\nต่างหูรูปหัวใจ', id: 4, type: 'earring'),
    AccessoryItem(name: 'Flower\nต่างหูดอกไม้', id: 5, type: 'earring'),
    AccessoryItem(name: 'Teardrop\nต่างหูหยดน้ำ', id: 6, type: 'earring'),
    AccessoryItem(name: 'Cherry\nต่างหูเชอร์รี่', id: 7, type: 'earring'),
  ];
  static const List<AccessoryItem> _maleEarring = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'earring'),
    AccessoryItem(name: 'Diamond Stud\nต่างหูเพชร', id: 8, type: 'earring'),
    AccessoryItem(name: 'Cross\nต่างหูไม้กางเขน', id: 9, type: 'earring'),
    AccessoryItem(name: 'Silver Hoop\nต่างหูห่วงเงิน', id: 10, type: 'earring'),
    AccessoryItem(name: 'Gold Stud\nต่างหูทอง', id: 11, type: 'earring'),
  ];
  List<AccessoryItem> get earringList =>
      selectedGender == 'male' ? _maleEarring : _femaleEarring;

  static const List<AccessoryItem> _femaleNeck = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'neck'),
    AccessoryItem(name: 'Pearls\nสร้อยมุก', id: 1, type: 'neck'),
    AccessoryItem(name: 'Heart Pendant\nสร้อยจี้หัวใจ', id: 2, type: 'neck'),
    AccessoryItem(name: 'Choker\nสร้อยโชกเกอร์', id: 3, type: 'neck'),
    AccessoryItem(name: 'Ribbon\nริบบิ้นผูกคอ', id: 5, type: 'neck'),
    AccessoryItem(name: 'Star Pendant\nสร้อยจี้ดาว', id: 6, type: 'neck'),
    AccessoryItem(name: 'Pink Scarf\nผ้าพันคอสีชมพู', id: 8, type: 'neck'),
    AccessoryItem(name: 'Daisy Chain\nสร้อยดอกเดซี่', id: 9, type: 'neck'),
  ];
  static const List<AccessoryItem> _maleNeck = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'neck'),
    AccessoryItem(name: 'Scarf\nผ้าพันคอ', id: 4, type: 'neck'),
    AccessoryItem(name: 'Gold Chain\nสร้อยทอง', id: 7, type: 'neck'),
    AccessoryItem(name: 'Bow Tie\nหูกระต่าย', id: 10, type: 'neck'),
    AccessoryItem(name: 'Dog Tag\nสร้อยป้ายชื่อ', id: 11, type: 'neck'),
    AccessoryItem(name: 'Headphones\nหูฟังคล้องคอ', id: 12, type: 'neck'),
    AccessoryItem(name: 'Cord\nสร้อยเชือก', id: 13, type: 'neck'),
  ];
  List<AccessoryItem> get neckList =>
      selectedGender == 'male' ? _maleNeck : _femaleNeck;

  static const List<AccessoryItem> _femaleExtra = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'extra'),
    AccessoryItem(name: 'Freckles\nกระบนหน้า', id: 1, type: 'extra'),
    AccessoryItem(name: 'Star Sticker\nสติกเกอร์ดาว', id: 3, type: 'extra'),
    AccessoryItem(name: 'Heart Sticker\nสติกเกอร์หัวใจ', id: 4, type: 'extra'),
    AccessoryItem(name: 'Sparkles\nประกายวิบวับ', id: 5, type: 'extra'),
    AccessoryItem(name: 'Face Gems\nอัญมณีติดหน้า', id: 6, type: 'extra'),
  ];
  static const List<AccessoryItem> _maleExtra = <AccessoryItem>[
    AccessoryItem(name: 'None\nไม่ใส่', id: 0, type: 'extra'),
    AccessoryItem(name: 'Band-Aid\nพลาสเตอร์ยา', id: 2, type: 'extra'),
    AccessoryItem(name: 'Scar\nรอยแผลเป็น', id: 7, type: 'extra'),
    AccessoryItem(name: 'Nose Band-Aid\nพลาสเตอร์แปะจมูก', id: 8, type: 'extra'),
    AccessoryItem(name: 'Eye Black\nแถบดำใต้ตา', id: 9, type: 'extra'),
  ];
  List<AccessoryItem> get extraList =>
      selectedGender == 'male' ? _maleExtra : _femaleExtra;

  List<HairItem> get currentHairStyles =>
      selectedGender == 'male' ? maleHairStyles : femaleHairStyles;
  List<OutfitItem> get currentOutfits =>
      selectedGender == 'male' ? maleOutfits : femaleOutfits;

  // ignore: unused_field
  static const LinearGradient _candyGradient = LinearGradient(
    colors: [
      Color(0xFF4F86FF),
      Color(0xFF3B73F5),
      Color(0xFF2D63E8),
      Color(0xFF2556D6),
    ],
    stops: [0.0, 0.38, 0.72, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // หัวหน้าสไตล์เดียวกับหน้า Check in / ตั้งค่า: ฟ้า 0xFF2F63EA ไล่เฉดแนวทแยง
  // ใช้ทั้งหน้าโปรไฟล์และหน้าต่างแต่งตัว
  static const LinearGradient _headerGradient = LinearGradient(
    colors: [Color(0xFF5B8DFF), Color(0xFF2F63EA), Color(0xFF2556D6)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // (ไม่ได้ใช้แล้ว — คงไว้ตามที่คุณปรับ) ฟ้าไล่เฉดแนวตั้งของ backdrop เดิม
  // ignore: unused_field
  static const LinearGradient _blueSkyGradient = LinearGradient(
    colors: [
      Color.fromARGB(255, 255, 255, 255),
      Color.fromARGB(255, 172, 195, 255),
      Color(0xFF2556D6),
    ],
    stops: [0.0, 0.50, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Bright aqua sky used behind the profile hero (เดิม — ไม่ได้ใช้ในหน้าโปรไฟล์หลักแล้ว).
  // ignore: unused_field
  static const LinearGradient _skyGradient = LinearGradient(
    colors: [
      Color(0xFF4F86FF),
      Color(0xFF3B73F5),
      Color(0xFF2D63E8),
      Color(0xFF2556D6),
    ],
    stops: [0.0, 0.40, 0.75, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Soft shadow that keeps white text readable on the blue background.
  static const List<Shadow> _softTextShadow = [
    Shadow(color: Color(0x730B3C7A), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const LinearGradient _brandGradient = LinearGradient(
    colors: [Color(0xFF4A82FA), Color(0xFF2B5FE0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  BoxDecoration _tileDecoration(bool selected, {Gradient? gradient}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: selected ? (gradient ?? _brandGradient) : null,
      color: selected ? null : Colors.white,
      border: Border.all(
        color: selected ? Colors.white : const Color(0xFFDCE9FF),
        width: 2.5,
      ),
      boxShadow:
          selected
              ? [
                BoxShadow(
                  color: const Color(0xFF2F63EA).withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
              : [
                BoxShadow(
                  color: const Color(0xFF2F63EA).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
    );
  }

  Widget _checkBadge({double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.check_rounded, size: size * 0.66, color: Colors.white),
    );
  }

  Widget _sectionTitle(String text, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD43B), Color(0xFFFFA62B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA62B).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFF26314F),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sheetCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3EBFA), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B73F5).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // ---------- Decorative kid-friendly pieces (UI only) ----------

  // ignore: unused_element
  Widget _cloud(double w, {double opacity = 0.9}) {
    final Color c = Colors.white.withValues(alpha: opacity);
    return SizedBox(
      width: w,
      height: w * 0.55,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: w * 0.32,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(w),
              ),
            ),
          ),
          Positioned(
            bottom: w * 0.14,
            left: w * 0.16,
            child: Container(
              width: w * 0.36,
              height: w * 0.36,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            bottom: w * 0.12,
            right: w * 0.18,
            child: Container(
              width: w * 0.28,
              height: w * 0.28,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }

  // Soft translucent circle used as a cute background bubble.
  // ignore: unused_element
  Widget _softBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  // ignore: unused_element
  Widget _decoStar(double size, {double opacity = 1.0}) {
    return Icon(
      Icons.star_rounded,
      size: size,
      color: const Color(0xFFFFE066).withValues(alpha: opacity),
    );
  }

  // ignore: unused_element
  Widget _letterChip(
    String letter,
    Color color,
    double angle, {
    double size = 38,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.32),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.52,
          ),
        ),
      ),
    );
  }

  // กรอบรูปอวตาร (วงแหวนขาวโปร่งแสงซ้อนชั้น) ใช้ทั้งหน้าโปรไฟล์และหน้าต่างแต่งตัว
  static const double _frameSize = 200;

  Widget _avatarFrame({required double size, required Widget child}) {
    final double inner = size * 0.73;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: const _AvatarFramePainter(),
          ),
          Container(
            width: inner,
            height: inner,
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFBFD8F5), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F2F8C).withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(child: child),
          ),
        ],
      ),
    );
  }

  // ของตกแต่งหัวหน้า: วงกลมโปร่งแสง + แสงลำ เมฆ บล็อก A B E C D ลูกโลก หนังสือบนโต๊ะไม้ และประกายระยิบ
  // (วาดทับสีพื้นของหัวหน้า ไม่ได้ทาสีพื้นใหม่) — ใช้ทั้งหน้าโปรไฟล์และหน้าต่างแต่งตัว
  Widget _headerDecor({required double haloY}) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: _softBubble(220, Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _softBubble(160, Colors.white.withValues(alpha: 0.07)),
            ),
            Positioned.fill(
              child: _ProfileBackdrop(
                hidden: 0,
                haloY: haloY,
                laurelStyle: true,
                skyless: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ตำแหน่งแสงหลังรูปอวตารเทียบกับความสูงของหัวหน้า (ให้ของตกแต่งจัดตามกรอบรูป)
  double _heroHaloY(BuildContext context) {
    final double above = MediaQuery.of(context).padding.top + 10 + 49 + 10;
    final double total = above + _frameSize + 12 + 22 + 8 + 28 + 40;
    return ((above + _frameSize / 2) / total).clamp(0.30, 0.60).toDouble();
  }

  // ignore: unused_element
  Widget _rainbowRing({required double size, required Widget child}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFEFB8),
            Color(0xFFFFFFFF),
            Color(0xFFCDEFFF),
            Color(0xFFFFFFFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFF1B8).withValues(alpha: 0.85),
            blurRadius: 26,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 44,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: const Color(0xFF0F2F8C).withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  // ============================================================
  // SHOP HELPERS (เหรียญ / ล็อก / แลกปลดล็อก)
  // ============================================================

  Future<void> _initShop() async {
    await AvatarProfile.instance.load();
    await _wallet.load(force: true);
    if (mounted) setState(() {});
  }

  void _onWalletChanged() {
    if (mounted) setState(() {});
  }

  Widget _coinPill() {
    return AnimatedBuilder(
      animation: _wallet,
      builder:
          (context, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD43B), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFB627),
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  _coinBalanceLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _priceChip(int price) {
    final bool affordable = (_serverCoinBalance ?? 0) >= price;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: affordable ? const Color(0xFFFFB627) : const Color(0xFFFCA5A5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFB627),
            size: 13,
          ),
          const SizedBox(width: 3),
          Text(
            '$price',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color:
                  affordable
                      ? const Color(0xFFB45309)
                      : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  // ผ้าคลุมสีจางพร้อมแม่กุญแจ + ราคา ใช้ซ้อนบนรูปตัวอย่างของที่ยังไม่ได้ปลดล็อก
  Widget _lockCover(int price, {double radius = 12}) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF64748B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _priceChip(price),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _earnHint() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFEFC2)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD43B), width: 2),
      ),
      child: Row(
        children: [
          const Text('🎮', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'เล่นเกมในแอปเพื่อสะสมเหรียญ แล้วนำมาแลกปลดล็อกชุดและอุปกรณ์ใหม่ ๆ ได้ที่นี่',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.brown.shade700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // แตะไอเทม: ถ้าเป็นของที่ปลดล็อกแล้ว = ใส่ทันที / ถ้ายังล็อก = เปิดหน้าต่างแลกด้วยเหรียญ
  Future<void> _onShopItemTap({
    required String key,
    required int price,
    required String name,
    required CustomPainter Function() previewBuilder,
    required VoidCallback equip,
    required StateSetter setModalState,
    double zoom = 1.0,
    double focusY = 0.0,
  }) async {
    HapticFeedback.selectionClick();
    if (_ownsAvatar(key, price)) {
      equip();
      setModalState(() {});
      return;
    }
    if (!mounted) return;
    final bool? bought = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => _UnlockDialog(
            itemKey: key,
            price: price,
            name: name,
            initialBalance: _serverCoinBalance ?? 0,
            onPurchase: _purchaseAvatar,
            preview: previewBuilder(),
            zoom: zoom,
            focusY: focusY,
          ),
    );
    if (bought == true) equip(); // แลกสำเร็จ → ใส่ให้ทันที
    if (mounted) setModalState(() {});
  }

  AvatarPainter _outfitPainter(OutfitItem outfit) {
    return AvatarPainter(
      gender: selectedGender,
      skinColor: skinTones[selectedSkin],
      hairStyle: selectedHairStyle,
      hairColor: hairColors[selectedHairColor],
      outfit: outfit,
      glassesStyle: selectedGlasses,
      hatStyle: selectedHat,
      clipStyle: selectedClip,
      earringStyle: selectedEarring,
      neckStyle: selectedNeck,
      extraStyle: selectedExtra,
    );
  }

  int get _ownedOutfitCount {
    int n = 0;
    for (int i = 0; i < currentOutfits.length; i++) {
      if (_ownsAvatar(
        ShopCatalog.outfitKey(selectedGender, i),
        ShopCatalog.outfitPrice(selectedGender, i),
      )) {
        n++;
      }
    }
    return n;
  }

  // ============================================================
  // AVATAR CUSTOMIZER SHEET
  // ============================================================

  void _openAvatarCustomizer() {
    int category = 0;
    HapticFeedback.lightImpact();
    _loadRewards();
    _avatarSheetOpen = true;
    _avatarCommitted = false;
    _looks.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // Rebuild the sheet whenever this screen's state changes (e.g. the
        // coin balance finishes loading after the sheet is already open).
        return AnimatedBuilder(
          animation: _sheetRefresh,
          builder: (_, __) => StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.88,
                color: const Color(0xFFEEF3FB),
                child: Column(
                  children: [
                    // ---------- Sky header + live preview ----------
                    Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        gradient: _headerGradient,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 52,
                              // Stack so the title is centred on the whole width,
                              // not just the space left between the two buttons.
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Text(
                                    'แต่งตัวอวตาร',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () => Navigator.pop(sheetContext),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.26,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        margin: const EdgeInsets.only(right: 10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFFB627),
                                              Color(0xFFFF8A3D),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0xFFE56B1F),
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 6,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                22,
                                              ),
                                            ),
                                          ),
                                          onPressed: () {
                                            _avatarCommitted = true;
                                            _avatarSheetOpen = false;
                                            _commitProfile();
                                            Navigator.pop(sheetContext);
                                          },
                                          child: const Text(
                                            'เสร็จสิ้น',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: 268,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // Same header decoration + avatar frame as the profile page
                                  // (light beams, clouds, ABC blocks, globe, book on a desk, sparkles).
                                  _headerDecor(haloY: 0.48),
                                  Align(
                                    alignment: const Alignment(0, -0.16),
                                    child: _avatarFrame(
                                      size: _frameSize,
                                      child: _buildAvatar(
                                        size: _frameSize * 0.665,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    left: 10,
                                    child: _coinPill(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B73F5).withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _categoryButton(
                            icon: Icons.wc_rounded,
                            label: 'เพศ',
                            selected: category == 0,
                            onTap: () => setModalState(() => category = 0),
                          ),
                          _categoryButton(
                            icon: Icons.face_retouching_natural_rounded,
                            label: 'ใบหน้า / ผม',
                            selected: category == 1,
                            onTap: () => setModalState(() => category = 1),
                          ),
                          _categoryButton(
                            icon: Icons.checkroom_rounded,
                            label: 'เสื้อผ้า',
                            selected: category == 2,
                            onTap: () => setModalState(() => category = 2),
                          ),
                          _categoryButton(
                            icon: Icons.style_rounded,
                            label: 'อุปกรณ์',
                            selected: category == 3,
                            onTap: () => setModalState(() => category = 3),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: ValueKey<int>(category),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                        child:
                            category == 0
                                ? _buildGenderCategory(setModalState)
                                : category == 1
                                ? _buildFaceCategory(setModalState)
                                : category == 2
                                ? _buildOutfitCategory(setModalState)
                                : _buildAccessoryCategory(setModalState),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        );
      },
    ).whenComplete(_finishAvatarSheet);
  }

  /// The sheet is closed. Closed with the X, by swiping it down or with the
  /// back button (not "เสร็จสิ้น"): go back to the saved avatar.
  void _finishAvatarSheet() {
    _avatarSheetOpen = false;
    _looks.clear();
    if (_avatarCommitted || !mounted) return;
    setState(_pullFromGlobal);
  }

  /// Switching gender: remember what the old gender wears, and bring back
  /// what the new one wore earlier (a first time starts from the first hair
  /// style and outfit; the items are different for each gender).
  void _switchGender(String gender) {
    _looks[selectedGender] = (
      hairStyle: selectedHairStyle,
      outfit: selectedOutfit,
      glasses: selectedGlasses,
      hat: selectedHat,
      clip: selectedClip,
      earring: selectedEarring,
      neck: selectedNeck,
      extra: selectedExtra,
    );
    selectedGender = gender;
    final _GenderLook? look = _looks[gender];
    selectedHairStyle = look?.hairStyle ?? 0;
    selectedOutfit = look?.outfit ?? 0;
    selectedGlasses = look?.glasses ?? 0;
    selectedHat = look?.hat ?? 0;
    selectedClip = look?.clip ?? 0;
    selectedEarring = look?.earring ?? 0;
    selectedNeck = look?.neck ?? 0;
    selectedExtra = look?.extra ?? 0;
  }

  Widget _categoryButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          // FIX: this used to be Curves.easeOutBack. That curve overshoots past 1.0,
          // so while the shadow faded out its blurRadius went NEGATIVE for a frame
          // and Flutter flashed an error every time you switched category tab.
          // easeOutCubic never overshoots.
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          // Both states now have the SAME shape (one gradient + one shadow), so the
          // animation only blends colours instead of scaling a missing gradient /
          // shadow in and out.
          decoration: BoxDecoration(
            gradient:
                selected
                    ? _brandGradient
                    : const LinearGradient(
                      colors: [Color(0xFFF1F6FF), Color(0xFFF1F6FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF3B73F5,
                ).withValues(alpha: selected ? 0.35 : 0.0),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF8FA3C8),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF8FA3C8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCategory(StateSetter setModalState) {
    Widget genderCard({
      required String gender,
      required IconData icon,
      required String label,
      required List<Color> gradientColors,
    }) {
      final bool isSelected = selectedGender == gender;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (selectedGender == gender) return;
            HapticFeedback.selectionClick();
            setState(() => _switchGender(gender));
            _syncProfile();
            setModalState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 148,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              color: isSelected ? null : Colors.white,
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0xFFDCE9FF),
                width: 2.5,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: gradientColors.first.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
            ),
            child: Stack(
              children: [
                if (isSelected)
                  Positioned(top: 10, right: 10, child: _checkBadge()),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : gradientColors.first.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 30,
                          color:
                              isSelected ? Colors.white : gradientColors.first,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color:
                              isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E1B2E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _sheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('เลือกเพศอวตาร'),
          Row(
            children: [
              genderCard(
                gender: 'female',
                icon: Icons.female_rounded,
                label: 'หญิง',
                gradientColors: const [Color(0xFFFF5FA2), Color(0xFFFF9CC8)],
              ),
              const SizedBox(width: 14),
              genderCard(
                gender: 'male',
                icon: Icons.male_rounded,
                label: 'ชาย',
                gradientColors: const [Color(0xFF3B73F5), Color(0xFF6C9BFF)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatchCircle({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    double size = 46,
  }) {
    final bool isLight =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFFFFB627) : Colors.white,
            width: selected ? 3.5 : 2.5,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: const Color(0xFFFFB627).withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child:
            selected
                ? Icon(
                  Icons.check_rounded,
                  size: size * 0.46,
                  color: isLight ? Colors.black87 : Colors.white,
                )
                : null,
      ),
    );
  }

  Widget _buildFaceCategory(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('สีผิว'),
              SizedBox(
                height: 54,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: skinTones.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder:
                      (context, index) => _swatchCircle(
                        color: skinTones[index],
                        selected: selectedSkin == index,
                        onTap: () {
                          setState(() => selectedSkin = index);
                          _syncProfile();
                          setModalState(() {});
                        },
                      ),
                ),
              ),
              const SizedBox(height: 22),
              _sectionTitle('สีผม'),
              SizedBox(
                height: 54,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: hairColors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder:
                      (context, index) => _swatchCircle(
                        color: hairColors[index],
                        selected: selectedHairColor == index,
                        onTap: () {
                          setState(() => selectedHairColor = index);
                          _syncProfile();
                          setModalState(() {});
                        },
                      ),
                ),
              ),
            ],
          ),
        ),
        _sheetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'ทรงผม',
                trailing: '${currentHairStyles.length} แบบ',
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentHairStyles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemBuilder: (context, index) {
                  final hair = currentHairStyles[index];
                  final bool isSelected = selectedHairStyle == hair.id;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => selectedHairStyle = hair.id);
                      _syncProfile();
                      setModalState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: _tileDecoration(isSelected),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: HairThumbPainter(
                                        hair.id,
                                        hairColors[selectedHairColor],
                                        skinTones[selectedSkin],
                                        selectedGender,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: _checkBadge(size: 17),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hair.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                color:
                                    isSelected
                                        ? const Color(0xFF1D4FD1)
                                        : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutfitCategory(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _earnHint(),
        _sheetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'ชุดแต่งกาย',
                trailing: 'ปลดล็อก $_ownedOutfitCount / ${currentOutfits.length}',
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentOutfits.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.80,
                ),
                itemBuilder: (context, index) {
                  final OutfitItem outfit = currentOutfits[index];
                  final bool isSelected = selectedOutfit == index;
                  final String key = ShopCatalog.outfitKey(
                    selectedGender,
                    index,
                  );
                  final int price = ShopCatalog.outfitPrice(
                    selectedGender,
                    index,
                  );
                  final bool locked = !_ownsAvatar(key, price);
                  return GestureDetector(
                    onTap:
                        () => _onShopItemTap(
                          key: key,
                          price: price,
                          name: outfit.name,
                          previewBuilder: () => _outfitPainter(outfit),
                          equip: () {
                            setState(() => selectedOutfit = index);
                            _syncProfile();
                          },
                          setModalState: setModalState,
                        ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: _tileDecoration(isSelected),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _outfitPainter(outfit),
                                    ),
                                  ),
                                  if (locked) _lockCover(price, radius: 14),
                                  if (isSelected)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: _checkBadge(),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: outfit.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: 0.08),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    outfit.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                      color:
                                          isSelected
                                              ? const Color(0xFF1D4FD1)
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Avatar painter for the current selection, with one accessory slot overridden (used by the tiles).
  AvatarPainter _previewPainter({
    int? glasses,
    int? hat,
    int? clip,
    int? earring,
    int? neck,
    int? extra,
  }) {
    final int safeOutfit =
        selectedOutfit < currentOutfits.length ? selectedOutfit : 0;
    return AvatarPainter(
      gender: selectedGender,
      skinColor: skinTones[selectedSkin],
      hairStyle: selectedHairStyle,
      hairColor: hairColors[selectedHairColor],
      outfit: currentOutfits[safeOutfit],
      glassesStyle: glasses ?? selectedGlasses,
      hatStyle: hat ?? selectedHat,
      clipStyle: clip ?? selectedClip,
      earringStyle: earring ?? selectedEarring,
      neckStyle: neck ?? selectedNeck,
      extraStyle: extra ?? selectedExtra,
    );
  }

  Widget _accessorySection({
    required String title,
    required String type,
    required List<AccessoryItem> items,
    required int selectedId,
    required ValueChanged<int> onSelect,
    required StateSetter setModalState,
    required AvatarPainter Function(int id) painterFor,
    required double zoom,
    required double focusY,
  }) {
    int ownedCount = 0;
    for (final AccessoryItem it in items) {
      if (it.id != 0 &&
          _ownsAvatar(
            ShopCatalog.accKey(type, it.id),
            ShopCatalog.accessoryPrice(type, it.id),
          )) {
        ownedCount++;
      }
    }
    return _sheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title,
            trailing: 'ปลดล็อก $ownedCount / ${items.length - 1}',
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.80,
            ),
            itemBuilder: (context, index) {
              final AccessoryItem item = items[index];
              final bool isSelected = selectedId == item.id;
              final String key = ShopCatalog.accKey(type, item.id);
              final int price = ShopCatalog.accessoryPrice(type, item.id);
              final bool locked = !_ownsAvatar(key, price);
              return GestureDetector(
                onTap:
                    () => _onShopItemTap(
                      key: key,
                      price: price,
                      name: item.name,
                      previewBuilder: () => painterFor(item.id),
                      equip: () => onSelect(item.id),
                      setModalState: setModalState,
                      zoom: zoom,
                      focusY: focusY,
                    ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: _tileDecoration(isSelected),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.fromLTRB(3, 5, 3, 4),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child:
                                    item.id == 0
                                        ? Center(
                                          child: Icon(
                                            Icons.block_rounded,
                                            size: 26,
                                            color: Colors.grey.shade400,
                                          ),
                                        )
                                        : ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Transform.scale(
                                            scale: zoom,
                                            alignment: Alignment(0, focusY),
                                            child: CustomPaint(
                                              painter: painterFor(item.id),
                                            ),
                                          ),
                                        ),
                              ),
                              if (locked) _lockCover(price, radius: 10),
                              if (isSelected)
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: _checkBadge(size: 16),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color:
                                isSelected
                                    ? const Color(0xFF1D4FD1)
                                    : Colors.black54,
                          ),
                        ),
                      ],
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

  Widget _buildAccessoryCategory(StateSetter setModalState) {
    // focusY: where the zoom is centred (-0.28 = head, 0.2 = neck/chest)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _earnHint(),
        _accessorySection(
          title: 'หมวก & ที่คาดผม',
          type: 'hat',
          items: hatList,
          selectedId: selectedHat,
          onSelect:
              (id) => setState(() {
                selectedHat = id;
                _syncProfile();
              }),
          setModalState: setModalState,
          painterFor: (id) => _previewPainter(hat: id),
          zoom: 1.55,
          focusY: -0.42,
        ),
        _accessorySection(
          title: 'แว่นตา',
          type: 'glasses',
          items: glassesList,
          selectedId: selectedGlasses,
          onSelect:
              (id) => setState(() {
                selectedGlasses = id;
                _syncProfile();
              }),
          setModalState: setModalState,
          painterFor: (id) => _previewPainter(glasses: id),
          zoom: 1.7,
          focusY: -0.28,
        ),
        _accessorySection(
          title: 'กิ๊บติดผม',
          type: 'clip',
          items: clipList,
          selectedId: selectedClip,
          onSelect:
              (id) => setState(() {
                selectedClip = id;
                _syncProfile();
              }),
          setModalState: setModalState,
          painterFor: (id) => _previewPainter(clip: id),
          zoom: 1.7,
          focusY: -0.42,
        ),
        _accessorySection(
          title: 'ต่างหู',
          type: 'earring',
          items: earringList,
          selectedId: selectedEarring,
          onSelect:
              (id) => setState(() {
                selectedEarring = id;
                _syncProfile();
              }),
          setModalState: setModalState,
          painterFor: (id) => _previewPainter(earring: id),
          zoom: 1.7,
          focusY: -0.15,
        ),
        _accessorySection(
          title: 'สร้อยคอ & ผ้าพันคอ',
          type: 'neck',
          items: neckList,
          selectedId: selectedNeck,
          onSelect:
              (id) => setState(() {
                selectedNeck = id;
                _syncProfile();
              }),
          setModalState: setModalState,
          painterFor: (id) => _previewPainter(neck: id),
          zoom: 2.3,
          focusY: 0.25,
        ),
        _accessorySection(
          title: 'สติกเกอร์ & แต่งหน้า',
          type: 'extra',
          items: extraList,
          selectedId: selectedExtra,
          onSelect:
              (id) => setState(() {
                selectedExtra = id;
                _syncProfile();
              }),
          setModalState: setModalState,
          painterFor: (id) => _previewPainter(extra: id),
          zoom: 1.9,
          focusY: -0.1,
        ),
      ],
    );
  }

  Widget _buildAvatar({double size = 165}) {
    final safeOutfitIndex =
        selectedOutfit < currentOutfits.length ? selectedOutfit : 0;
    final String signature =
        '$selectedGender-$selectedSkin-$selectedHairStyle-$selectedHairColor-$safeOutfitIndex-$selectedGlasses-$selectedHat-$selectedClip-$selectedEarring-$selectedNeck-$selectedExtra';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder:
          (child, animation) => ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: animation, child: child),
          ),
      child: SizedBox(
        key: ValueKey(signature),
        width: size,
        height: size,
        child: CustomPaint(
          painter: AvatarPainter(
            gender: selectedGender,
            skinColor: skinTones[selectedSkin],
            hairStyle: selectedHairStyle,
            hairColor: hairColors[selectedHairColor],
            outfit: currentOutfits[safeOutfitIndex],
            glassesStyle: selectedGlasses,
            hatStyle: selectedHat,
            clipStyle: selectedClip,
            earringStyle: selectedEarring,
            neckStyle: selectedNeck,
            extraStyle: selectedExtra,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3FB),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Header (สไตล์เดียวกับหน้า Check in / ตั้งค่า) ----------
              Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: _headerGradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F63EA).withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    _headerDecor(haloY: _heroHaloY(context)),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello !',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        shadows: _softTextShadow,
                                      ),
                                    ),
                                    Text(
                                      _profile?.name ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        shadows: _softTextShadow,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Coins are shown in "My Avatar" below, so no
                                // coin pill here. The dress-up button stands
                                // out in the same orange as the edit badge.
                                InkWell(
                                  onTap: _openAvatarCustomizer,
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFFB627),
                                          Color(0xFFFF8A3D),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFE65100).withValues(alpha: 0.45),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.checkroom_rounded,
                                      color: Colors.white,
                                      size: 23,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _avatarFrame(
                                  size: _frameSize,
                                  child: _buildAvatar(size: _frameSize * 0.665),
                                ),
                                Positioned(
                                  bottom: 22,
                                  right: 22,
                                  child: GestureDetector(
                                    onTap: _openAvatarCustomizer,
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFB627),
                                            Color(0xFFFF8A3D),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 
                                              0.20,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _profile?.email ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: _softTextShadow,
                              ),
                            ),
                            if (_profile?.createdAt != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'เข้าร่วมเมื่อ ${_formatJoinedDate(_profile!.createdAt!)}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- เนื้อหา: การ์ดขาวโค้งมนแบบเดียวกับหน้า Check in / ตั้งค่า ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customize CTA (chunky game-style button)
                    InkWell(
                      onTap: _openAvatarCustomizer,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB03D), Color(0xFFFF8A00)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 1.5,
                          ),
                          boxShadow: [
                            const BoxShadow(
                              color: Color(0xFFE57A00),
                              offset: Offset(0, 5),
                            ),
                            BoxShadow(
                              color: const Color(0xFFFF8A00).withValues(alpha: 0.38),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'แต่งตัวอวตารของคุณ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x40B45309),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'เล่นเกมเก็บเหรียญ แล้วแลกชุดใหม่ได้เลย',
                                    style: TextStyle(
                                      color: Color(0xF2FFFFFF),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _avatarInfoCard(),
                    const SizedBox(height: 26),

                    _zoneTitle(Icons.badge_rounded, 'ข้อมูลบัญชี'),
                    if (_isProfileLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text('กำลังโหลดข้อมูลบัญชี...'),
                            ],
                          ),
                        ),
                      )
                    else if (_profileError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_profileError!),
                            TextButton.icon(
                              onPressed: _loadProfile,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('ลองอีกครั้ง'),
                            ),
                          ],
                        ),
                      )
                    else if (_profile != null) ...[
                      _accountRow(
                        icon: Icons.person_rounded,
                        label: 'ชื่อ',
                        value: _profile!.name,
                        color: const Color(0xFFFF8A3D),
                      ),
                      const SizedBox(height: 12),
                      _accountRow(
                        icon: Icons.phone_rounded,
                        label: 'เบอร์โทรศัพท์',
                        value: _profile!.phone ?? 'ยังไม่ได้เพิ่ม',
                        color: const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(height: 12),
                      _accountRow(
                        icon: Icons.email_rounded,
                        label: 'อีเมล',
                        value: _profile!.email,
                        color: const Color(0xFF3B73F5),
                      ),
                      if (_profile!.createdAt != null) ...[
                        const SizedBox(height: 12),
                        _accountRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'วันที่เข้าร่วม',
                          value: _formatJoinedDate(_profile!.createdAt!),
                          color: const Color(0xFF22B573),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _openEditProfile,
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text(
                            'แก้ไขข้อมูลส่วนตัว',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B73F5),
                            side: const BorderSide(
                              color: Color(0xFF3B73F5),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromARGB(255, 0, 68, 255),
        unselectedItemColor: const Color(0xFF94A3B8),
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CheckInScreen()),
            );
          }
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SettingScreen()),
            );
          }
          if (index == 3) setState(() => currentIndex = 3);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "หน้าหลัก",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            label: "เช็คอิน",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: "ตั้งค่า",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "โปรไฟล์",
          ),
        ],
      ),
    );
  }

  // การ์ดข้อมูลอวตาร (สไตล์เดียวกับการ์ด Day Streak ในหน้า Check in)
  Widget _avatarInfoCard() {
    final OutfitItem outfit =
        currentOutfits[selectedOutfit < currentOutfits.length
            ? selectedOutfit
            : 0];
    final bool female = selectedGender == 'female';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F63EA).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _wallet,
        builder:
            (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.face_retouching_natural_rounded,
                        color: Color(0xFF3B73F5),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Avatar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1F2B52),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'ข้อมูลอวตารของคุณ',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7794),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _pastelChip(
                        icon: Icon(
                          female ? Icons.female_rounded : Icons.male_rounded,
                          size: 20,
                          color:
                              female
                                  ? const Color(0xFFFF5FA2)
                                  : const Color(0xFF3B73F5),
                        ),
                        value: female ? 'หญิง' : 'ชาย',
                        label: 'เพศอวตาร',
                        bg:
                            female
                                ? const Color(0xFFFFE9F2)
                                : const Color(0xFFE8EEFF),
                        valueColor:
                            female
                                ? const Color(0xFFD6336C)
                                : const Color(0xFF2F63EA),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _pastelChip(
                        icon: const Icon(
                          Icons.monetization_on_rounded,
                          size: 20,
                          color: Color(0xFFFFB627),
                        ),
                        value: _coinBalanceLabel,
                        label: 'เหรียญสะสม',
                        bg: const Color(0xFFFFF3D6),
                        valueColor: const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _pastelChip(
                        icon: const Icon(
                          Icons.lock_open_rounded,
                          size: 20,
                          color: Color(0xFF22C55E),
                        ),
                        value: '$_ownedOutfitCount / ${currentOutfits.length}',
                        label: 'ชุดที่ปลดล็อก',
                        bg: const Color(0xFFE3F8EA),
                        valueColor: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
                if (_coinBalanceError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _loadRewards,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('โหลด Coins อีกครั้ง'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.checkroom_rounded,
                          color: Color(0xFFFF9F1C),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ชุดปัจจุบัน',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5B6785),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              outfit.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1F2B52),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  // ชิปสีพาสเทล (เหมือนชิปสถิติในการ์ด Day Streak)
  Widget _pastelChip({
    required Widget icon,
    required String value,
    required String label,
    required Color bg,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: valueColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B6785),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // หัวข้อโซน (สไตล์เดียวกับ "โซนผู้ปกครอง" ในหน้าตั้งค่า)
  Widget _zoneTitle(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3B73F5), size: 24),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFF1F2B52),
            ),
          ),
        ],
      ),
    );
  }

  // การ์ดขอบสี + ไอคอนในกรอบพาสเทล (สไตล์เดียวกับการ์ดในหน้าตั้งค่า)
  Widget _accountRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F2B52),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7794),
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
