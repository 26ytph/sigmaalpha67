/**
 * Thin Supabase data layer for the most write-heavy tables (profiles +
 * personas). Routes call these helpers as a write-through cache:
 *
 *   1. Update the in-memory `store` (always works, even offline).
 *   2. If Supabase is configured, also persist to Postgres.
 *
 * This means existing routes don't need a major rewrite — they continue
 * to use `store.profiles` etc. and we just add `await db.upsertProfile(...)`
 * after the local write.
 *
 * Snake-case column names match the schema in
 *   `supabase/schema.sql`
 *
 * If Supabase isn't configured, every helper here is a no-op so the
 * fake demo backend still works offline.
 */

import { getSupabaseAdmin } from "./supabase";
import type { Profile } from "@/types/profile";
import type { CounselorProfile } from "@/types/counselorProfile";
import type { Persona } from "@/types/persona";
import type { SwipeRecord } from "@/types/swipe";
import type { SkillTranslation } from "@/types/skill";
import type { ChatConversation, ChatMessage } from "@/types/chat";
import type { UserInsight, UserInsightDraft } from "@/types/insight";
import type {
  NormalizedQuestionDraft,
  StoredNormalizedQuestion,
} from "@/types/normalizedQuestion";
import type {
  StoredTopic,
  TopicCounselorReply,
  TopicMemberQuestion,
  TopicWithMembers,
} from "@/types/topic";

// ---------------------------------------------------------------------------
// PROFILE
// ---------------------------------------------------------------------------

export async function upsertProfile(userId: string, p: Profile) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const row = {
    user_id: userId,
    name: p.name ?? "",
    school: p.school ?? "",
    birthday: p.birthday && p.birthday.length > 0 ? p.birthday : null,
    email: p.email ?? "",
    phone: p.phone ?? "",
    department: p.department ?? "",
    grade: p.grade ?? "",
    location: p.location ?? "",
    current_stage: p.currentStage ?? "",
    goals: p.goals ?? [],
    interests: p.interests ?? [],
    experiences: p.experiences ?? [],
    education_items: p.educationItems ?? [],
    concerns: p.concerns ?? "",
    startup_interest: p.startupInterest === true,
  };
  const { error } = await supabase
    .from("profiles")
    .upsert(row, { onConflict: "user_id" });
  if (error) console.warn("[db] upsertProfile failed:", error.message);
}

export async function fetchProfile(userId: string): Promise<Profile | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) return null;
  return {
    name: data.name ?? "",
    school: data.school ?? "",
    birthday: data.birthday ?? "",
    email: data.email ?? "",
    phone: data.phone ?? "",
    department: data.department ?? "",
    grade: data.grade ?? "",
    location: data.location ?? "",
    currentStage: data.current_stage ?? "",
    goals: Array.isArray(data.goals) ? data.goals : [],
    interests: Array.isArray(data.interests) ? data.interests : [],
    experiences: Array.isArray(data.experiences) ? data.experiences : [],
    educationItems: Array.isArray(data.education_items)
      ? data.education_items
      : [],
    concerns: data.concerns ?? "",
    startupInterest: data.startup_interest === true,
    createdAt: data.created_at ?? "",
    updatedAt: data.updated_at ?? "",
  };
}

/**
 * 給諮詢師端用：列出所有有 profile 的使用者（id + 顯示名稱）+ 每人的「未回題數」。
 * 未回題數 = 該 user 處在 pending topic 裡、且 messageId 沒有出現在
 *   chat_messages.normalized.reply_to_message_id 集合的 normalized_questions 條數。
 *
 * Supabase 沒設定就回空陣列，呼叫端會自動 fallback 到 in-memory。
 */
export async function listAllUsersForCounselor(
  limit = 200,
): Promise<
  Array<{
    userId: string;
    name: string;
    email: string;
    unansweredCount: number;
  }>
> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("profiles")
    .select("user_id, name, email, updated_at")
    .order("updated_at", { ascending: false })
    .limit(limit);
  if (error) {
    console.warn("[db] listAllUsersForCounselor failed:", error.message);
    return [];
  }
  const users = (data ?? []).map((r: Record<string, unknown>) => ({
    userId: (r.user_id as string) ?? "",
    name: (((r.name as string) ?? "") + "").trim(),
    email: (((r.email as string) ?? "") + "").trim(),
  }));

  // 一次撈 pending topics + 屬於這些 topic 的 normalized_questions + 諮詢師回過的 reply_to_message_id。
  const counts = new Map<string, number>();
  try {
    const { data: pendingTopics } = await supabase
      .from("question_topics")
      .select("id, user_id")
      .eq("status", "pending");
    if (!pendingTopics || pendingTopics.length === 0) {
      return users.map((u) => ({ ...u, unansweredCount: 0 }));
    }
    const topicIdToUser = new Map<string, string>();
    for (const t of pendingTopics) {
      topicIdToUser.set(t.id as string, t.user_id as string);
    }
    const topicIds = Array.from(topicIdToUser.keys());
    const [{ data: nqRows }, { data: replyRows }] = await Promise.all([
      supabase
        .from("normalized_questions")
        .select("topic_id, message_id")
        .in("topic_id", topicIds)
        .not("message_id", "is", null),
      supabase
        .from("chat_messages")
        .select("normalized")
        .eq("by_counselor", true),
    ]);
    const answered = new Set<string>();
    for (const r of replyRows ?? []) {
      const n = r.normalized as { reply_to_message_id?: unknown } | null;
      if (n && typeof n.reply_to_message_id === "string") {
        answered.add(n.reply_to_message_id);
      }
    }
    for (const r of nqRows ?? []) {
      const tid = r.topic_id as string | null;
      const mid = r.message_id as string | null;
      if (!tid || !mid) continue;
      if (answered.has(mid)) continue;
      const uid = topicIdToUser.get(tid);
      if (!uid) continue;
      counts.set(uid, (counts.get(uid) ?? 0) + 1);
    }
  } catch (e) {
    console.warn("[db] listAllUsersForCounselor unanswered count failed:", e);
  }

  return users.map((u) => ({
    ...u,
    unansweredCount: counts.get(u.userId) ?? 0,
  }));
}

// ---------------------------------------------------------------------------
// COUNSELOR PROFILE  (independent table; doesn't share `profiles`)
// ---------------------------------------------------------------------------

export async function upsertCounselorProfile(
  userId: string,
  p: CounselorProfile,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const row = {
    user_id: userId,
    name: p.name ?? "",
    description: p.description ?? "",
    expertise: p.expertise ?? [],
    email: p.email ?? "",
  };
  const { error } = await supabase
    .from("counselor_profiles")
    .upsert(row, { onConflict: "user_id" });
  if (error) console.warn("[db] upsertCounselorProfile failed:", error.message);
}

export async function fetchCounselorProfile(
  userId: string,
): Promise<CounselorProfile | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("counselor_profiles")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) return null;
  return {
    name: (data.name as string) ?? "",
    description: (data.description as string) ?? "",
    expertise: Array.isArray(data.expertise) ? (data.expertise as string[]) : [],
    email: (data.email as string) ?? "",
    createdAt: (data.created_at as string) ?? "",
    updatedAt: (data.updated_at as string) ?? "",
  };
}

// ---------------------------------------------------------------------------
// PERSONA
// ---------------------------------------------------------------------------

export async function upsertPersona(userId: string, p: Persona) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  // Persona shape on the backend uses camelCase fields; map to snake_case.
  const row = {
    user_id: userId,
    text: p.text ?? "",
    career_stage: p.careerStage ?? "",
    main_interests: p.mainInterests ?? [],
    strengths: p.strengths ?? [],
    skill_gaps: p.skillGaps ?? [],
    main_concerns: p.mainConcerns ?? [],
    recommended_next_step: p.recommendedNextStep ?? "",
    user_edited: p.userEdited === true,
    last_updated: p.lastUpdated ?? new Date().toISOString(),
  };
  const { error } = await supabase
    .from("personas")
    .upsert(row, { onConflict: "user_id" });
  if (error) console.warn("[db] upsertPersona failed:", error.message);
}

export async function fetchPersona(userId: string): Promise<Persona | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("personas")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) return null;
  return {
    text: data.text ?? "",
    careerStage: data.career_stage ?? "",
    mainInterests: Array.isArray(data.main_interests) ? data.main_interests : [],
    strengths: Array.isArray(data.strengths) ? data.strengths : [],
    skillGaps: Array.isArray(data.skill_gaps) ? data.skill_gaps : [],
    mainConcerns: Array.isArray(data.main_concerns) ? data.main_concerns : [],
    recommendedNextStep: data.recommended_next_step ?? "",
    userEdited: data.user_edited === true,
    lastUpdated: data.last_updated ?? "",
  };
}

// ---------------------------------------------------------------------------
// SWIPE  (insert-only event log)
// ---------------------------------------------------------------------------

export async function insertSwipeRecord(userId: string, r: SwipeRecord) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase.from("swipe_records").insert({
    user_id: userId,
    card_id: r.cardId,
    action: r.action,
    swiped_at: r.swipedAt,
  });
  if (error) console.warn("[db] insertSwipeRecord failed:", error.message);
}

// ---------------------------------------------------------------------------
// SKILL TRANSLATIONS
// ---------------------------------------------------------------------------

