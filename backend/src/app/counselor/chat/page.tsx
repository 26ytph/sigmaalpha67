"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { colors, radii, gradients, shadows, fontStack } from "../theme";
import { apiFetch, clearSession, getToken } from "../lib/api";
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
};

type ConversationResponse = {
  conversationId: string | null;
  mode: "career" | "startup";
  messages: RemoteMessage[];
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

  const [conv, setConv] = useState<ConversationResponse | null>(null);
  const [convLoading, setConvLoading] = useState(false);
  const [convError, setConvError] = useState<string | null>(null);

  const [insight, setInsight] = useState<UserInsight | null>(null);
  const [insightLoading, setInsightLoading] = useState(false);
  const [insightError, setInsightError] = useState<string | null>(null);

  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const selectedIdRef = useRef<string | null>(null);
  selectedIdRef.current = selectedId;
  const messagesScrollRef = useRef<HTMLDivElement | null>(null);

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

  // 拉某個 user 的對話 + AI 摘要。
  // mode='full' 是切換個案／第一次載入時用，會清空舊資料、顯示 loading；
  // mode='silent' 是輪詢／按下重新整理時用，不會閃畫面。
  const loadFor = useCallback(
    async (userId: string, mode: "full" | "silent") => {
      if (mode === "full") {
        setConvLoading(true);
        setConvError(null);
        setInsightLoading(true);
        setInsightError(null);
        setConv(null);
        setInsight(null);
      } else {
        setRefreshing(true);
      }

      const convPromise = apiFetch<ConversationResponse>(
        `/api/counselor/users/${encodeURIComponent(userId)}/conversation`,
      )
        .then((r) => {
          // 如果使用者在這個 await 期間切換了個案，丟棄結果
          if (selectedIdRef.current !== userId) return;
          setConv(r);
          setConvError(null);
        })
        .catch((e) => {
          if (selectedIdRef.current !== userId) return;
          const msg =
            typeof e === "object" && e && "message" in e
              ? String((e as { message?: string }).message ?? "")
              : "";
          setConvError(msg || "載入對話失敗");
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

      await Promise.all([convPromise, insightPromise]);

      if (mode === "full") {
        setConvLoading(false);
        setInsightLoading(false);
      } else {
        setRefreshing(false);
      }
    },
    [],
  );

  // 切換個案：full reload
  useEffect(() => {
    if (!selectedId) {
      setConv(null);
      setInsight(null);
      return;
    }
    setDraft("");
    setSendError(null);
    void loadFor(selectedId, "full");
  }, [selectedId, loadFor]);

  // 自動輪詢：每 5 秒拉一次新訊息（只在有選個案、頁面可見時執行）
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
        // tab 切回來時立刻 refresh 一次
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

  // 自動把對話捲到底：
  //   - 第一次載入 / 切換個案：強制捲到底（不檢查使用者位置）
  //   - 後續訊息更新：只有使用者本來就接近最底端時才捲下去，
  //     避免他在往上看歷史訊息時被拉走。
  const messageCount = conv?.messages.length ?? 0;
  const conversationKey = `${selectedId ?? ""}:${conv?.conversationId ?? ""}`;
  const lastConversationKeyRef = useRef<string>("");
  useEffect(() => {
    const el = messagesScrollRef.current;
    if (!el) return;
    const isNewConversation = lastConversationKeyRef.current !== conversationKey;
    lastConversationKeyRef.current = conversationKey;

    if (isNewConversation) {
      // 切到新對話：直接到底（不需要 smooth）
      el.scrollTop = el.scrollHeight;
      return;
    }

    // 同一段對話新訊息進來：判斷使用者是不是還在底部附近
    const distanceFromBottom =
      el.scrollHeight - el.scrollTop - el.clientHeight;
    if (distanceFromBottom < 120) {
      el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
    }
  }, [conversationKey, messageCount]);

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
    if (!text || !selectedId || sending) return;
    setSending(true);
    setSendError(null);
    try {
      const res = await apiFetch<{
        conversationId: string;
        message: RemoteMessage;
      }>(
        `/api/counselor/users/${encodeURIComponent(selectedId)}/conversation/messages`,
        {
          method: "POST",
          body: JSON.stringify({
            conversationId: conv?.conversationId ?? undefined,
            text,
          }),
        },
      );
      // 樂觀更新：把剛送出的訊息直接 push 進對話列，
      // 不等再打一次 GET（也避免 race）。
      setConv((prev) => {
        const baseMessages = prev?.messages ?? [];
        return {
          conversationId: res.conversationId,
          mode: prev?.mode ?? "career",
          messages: [...baseMessages, res.message],
        };
      });
      setDraft("");
      // 順手 silent refresh 一次，把對話狀態跟 Supabase 對齊
      // （避免使用者在這段時間又補了一句話我們漏掉）
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

        {/* 中：對話紀錄 */}
        <Pane
          title={
            selectedUser
              ? selectedUser.name || selectedUser.email || selectedUser.userId
              : "選擇一位個案"
          }
          subtitle={
            selectedUser
              ? `對話紀錄${conv?.mode ? `・${conv.mode === "startup" ? "創業模式" : "求職模式"}` : ""}${refreshing ? "・更新中…" : "・每 5 秒自動更新"}`
              : "從左邊挑一位開始"
          }
          headerAction={
            selectedId ? (
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
              <Empty hint="點左邊的個案，這邊會顯示完整對話紀錄。" />
            )}
            {selectedId && convLoading && <Empty hint="載入對話中…" />}
            {selectedId && convError && (
              <Empty hint={convError} tone="error" />
            )}
            {selectedId &&
              !convLoading &&
              !convError &&
              (conv?.messages.length ?? 0) === 0 && (
                <Empty hint="這位 user 還沒有任何對話紀錄。直接在下面打第一句話跟他說話吧。" />
              )}
            {selectedId && conv && conv.messages.length > 0 && (
              <div
                ref={messagesScrollRef}
                style={{
                  flex: 1,
                  overflowY: "auto",
                  paddingRight: 4,
                  display: "flex",
                  flexDirection: "column",
                  gap: 10,
                }}
              >
                {conv.messages.map((m) => (
                  <MessageBubble key={m.id} m={m} />
                ))}
              </div>
            )}
          </div>

          {selectedId && (
            <ReplyComposer
              draft={draft}
              setDraft={setDraft}
              sending={sending}
              error={sendError}
              onSend={sendReply}
              disabled={!conv && !convError}
            />
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

function MessageBubble({ m }: { m: RemoteMessage }) {
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

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: fromUser ? "flex-start" : "flex-end",
      }}
    >
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
