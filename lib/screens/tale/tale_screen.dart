import 'package:flutter/material.dart';

import 'favorites_screen.dart';
import 'tale_catalog.dart';
import 'tale_api_service.dart';
import 'tale_card.dart';

class TaleScreen extends StatefulWidget {
  const TaleScreen({super.key});

  @override
  State<TaleScreen> createState() => _TaleScreenState();
}

class _TaleScreenState extends State<TaleScreen> {
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

  Future<void> _toggleFavorite(TaleItem tale) async {
    final taleId = tale.id;
    if (taleId == null || _updating.contains(taleId)) {
      _showError('ไม่พบรหัสนิทาน จึงไม่สามารถบันทึกรายการโปรดได้');
      return;
    }
    final wasFavorite = _favorites.contains(taleId);
    setState(() => _updating.add(taleId));
    try {
      if (wasFavorite) {
        await TaleApiService.removeFavorite(taleId);
      } else {
        await TaleApiService.addFavorite(taleId);
      }
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favorites.remove(taleId);
        } else {
          _favorites.add(taleId);
        }
      });
    } catch (_) {
      if (mounted) _showError('บันทึกรายการโปรดไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _updating.remove(taleId));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openFavorites() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
    if (mounted) _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF8B5CF6);
    const background = Color(0xFFF3E8FF);
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
        title: const Text('นิทาน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
        actions: [
          IconButton(
            tooltip: 'รายการโปรด',
            onPressed: _openFavorites,
            icon: const Icon(Icons.favorite_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              Container(width: 4, height: 18, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              const Expanded(child: Text('เลือกนิทานที่คุณชอบ', style: TextStyle(fontSize: 17.5, color: Color(0xFF475569), fontWeight: FontWeight.w900))),
            ]),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: primary)))
          else if (_loadError != null)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_loadError!, textAlign: TextAlign.center), const SizedBox(height: 8), FilledButton(onPressed: _loadFavorites, child: const Text('ลองอีกครั้ง'))])))
          else
            Expanded(
              child: ListView.builder(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                itemCount: taleItems.length,
                itemBuilder: (context, index) {
                  final tale = taleItems[index];
                  return TaleCard(
                    tale: tale,
                    isFavorite: tale.id != null && _favorites.contains(tale.id),
                    isUpdatingFavorite: tale.id != null && _updating.contains(tale.id),
                    onToggleFavorite: () => _toggleFavorite(tale),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