export async function insertSkillTranslation(
  userId: string,
  t: SkillTranslation,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase.from("skill_translations").insert({
    id: t.id,
    user_id: userId,
    raw_experience: t.rawExperience,
    groups: t.groups,
    resume_sentence: t.resumeSentence,
    created_at: t.createdAt,
  });
  if (error) console.warn("[db] insertSkillTranslation failed:", error.message);
}

// ---------------------------------------------------------------------------
// PLAN TODOS / WEEK NOTES / DAILY ANSWERS  (small surface)
// ---------------------------------------------------------------------------

export async function upsertPlanTodo(
  userId: string,
  key: string,
  done: boolean,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase
    .from("plan_todos")
    .upsert(
      { user_id: userId, key, done },
      { onConflict: "user_id,key" },
    );
  if (error) console.warn("[db] upsertPlanTodo failed:", error.message);
}

export async function upsertWeekNote(
  userId: string,
  week: number,
  note: string,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase
    .from("plan_week_notes")
    .upsert(
      { user_id: userId, week, note },
      { onConflict: "user_id,week" },
    );
  if (error) console.warn("[db] upsertWeekNote failed:", error.message);
}

export async function insertDailyAnswer(
  userId: string,
  date: string,
  questionId: string,
  answer: string,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase
    .from("daily_answers")
    .upsert(
      {
        user_id: userId,
        date,
        question_id: questionId,
        answer,
      },
      { onConflict: "user_id,date" },
    );
  if (error) console.warn("[db] insertDailyAnswer failed:", error.message);
}

export async function upsertStrike(
  userId: string,
  current: number,
  lastDate: string | null,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase.from("user_strikes").upsert(
    {
      user_id: userId,
      current,
      last_answered_date: lastDate,
    },
    { onConflict: "user_id" },
  );
  if (error) console.warn("[db] upsertStrike failed:", error.message);
}

// ---------------------------------------------------------------------------
// CHAT  (conversations + messages)
// ---------------------------------------------------------------------------

/** Ensure conversation row exists. Safe to call repeatedly. */
export async function upsertConversation(
  userId: string,
  conversationId: string,
  mode: "career" | "startup",
  createdAt: string,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase.from("chat_conversations").upsert(
    {
      id: conversationId,
      user_id: userId,
      mode,
      created_at: createdAt,
    },
    { onConflict: "id" },
  );
  if (error) console.warn("[db] upsertConversation failed:", error.message);
}

export async function insertChatMessage(
  userId: string,
  conversationId: string,
  message: ChatMessage,
  opts: { normalized?: unknown; askedHandoff?: boolean; byCounselor?: boolean } = {},
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase.from("chat_messages").insert({
    id: message.id,
    conversation_id: conversationId,
    user_id: userId,
    sender: message.role, // 'user' | 'assistant'
    content: message.text,
    normalized: opts.normalized ?? null,
    asked_handoff: opts.askedHandoff === true,
    by_counselor: opts.byCounselor === true,
    created_at: message.createdAt,
  });
  if (error) console.warn("[db] insertChatMessage failed:", error.message);
}

// ---------------------------------------------------------------------------
// COUNSELOR FAQS  (持久化諮詢師回過的問答 → 重啟後 RAG 仍能命中)
// ---------------------------------------------------------------------------

export type StoredCounselorFaq = {
  id: string;
  question: string;
  answer: string;
  tags: string[];
  createdBy: string | null;
  createdAt: string;
  updatedAt: string;
};

export async function upsertCounselorFaq(input: {
  id: string;
  question: string;
  answer: string;
  tags: string[];
  createdBy: string | null;
}): Promise<void> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase.from("counselor_faqs").upsert(
    {
      id: input.id,
      question: input.question,
      answer: input.answer,
      tags: input.tags,
      created_by: input.createdBy,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "id" },
  );
  if (error) console.warn("[db] upsertCounselorFaq failed:", error.message);
}

export async function listCounselorFaqs(
  limit = 200,
): Promise<StoredCounselorFaq[]> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("counselor_faqs")
    .select("*")
    .order("updated_at", { ascending: false })
    .limit(limit);
  if (error) {
    console.warn("[db] listCounselorFaqs failed:", error.message);
    return [];
  }
  return (data ?? []).map((r: Record<string, unknown>) => ({
    id: (r.id as string) ?? "",
    question: (r.question as string) ?? "",
    answer: (r.answer as string) ?? "",
    tags: Array.isArray(r.tags) ? (r.tags as string[]) : [],
    createdBy: (r.created_by as string | null) ?? null,
    createdAt: (r.created_at as string) ?? "",
    updatedAt: (r.updated_at as string) ?? "",
  }));
}

