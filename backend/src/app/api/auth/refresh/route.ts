import { NextResponse } from "next/server";
import { apiError } from "@/lib/errors";
import { readJson } from "@/lib/route";
import type { NextRequest } from "next/server";

type Body = { refreshToken?: string };

// FAKE: extracts the userId from `refresh_<uid>` and re-issues an access token.
export async function POST(req: NextRequest) {
  const body = await readJson<Body>(req);
  if (!body?.refreshToken?.startsWith("refresh_")) {
    return apiError("unauthorized", "Invalid refresh token.");
  }
  const userId = body.refreshToken.slice("refresh_".length);
  return NextResponse.json({
    accessToken: userId,
    refreshToken: body.refreshToken,
    tokenType: "Bearer",
    expiresIn: 60 * 60 * 24 * 7,
  });
}
