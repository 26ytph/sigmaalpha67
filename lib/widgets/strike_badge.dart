import 'package:flutter/cupertino.dart';

class StrikeBadge extends StatelessWidget {
  const StrikeBadge({super.key, required this.strike});

  final int strike;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(0, 4), color: Color(0x14020617)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '$strike',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          const Text('streak', style: TextStyle(color: Color(0xFF52525B))),
        ],
      ),
    );
  }
}
