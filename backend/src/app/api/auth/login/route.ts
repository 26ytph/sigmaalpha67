import { NextResponse } from "next/server";
import { apiError } from "@/lib/errors";
import { readJson } from "@/lib/route";
import type { NextRequest } from "next/server";

type Body = { email?: string; provider?: "email" | "google" | "apple"; password?: string };

// FAKE: returns a token equal to a user id derived from email.
// Replace with a real auth provider (next-auth, Firebase, Supabase, etc.).
export async function POST(req: NextRequest) {
  const body = await readJson<Body>(req);
  if (!body?.email) return apiError("bad_request", "`email` is required.");
  const userId = `u_${Buffer.from(body.email).toString("hex").slice(0, 16)}`;
  const expiresIn = 60 * 60 * 24 * 7; // 7 days
  return NextResponse.json({
    accessToken: userId,
    refreshToken: `refresh_${userId}`,
    tokenType: "Bearer",
    expiresIn,
    user: { id: userId, email: body.email, provider: body.provider ?? "email" },
  });
}
