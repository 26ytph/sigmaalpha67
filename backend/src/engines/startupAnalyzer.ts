// =====================================================================
// FAKE engine — startup stage classifier + resource recommender.
// Replace with an LLM-driven analyzer for richer reasoning.
// =====================================================================

import type { Profile } from "@/types/profile";
import type { StartupAnalysis, StartupStage } from "@/types/startup";
import { filterStartupResources } from "@/data/startupResources";
import { PLAN_TEMPLATES } from "@/data/planTemplates";

export function analyzeStartup(opts: {
  idea: string;
  profile?: Partial<Profile> | null;
}): StartupAnalysis {
  const idea = opts.idea.trim();

  let stage: StartupStage = "想法期";
  if (/已開店|有客戶|營業中|已上線/.test(idea)) stage = "營運初期";
  else if (/籌備|登記|公司|資金/.test(idea)) stage = "籌備期";
  else if (/已驗證|有人買|預購|MVP|測試/.test(idea)) stage = "驗證期";

  const missingInfo: string[] = [];
  if (!/客|target|target customer|TA/i.test(idea)) missingInfo.push("客群定義");
  if (!/驗證|訪談|預購|問卷/.test(idea)) missingInfo.push("市場驗證");
  if (!/獲利|商業模式|收入|profit/i.test(idea)) missingInfo.push("商業模式");
  if (!/競品|對手|alternatives?/i.test(idea)) missingInfo.push("競品分析");

  return {
    stage,
    missingInfo,
    recommendedResources: filterStartupResources({ stage }),
    todos: PLAN_TEMPLATES.startup,
  };
}
