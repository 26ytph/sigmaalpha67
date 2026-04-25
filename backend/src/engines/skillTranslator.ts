// =====================================================================
// FAKE engine — keyword-based skill translation.
// Mirrors `lib/logic/skill_translator.dart`. Replace with an LLM call.
// =====================================================================

import type { SkillTranslation } from "@/types/skill";
import { newId } from "@/lib/store";

const KEYWORD_SKILLS: Array<{ kw: RegExp; skills: string[] }> = [
  { kw: /(迎新|活動|社團|策展)/, skills: ["活動企劃", "流程把控", "跨組溝通"] },
  { kw: /(訪談|採訪|報導)/, skills: ["訪談技巧", "資料整理", "結論歸納"] },
  { kw: /(報告|簡報|presentation)/i, skills: ["敘事結構", "資料視覺化", "公開表達"] },
  { kw: /(教|家教|助教|tutor)/i, skills: ["教學設計", "拆解複雜概念", "耐心溝通"] },
  { kw: /(打工|餐廳|店員|service)/i, skills: ["服務流程", "壓力管理", "顧客同理心"] },
  { kw: /(程式|coding|專案|hackathon|coding|build|寫程式)/i, skills: ["問題拆解", "工具實作", "團隊協作"] },
  { kw: /(設計|繪|畫|插畫|圖)/, skills: ["視覺敏感度", "工具熟悉度", "美感判斷"] },
  { kw: /(分析|統計|數據|excel|sql)/i, skills: ["資料處理", "假設驗證", "結論歸納"] },
];

export function translateExperience(raw: string): SkillTranslation {
  const text = raw.trim();
  const segments = text
    .split(/[，,。.；;\n]/)
    .map((s) => s.trim())
    .filter(Boolean);
  const groups = segments.length ? segments : [text];

  const groupResults = groups.map((seg) => {
    const skillSet = new Set<string>();
    for (const { kw, skills } of KEYWORD_SKILLS) {
      if (kw.test(seg)) for (const s of skills) skillSet.add(s);
    }
    if (skillSet.size === 0) {
      ["問題拆解", "團隊協作", "成果交付"].forEach((s) => skillSet.add(s));
    }
    return { experience: seg, skills: [...skillSet].slice(0, 4) };
  });

  const sentenceParts = groupResults.map(
    (g) => `曾於${g.experience}中展現${g.skills.slice(0, 3).join("、")}的能力`,
  );
  const resumeSentence = `${sentenceParts.join("，並")} ，能將實作經驗轉化為可量化交付。`;

  return {
    id: newId("st"),
    rawExperience: text,
    groups: groupResults,
    resumeSentence,
    createdAt: new Date().toISOString(),
  };
}
