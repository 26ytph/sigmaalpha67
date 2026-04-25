import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { getRoleCards } from "@/data/roles";

export const GET = withAuth(async (req) => {
  const url = new URL(req.url);
  const mode = (url.searchParams.get("mode") ?? "career") as "career" | "startup";
  const limitRaw = url.searchParams.get("limit");
  const limit = limitRaw ? Number.parseInt(limitRaw, 10) : undefined;
  const cards = getRoleCards(mode, Number.isFinite(limit) ? limit : undefined);
  return NextResponse.json({ cards });
});
