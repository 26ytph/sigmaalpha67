import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { SKILL_GAPS } from "@/data/adminMetrics";

export const GET = withAuth(async () => {
  return NextResponse.json({ items: SKILL_GAPS });
});
