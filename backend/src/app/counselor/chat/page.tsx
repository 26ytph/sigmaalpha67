"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { colors, radii, gradients, shadows, fontStack } from "../theme";
import { apiFetch, clearSession, getToken } from "../lib/api";
import { getSupabaseBrowser } from "../lib/supabaseBrowser";
import { Header } from "../components/Header";

type CounselorUser = {
  userId: string;
  name: string;
  email: string;
};

type RemoteMessage = {
  id: string;
  role: "user" | "assistant";
  text: string;
  createdAt: string;
  fromCounselor?: boolean;
  /** user msg 對應的 normalized_questions.resolved — true = AI 已處理，UI 會淡化。 */
  resolved?: boolean;
};

type StoredTopic = {
  id: string;
  userId: string;
  title: string;
  summary: string;
  status: "pending" | "resolved";
  questionCount: number;
  createdAt: string;
  updatedAt: string;
};

type TopicMember = {
  normalizedQuestionId: string;
  messageId: string | null;
  conversationId: string | null;
  rawQuestion: string;
  normalizedText: string;
  intents: string[];
  emotion: string;
  urgency: string;
  createdAt: string;
};

type TopicCounselorReply = {
  messageId: string;
  conversationId: string;
  text: string;
  createdAt: string;
  replyToMessageId?: string;
  replyToText?: string;
};

type TopicWithMembers = StoredTopic & {
  members: TopicMember[];
  counselorReplies: TopicCounselorReply[];
};

type UserInsight = {
  userId: string;
  problemPositioning: string;
  categories: string[];
  emotionProfile: string;
  specificConcerns: string[];
  triedApproaches: string[];
  blockers: string[];
  recommendedTopics: string[];
  priority: "低" | "中" | "中高" | "高";
  tags: string[];
  rawSummary: string;
  messageCount: number;
  generatedBy: string;
  counselorNote: string;
  generatedAt: string;
  updatedAt: string;
};

