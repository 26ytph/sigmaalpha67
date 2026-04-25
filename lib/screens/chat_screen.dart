import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';

class ChatMessage {
  ChatMessage({required this.text, required this.fromUser, required this.time});

  final String text;
  final bool fromUser;
  final DateTime time;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: '嗨，我是 EmploYA 小幫手。想聊聊職涯方向、面試準備、或計畫怎麼推進都可以！',
      fromUser: false,
      time: DateTime.now(),
    ),
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  bool _typing = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  String _mockReply(String prompt) {
    final p = prompt.toLowerCase();
    if (p.contains('面試') || p.contains('interview')) {
      return '面試前先把履歷上的每個專案濃縮成 30 秒版本，並準備 1 個量化成果（例如「將處理時間縮短 40%」）。要我幫你列幾個常見問題嗎？';
    }
    if (p.contains('履歷') || p.contains('resume') || p.contains('cv')) {
      return '一頁式履歷的關鍵：用動詞開頭、加數字、把最近最相關的經驗放最上面。需要我看哪一段？';
    }
    if (p.contains('計畫') || p.contains('plan') || p.contains('todo')) {
      return '可以從「計畫」分頁的 4–8 週清單開始，挑一週先完成 1 個小任務累積動能，比一次塞滿更容易持續。';
    }
    if (p.contains('興趣') || p.contains('探索') || p.contains('方向')) {
      return '不確定方向時，建議到「探索」分頁滑 20 張卡，把按 ❤ 的職位列出來，再看共同的關鍵字 — 那通常就是你的興趣輪廓。';
    }
    if (p.contains('壓力') || p.contains('焦慮') || p.contains('迷惘')) {
      return '迷惘很正常。把你今天能做的事縮到最小一步：寫下 1 件想釐清的事 + 1 個可以問的人，先動起來再說。';
    }
    if (p.contains('你好') ||
        p.contains('hi') ||
        p.contains('hello') ||
        p.contains('哈囉')) {
      return '哈囉！想從哪裡開始？我可以陪你想方向、整理履歷、或拆解計畫。';
    }
    const fallbacks = [
      '可以再多說一點嗎？例如你目前卡在哪個階段？',
      '我先記下這個方向。你希望今天就動手做一件小事，還是先想清楚再行動？',
      '聽起來值得拆成幾個小步驟。要不要一起列出第一步？',
      '不錯的問題。先問自己：3 個月後若這件事完成，會長什麼樣子？',
    ];
    return fallbacks[_random.nextInt(fallbacks.length)];
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _typing) return;
    setState(() {
      _messages.add(
        ChatMessage(text: text, fromUser: true, time: DateTime.now()),
      );
      _typing = true;
      _controller.clear();
    });
    _scrollToBottom();

    await Future.delayed(Duration(milliseconds: 600 + _random.nextInt(500)));
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          text: _mockReply(text),
          fromUser: false,
          time: DateTime.now(),
        ),
      );
      _typing = false;
    });
    _scrollToBottom();
  }

  void _clear() {
    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            text: '已清空對話。想聊什麼？',
            fromUser: false,
            time: DateTime.now(),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withValues(alpha: 0.85),
        border: const Border(bottom: BorderSide(color: Color(0x1A000000))),
        middle: const Text('AI 小幫手'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _messages.length <= 1 ? null : _clear,
          child: const Text('清空', style: TextStyle(fontSize: 15)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                itemCount: _messages.length + (_typing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_typing && index == _messages.length) {
                    return const _TypingBubble();
                  }
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),
            _Composer(
              controller: _controller,
              onSend: _send,
              enabled: !_typing,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    final align = fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = fromUser ? const Color(0xFF18181B) : CupertinoColors.white;
    final fg = fromUser ? CupertinoColors.white : const Color(0xFF18181B);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(fromUser ? 18 : 4),
      bottomRight: Radius.circular(fromUser ? 4 : 18),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: fromUser
                  ? null
                  : Border.all(color: const Color(0x1A000000)),
              boxShadow: fromUser
                  ? null
                  : const [
                      BoxShadow(
                        blurRadius: 12,
                        offset: Offset(0, 4),
                        color: Color(0x14020617),
                      ),
                    ],
            ),
            child: Text(
              message.text,
              style: TextStyle(fontSize: 15, height: 1.45, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: const Color(0x1A000000)),
          ),
          child: AnimatedBuilder(
            animation: _ac,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_ac.value + i / 3) % 1.0;
                  final scale = 0.6 + 0.4 * (1 - (t * 2 - 1).abs());
                  return Padding(
                    padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                    child: Opacity(
                      opacity: 0.4 + 0.6 * scale,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF52525B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: const Border(top: BorderSide(color: Color(0x1A000000))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              enabled: enabled,
              placeholder: '輸入訊息…',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x1A000000)),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF18181B),
            disabledColor: const Color(0xFFA1A1AA),
            borderRadius: BorderRadius.circular(20),
            onPressed: enabled ? onSend : null,
            child: const Icon(
              CupertinoIcons.arrow_up,
              color: CupertinoColors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