/**
 * 把某個使用者訊息對應的 normalized_questions row 標成已解決（諮詢師回完了）。
 * 該 user msg 沒有 normalized row 時就 noop — 表示是 KB 直接命中那條，
 * 之後同樣的問題以 KB 為準。
 */
export async function markNormalizedQuestionResolvedByMessageId(
  userMsgId: string,
  reason: string,
): Promise<void> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase
    .from("normalized_questions")
    .update({
      resolved: true,
      resolved_reason: reason,
    })
    .eq("message_id", userMsgId);
  if (error) {
    console.warn(
      "[db] markNormalizedQuestionResolvedByMessageId failed:",
      error.message,
    );
  }
}

/** 依 chat_messages.id 反查它所在的 conversation_id（限該 user 自己）。 */
export async function findConversationIdByMessageId(
  userId: string,
  messageId: string,
): Promise<string | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("chat_messages")
    .select("conversation_id")
    .eq("id", messageId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) {
    console.warn("[db] findConversationIdByMessageId failed:", error.message);
    return null;
  }
  return (data?.conversation_id as string | null) ?? null;
}

/**
 * 找該 user「最近一次有訊息流動」的 conversation_id。
 *
 * 為什麼不直接拿 chat_conversations.created_at 最新一筆？
 *   使用者切換創業／求職模式時可能會建一筆全新但空的 conversation，
 *   那筆會比真正在聊的對話更新，諮詢師端拿到就會是空的。
 *   所以這裡用 chat_messages 最新一筆所屬的 conversation_id，
 *   才是「使用者實際在聊」的那段。
 *
 * 沒有任何 chat_messages → 回 null（呼叫端會 fallback 到 listConversations）。
 */
export async function findMostActiveConversationId(
  userId: string,
): Promise<string | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("chat_messages")
    .select("conversation_id")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) {
    console.warn("[db] findMostActiveConversationId failed:", error.message);
    return null;
  }
  return (data?.conversation_id as string | null) ?? null;
}

/** List the user's conversations, newest first. */
export async function listConversations(
  userId: string,
  limit = 20,
): Promise<Array<{ id: string; mode: "career" | "startup"; createdAt: string }>> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("chat_conversations")
    .select("id, mode, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) {
    console.warn("[db] listConversations failed:", error.message);
    return [];
  }
  return (data ?? []).map((row) => ({
    id: row.id as string,
    mode: (row.mode as "career" | "startup") ?? "career",
    createdAt: (row.created_at as string) ?? new Date().toISOString(),
  }));
}

// ---------------------------------------------------------------------------
// USER INSIGHTS  (rolling AI-generated profile for counselors)
// ---------------------------------------------------------------------------

/** Upsert AI-extracted insight for a user. */
export async function upsertUserInsight(
  userId: string,
  draft: UserInsightDraft,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const now = new Date().toISOString();
  const { error } = await supabase.from("user_insights").upsert(
    {
      user_id: userId,
      problem_positioning: draft.problemPositioning ?? "",
      categories: draft.categories ?? [],
      emotion_profile: draft.emotionProfile ?? "",
      specific_concerns: draft.specificConcerns ?? [],
      tried_approaches: draft.triedApproaches ?? [],
      blockers: draft.blockers ?? [],
      recommended_topics: draft.recommendedTopics ?? [],
      priority: draft.priority ?? "中",
      tags: draft.tags ?? [],
      raw_summary: draft.rawSummary ?? "",
      message_count: draft.messageCount ?? 0,
      generated_by: draft.generatedBy ?? "",
      generated_at: now,
    },
    { onConflict: "user_id" },
  );
  if (error) console.warn("[db] upsertUserInsight failed:", error.message);
}

/** Fetch the latest insight for a user. Returns null when none / Supabase off. */
export async function fetchUserInsight(
  userId: string,
): Promise<UserInsight | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("user_insights")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) return null;
  return {
    userId: data.user_id as string,
    problemPositioning: (data.problem_positioning as string) ?? "",
    categories: Array.isArray(data.categories) ? data.categories : [],
    emotionProfile: (data.emotion_profile as string) ?? "",
    specificConcerns: Array.isArray(data.specific_concerns)
      ? data.specific_concerns
      : [],
    triedApproaches: Array.isArray(data.tried_approaches)
      ? data.tried_approaches
      : [],
    blockers: Array.isArray(data.blockers) ? data.blockers : [],
    recommendedTopics: Array.isArray(data.recommended_topics)
      ? data.recommended_topics
      : [],
    priority: (data.priority as UserInsight["priority"]) ?? "中",
    tags: Array.isArray(data.tags) ? data.tags : [],
    rawSummary: (data.raw_summary as string) ?? "",
    messageCount: (data.message_count as number) ?? 0,
    generatedBy: (data.generated_by as string) ?? "",
    counselorNote: (data.counselor_note as string) ?? "",
    generatedAt: (data.generated_at as string) ?? new Date(0).toISOString(),
    updatedAt: (data.updated_at as string) ?? new Date(0).toISOString(),
  };
}

