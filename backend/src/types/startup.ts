import type { PlanWeek } from "./plan";

export type StartupStage = "想法期" | "驗證期" | "籌備期" | "營運初期";

export type StartupResourceType = "loan" | "grant" | "consulting" | "course" | "community";

export type StartupResource = {
  type: StartupResourceType;
  name: string;
  url: string;
  stages: StartupStage[];
};

export type StartupAnalysis = {
  stage: StartupStage;
  missingInfo: string[];
  recommendedResources: StartupResource[];
  todos: PlanWeek[];
};
