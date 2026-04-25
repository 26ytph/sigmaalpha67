import { NextResponse } from "next/server";
import { apiError } from "@/lib/errors";
import { readJson } from "@/lib/route";
import type { NextRequest } from "next/server";

type Body = { email?: string; password?: string; name?: string };

// FAKE: registration just hands back a Bearer token (same scheme as /login).
export async function POST(req: NextRequest) {
  const body = await readJson<Body>(req);
  if (!body?.email) return apiError("bad_request", "`email` is required.");
  const userId = `u_${Buffer.from(body.email).toString("hex").slice(0, 16)}`;
  return NextResponse.json({
    accessToken: userId,
    refreshToken: `refresh_${userId}`,
    tokenType: "Bearer",
    expiresIn: 60 * 60 * 24 * 7,
    user: { id: userId, email: body.email, name: body.name ?? null },
  });
}
