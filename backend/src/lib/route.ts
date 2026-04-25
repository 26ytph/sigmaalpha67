import { NextRequest, NextResponse } from "next/server";
import { apiError } from "./errors";
import { authenticate, type AuthContext } from "./auth";

type Handler<T> = (
  req: NextRequest,
  ctx: { auth: AuthContext; params: T },
) => Promise<NextResponse> | NextResponse;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function withAuth<T = any>(handler: Handler<T>) {
  return async (req: NextRequest, route: { params: Promise<T> }) => {
    const auth = await authenticate(req);
    if (!auth) return apiError("unauthorized", "Missing or invalid Bearer token.");
    const params = await route.params;
    try {
      return await handler(req, { auth, params });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error";
      return apiError("internal", message);
    }
  };
}

export async function readJson<T>(req: NextRequest): Promise<T> {
  try {
    return (await req.json()) as T;
  } catch {
    throw new Error("Invalid JSON body.");
  }
}
