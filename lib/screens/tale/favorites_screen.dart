import 'package:flutter/material.dart';

import 'tale_api_service.dart';
import 'tale_card.dart';
import 'tale_catalog.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Set<String> _favorites = {};
  bool _isLoading = true;
  String? _loadError;
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final favorites = await TaleApiService.getFavorites();
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'โหลดรายการโปรดไม่สำเร็จ กรุณาลองอีกครั้ง';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(TaleItem tale) async {
    final taleId = tale.id;
    if (taleId == null || _updating.contains(taleId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรหัสนิทาน จึงไม่สามารถแก้ไขรายการโปรดได้')),
      );
      return;
    }
    setState(() => _updating.add(taleId));
    try {
      await TaleApiService.removeFavorite(taleId);
      if (!mounted) return;
      setState(() => _favorites.remove(taleId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('นำออกจากรายการโปรดไม่สำเร็จ กรุณาลองอีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(taleId));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF8B5CF6);
    const background = Color(0xFFF3E8FF);
    final favoriteTales = taleItems
        .where((tale) => tale.id != null && _favorites.contains(tale.id))
        .toList();
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 1.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('รายการโปรด', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_loadError!, textAlign: TextAlign.center), const SizedBox(height: 8), FilledButton(onPressed: _loadFavorites, child: const Text('ลองอีกครั้ง'))])))
              : favoriteTales.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.favorite_border_rounded, size: 56, color: primary), SizedBox(height: 12), Text('ยังไม่มีนิทานในรายการโปรด', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF475569)))])))
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                      itemCount: favoriteTales.length,
                      itemBuilder: (context, index) {
                        final tale = favoriteTales[index];
                        return TaleCard(
                          tale: tale,
                          isFavorite: true,
                          isUpdatingFavorite: tale.id != null && _updating.contains(tale.id),
                          onToggleFavorite: () => _removeFavorite(tale),
                        );
                      },
                    ),
    );
  }
}
