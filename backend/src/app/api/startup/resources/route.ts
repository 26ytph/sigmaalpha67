import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { filterStartupResources } from "@/data/startupResources";
import type { StartupStage, StartupResourceType } from "@/types/startup";

const VALID_STAGES: StartupStage[] = ["想法期", "驗證期", "籌備期", "營運初期"];
const VALID_TYPES: StartupResourceType[] = ["loan", "grant", "consulting", "course", "community"];

export const GET = withAuth(async (req) => {
  const url = new URL(req.url);
  const stageParam = url.searchParams.get("stage");
  const typeParam = url.searchParams.get("type");
  const stage =
    stageParam && (VALID_STAGES as string[]).includes(stageParam) ? (stageParam as StartupStage) : undefined;
  const type =
    typeParam && (VALID_TYPES as string[]).includes(typeParam) ? (typeParam as StartupResourceType) : undefined;
  const resources = filterStartupResources({ stage, type });
  return NextResponse.json({ resources });
});
