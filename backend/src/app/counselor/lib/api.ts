"use client";

/**
 * 諮詢師端瀏覽器側 API 工具：
 *   - localStorage 存／讀 Bearer token
 *   - apiFetch() 自動帶 Authorization header
 *
 * 設計上完全跑在 client（"use client"），這樣在 SSR 階段就不會碰到
 * `window`/`localStorage`，而且和現有 next 路由（同 host /api/...）共存。
 */

const TOKEN_KEY = "employa.counselor.token";
const EMAIL_KEY = "employa.counselor.email";

export function saveSession(token: string, email: string) {
  if (typeof window === "undefined") return;
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(EMAIL_KEY, email);
}

export function clearSession() {
  if (typeof window === "undefined") return;
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(EMAIL_KEY);
}

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function getEmail(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(EMAIL_KEY);
}

export type ApiError = {
  status: number;
  message: string;
};

export async function apiFetch<T = unknown>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = getToken();
  const headers = new Headers(init.headers ?? {});
  if (!headers.has("content-type") && init.body) {
    headers.set("content-type", "application/json");
  }
  if (token) {
    headers.set("authorization", `Bearer ${token}`);
  }

  const res = await fetch(path, { ...init, headers });
  const text = await res.text();
  let body: unknown = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  if (!res.ok) {
    const message =
      (body && typeof body === "object" && "error" in body
        ? String((body as { error?: { message?: string } }).error?.message ?? "")
        : "") ||
      (typeof body === "string" ? body : "") ||
      `HTTP ${res.status}`;
    throw { status: res.status, message } as ApiError;
  }
  return body as T;
}
