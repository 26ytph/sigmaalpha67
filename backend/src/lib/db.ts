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
import type { Persona } from "@/types/persona";
import type { SwipeRecord } from "@/types/swipe";
import type { SkillTranslation } from "@/types/skill";
import type { ChatConversation, ChatMessage } from "@/types/chat";
import type { UserInsight, UserInsightDraft } from "@/types/insight";
import type {
  NormalizedQuestionDraft,
  StoredNormalizedQuestion,
} from "@/types/normalizedQuestion";

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
    .select("id, sender, content, by_counselor, created_at")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true });
  if (msgErr) {
    console.warn("[db] fetchConversationMessages failed:", msgErr.message);
    return null;
  }
  const messages: ChatMessage[] = (msgRows ?? []).map((m) => ({
    id: m.id as string,
    role: (m.sender as "user" | "assistant") ?? "assistant",
    text: (m.content as string) ?? "",
    byCounselor: m.by_counselor === true,
    createdAt: (m.created_at as string) ?? new Date().toISOString(),
  }));
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
