import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/counselor_brief.dart';
import '../logic/intent_normalizer.dart';
import '../models/models.dart';
import '../services/app_repository.dart';
import '../services/backend_api.dart';
import '../services/supabase_config.dart';
import '../utils/theme.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.fromUser,
    required this.time,
    this.id,
    this.normalized,
    this.askedHandoff = false,
    this.byCounselor = false,
    this.sources = const [],
  });

  /// 對應 supabase chat_messages.id (uuid)。本機 optimistic 訊息一開始是 null，
  /// realtime 事件回來後會被 _claimOptimistic 補上 id 以便後續去重。
  String? id;
  final String text;
  final bool fromUser;
  final DateTime time;
  final NormalizedQuestion? normalized;
  final bool askedHandoff;
  /// 這則訊息是真人諮詢師發的（透過 case reply）。Bubble 會多一個「諮詢師」徽章。
  final bool byCounselor;
  final List<RagSource> sources;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.storage});

  final AppStorage storage;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late List<ChatMessage> _messages;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  String? _conversationId;
  bool _typing = false;
  DateTime? _cooldownUntil;
  static const Duration _sendCooldown = Duration(milliseconds: 1500);
  static const String _convIdPrefsKey = 'employa.chat.conversationId';

  // realtime 去重：已經渲染過的 chat_messages.id 都進這個 set。
  final Set<String> _seenIds = <String>{};
  RealtimeChannel? _msgChannel;
  String? _subscribedConvId;

  bool get _onCooldown =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  @override
  void initState() {
    super.initState();
    _messages = [_greeting()];
    _bootstrap();
  }

  /// 開啟 chat 時：
  /// 1. 從本機 SharedPreferences 撈出之前用過的 conversationId
  /// 2. 如果沒有，去後端 `GET /api/chat/conversations` 拿最新一段對話的 id
  /// 3. 用 conversationId 去後端 `GET /api/chat/conversations/{id}/messages`
  ///    把訊息 hydrate 進 `_messages`，這樣換裝置／清快取也看得到歷史。
  Future<void> _bootstrap() async {
    await _restoreConversationId();
    var convId = _conversationId;

    // 沒有本機 id → 看後端有沒有歷史對話
    if (convId == null || convId.isEmpty) {
      try {
        final list = await BackendApi.listConversations();
        if (list.isNotEmpty) {
          convId = list.first.id;
          unawaited(_persistConversationId(convId));
          if (mounted) setState(() => _conversationId = convId);
        }
      } catch (_) {}
    }

    if (convId == null || convId.isEmpty) return;

    // 有 id 就把整段歷史撈回來顯示
    try {
      final history = await BackendApi.fetchConversationMessages(convId);
      if (history != null && history.messages.isNotEmpty && mounted) {
        setState(() {
          _messages
            ..clear()
            // 之前的訊息不需要重新跑 IntentNormalizer（也沒有 normalized 結果），
            // 直接用內容渲染就好。
            ..addAll(history.messages.map(_remoteToLocal));
        });
        for (final m in history.messages) {
          _seenIds.add(m.id);
        }
        _scrollToBottom();
      }
    } catch (_) {
      // 撈不到就保留原本的 greeting，使用者體感是新對話。
    }

    _subscribeRealtime(convId);
  }

  ChatMessage _remoteToLocal(RemoteChatMessage m) {
    final created = DateTime.tryParse(m.createdAt) ?? DateTime.now();
    return ChatMessage(
      id: m.id,
      text: m.text,
      fromUser: m.fromUser,
      time: created,
      byCounselor: m.byCounselor,
    );
  }

  // ---------------------------------------------------------------------------
  // Realtime — 訂閱 supabase chat_messages 的 INSERT，
  //   收到自己／別台裝置寫入的新訊息就即時刷新 chatbox。
  // ---------------------------------------------------------------------------
  void _subscribeRealtime(String convId) {
    if (!SupabaseConfig.isConfigured) return;
    if (_subscribedConvId == convId && _msgChannel != null) return;
    _teardownRealtime();

    final supa = Supabase.instance.client;
    final channel = supa.channel('chat_messages:$convId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: convId,
        ),
        callback: (payload) => _onRealtimeInsert(payload.newRecord),
      )
      ..subscribe();

    _msgChannel = channel;
    _subscribedConvId = convId;
  }

  void _teardownRealtime() {
    final ch = _msgChannel;
    if (ch != null) {
      try {
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
    }
    _msgChannel = null;
    _subscribedConvId = null;
  }

  void _onRealtimeInsert(Map<String, dynamic> row) {
    final id = row['id'] as String?;
    final sender = row['sender'] as String?;
    final content = row['content'] as String?;
    if (id == null || sender == null || content == null) return;
    if (_seenIds.contains(id)) return;

    final fromUser = sender == 'user';
    final byCounselor = row['by_counselor'] == true;
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now();

    // 嘗試把這個 id 綁到本機剛剛 optimistic 加上去的訊息上（避免 user 自己送的訊息被 dup）。
    // 諮詢師訊息一定是 server-only — 不會有對應的 optimistic bubble，所以跳過 claim 直接 append。
    if (!byCounselor) {
      final claimed = _claimOptimistic(
        id: id,
        fromUser: fromUser,
        content: content,
        createdAt: created,
      );
      if (claimed) {
        _seenIds.add(id);
        return;
      }
    }

    // 真的是新訊息（諮詢師回覆 / 另一台裝置同步過來）→ append + 滑到底。
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          id: id,
          text: content,
          fromUser: fromUser,
          time: created,
          byCounselor: byCounselor,
        ),
      );
    });
    _seenIds.add(id);
    _scrollToBottom();
  }

  bool _claimOptimistic({
    required String id,
    required bool fromUser,
    required String content,
    required DateTime createdAt,
  }) {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.id != null) continue;
      if (m.fromUser != fromUser) continue;
      if (m.text != content) continue;
      if (m.time.difference(createdAt).abs() > const Duration(seconds: 30)) {
        continue;
      }
      m.id = id;
      return true;
    }
    return false;
  }

  Future<void> _restoreConversationId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_convIdPrefsKey);
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => _conversationId = saved);
      }
    } catch (_) {}
  }

  Future<void> _persistConversationId(String? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null || id.isEmpty) {
        await prefs.remove(_convIdPrefsKey);
      } else {
        await prefs.setString(_convIdPrefsKey, id);
      }
    } catch (_) {}
  }

  ChatMessage _greeting() {
    final name = widget.storage.profile.name;
    final greet = name.isNotEmpty
        ? '嗨 $name！我是 EmploYA 小幫手。想聊職涯方向、面試、創業或心情都可以。'
        : '嗨，我是 EmploYA 小幫手。想聊聊職涯方向、面試準備、或計畫怎麼推進都可以！';
    return ChatMessage(text: greet, fromUser: false, time: DateTime.now());
  }

  @override
  void dispose() {
    _teardownRealtime();
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

  String _mockReply(String prompt, NormalizedQuestion n) {
    final p = prompt.toLowerCase();
    if (p.contains('面試') || p.contains('interview')) {
      return '面試前先把履歷上的每個專案濃縮成 30 秒版本，並準備 1 個量化成果（例如「將處理時間縮短 40%」）。要我幫你列幾個常見問題嗎？';
    }
    if (p.contains('履歷') || p.contains('resume') || p.contains('cv')) {
      return '一頁式履歷的關鍵：用動詞開頭、加數字、把最近最相關的經驗放最上面。需要我幫你看哪一段？也可以到「技能翻譯」把生活經驗轉成可放履歷的句子。';
    }
    if (p.contains('計畫') || p.contains('plan') || p.contains('todo')) {
      return '可以從「計畫」分頁的 4–8 週清單開始，挑一週先完成 1 個小任務累積動能，比一次塞滿更容易持續。';
    }
    if (p.contains('興趣') ||
        p.contains('探索') ||
        p.contains('方向') ||
        p.contains('迷惘')) {
      return '不確定方向時，建議到「探索」分頁滑 20 張卡，把按 ❤ 的職位列出來，再看共同的關鍵字 — 那通常就是你的興趣輪廓。Persona 也會跟著更新。';
    }
    if (p.contains('創業') || p.contains('開店') || p.contains('做生意')) {
      return '如果是早期想法，可以先用一頁紙寫清楚：受眾／價值／驗證方式。資金面可以查青年創業貸款與政府補助。要我幫你拆成 To-do 嗎？';
    }
    if (p.contains('壓力') || p.contains('焦慮') || p.contains('累')) {
      return '聽起來最近真的有點累，先深呼吸一下。把今天能做的事縮到最小一步：寫下 1 件想釐清的事 + 1 個可以問的人，先動起來再說。';
    }
    if (p.contains('你好') ||
        p.contains('hi') ||
        p.contains('hello') ||
        p.contains('哈囉')) {
      return '哈囉！想從哪裡開始？我可以陪你想方向、整理履歷、拆解計畫，或聊聊心情。';
    }
    if (n.intents.contains('資源／政策')) {
      return '資源面我可以先幫你列：青年職涯諮詢、創業貸款、補助公告。要不要把你的條件告訴我，我幫你篩出最相關的幾個？';
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
    if (text.isEmpty || _typing || _onCooldown) return;

    final normalized = IntentNormalizer.normalize(
      question: text,
      profile: widget.storage.profile,
    );

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          fromUser: true,
          time: DateTime.now(),
          normalized: normalized,
        ),
      );
      _typing = true;
      _controller.clear();
    });
    _scrollToBottom();

    String reply;
    bool shouldHandoff;
    String? assistantId;
    List<RagSource> sources = const [];
    Duration cooldown = _sendCooldown;
    try {
      final remote = await AppRepository.sendChatMessage(
        conversationId: _conversationId,
        message: text,
        mode: widget.storage.profile.mode,
      );
      final nextConvId = remote.conversationId ?? _conversationId;
      if (nextConvId != null && nextConvId != _conversationId) {
        unawaited(_persistConversationId(nextConvId));
        // 第一次拿到 conversationId 之後才能訂閱 realtime channel。
        _subscribeRealtime(nextConvId);
      }
      _conversationId = nextConvId;
      reply = remote.reply;
      sources = remote.sources;
      shouldHandoff = remote.shouldHandoff;
      assistantId = remote.messageId;
      // 後端回傳的 messageId 是 assistant reply 的 id；先收進 seen set，
      // realtime 過幾百毫秒後會 echo 回來，會被直接過濾掉。
      if (assistantId != null && assistantId.isNotEmpty) {
        _seenIds.add(assistantId);
      }
    } on BackendApiException catch (e) {
      if (e.isRateLimited) {
        final waitMs = e.retryAfterMs ?? 5000;
        cooldown = Duration(milliseconds: waitMs);
        final secs = (waitMs / 1000).ceil();
        reply = '一下子問太多囉～請等 $secs 秒再試一次喔。'
            '（為了避免 LLM 配額被打爆，每分鐘限制 30 則訊息）';
        shouldHandoff = false;
      } else {
        await Future.delayed(
          Duration(milliseconds: 600 + _random.nextInt(500)),
        );
        reply = _mockReply(text, normalized);
        shouldHandoff =
            normalized.urgency == '高' ||
            normalized.urgency == '中高' ||
            normalized.intents.length >= 2;
      }
    } catch (_) {
      await Future.delayed(Duration(milliseconds: 600 + _random.nextInt(500)));
      reply = _mockReply(text, normalized);
      shouldHandoff =
          normalized.urgency == '高' ||
          normalized.urgency == '中高' ||
          normalized.intents.length >= 2;
    }
    if (!mounted) return;

    setState(() {
      _messages.add(
        ChatMessage(
          id: assistantId,
          text: reply,
          fromUser: false,
          time: DateTime.now(),
          askedHandoff: shouldHandoff,
          sources: sources,
        ),
      );
      _typing = false;
      _cooldownUntil = DateTime.now().add(cooldown);
    });
    _scrollToBottom();

    Future.delayed(cooldown, () {
      if (mounted) setState(() {});
    });
  }

  void _showCounselorBrief(ChatMessage userMsg) {
    final n = userMsg.normalized;
    if (n == null) return;
    final brief = CounselorBriefEngine.build(
      profile: widget.storage.profile,
      persona: widget.storage.persona,
      explore: widget.storage.explore,
      normalized: n,
      originalQuestion: userMsg.text,
    );

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _CounselorBriefSheet(brief: brief),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bg,
      navigationBar: CupertinoNavigationBar(
        // Always-mounted tab inside AppShell's IndexedStack. Opt out of
        // route hero so it doesn't collide with sibling tab nav bars
        // when another route is pushed/popped over AppShell.
        transitionBetweenRoutes: false,
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        middle: const Text(
          'YAYA - AI 職涯小助理',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
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
                  vertical: 14,
                ),
                itemCount: _messages.length + (_typing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_typing && index == _messages.length) {
                    return const _TypingBubble();
                  }
                  final m = _messages[index];
                  if (!m.fromUser && m.askedHandoff) {
                    final prevUser = _findPrevUser(index);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MessageBubble(message: m),
                        if (prevUser != null)
                          _HandoffPrompt(
                            onTap: () => _showCounselorBrief(prevUser),
                          ),
                      ],
                    );
                  }
                  return _MessageBubble(message: m);
                },
              ),
            ),
            _Composer(
              controller: _controller,
              onSend: _send,
              enabled: !_typing && !_onCooldown,
            ),
          ],
        ),
      ),
    );
  }

  ChatMessage? _findPrevUser(int idx) {
    for (var i = idx - 1; i >= 0; i--) {
      if (_messages[i].fromUser) return _messages[i];
    }
    return null;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    final byCounselor = !fromUser && message.byCounselor;
    final align = fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(fromUser ? 20 : 4),
      bottomRight: Radius.circular(fromUser ? 4 : 20),
    );

    final decoration = fromUser
        ? BoxDecoration(gradient: AppColors.brandGradient, borderRadius: radius)
        : BoxDecoration(
            color: byCounselor ? AppColors.bgAlt : AppColors.surface,
            borderRadius: radius,
            border: Border.all(
              color: byCounselor ? AppColors.brandStart : AppColors.border,
              width: byCounselor ? 1.2 : 1,
            ),
            boxShadow: AppColors.shadowSoft,
          );

    final hasSources = !fromUser && message.sources.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Column(
            crossAxisAlignment: fromUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (byCounselor) ...[
                const _CounselorBadge(),
                const SizedBox(height: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: decoration,
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: fromUser
                        ? CupertinoColors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (hasSources) ...[
                const SizedBox(height: 6),
                _SourceChips(sources: message.sources),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CounselorBadge extends StatelessWidget {
  const _CounselorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.person_2_fill,
            size: 10,
            color: CupertinoColors.white,
          ),
          SizedBox(width: 4),
          Text(
            '諮詢師回覆',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChips extends StatelessWidget {
  const _SourceChips({required this.sources});

  final List<RagSource> sources;

  @override
  Widget build(BuildContext context) {
    final visible = sources.take(3).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in visible) _SourceChip(source: s),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final RagSource source;

  Future<void> _open() async {
    final url = source.url;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = source.url != null && source.url!.isNotEmpty;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: hasUrl ? _open : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasUrl
                  ? CupertinoIcons.link
                  : CupertinoIcons.doc_text,
              size: 11,
              color: hasUrl ? AppColors.brandStart : AppColors.textTertiary,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                source.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: hasUrl
                      ? AppColors.brandStart
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (hasUrl) ...[
              const SizedBox(width: 2),
              const Icon(
                CupertinoIcons.arrow_up_right,
                size: 10,
                color: AppColors.brandStart,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HandoffPrompt extends StatelessWidget {
  const _HandoffPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              gradient: AppColors.softGradient,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.person_2_fill,
                  size: 14,
                  color: AppColors.brandStart,
                ),
                AppGaps.w6,
                Text(
                  '需要真人諮詢師？產生交接單',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandStart,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CounselorBriefSheet extends StatelessWidget {
  const _CounselorBriefSheet({required this.brief});

  final CounselorBrief brief;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D4D8),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: const Text(
                        '諮詢師交接單',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '迫切度：${brief.urgency}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    const Text(
                      '快速接手對話',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    AppGaps.h12,
                    _briefSection('使用者背景', brief.userBackground),
                    _briefSection('Persona 摘要', brief.personaSummary),
                    _briefSection('近期互動', brief.recentActivities),
                    _briefSection('原始問題', brief.mainQuestion),
                    _briefSection('AI 分析', brief.aiAnalysis),
                    _briefList('建議談話方向', brief.suggestedTopics),
                    _briefList('推薦資源', brief.recommendedResources),
                    AppGaps.h8,
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgAlt,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI 回稿（諮詢師可修改後送出）',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppColors.brandStart,
                            ),
                          ),
                          AppGaps.h8,
                          Text(
                            brief.aiDraftReply,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: AppColors.textPrimary,
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
        );
      },
    );
  }

  Widget _briefSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textTertiary,
            ),
          ),
          AppGaps.h6,
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _briefList(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textTertiary,
            ),
          ),
          AppGaps.h6,
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '・$s',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
        ],
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
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: AppColors.border),
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
                          color: AppColors.textMuted,
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // 攔截實體鍵盤 / 桌面：Enter 直接送，Shift+Enter 才換行。
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  if (enabled) onSend();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: CupertinoTextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                enabled: enabled,
                placeholder: '和 YAYA 說說你的職涯小煩惱…',
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                // iOS 軟鍵盤的 return 鍵改成「送出」。
                textInputAction: TextInputAction.send,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          AppGaps.w8,
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: AppColors.textPrimary,
            disabledColor: const Color(0xFFA1A1AA),
            borderRadius: BorderRadius.circular(22),
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
