import 'package:flutter/cupertino.dart';

import '../models/models.dart';

class DailyQuestionCard extends StatelessWidget {
  const DailyQuestionCard({
    super.key,
    required this.question,
    this.answered,
    required this.onAnswer,
  });

  final DailyQuestion question;
  final DailyAnswerEntry? answered;
  final void Function(DailyAnswerValue value) onAnswer;

  @override
  Widget build(BuildContext context) {
    final done = answered != null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 36,
            offset: Offset(0, 24),
            color: Color(0x1F020617),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '職涯小問題',
                      style: TextStyle(fontSize: 13, color: Color(0xFF52525B)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '今天你想探索什麼？',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: const Text(
                  '每天一題，累積 streak',
                  style: TextStyle(fontSize: 11, color: Color(0xFF3F3F46)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('題目', style: TextStyle(fontSize: 13, color: Color(0xFF52525B))),
                const SizedBox(height: 8),
                Text(
                  question.text,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              for (var i = 0; i < question.options.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _OptionButton(
                          label: question.options[i],
                          selected: done && answered!.answer == question.options[i],
                          dimmed: done && answered!.answer != question.options[i],
                          enabled: !done,
                          onPressed: () => onAnswer(question.options[i]),
                        ),
                      ),
                      if (i + 1 < question.options.length) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OptionButton(
                            label: question.options[i + 1],
                            selected: done && answered!.answer == question.options[i + 1],
                            dimmed: done && answered!.answer != question.options[i + 1],
                            enabled: !done,
                            onPressed: () => onAnswer(question.options[i + 1]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          if (done) ...[
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF3F3F46)),
                children: [
                  const TextSpan(text: '你今天的答案是：'),
                  TextSpan(
                    text: answered!.answer,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF18181B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: const Text('A', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: Text(
                      question.answer,
                      style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF18181B)),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '作答後會自動計入今日 streak。',
                style: TextStyle(fontSize: 11, color: Color(0xFF52525B)),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool dimmed;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled ? onPressed : null,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? CupertinoColors.black : CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: dimmed ? const Color(0xFF52525B) : (selected ? CupertinoColors.white : CupertinoColors.black),
          ),
        ),
      ),
    );
  }
}
