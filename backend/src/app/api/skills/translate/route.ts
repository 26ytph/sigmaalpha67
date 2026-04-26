import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { translateExperience } from "@/engines/skillTranslator";

export const POST = withAuth(async (req) => {
  const body = await readJson<{ raw?: string }>(req);
  if (!body?.raw || !body.raw.trim()) return apiError("bad_request", "`raw` is required.");
  const translation = await translateExperience(body.raw);
  return NextResponse.json({ translation });
});