export default function CounselorChatPage() {
  const router = useRouter();
  const [users, setUsers] = useState<CounselorUser[]>([]);
  const [usersLoading, setUsersLoading] = useState(true);
  const [usersError, setUsersError] = useState<string | null>(null);

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [filter, setFilter] = useState("");

  // 中欄改為「主題卡」流：先列出 topics，點擊後看詳情。
  const [topics, setTopics] = useState<StoredTopic[]>([]);
  const [topicsLoading, setTopicsLoading] = useState(false);
  const [topicsError, setTopicsError] = useState<string | null>(null);

  const [selectedTopicId, setSelectedTopicId] = useState<string | null>(null);
  const [topicDetail, setTopicDetail] = useState<TopicWithMembers | null>(null);
  const [topicDetailLoading, setTopicDetailLoading] = useState(false);
  const [topicDetailError, setTopicDetailError] = useState<string | null>(null);

  const [insight, setInsight] = useState<UserInsight | null>(null);
  const [insightLoading, setInsightLoading] = useState(false);
  const [insightError, setInsightError] = useState<string | null>(null);

  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [resolving, setResolving] = useState(false);
  const [resolveError, setResolveError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const selectedIdRef = useRef<string | null>(null);
  selectedIdRef.current = selectedId;
  const selectedTopicIdRef = useRef<string | null>(null);
  selectedTopicIdRef.current = selectedTopicId;

  useEffect(() => {
    if (!getToken()) {
      router.replace("/counselor/login");
      return;
    }
    (async () => {
      try {
        const res = await apiFetch<{ users: CounselorUser[] }>(
          "/api/counselor/users",
        );
        setUsers(res.users ?? []);
        if (res.users && res.users.length > 0) {
          setSelectedId(res.users[0].userId);
        }
      } catch (e) {
        const status = (e as { status?: number })?.status;
        if (status === 401) {
          clearSession();
          router.replace("/counselor/login");
          return;
        }
        const msg =
          typeof e === "object" && e && "message" in e
            ? String((e as { message?: string }).message ?? "")
            : "";
        setUsersError(msg || "載入使用者失敗");
      } finally {
        setUsersLoading(false);
      }
    })();
  }, [router]);

  // 拉某個 user 的 topics + AI 摘要。
  //   - mode='full'：切個案／第一次載入。清空、顯示 loading。
  //   - mode='silent'：輪詢。不閃 UI。
  // 如果同時有打開的 topic，也順手 refresh detail。
  const loadFor = useCallback(
    async (userId: string, mode: "full" | "silent") => {
      if (mode === "full") {
        setTopicsLoading(true);
        setTopicsError(null);
        setInsightLoading(true);
        setInsightError(null);
        setTopics([]);
        setInsight(null);
      } else {
        setRefreshing(true);
      }

      const topicsPromise = apiFetch<{ topics: StoredTopic[] }>(
        `/api/counselor/users/${encodeURIComponent(userId)}/topics?status=all`,
      )
        .then((r) => {
          if (selectedIdRef.current !== userId) return;
          // 待處理優先；已解決排到下方並用灰色顯示
          const sorted = [...(r.topics ?? [])].sort((a, b) => {
            if (a.status !== b.status) return a.status === "pending" ? -1 : 1;
            return (b.updatedAt ?? "").localeCompare(a.updatedAt ?? "");
          });
          setTopics(sorted);
          setTopicsError(null);
        })
        .catch((e) => {
          if (selectedIdRef.current !== userId) return;
          const msg =
            typeof e === "object" && e && "message" in e
              ? String((e as { message?: string }).message ?? "")
              : "";
          setTopicsError(msg || "載入主題列表失敗");
        });

      const insightPromise = apiFetch<{ insight: UserInsight | null }>(
        `/api/counselor/users/${encodeURIComponent(userId)}/summary`,
      )
        .then((r) => {
          if (selectedIdRef.current !== userId) return;
          setInsight(r.insight ?? null);
          setInsightError(null);
        })
        .catch((e) => {
          if (selectedIdRef.current !== userId) return;
          const msg =
            typeof e === "object" && e && "message" in e
              ? String((e as { message?: string }).message ?? "")
              : "";
          setInsightError(msg || "載入摘要失敗");
        });

      const detailPromise = (async () => {
        const tid = selectedTopicIdRef.current;
        if (!tid) return;
        try {
          const r = await apiFetch<{ topic: TopicWithMembers }>(
            `/api/counselor/topics/${encodeURIComponent(tid)}`,
          );
          if (selectedTopicIdRef.current !== tid) return;
          setTopicDetail(r.topic);
          setTopicDetailError(null);
        } catch (e) {
          if (selectedTopicIdRef.current !== tid) return;
          const msg =
            typeof e === "object" && e && "message" in e
              ? String((e as { message?: string }).message ?? "")
              : "";
          setTopicDetailError(msg || "載入主題詳情失敗");
        }
      })();

      await Promise.all([topicsPromise, insightPromise, detailPromise]);

      if (mode === "full") {
        setTopicsLoading(false);
        setInsightLoading(false);
      } else {
        setRefreshing(false);
      }
    },
    [],
  );

  // 顯式打開某個 topic 的詳情（卡片點擊用）。
  const openTopic = useCallback(async (topicId: string) => {
    setSelectedTopicId(topicId);
    setTopicDetailLoading(true);
    setTopicDetailError(null);
    setTopicDetail(null);
    setDraft("");
    setSendError(null);
    setResolveError(null);
    try {
      const r = await apiFetch<{ topic: TopicWithMembers }>(
        `/api/counselor/topics/${encodeURIComponent(topicId)}`,
      );
      if (selectedTopicIdRef.current !== topicId) return;
      setTopicDetail(r.topic);
    } catch (e) {
      if (selectedTopicIdRef.current !== topicId) return;
      const msg =
        typeof e === "object" && e && "message" in e
          ? String((e as { message?: string }).message ?? "")
          : "";
      setTopicDetailError(msg || "載入主題詳情失敗");
    } finally {
      if (selectedTopicIdRef.current === topicId) {
        setTopicDetailLoading(false);
      }
    }
  }, []);

  // 切換個案：full reload + 清掉打開的 topic
  useEffect(() => {
    if (!selectedId) {
      setTopics([]);
      setSelectedTopicId(null);
      setTopicDetail(null);
      setInsight(null);
      return;
    }
    setSelectedTopicId(null);
    setTopicDetail(null);
    setDraft("");
    setSendError(null);
    setResolveError(null);
    void loadFor(selectedId, "full");
  }, [selectedId, loadFor]);

  // 自動輪詢：每 5 秒拉一次（只在有選個案、頁面可見時執行）
  useEffect(() => {
    if (!selectedId) return;
    let timer: ReturnType<typeof setInterval> | null = null;
    const start = () => {
      if (timer) return;
      timer = setInterval(() => {
        if (document.visibilityState !== "visible") return;
        const sid = selectedIdRef.current;
        if (!sid) return;
        void loadFor(sid, "silent");
      }, 5000);
    };
    const stop = () => {
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
    };
    start();
    const onVis = () => {
      if (document.visibilityState === "visible") {
        const sid = selectedIdRef.current;
        if (sid) void loadFor(sid, "silent");
      }
    };
    document.addEventListener("visibilitychange", onVis);
    return () => {
      stop();
      document.removeEventListener("visibilitychange", onVis);
    };
  }, [selectedId, loadFor]);

  // 即時刷新：訂閱該 user 的 chat_messages INSERT。
  // 諮詢師自己送出的訊息也會 echo 回來 → silent loadFor → topic detail 立刻看到自己回了。
  // 個案那端說了新東西 → topics list 也會被刷新（新 topic 或既有 topic 多一題）。
  useEffect(() => {
    if (!selectedId) return;
    const supa = getSupabaseBrowser();
    if (!supa) return;
    const channel = supa
      .channel(`counselor-chat:${selectedId}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "chat_messages",
          filter: `user_id=eq.${selectedId}`,
        },
        () => {
          const sid = selectedIdRef.current;
          if (sid) void loadFor(sid, "silent");
        },
      )
      .subscribe();
    return () => {
      void supa.removeChannel(channel);
    };
  }, [selectedId, loadFor]);

  const filteredUsers = useMemo(() => {
    const q = filter.trim().toLowerCase();
    if (!q) return users;
    return users.filter((u) => {
      return (
        u.name.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q) ||
        u.userId.toLowerCase().includes(q)
      );
    });
  }, [users, filter]);

  function logout() {
    clearSession();
    router.replace("/counselor/login");
  }

  async function sendReply() {
    const text = draft.trim();
    const tid = selectedTopicId;
    if (!text || !tid || sending) return;
    setSending(true);
    setSendError(null);
    try {
      await apiFetch<{ conversationId: string; topicId: string }>(
        `/api/counselor/topics/${encodeURIComponent(tid)}/reply`,
        { method: "POST", body: JSON.stringify({ text }) },
      );
      setDraft("");
      // 順手 silent refresh — 把 topic detail / topics list 拉新。
      const sid = selectedIdRef.current;
      if (sid) void loadFor(sid, "silent");
    } catch (e) {
      const msg =
        typeof e === "object" && e && "message" in e
          ? String((e as { message?: string }).message ?? "")
          : "";
      setSendError(msg || "送出失敗");
    } finally {
      setSending(false);
    }
  }

  async function resolveCurrentTopic() {
    const tid = selectedTopicId;
    if (!tid || resolving) return;
    if (
      !window.confirm(
        "確認要把這個主題標記為已解決嗎？AI 會把整理過的 Q&A 推進 RAG，下次相同提問將直接由 AI 回覆。",
      )
    ) {
      return;
    }
    setResolving(true);
    setResolveError(null);
    try {
      await apiFetch<{ topic: StoredTopic }>(
        `/api/counselor/topics/${encodeURIComponent(tid)}/resolve`,
        { method: "POST" },
      );
      // 解決後就回 topics list，並 silent refresh
      setSelectedTopicId(null);
      setTopicDetail(null);
      const sid = selectedIdRef.current;
      if (sid) void loadFor(sid, "silent");
    } catch (e) {
      const msg =
        typeof e === "object" && e && "message" in e
          ? String((e as { message?: string }).message ?? "")
          : "";
      setResolveError(msg || "標記解決失敗");
    } finally {
      setResolving(false);
    }
  }

  const selectedUser = users.find((u) => u.userId === selectedId) ?? null;

  return (
    <main
      style={{
        height: "100vh",
        background: gradients.bg,
        fontFamily: fontStack,
        color: colors.textPrimary,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      <Header onLogout={logout} active="chat" />

      <div
        style={{
          flex: 1,
          display: "grid",
          gridTemplateColumns: "minmax(240px, 300px) 1fr minmax(280px, 360px)",
          gap: 16,
          padding: 16,
          minHeight: 0,
          height: "calc(100vh - 56px)", // 56px ≈ Header 高度，扣掉後三個 pane 共用剩下的空間
        }}
      >
        {/* 左：個案列表 */}
        <Pane title="我的個案" subtitle="先讓所有諮詢師看到全部 user">
          <div style={{ marginBottom: 10 }}>
            <input
              placeholder="搜尋姓名 / Email"
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              style={{
                width: "100%",
                padding: "10px 12px",
                background: colors.surfaceMuted,
                border: `1px solid ${colors.border}`,
                borderRadius: radii.md,
                fontSize: 13,
                outline: "none",
                boxSizing: "border-box",
              }}
            />
          </div>
          <div style={{ flex: 1, overflowY: "auto", margin: "0 -4px" }}>
            {usersLoading && (
              <div
                style={{ color: colors.textTertiary, padding: 8, fontSize: 13 }}
              >
                載入中…
              </div>
            )}
            {usersError && (
              <div
                style={{ color: colors.iosRed, padding: 8, fontSize: 12 }}
              >
                {usersError}
              </div>
            )}
            {!usersLoading && filteredUsers.length === 0 && (
              <div
                style={{ color: colors.textTertiary, padding: 8, fontSize: 13 }}
              >
                目前沒有使用者
              </div>
            )}
            {filteredUsers.map((u) => {
              const active = u.userId === selectedId;
              const display = u.name || u.email || u.userId;
              return (
                <button
                  key={u.userId}
                  onClick={() => setSelectedId(u.userId)}
                  style={{
                    width: "100%",
                    textAlign: "left",
                    padding: "10px 12px",
                    margin: "4px",
                    borderRadius: radii.lg,
                    border: "none",
                    background: active
                      ? gradients.brand
                      : "rgba(255,255,255,0.65)",
                    color: active ? "#fff" : colors.textPrimary,
                    cursor: "pointer",
                    boxShadow: active ? shadows.soft : "none",
                    display: "flex",
                    alignItems: "center",
                    gap: 10,
                  }}
                >
                  <Avatar name={display} active={active} />
                  <div style={{ minWidth: 0, flex: 1 }}>
                    <div
                      style={{
                        fontSize: 14,
                        fontWeight: 700,
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                      }}
                    >
                      {display}
                    </div>
                    <div
                      style={{
                        fontSize: 11,
                        opacity: 0.85,
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                      }}
                    >
                      {u.email || u.userId}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        </Pane>

        {/* 中：主題列表 / 主題詳情 */}
        <Pane
          title={
            selectedTopicId && topicDetail
              ? topicDetail.title || "未命名主題"
              : selectedUser
                ? selectedUser.name ||
                  selectedUser.email ||
                  selectedUser.userId
                : "選擇一位個案"
          }
          subtitle={
            selectedTopicId && topicDetail
              ? `${topicDetail.questionCount} 題・由 AI 自動歸類同主題的未解問題`
              : selectedUser
                ? `待處理主題${refreshing ? "・更新中…" : "・每 5 秒自動更新"}`
                : "從左邊挑一位開始"
          }
          headerAction={
            selectedTopicId ? (
              <button
                onClick={() => {
                  setSelectedTopicId(null);
                  setTopicDetail(null);
                  setDraft("");
                  setSendError(null);
                  setResolveError(null);
                }}
                style={{
                  padding: "6px 12px",
                  borderRadius: 999,
                  border: `1px solid ${colors.borderStrong}`,
                  background: "transparent",
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: 700,
                  cursor: "pointer",
                }}
              >
                ← 回主題列表
              </button>
            ) : selectedId ? (
              <button
                onClick={() => {
                  const sid = selectedIdRef.current;
                  if (sid) void loadFor(sid, "silent");
                }}
                disabled={refreshing}
                title="立即重新整理"
                style={{
                  padding: "6px 12px",
                  borderRadius: 999,
                  border: `1px solid ${colors.borderStrong}`,
                  background: refreshing
                    ? colors.surfaceMuted
                    : "transparent",
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: 700,
                  cursor: refreshing ? "default" : "pointer",
                }}
              >
                {refreshing ? "更新中…" : "↻ 重新整理"}
              </button>
            ) : null
          }
        >
          <div
            style={{
              flex: 1,
              minHeight: 0,
              display: "flex",
              flexDirection: "column",
            }}
          >
            {!selectedId && (
              <Empty hint="點左邊的個案，這邊會列出 AI 沒能解決、需要你接手的主題。" />
            )}

            {/* —— 主題列表 —— */}
            {selectedId && !selectedTopicId && (
              <>
                {topicsLoading && <Empty hint="載入主題中…" />}
                {topicsError && <Empty hint={topicsError} tone="error" />}
                {!topicsLoading && !topicsError && topics.length === 0 && (
                  <Empty hint="這位 user 沒有需要處理的主題 ✨ 表示 AI 已經把所有問題答清楚了。" />
                )}
                {!topicsLoading && !topicsError && topics.length > 0 && (
                  <div
                    style={{
                      flex: 1,
                      overflowY: "auto",
                      display: "flex",
                      flexDirection: "column",
                      gap: 10,
                      paddingRight: 4,
                    }}
                  >
                    {topics.map((t) => (
                      <TopicCard
                        key={t.id}
                        topic={t}
                        onClick={() => void openTopic(t.id)}
                      />
                    ))}
                  </div>
                )}
              </>
            )}

            {/* —— 主題詳情 —— */}
            {selectedId && selectedTopicId && (
              <>
                {topicDetailLoading && <Empty hint="載入主題詳情中…" />}
                {topicDetailError && (
                  <Empty hint={topicDetailError} tone="error" />
                )}
                {!topicDetailLoading &&
                  !topicDetailError &&
                  topicDetail && (
                    <TopicDetailView topic={topicDetail} />
                  )}
              </>
            )}
          </div>

          {selectedId && selectedTopicId && (
            <>
              {resolveError && (
                <div
                  style={{
                    fontSize: 12,
                    color: colors.iosRed,
                    fontWeight: 600,
                    marginTop: 6,
                  }}
                >
                  {resolveError}
                </div>
              )}
              <ReplyComposer
                draft={draft}
                setDraft={setDraft}
                sending={sending}
                error={sendError}
                onSend={sendReply}
                disabled={!topicDetail && !topicDetailError}
              />
              <div style={{ marginTop: 8, display: "flex", justifyContent: "flex-end" }}>
                <button
                  onClick={resolveCurrentTopic}
                  disabled={resolving || !topicDetail}
                  style={{
                    padding: "8px 16px",
                    borderRadius: radii.md,
                    border: "none",
                    background: resolving
                      ? colors.borderStrong
                      : "linear-gradient(135deg,#10B981,#059669)",
                    color: "#fff",
                    fontSize: 13,
                    fontWeight: 800,
                    cursor: resolving || !topicDetail ? "default" : "pointer",
                  }}
                >
                  {resolving ? "整理中…" : "✅ 問題解決（彙整進 RAG）"}
                </button>
              </div>
            </>
          )}
        </Pane>

        {/* 右：AI 摘要 */}
        <Pane
          title="AI 摘要"
          subtitle="幫你快速掌握這位 user 的狀況"
          accent="ai"
        >
          {!selectedId && (
            <Empty hint="選擇個案後，這裡會出現 AI 摘要。" />
          )}
          {selectedId && insightLoading && <Empty hint="生成中…" />}
          {selectedId && insightError && (
            <Empty hint={insightError} tone="error" />
          )}
          {selectedId && !insightLoading && !insightError && !insight && (
            <Empty hint="這位 user 還沒有 AI 摘要。等他們累積一段對話後就會自動產生。" />
          )}
          {selectedId && insight && <InsightCard insight={insight} />}
        </Pane>
      </div>
    </main>
  );
}

function Pane({
  title,
  subtitle,
  accent,
  headerAction,
  children,
}: {
  title: string;
  subtitle?: string;
  accent?: "ai";
  headerAction?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section
      style={{
        background: "rgba(255,255,255,0.92)",
        borderRadius: radii.xl,
        boxShadow: shadows.soft,
        padding: 16,
        display: "flex",
        flexDirection: "column",
        minHeight: 0,
      }}
    >
      <div
        style={{
          marginBottom: 10,
          display: "flex",
          alignItems: "flex-start",
          gap: 12,
        }}
      >
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              display: "inline-block",
              padding: accent === "ai" ? "4px 10px" : 0,
              borderRadius: radii.pill,
              background: accent === "ai" ? gradients.ai : "transparent",
              color: accent === "ai" ? "#fff" : "inherit",
              fontSize: accent === "ai" ? 11 : 18,
              fontWeight: accent === "ai" ? 700 : 800,
              letterSpacing: -0.3,
              marginBottom: accent === "ai" ? 6 : 0,
            }}
          >
            {accent === "ai" ? "✨ AI" : title}
          </div>
          {accent === "ai" && (
            <div
              style={{
                fontSize: 18,
                fontWeight: 800,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              }}
            >
              {title}
            </div>
          )}
          {subtitle && (
            <div
              style={{
                fontSize: 12,
                color: colors.textTertiary,
                marginTop: 2,
              }}
            >
              {subtitle}
            </div>
          )}
        </div>
        {headerAction && (
          <div style={{ flex: "0 0 auto" }}>{headerAction}</div>
        )}
      </div>
      <div
        style={{
          flex: 1,
          minHeight: 0,
          display: "flex",
          flexDirection: "column",
        }}
      >
        {children}
      </div>
    </section>
  );
}

function Avatar({ name, active }: { name: string; active: boolean }) {
  const ch = (name || "?").trim().charAt(0).toUpperCase() || "?";
  return (
    <span
      style={{
        width: 36,
        height: 36,
        borderRadius: "50%",
        background: active ? "rgba(255,255,255,0.25)" : gradients.heart,
        color: "#fff",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        fontWeight: 800,
        fontSize: 14,
        flex: "0 0 auto",
        boxShadow: active ? "none" : shadows.soft,
      }}
    >
      {ch}
    </span>
  );
}

function MessageBubble({
  m,
  dimmed = false,
}: {
  m: RemoteMessage;
  dimmed?: boolean;
}) {
  const fromUser = m.role === "user";
  const fromCounselor = m.fromCounselor === true;
  const time = (() => {
    const d = new Date(m.createdAt);
    if (isNaN(d.getTime())) return "";
    return d.toLocaleString();
  })();

  // 三種樣式：個案（左、灰）／AI（右、粉漸層）／諮詢師自己（右、靛紫）
  const bg = fromUser
    ? colors.surfaceMuted
    : fromCounselor
      ? gradients.ai
      : gradients.brand;
  const fg = fromUser ? colors.textPrimary : "#fff";
  const label = fromUser ? "個案" : fromCounselor ? "我（諮詢師）" : "AI";

  // 已被 AI / RAG 處理掉的 Q+A 整組淡化，諮詢師一眼能跳過。
  const containerOpacity = dimmed ? 0.45 : 1;

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: fromUser ? "flex-start" : "flex-end",
        opacity: containerOpacity,
      }}
    >
      {/* 來源徽章 — 三種來源各自一個明顯色塊，諮詢師看一眼就分得出 AI / 真人 */}
      {!fromUser && (
        <SourcePill
          kind={fromCounselor ? "counselor" : "ai"}
          marginSide="right"
        />
      )}
      {fromUser && dimmed && <ResolvedPill marginSide="left" />}
      <div
        style={{
          maxWidth: "82%",
          padding: "10px 14px",
          borderRadius: 18,
          borderBottomLeftRadius: fromUser ? 6 : 18,
          borderBottomRightRadius: fromUser ? 18 : 6,
          background: bg,
          color: fg,
          fontSize: 14,
          lineHeight: 1.55,
          whiteSpace: "pre-wrap",
          wordBreak: "break-word",
          boxShadow: fromUser ? "none" : shadows.soft,
          // 諮詢師自己的訊息再多一條深色左邊條，跟 AI 漸層做雙重區分
          borderLeft: fromCounselor ? "3px solid #4338CA" : undefined,
        }}
      >
        {m.text}
      </div>
      <div
        style={{
          fontSize: 10,
          color: colors.textTertiary,
          marginTop: 4,
          padding: "0 4px",
        }}
      >
        {label} · {time}
      </div>
    </div>
  );
}

function SourcePill({
  kind,
  marginSide,
}: {
  kind: "ai" | "counselor";
  marginSide: "left" | "right";
}) {
  const isCounselor = kind === "counselor";
  return (
    <span
      style={{
        alignSelf: marginSide === "right" ? "flex-end" : "flex-start",
        marginBottom: 4,
        padding: "2px 8px",
        borderRadius: 999,
        fontSize: 10,
        fontWeight: 800,
        letterSpacing: 0.4,
        color: "#fff",
        background: isCounselor
          ? "linear-gradient(135deg,#6366F1,#4338CA)"
          : "linear-gradient(135deg,#F472B6,#FB7185)",
      }}
    >
      {isCounselor ? "👤 諮詢師回覆" : "🤖 AI 自動回覆"}
    </span>
  );
}

function ResolvedPill({ marginSide }: { marginSide: "left" | "right" }) {
  return (
    <span
      style={{
        alignSelf: marginSide === "right" ? "flex-end" : "flex-start",
        marginBottom: 4,
        padding: "2px 8px",
        borderRadius: 999,
        fontSize: 10,
        fontWeight: 800,
        letterSpacing: 0.4,
        color: "#166534",
        background: "#DCFCE7",
        border: "1px solid #86EFAC",
      }}
    >
      ✅ 已完成 · AI 處理
    </span>
  );
}

function ReplyComposer({
  draft,
  setDraft,
  sending,
  error,
  onSend,
  disabled,
}: {
  draft: string;
  setDraft: (s: string) => void;
  sending: boolean;
  error: string | null;
  onSend: () => void;
  disabled: boolean;
}) {
  const canSend = draft.trim().length > 0 && !sending && !disabled;
  return (
    <div
      style={{
        marginTop: 10,
        paddingTop: 10,
        borderTop: `1px solid ${colors.separator}`,
      }}
    >
      {error && (
        <div
          style={{
            fontSize: 12,
            color: colors.iosRed,
            marginBottom: 6,
            fontWeight: 600,
          }}
        >
          {error}
        </div>
      )}
      <div style={{ display: "flex", alignItems: "flex-end", gap: 8 }}>
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="輸入要傳給個案的訊息（Enter 送出，Shift+Enter 換行）"
          rows={2}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              if (canSend) onSend();
            }
          }}
          disabled={disabled || sending}
          style={{
            flex: 1,
            resize: "none",
            padding: "10px 12px",
            background: colors.surfaceMuted,
            border: `1px solid ${colors.border}`,
            borderRadius: radii.md,
            fontSize: 14,
            lineHeight: 1.55,
            color: colors.textPrimary,
            outline: "none",
            fontFamily: "inherit",
            boxSizing: "border-box",
          }}
        />
        <button
          onClick={onSend}
          disabled={!canSend}
          style={{
            padding: "10px 18px",
            border: "none",
            borderRadius: radii.md,
            background: canSend ? colors.brandStart : colors.borderStrong,
            color: "#fff",
            fontSize: 14,
            fontWeight: 800,
            cursor: canSend ? "pointer" : "not-allowed",
            boxShadow: canSend ? shadows.soft : "none",
            whiteSpace: "nowrap",
          }}
        >
          {sending ? "傳送中…" : "送出 ❤"}
        </button>
      </div>
    </div>
  );
}

function Empty({
  hint,
  tone,
}: {
  hint: string;
  tone?: "error";
}) {
  return (
    <div
      style={{
        flex: 1,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        textAlign: "center",
        padding: 24,
        color: tone === "error" ? colors.iosRed : colors.textTertiary,
        fontSize: 13,
      }}
    >
      {hint}
    </div>
  );
}

function InsightCard({ insight }: { insight: UserInsight }) {
  return (
    <div
      style={{
        flex: 1,
        overflowY: "auto",
        paddingRight: 4,
        display: "flex",
        flexDirection: "column",
        gap: 14,
      }}
    >
      <Section label="優先度">
        <PriorityBadge value={insight.priority} />
      </Section>

      {insight.problemPositioning && (
        <Section label="主要議題">
          <div style={paragraphStyle}>{insight.problemPositioning}</div>
        </Section>
      )}

      {insight.emotionProfile && (
        <Section label="情緒狀態">
          <div style={paragraphStyle}>{insight.emotionProfile}</div>
        </Section>
      )}

      {insight.categories.length > 0 && (
        <Section label="分類">
          <ChipRow items={insight.categories} />
        </Section>
      )}

      {insight.specificConcerns.length > 0 && (
        <Section label="具體擔憂">
          <BulletList items={insight.specificConcerns} />
        </Section>
      )}

      {insight.triedApproaches.length > 0 && (
        <Section label="已嘗試的做法">
          <BulletList items={insight.triedApproaches} />
        </Section>
      )}

      {insight.blockers.length > 0 && (
        <Section label="目前卡關">
          <BulletList items={insight.blockers} />
        </Section>
      )}

      {insight.recommendedTopics.length > 0 && (
        <Section label="建議聊聊">
          <ChipRow items={insight.recommendedTopics} />
        </Section>
      )}

      {insight.tags.length > 0 && (
        <Section label="標籤">
          <ChipRow items={insight.tags} muted />
        </Section>
      )}

      {insight.rawSummary && (
        <Section label="完整摘要">
          <div style={paragraphStyle}>{insight.rawSummary}</div>
        </Section>
      )}

      {insight.counselorNote && (
        <Section label="諮詢師備註">
          <div style={paragraphStyle}>{insight.counselorNote}</div>
        </Section>
      )}

      <div
        style={{
          fontSize: 11,
          color: colors.textTertiary,
          marginTop: 4,
        }}
      >
        共 {insight.messageCount} 則訊息
        {insight.generatedBy ? `・${insight.generatedBy}` : ""}
        {insight.generatedAt
          ? `・${new Date(insight.generatedAt).toLocaleString()}`
          : ""}
      </div>
    </div>
  );
}

const paragraphStyle: React.CSSProperties = {
  fontSize: 13,
  lineHeight: 1.65,
  color: colors.textPrimary,
};

function Section({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div>
      <div
        style={{
          fontSize: 11,
          fontWeight: 700,
          color: colors.textTertiary,
          letterSpacing: 0.4,
          textTransform: "uppercase",
          marginBottom: 6,
        }}
      >
        {label}
      </div>
      {children}
    </div>
  );
}

function ChipRow({
  items,
  muted,
}: {
  items: string[];
  muted?: boolean;
}) {
  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
      {items.map((it) => (
        <span
          key={it}
          style={{
            padding: "4px 10px",
            borderRadius: radii.pill,
            background: muted
              ? colors.surfaceMuted
              : "rgba(254,60,114,0.10)",
            color: muted ? colors.textSecondary : colors.brandStart,
            fontSize: 12,
            fontWeight: 700,
            border: muted
              ? `1px solid ${colors.border}`
              : "1px solid rgba(254,60,114,0.25)",
          }}
        >
          {it}
        </span>
      ))}
    </div>
  );
}

function BulletList({ items }: { items: string[] }) {
  return (
    <ul
      style={{
        margin: 0,
        paddingLeft: 18,
        display: "flex",
        flexDirection: "column",
        gap: 4,
      }}
    >
      {items.map((it) => (
        <li
          key={it}
          style={{
            fontSize: 13,
            lineHeight: 1.55,
            color: colors.textPrimary,
          }}
        >
          {it}
        </li>
      ))}
    </ul>
  );
}

function PriorityBadge({ value }: { value: UserInsight["priority"] }) {
  const palette: Record<
    UserInsight["priority"],
    { bg: string; color: string }
  > = {
    低: { bg: "rgba(52,199,89,0.15)", color: colors.iosGreen },
    中: { bg: "rgba(0,122,255,0.12)", color: colors.iosBlue },
    中高: { bg: "rgba(255,149,0,0.15)", color: "#FF9500" },
    高: { bg: "rgba(255,59,48,0.15)", color: colors.iosRed },
  };
  const c = palette[value] ?? palette["中"];
  return (
    <span
      style={{
        display: "inline-block",
        padding: "4px 12px",
        borderRadius: radii.pill,
        background: c.bg,
        color: c.color,
        fontSize: 12,
        fontWeight: 800,
      }}
    >
      {value}
    </span>
  );
}

// ---------------------------------------------------------------------------
// Topic 卡片：列在主題列表
// ---------------------------------------------------------------------------
function TopicCard({
  topic,
  onClick,
}: {
  topic: StoredTopic;
  onClick: () => void;
}) {
  const updated = (() => {
    const d = new Date(topic.updatedAt);
    return isNaN(d.getTime()) ? "" : d.toLocaleString();
  })();
  const resolved = topic.status === "resolved";
  return (
    <button
      onClick={onClick}
      style={{
        textAlign: "left",
        padding: "14px 16px",
        background: resolved
          ? "rgba(243,244,246,0.85)"
          : "rgba(255,255,255,0.92)",
        border: `1px solid ${resolved ? "#E5E7EB" : colors.border}`,
        borderRadius: radii.lg,
        cursor: "pointer",
        boxShadow: resolved ? "none" : shadows.soft,
        display: "flex",
        flexDirection: "column",
        gap: 6,
        opacity: resolved ? 0.7 : 1,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <span
          style={{
            padding: "2px 8px",
            borderRadius: 999,
            fontSize: 10,
            fontWeight: 800,
            background: resolved
              ? "#D1FAE5"
              : "linear-gradient(135deg,#F472B6,#FB7185)",
            color: resolved ? "#065F46" : "#fff",
            letterSpacing: 0.4,
            border: resolved ? "1px solid #6EE7B7" : "none",
          }}
        >
          {resolved ? "✅ 已完成" : "📌 待處理"}
        </span>
        <span
          style={{
            fontSize: 11,
            color: colors.textTertiary,
          }}
        >
          {topic.questionCount} 題・{updated}
        </span>
      </div>
      <div
        style={{
          fontSize: 16,
          fontWeight: 800,
          color: resolved ? "#6B7280" : colors.textPrimary,
          letterSpacing: -0.2,
          textDecoration: resolved ? "line-through" : "none",
          textDecorationColor: "#9CA3AF",
        }}
      >
        {topic.title || "未命名主題"}
      </div>
      {topic.summary && (
        <div
          style={{
            fontSize: 13,
            lineHeight: 1.55,
            color: resolved ? "#9CA3AF" : colors.textSecondary,
            display: "-webkit-box",
            WebkitBoxOrient: "vertical",
            WebkitLineClamp: 2,
            overflow: "hidden",
          }}
        >
          {topic.summary}
        </div>
      )}
    </button>
  );
}

// ---------------------------------------------------------------------------
// Topic 詳情：列出該主題下所有 user Q + AI 暫時回覆
// ---------------------------------------------------------------------------
function TopicDetailView({ topic }: { topic: TopicWithMembers }) {
  // 把所有成員問題 + 諮詢師回覆按時間排成一條 thread。
  type Item =
    | { kind: "q"; createdAt: string; member: TopicMember; index: number }
    | { kind: "r"; createdAt: string; reply: TopicCounselorReply };
  const items: Item[] = [
    ...topic.members.map(
      (m, i) =>
        ({
          kind: "q",
          createdAt: m.createdAt,
          member: m,
          index: i + 1,
        }) as Item,
    ),
    ...(topic.counselorReplies ?? []).map(
      (r) =>
        ({
          kind: "r",
          createdAt: r.createdAt,
          reply: r,
        }) as Item,
    ),
  ].sort((a, b) => (a.createdAt ?? "").localeCompare(b.createdAt ?? ""));

  return (
    <div
      style={{
        flex: 1,
        overflowY: "auto",
        paddingRight: 4,
        display: "flex",
        flexDirection: "column",
        gap: 14,
      }}
    >
      {topic.summary && (
        <div
          style={{
            padding: "12px 14px",
            background: colors.surfaceMuted,
            border: `1px solid ${colors.border}`,
            borderRadius: radii.md,
            fontSize: 13,
            lineHeight: 1.6,
            color: colors.textSecondary,
          }}
        >
          🧭 主題脈絡：{topic.summary}
        </div>
      )}
      {items.length === 0 && (
        <div
          style={{
            fontSize: 13,
            color: colors.textTertiary,
            textAlign: "center",
            padding: 24,
          }}
        >
          這個主題還沒有任何訊息。
        </div>
      )}
      {items.map((it) =>
        it.kind === "q" ? (
          <TopicMemberCard
            key={it.member.normalizedQuestionId}
            member={it.member}
            index={it.index}
          />
        ) : (
          <CounselorReplyCard key={it.reply.messageId} reply={it.reply} />
        ),
      )}
    </div>
  );
}

function TopicMemberCard({
  member,
  index,
}: {
  member: TopicMember;
  index: number;
}) {
  const ts = (() => {
    const d = new Date(member.createdAt);
    return isNaN(d.getTime()) ? "" : d.toLocaleString();
  })();
  return (
    <div
      style={{
        padding: 12,
        background: "rgba(255,255,255,0.92)",
        border: `1px solid ${colors.border}`,
        borderRadius: radii.lg,
        boxShadow: shadows.soft,
        display: "flex",
        flexDirection: "column",
        gap: 8,
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          fontSize: 11,
          color: colors.textTertiary,
        }}
      >
        <span
          style={{
            padding: "1px 7px",
            borderRadius: 999,
            background: colors.surfaceMuted,
            fontWeight: 800,
            color: colors.textSecondary,
          }}
        >
          Q{index}
        </span>
        {ts && <span>{ts}</span>}
        {member.urgency && member.urgency !== "中" && (
          <span
            style={{
              padding: "1px 7px",
              borderRadius: 999,
              background: "#FEF3C7",
              color: "#92400E",
              fontWeight: 700,
            }}
          >
            迫切：{member.urgency}
          </span>
        )}
      </div>
      <div
        style={{
          fontSize: 14,
          lineHeight: 1.55,
          color: colors.textPrimary,
          whiteSpace: "pre-wrap",
        }}
      >
        {member.rawQuestion || member.normalizedText}
      </div>
    </div>
  );
}

function CounselorReplyCard({ reply }: { reply: TopicCounselorReply }) {
  const ts = (() => {
    const d = new Date(reply.createdAt);
    return isNaN(d.getTime()) ? "" : d.toLocaleString();
  })();
  return (
    <div
      style={{
        padding: 12,
        background: "linear-gradient(135deg,#EEF2FF,#E0E7FF)",
        border: "1px solid #C7D2FE",
        borderLeft: "3px solid #4338CA",
        borderRadius: radii.lg,
        boxShadow: shadows.soft,
        display: "flex",
        flexDirection: "column",
        gap: 8,
        alignSelf: "flex-end",
        maxWidth: "92%",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          fontSize: 11,
          color: colors.textTertiary,
        }}
      >
        <span
          style={{
            padding: "1px 7px",
            borderRadius: 999,
            background: "linear-gradient(135deg,#6366F1,#4338CA)",
            color: "#fff",
            fontWeight: 800,
            letterSpacing: 0.4,
          }}
        >
          👤 我（諮詢師）
        </span>
        {ts && <span>{ts}</span>}
      </div>
      {reply.replyToText && (
        <div
          style={{
            padding: "6px 10px",
            background: "rgba(255,255,255,0.7)",
            borderLeft: "3px solid #818CF8",
            borderRadius: 6,
            fontSize: 12,
            color: colors.textSecondary,
            display: "-webkit-box",
            WebkitBoxOrient: "vertical",
            WebkitLineClamp: 2,
            overflow: "hidden",
          }}
        >
          ↩ 回覆：{reply.replyToText}
        </div>
      )}
      <div
        style={{
          fontSize: 14,
          lineHeight: 1.55,
          color: colors.textPrimary,
          whiteSpace: "pre-wrap",
        }}
      >
        {reply.text}
      </div>
    </div>
  );
}
