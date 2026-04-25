import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { STUCK_TASKS } from "@/data/adminMetrics";

export const GET = withAuth(async () => {
  return NextResponse.json({ items: STUCK_TASKS });
});