/** Update only the counselor_note on an existing row. */
export async function updateInsightCounselorNote(
  userId: string,
  note: string,
) {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const { error } = await supabase
    .from("user_insights")
    .update({ counselor_note: note })
    .eq("user_id", userId);
  if (error)
    console.warn("[db] updateInsightCounselorNote failed:", error.message);
}

/**
 * 把新 tags 合併進 user_insights.tags（去重、保留順序、上限 12 個）。
 * 如果還沒有 user_insights row，會 upsert 一筆只有 tags 的最小 row。
 */
export async function appendUserTags(userId: string, newTags: string[]) {
  if (!newTags || newTags.length === 0) return;
  const supabase = getSupabaseAdmin();
  if (!supabase) return;

  const existing = await fetchUserInsight(userId);
  const merged: string[] = [];
  const seen = new Set<string>();
  for (const t of [...(existing?.tags ?? []), ...newTags]) {
    const trimmed = (t ?? "").trim();
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    merged.push(trimmed);
    if (merged.length >= 12) break;
  }

  if (existing) {
    const { error } = await supabase
      .from("user_insights")
      .update({ tags: merged })
      .eq("user_id", userId);
    if (error) console.warn("[db] appendUserTags update failed:", error.message);
  } else {
    const { error } = await supabase
      .from("user_insights")
      .insert({ user_id: userId, tags: merged });
    if (error) console.warn("[db] appendUserTags insert failed:", error.message);
  }
}

// ---------------------------------------------------------------------------
// QUESTION TOPICS  (相似 / 相同主題 + 未被 AI 解決的問題群組)
// ---------------------------------------------------------------------------

function rowToTopic(row: Record<string, unknown>): StoredTopic {
  return {
    id: (row.id as string) ?? "",
    userId: (row.user_id as string) ?? "",
    title: (row.title as string) ?? "",
    summary: (row.summary as string) ?? "",
    centroidText: (row.centroid_text as string) ?? "",
    status:
      (row.status as StoredTopic["status"]) === "resolved"
        ? "resolved"
        : "pending",
    resolvedBy: (row.resolved_by as string | null) ?? null,
    resolvedAt: (row.resolved_at as string | null) ?? null,
    kbSourceId: (row.kb_source_id as string | null) ?? null,
    questionCount: Number(row.question_count ?? 0),
    createdAt: (row.created_at as string) ?? "",
    updatedAt: (row.updated_at as string) ?? "",
  };
}

/**
 * 撈某 user「諮詢師回過的所有 reply_to_message_id」集合 — 用來判斷哪些 user msg 已被回覆。
 * 諮詢師回覆永遠會把 anchor 的 chat_messages.id 寫進 normalized.reply_to_message_id。
 */
async function fetchAnsweredMessageIds(
  userId: string,
): Promise<Set<string>> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return new Set();
  const { data, error } = await supabase
    .from("chat_messages")
    .select("normalized")
    .eq("user_id", userId)
    .eq("by_counselor", true);
  if (error) {
    console.warn("[db] fetchAnsweredMessageIds failed:", error.message);
    return new Set();
  }
  const set = new Set<string>();
  for (const row of data ?? []) {
    const n = row.normalized as { reply_to_message_id?: unknown } | null;
    if (n && typeof n.reply_to_message_id === "string") {
      set.add(n.reply_to_message_id);
    }
  }
  return set;
}

/** 列出某 user 的 topics（給諮詢師端 UI）。預設只回 pending。 */
export async function listUserTopics(
  userId: string,
  opts: { status?: "pending" | "resolved" | "all"; limit?: number } = {},
): Promise<StoredTopic[]> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return [];
  let q = supabase
    .from("question_topics")
    .select("*")
    .eq("user_id", userId)
    .order("updated_at", { ascending: false })
    .limit(opts.limit ?? 50);
  if (opts.status && opts.status !== "all") {
    q = q.eq("status", opts.status);
  }
  const { data, error } = await q;
  if (error) {
    console.warn("[db] listUserTopics failed:", error.message);
    return [];
  }
  const topics = (data ?? []).map(rowToTopic);
  if (topics.length === 0) return topics;

  // 補上 unansweredCount：拉這些 topic 的所有 normalized_questions（user msg id），
  // 比對諮詢師已回過哪些 reply_to_message_id，差集大小即未回題數。
  const topicIds = topics.map((t) => t.id);
  const [{ data: nqRows }, answeredIds] = await Promise.all([
    supabase
      .from("normalized_questions")
      .select("topic_id, message_id")
      .in("topic_id", topicIds)
      .not("message_id", "is", null),
    fetchAnsweredMessageIds(userId),
  ]);
  const counts = new Map<string, number>();
  for (const r of nqRows ?? []) {
    const tid = r.topic_id as string | null;
    const mid = r.message_id as string | null;
    if (!tid || !mid) continue;
    if (answeredIds.has(mid)) continue;
    counts.set(tid, (counts.get(tid) ?? 0) + 1);
  }
  return topics.map((t) => ({
    ...t,
    unansweredCount: counts.get(t.id) ?? 0,
  }));
}

