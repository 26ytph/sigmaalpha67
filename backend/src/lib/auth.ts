import type { NextRequest } from "next/server";

export type AuthContext = {
  userId: string;
  token: string;
};

// FAKE: accepts any non-empty Bearer token and treats it as the user id.
// TODO: replace with real JWT verification (jose / next-auth / firebase-admin / etc.)
export function authenticate(req: NextRequest): AuthContext | null {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    if (process.env.ALLOW_ANON === "1") {
      return { userId: "anon", token: "" };
    }
    return null;
  }
  const token = match[1].trim();
  if (!token) return null;
  // For the fake backend, the token *is* the user id.
  return { userId: token, token };
}
