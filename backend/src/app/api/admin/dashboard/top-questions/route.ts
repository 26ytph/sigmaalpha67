import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { TOP_QUESTIONS } from "@/data/adminMetrics";

export const GET = withAuth(async (req) => {
  const url = new URL(req.url);
  const from = url.searchParams.get("from");
  const to = url.searchParams.get("to");
  // FAKE: range filter is a no-op since the data is static.
  return NextResponse.json({ from, to, items: TOP_QUESTIONS });
});
