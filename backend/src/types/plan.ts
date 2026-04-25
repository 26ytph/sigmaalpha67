import type { RoleCard } from "./swipe";

export type PlanWeek = {
  week: number;
  title: string;
  goals: string[];
  resources: string[];
  outputs: string[];
};

export type Plan = {
  headline: string;
  basedOnTopTags: Array<{ tag: string; score: number }>;
  recommendedRoles: RoleCard[];
  weeks: PlanWeek[];
};

export type PlanState = {
  plan: Plan | null;
  todos: Record<string, boolean>;       // key e.g. "w1.t0" -> done
  weekNotes: Record<string, string>;    // key e.g. "1" -> note
  generatedAt: string | null;
};
