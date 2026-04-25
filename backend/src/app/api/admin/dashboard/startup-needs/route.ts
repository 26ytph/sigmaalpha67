import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { STARTUP_NEEDS } from "@/data/adminMetrics";

export const GET = withAuth(async () => {
  return NextResponse.json({ items: STARTUP_NEEDS });
});
