import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { TOP_CAREER_PATHS } from "@/data/adminMetrics";

export const GET = withAuth(async () => {
  return NextResponse.json({ items: TOP_CAREER_PATHS });
});
