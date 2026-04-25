import { NextResponse } from "next/server";
import { withAuth } from "@/lib/route";
import { store } from "@/lib/store";

export const GET = withAuth(async (_req, { auth }) => {
  const translations = store.translations.get(auth.userId) ?? [];
  return NextResponse.json({ translations });
});
