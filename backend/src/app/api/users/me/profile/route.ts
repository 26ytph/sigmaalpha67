import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store } from "@/lib/store";
import * as db from "@/lib/db";
import type { Profile, ProfileInput, EducationEntry } from "@/types/profile";

const EDU_GRADE_LIKE =
  /(高中|高一|高二|高三|大[一二三四]|碩[一二]|博|畢業|年級|研一|研二|國[一二三]|高中部)/u;
const EDU_SEPARATOR = /[\s・·|/，,]/u;

function normaliseEducation(value: unknown): EducationEntry[] {
  if (!Array.isArray(value)) return [];
  if (value.length === 0) return [];

  // List-level legacy detection: a single education record was saved as 2–3
  // separate strings (each element = one field) instead of one object. Merge
  // them back into one entry. Triggers when:
  //   - all elements are strings AND length is 2 or 3, AND
  //   - at least one element looks like a grade, OR every element is a
  //     single token (no internal whitespace / separator).
  if (
    value.every((e) => typeof e === "string") &&
    value.length >= 2 &&
    value.length <= 3
  ) {
    const strings = (value as string[]).map((s) => s.trim());
    const gradeIdx = strings.findIndex((s) => EDU_GRADE_LIKE.test(s));
    const allSingleToken = strings.every(
      (s) => s.length > 0 && !EDU_SEPARATOR.test(s),
    );
    if (gradeIdx >= 0 || allSingleToken) {
      let school = "";
      let department = "";
      let grade = "";
      if (gradeIdx >= 0) {
        grade = strings[gradeIdx];
        const remaining = strings.filter((_, i) => i !== gradeIdx);
        if (remaining.length === 1) {
          school = remaining[0];
        } else if (remaining.length === 2) {
          // 較長的當學校（'國立臺灣大學' vs '社會系'）。
          if (remaining[0].length >= remaining[1].length) {
            school = remaining[0];
            department = remaining[1];
          } else {
            school = remaining[1];
            department = remaining[0];
          }
        }
      } else {
        // 沒抓到年級但全是原子欄位：以位置推 [學校, 學系, (年級)]
        school = strings[0] ?? "";
        department = strings[1] ?? "";
        grade = strings[2] ?? "";
      }
      return school || department || grade ? [{ school, department, grade }] : [];
    }
  }

  return value
    .map((e): EducationEntry | null => {
      if (e && typeof e === "object") {
        const obj = e as Record<string, unknown>;
        return {
          school: typeof obj.school === "string" ? obj.school : "",
          department: typeof obj.department === "string" ? obj.department : "",
          grade: typeof obj.grade === "string" ? obj.grade : "",
        };
      }
      if (typeof e === "string") {
        // Per-string legacy: a single combined line like '台大 資工 大三'.
        const parts = e
          .split(/[\s・·|/，,]+/u)
          .filter((s) => s.length > 0);
        return {
          school: parts[0] ?? "",
          department: parts[1] ?? "",
          grade: parts.slice(2).join(" "),
        };
      }
      return null;
    })
    .filter(
      (e): e is EducationEntry =>
        e !== null && (e.school !== "" || e.department !== "" || e.grade !== ""),
    );
}

function healProfile(p: Profile): Profile {
  return { ...p, educationItems: normaliseEducation(p.educationItems) };
}

export const GET = withAuth(async (_req, { auth }) => {
  // Try Supabase first; fall back to in-memory.
  const remote = await db.fetchProfile(auth.userId);
  if (remote) {
    const healed = healProfile(remote);
    store.profiles.set(auth.userId, healed);
    return NextResponse.json({ profile: healed });
  }
  const profile = store.profiles.get(auth.userId);
  if (!profile) return apiError("not_found", "Profile not yet created.");
  return NextResponse.json({ profile: healProfile(profile) });
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
    school: body.school ?? existing?.school ?? "",
    birthday: body.birthday ?? existing?.birthday ?? "",
    email: body.email ?? existing?.email ?? "",
    phone: body.phone ?? existing?.phone ?? "",
    department: body.department ?? existing?.department ?? "",
    grade: body.grade ?? existing?.grade ?? "",
    location: body.location ?? existing?.location ?? "",
    currentStage: body.currentStage ?? existing?.currentStage ?? "",
    goals: body.goals ?? existing?.goals ?? [],
    interests: body.interests ?? existing?.interests ?? [],
    experiences: body.experiences ?? existing?.experiences ?? [],
    educationItems: body.educationItems
      ? normaliseEducation(body.educationItems)
      : existing?.educationItems ?? [],
    concerns: body.concerns ?? existing?.concerns ?? "",
    startupInterest: body.startupInterest ?? existing?.startupInterest ?? false,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };
  store.profiles.set(auth.userId, profile);
  // Best-effort sync to Supabase (silently ignored when not configured).
  await db.upsertProfile(auth.userId, profile);
  return NextResponse.json({ profile });
});
