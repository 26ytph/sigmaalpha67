// In-memory store. Survives across hot reloads via globalThis caching.
// TODO: replace with a real database (Postgres / Mongo / Firestore / Supabase…).

import type { Profile } from "@/types/profile";
import type { Persona } from "@/types/persona";
import type { SwipeRecord } from "@/types/swipe";
import type { SkillTranslation } from "@/types/skill";
import type { ChatConversation } from "@/types/chat";
import type { CounselorCase } from "@/types/counselor";
import type { DailyAnswer, Streak } from "@/types/daily";
import type { PlanState } from "@/types/plan";
import type { KnowledgeChunk, KnowledgeSource, RagLog } from "@/types/knowledge";

type StoreShape = {
  profiles: Map<string, Profile>;
  personas: Map<string, Persona>;
  swipes: Map<string, SwipeRecord[]>;
  translations: Map<string, SkillTranslation[]>;
  conversations: Map<string, ChatConversation>;
  cases: Map<string, CounselorCase>;
  dailyAnswers: Map<string, DailyAnswer[]>;
  streaks: Map<string, Streak>;
  plans: Map<string, PlanState>;
  knowledgeSources: Map<string, KnowledgeSource>;
  knowledgeChunks: Map<string, KnowledgeChunk>;
  knowledgeSeeded: boolean;
  ragLogs: RagLog[];
};

declare global {
  // eslint-disable-next-line no-var
  var __employaStore: StoreShape | undefined;
}

function createStore(): StoreShape {
  return {
    profiles: new Map(),
    personas: new Map(),
    swipes: new Map(),
    translations: new Map(),
    conversations: new Map(),
    cases: new Map(),
    dailyAnswers: new Map(),
    streaks: new Map(),
    plans: new Map(),
    knowledgeSources: new Map(),
    knowledgeChunks: new Map(),
    knowledgeSeeded: false,
    ragLogs: [],
  };
}

export const store: StoreShape =
  globalThis.__employaStore ?? (globalThis.__employaStore = createStore());

export function newId(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