/** Counselor 端用：拿某張 topic 的完整內容 + 所有成員問題（含 AI 暫時回覆）。 */
export async function fetchTopicWithMembers(
  topicId: string,
): Promise<TopicWithMembers | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data: tRow, error: tErr } = await supabase
    .from("question_topics")
    .select("*")
    .eq("id", topicId)
    .maybeSingle();
  if (tErr || !tRow) return null;
  const topic = rowToTopic(tRow);

  const { data: nqRows, error: nqErr } = await supabase
    .from("normalized_questions")
    .select(
      "id, message_id, conversation_id, raw_question, normalized_text, intents, emotion, urgency, created_at",
    )
    .eq("topic_id", topicId)
    .order("created_at", { ascending: true });
  if (nqErr) {
    console.warn("[db] fetchTopicWithMembers nq failed:", nqErr.message);
    return { ...topic, members: [], counselorReplies: [] };
  }

  const members: TopicMemberQuestion[] = (nqRows ?? []).map((r) => ({
    normalizedQuestionId: r.id as string,
    messageId: (r.message_id as string | null) ?? null,
    conversationId: (r.conversation_id as string | null) ?? null,
    rawQuestion: (r.raw_question as string) ?? "",
    normalizedText: (r.normalized_text as string) ?? "",
    intents: Array.isArray(r.intents) ? (r.intents as string[]) : [],
    emotion: (r.emotion as string) ?? "",
    urgency: (r.urgency as string) ?? "中",
    createdAt: (r.created_at as string) ?? "",
    // AI 暫時回覆已經不再給諮詢師看 — 兩個欄位永遠回 null。
    aiReply: null,
    aiReplyAt: null,
  }));

  // 把這個 topic 的諮詢師回覆全部抓出來（normalized.topic_id == this topic）。
  // 諮詢師端要看自己歷次回覆，user 端要靠這條知道引用了哪題。
  const counselorReplies: TopicCounselorReply[] = [];
  const conversationIds = Array.from(
    new Set(
      members
        .map((m) => m.conversationId)
        .filter((x): x is string => Boolean(x)),
    ),
  );
  if (conversationIds.length > 0) {
    const { data: replyRows } = await supabase
      .from("chat_messages")
      .select("id, conversation_id, content, normalized, created_at")
      .in("conversation_id", conversationIds)
      .eq("by_counselor", true)
      .order("created_at", { ascending: true });
    for (const r of replyRows ?? []) {
      const normalized = r.normalized as
        | {
            topic_id?: unknown;
            reply_to_message_id?: unknown;
            reply_to_text?: unknown;
          }
        | null;
      // 只收屬於這個 topic 的諮詢師訊息。
      if (
        !normalized ||
        typeof normalized.topic_id !== "string" ||
        normalized.topic_id !== topicId
      ) {
        continue;
      }
      counselorReplies.push({
        messageId: r.id as string,
        conversationId: r.conversation_id as string,
        text: (r.content as string) ?? "",
        createdAt: (r.created_at as string) ?? "",
        replyToMessageId:
          typeof normalized.reply_to_message_id === "string"
            ? (normalized.reply_to_message_id as string)
            : undefined,
        replyToText:
          typeof normalized.reply_to_text === "string"
            ? (normalized.reply_to_text as string)
            : undefined,
      });
    }
  }

  // 算這個 topic 的「未回答」數 — 把 counselorReplies 已知的 anchor id 對到 members。
  // counselorReplies 來源就是這 topic 的 by_counselor 訊息，已經 filter 過 topic_id 了。
  const answeredIds = new Set<string>();
  for (const r of counselorReplies) {
    if (r.replyToMessageId) answeredIds.add(r.replyToMessageId);
  }
  let unansweredCount = 0;
  for (const m of members) {
    if (m.messageId && !answeredIds.has(m.messageId)) unansweredCount++;
  }

  return { ...topic, unansweredCount, members, counselorReplies };
}

