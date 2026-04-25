// =====================================================================
// FAKE DATA — startup support resources (loans, grants, consulting…).
// Replace with a curated list / external data feed.
// =====================================================================

import type { StartupResource, StartupStage } from "@/types/startup";

export const STARTUP_RESOURCES: StartupResource[] = [
  {
    type: "loan",
    name: "青年創業及啟動金貸款",
    url: "https://www.youthloan.nyc.gov.tw/",
    stages: ["籌備期", "營運初期"],
  },
  {
    type: "grant",
    name: "教育部 U-Start 創新創業計畫",
    url: "https://ustart.yda.gov.tw/",
    stages: ["想法期", "驗證期", "籌備期"],
  },
  {
    type: "grant",
    name: "經濟部 SBIR 小型企業創新研發計畫",
    url: "https://www.sbir.org.tw/",
    stages: ["驗證期", "籌備期", "營運初期"],
  },
  {
    type: "consulting",
    name: "中小企業一站式服務",
    url: "https://www.sme.gov.tw/",
    stages: ["想法期", "驗證期", "籌備期", "營運初期"],
  },
  {
    type: "course",
    name: "國發會 / TTA 線上創業課程",
    url: "https://www.taiwanarena.tech/",
    stages: ["想法期", "驗證期"],
  },
  {
    type: "community",
    name: "AppWorks School / Accelerator",
    url: "https://appworks.tw/",
    stages: ["驗證期", "籌備期"],
  },
];

export function filterStartupResources(opts: {
  stage?: StartupStage;
  type?: StartupResource["type"];
}): StartupResource[] {
  return STARTUP_RESOURCES.filter((r) => {
    if (opts.stage && !r.stages.includes(opts.stage)) return false;
    if (opts.type && r.type !== opts.type) return false;
    return true;
  });
}
