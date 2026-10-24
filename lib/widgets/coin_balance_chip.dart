import 'package:flutter/material.dart';

import '../services/coin_balance.dart';

/// Small "🪙 123" pill for the top bar of game screens.
class CoinBalanceChip extends StatefulWidget {
  const CoinBalanceChip({super.key});

  /// Fixed width, so a centred title next to it stays centred.
  static const double width = 76;

  @override
  State<CoinBalanceChip> createState() => _CoinBalanceChipState();
}

class _CoinBalanceChipState extends State<CoinBalanceChip> {
  @override
  void initState() {
    super.initState();
    CoinBalance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: CoinBalance.refresh,
      child: Container(
        width: CoinBalanceChip.width,
        height: 32,
        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.monetization_on_rounded,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: ValueListenableBuilder<int?>(
                valueListenable: CoinBalance.value,
                builder:
                    (context, balance, _) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        balance == null ? '-' : '$balance',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