export async function createTopic(input: {
  userId: string;
  title: string;
  summary: string;
  centroidText: string;
}): Promise<StoredTopic | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("question_topics")
    .insert({
      user_id: input.userId,
      title: input.title,
      summary: input.summary,
      centroid_text: input.centroidText,
      question_count: 1,
      updated_at: new Date().toISOString(),
    })
    .select("*")
    .single();
  if (error) {
    console.warn("[db] createTopic failed:", error.message);
    return null;
  }
  return rowToTopic(data);
}

/** 把一筆 normalized_question 掛到某個 topic 上 + 同步 topic 的 centroid / count / updated_at。 */
export async function attachQuestionToTopic(
  topicId: string,
  normalizedQuestionId: string,
  appendedText: string,
): Promise<void> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return;
  const nqRes = await supabase
    .from("normalized_questions")
    .update({ topic_id: topicId })
    .eq("id", normalizedQuestionId);
  if (nqRes.error) {
    console.warn(
      "[db] attachQuestionToTopic update nq failed:",
      nqRes.error.message,
    );
  }
  // 拿目前的 topic 來更新 centroid / count（不用 atomic，諮詢端是低 QPS 場景）
  const { data: tRow } = await supabase
    .from("question_topics")
    .select("centroid_text, question_count")
    .eq("id", topicId)
    .maybeSingle();
  const baseText = (tRow?.centroid_text as string) ?? "";
  const baseCount = Number(tRow?.question_count ?? 0);
  const nextText = baseText
    ? `${baseText}\n${appendedText}`.slice(0, 4000)
    : appendedText.slice(0, 4000);
  await supabase
    .from("question_topics")
    .update({
      centroid_text: nextText,
      question_count: baseCount + 1,
      updated_at: new Date().toISOString(),
    })
    .eq("id", topicId);
}

export async function markTopicResolved(
  topicId: string,
  opts: { resolvedBy: string; kbSourceId?: string | null },
): Promise<StoredTopic | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("question_topics")
    .update({
      status: "resolved",
      resolved_by: opts.resolvedBy,
      resolved_at: new Date().toISOString(),
      kb_source_id: opts.kbSourceId ?? null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", topicId)
    .select("*")
    .single();
  if (error) {
    console.warn("[db] markTopicResolved failed:", error.message);
    return null;
  }

  // 同步把所有成員 normalized_questions 也標 resolved=true（諮詢師端 UI 會淡化）
  await supabase
    .from("normalized_questions")
    .update({
      resolved: true,
      resolved_reason: `Topic ${topicId} 已被諮詢師標記解決`,
    })
    .eq("topic_id", topicId);

  return rowToTopic(data);
}

// ---------------------------------------------------------------------------
// NORMALIZED QUESTIONS  (只存「不在既有 RAG KB」的新問題)
// ---------------------------------------------------------------------------

export async function insertNormalizedQuestion(
  userId: string,
  conversationId: string | null,
  messageId: string | null,
  draft: NormalizedQuestionDraft,
): Promise<StoredNormalizedQuestion | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data, error } = await supabase
    .from("normalized_questions")
    .insert({
      user_id: userId,
      conversation_id: conversationId,
      message_id: messageId,
      raw_question: draft.rawQuestion ?? "",
      normalized_text: draft.normalizedText ?? "",
      intents: draft.intents ?? [],
      emotion: draft.emotion ?? "",
      known_info: draft.knownInfo ?? [],
      missing_info: draft.missingInfo ?? [],
      urgency: draft.urgency ?? "中",
      counselor_summary: draft.counselorSummary ?? "",
      tags: draft.tags ?? [],
      novelty_score: draft.noveltyScore ?? 0,
      closest_kb_title: draft.closestKbTitle ?? "",
      closest_kb_score: draft.closestKbScore ?? 0,
      threshold_used: draft.thresholdUsed ?? 0,
      resolved: draft.resolved ?? false,
      resolved_reason: draft.resolvedReason ?? "",
      answer_score: draft.answerScore ?? 0,
      closest_kb_answer: draft.closestKbAnswer ?? "",
      generated_by: draft.generatedBy ?? "",
    })
    .select("*")
    .single();
  if (error) {
    console.warn("[db] insertNormalizedQuestion failed:", error.message);
    return null;
  }
  return rowToStoredQuestion(data);
}

export async function listNormalizedQuestions(
  userId: string,
  limit = 50,
): Promise<StoredNormalizedQuestion[]> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return [];
  const { data, error } = await supabase
    .from("normalized_questions")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) {
    console.warn("[db] listNormalizedQuestions failed:", error.message);
    return [];
  }
  return (data ?? []).map(rowToStoredQuestion);
}

