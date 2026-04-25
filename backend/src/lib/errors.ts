import { NextResponse } from "next/server";

export type ApiErrorCode =
  | "unauthorized"
  | "forbidden"
  | "bad_request"
  | "not_found"
  | "conflict"
  | "rate_limited"
  | "internal";

const STATUS: Record<ApiErrorCode, number> = {
  unauthorized: 401,
  forbidden: 403,
  bad_request: 400,
  not_found: 404,
  conflict: 409,
  rate_limited: 429,
  internal: 500,
};

export function apiError(code: ApiErrorCode, message: string) {
  return NextResponse.json({ error: { code, message } }, { status: STATUS[code] });
}
