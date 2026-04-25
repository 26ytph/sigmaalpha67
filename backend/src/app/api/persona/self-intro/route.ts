import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";
import {
  buildHeuristicSelfIntro,
  generateSelfIntroFromProfile,
} from "@/engines/selfIntro";

/**
 * POST /api/persona/self-intro
 *
 * 從使用者目前的 profile（履歷）跑 Gemini 生成一段自介。
 * 不會自動寫進 persona — 只回 { selfIntro }，由前端決定要不要儲存。
 */
export const POST = withAuth(async (_req, { auth }) => {
  const profile = store.profiles.get(auth.userId) ?? null;
  const persona = store.personas.get(auth.userId) ?? null;

  let selfIntro = await generateSelfIntroFromProfile(profile, persona);
  if (!selfIntro) selfIntro = buildHeuristicSelfIntro(profile, persona);

  return NextResponse.json({ selfIntro });
});