function rowToStoredQuestion(row: Record<string, unknown>): StoredNormalizedQuestion {
  return {
    id: (row.id as string) ?? "",
    userId: (row.user_id as string) ?? "",
    conversationId: (row.conversation_id as string | null) ?? null,
    messageId: (row.message_id as string | null) ?? null,
    rawQuestion: (row.raw_question as string) ?? "",
    normalizedText: (row.normalized_text as string) ?? "",
    intents: Array.isArray(row.intents) ? (row.intents as string[]) : [],
    emotion: (row.emotion as string) ?? "",
    knownInfo: Array.isArray(row.known_info) ? (row.known_info as string[]) : [],
    missingInfo: Array.isArray(row.missing_info)
      ? (row.missing_info as string[])
      : [],
    urgency:
      (row.urgency as StoredNormalizedQuestion["urgency"]) ?? "中",
    counselorSummary: (row.counselor_summary as string) ?? "",
    tags: Array.isArray(row.tags) ? (row.tags as string[]) : [],
    noveltyScore: Number(row.novelty_score ?? 0),
    closestKbTitle: (row.closest_kb_title as string) ?? "",
    closestKbScore: Number(row.closest_kb_score ?? 0),
    thresholdUsed: Number(row.threshold_used ?? 0),
    resolved: row.resolved === true,
    resolvedReason: (row.resolved_reason as string) ?? "",
    answerScore: Number(row.answer_score ?? 0),
    closestKbAnswer: (row.closest_kb_answer as string) ?? "",
    generatedBy: (row.generated_by as string) ?? "",
    createdAt:
      (row.created_at as string) ?? new Date().toISOString(),
  };
}

/** Load all messages of a conversation, oldest first (chat order). */
export async function fetchConversationMessages(
  userId: string,
  conversationId: string,
): Promise<ChatConversation | null> {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  const { data: convRow, error: convErr } = await supabase
    .from("chat_conversations")
    .select("id, user_id, mode, created_at")
    .eq("id", conversationId)
    .maybeSingle();
  if (convErr || !convRow) return null;
  if (convRow.user_id !== userId) return null;

  const { data: msgRows, error: msgErr } = await supabase
    .from("chat_messages")
    .select("id, sender, content, by_counselor, normalized, created_at")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true });
  if (msgErr) {
    console.warn("[db] fetchConversationMessages failed:", msgErr.message);
    return null;
  }

  // 額外把這段對話裡每一題 user msg 對應的 normalized_questions.resolved 取出來，
  // 諮詢師端就能把「AI 已經處理掉」的問答整組打上「已完成」並淡化。
  const userMsgIds = (msgRows ?? [])
    .filter((m) => (m.sender as string) === "user")
    .map((m) => m.id as string);
  const resolvedSet = new Set<string>();
  if (userMsgIds.length > 0) {
    const { data: nqRows } = await supabase
      .from("normalized_questions")
      .select("message_id, resolved")
      .in("message_id", userMsgIds);
    for (const r of nqRows ?? []) {
      if (r.resolved === true && r.message_id) {
        resolvedSet.add(r.message_id as string);
      }
    }
  }

  const messages: ChatMessage[] = (msgRows ?? []).map((m) => {
    // 1) 直接讀 by_counselor 欄位；2) 兼容舊資料 — normalized JSONB 裡可能塞 from_counselor
    const normalized = m.normalized as
      | {
          from_counselor?: unknown;
          reply_to_message_id?: unknown;
          reply_to_text?: unknown;
          topic_id?: unknown;
        }
      | null;
    const fromCounselor =
      m.by_counselor === true ||
      (normalized && normalized.from_counselor === true);
    return {
      id: m.id as string,
      role: (m.sender as "user" | "assistant") ?? "assistant",
      text: (m.content as string) ?? "",
      fromCounselor: fromCounselor === true,
      resolved: resolvedSet.has(m.id as string),
      replyToMessageId:
        typeof normalized?.reply_to_message_id === "string"
          ? (normalized.reply_to_message_id as string)
          : undefined,
      replyToText:
        typeof normalized?.reply_to_text === "string"
          ? (normalized.reply_to_text as string)
          : undefined,
      topicId:
        typeof normalized?.topic_id === "string"
          ? (normalized.topic_id as string)
          : undefined,
      createdAt: (m.created_at as string) ?? new Date().toISOString(),
    };
  });
  return {
    id: convRow.id as string,
    userId,
    mode: (convRow.mode as "career" | "startup") ?? "career",
    messages,
    createdAt: (convRow.created_at as string) ?? new Date().toISOString(),
    updatedAt:
      messages[messages.length - 1]?.createdAt ??
      ((convRow.created_at as string) ?? new Date().toISOString()),
  };
}
