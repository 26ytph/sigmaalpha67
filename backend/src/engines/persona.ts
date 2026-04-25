// =====================================================================
// FAKE engine — rule-based Persona generation.
// Mirrors `lib/logic/persona_engine.dart`. Replace with an LLM call
// (e.g. Anthropic Claude / OpenAI) for production-quality personas.
// =====================================================================

import type { Persona, PersonaGenerateInput } from "@/types/persona";
import { getRoleCardById } from "@/data/roles";

const TAG_TO_INTEREST: Record<string, string> = {
  design: "設計",
  engineering: "工程",
  data: "數據",
  product: "產品",
  marketing: "行銷",
  research: "研究",
  finance: "財務",
  startup: "創業",
};

export function generatePersona(input: PersonaGenerateInput): Persona {
  const profile = input.profile ?? {};
  const liked = input.explore?.likedRoleIds ?? [];

  const tagCount = new Map<string, number>();
  for (const id of liked) {
    const card = getRoleCardById(id);
    if (!card) continue;
    for (const tag of card.tags) tagCount.set(tag, (tagCount.get(tag) ?? 0) + 1);
  }
  const topTags = [...tagCount.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3);
  const mainInterests = topTags
    .map(([tag]) => TAG_TO_INTEREST[tag] ?? tag)
    .concat((profile.interests ?? []).slice(0, 2))
    .filter((v, i, a) => a.indexOf(v) === i)
    .slice(0, 4);

  const strengthSet = new Set<string>();
  for (const t of input.skillTranslations ?? []) {
    for (const g of t.groups) for (const s of g.skills) strengthSet.add(s);
  }
  for (const e of profile.experiences ?? []) strengthSet.add(e);
  const strengths = [...strengthSet].slice(0, 5);

  const skillGaps: string[] = [];
  if (mainInterests.includes("設計")) skillGaps.push("作品集敘事", "原型製作");
  if (mainInterests.includes("數據")) skillGaps.push("SQL 基本查詢", "資料視覺化");
  if (mainInterests.includes("工程")) skillGaps.push("Git workflow", "API 設計");
  if (skillGaps.length === 0) skillGaps.push("結構化面試回答", "履歷敘事");

  const stage = profile.currentStage || (profile.grade ? "在學探索" : "正在思考下一步");
  const concerns = profile.concerns ? [profile.concerns] : ["不知道科系能做什麼"];

  const dept = profile.department ?? "";
  const grade = profile.grade ?? "";
  const text =
    `你目前是一位${dept}${grade ? `${grade}學生` : ""}，` +
    `正處於${stage}階段。` +
    (mainInterests.length
      ? `從近期的滑卡與背景看，主要興趣集中在 ${mainInterests.join("、")}。`
      : "目前興趣方向尚未明顯，可以多探索幾個領域再收斂。") +
    (strengths.length ? `已經累積的能力包含 ${strengths.slice(0, 3).join("、")}。` : "") +
    `下一步建議：先用「技能翻譯」整理過去經驗，再投 2–3 份實習練習表達。`;

  const persona: Persona = {
    text: input.previousPersona?.userEdited ? input.previousPersona.text : text,
    careerStage: stage,
    mainInterests,
    strengths,
    skillGaps,
    mainConcerns: concerns,
    recommendedNextStep: "先用「技能翻譯」整理過去經驗，再投 2–3 份實習。",
    lastUpdated: new Date().toISOString(),
    userEdited: input.previousPersona?.userEdited ?? false,
  };
  return persona;
}

export function refreshPersonaSoft(input: PersonaGenerateInput): Persona {
  const fresh = generatePersona(input);
  if (input.previousPersona?.userEdited) {
    return {
      ...input.previousPersona,
      mainInterests: fresh.mainInterests,
      lastUpdated: fresh.lastUpdated,
    };
  }
  return fresh;
}
