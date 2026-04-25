import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import type { Profile, ProfileInput } from "@/types/profile";

export const GET = withAuth(async (_req, { auth }) => {
  const profile = store.profiles.get(auth.userId);
  if (!profile) return apiError("not_found", "Profile not yet created.");
  return NextResponse.json({ profile });
});

export const PUT = withAuth(async (req, { auth }) => {
  const body = await readJson<Partial<ProfileInput>>(req);
  if (!body || typeof body !== "object") {
    return apiError("bad_request", "Body must be a JSON object.");
  }
  const now = new Date().toISOString();
  const existing = store.profiles.get(auth.userId);
  const profile: Profile = {
    name: body.name ?? existing?.name ?? "",
    age: body.age ?? existing?.age ?? "",
    contact: body.contact ?? existing?.contact ?? "",
    department: body.department ?? existing?.department ?? "",
    grade: body.grade ?? existing?.grade ?? "",
    location: body.location ?? existing?.location ?? "",
    currentStage: body.currentStage ?? existing?.currentStage ?? "",
    goals: body.goals ?? existing?.goals ?? [],
    interests: body.interests ?? existing?.interests ?? [],
    experiences: body.experiences ?? existing?.experiences ?? [],
    educationItems: body.educationItems ?? existing?.educationItems ?? [],
    concerns: body.concerns ?? existing?.concerns ?? "",
    startupInterest: body.startupInterest ?? existing?.startupInterest ?? false,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };
  store.profiles.set(auth.userId, profile);
  return NextResponse.json({ profile });
});
