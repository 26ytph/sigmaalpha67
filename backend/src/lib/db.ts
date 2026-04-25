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
  opts: { normalized?: unknown; askedHandoff?: boolean } = {},
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
    created_at: message.createdAt,
  });
  if (error) console.warn("[db] insertChatMessage failed:", error.message);
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
    .select("id, sender, content, created_at")
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
