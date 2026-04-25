// In-memory rate limiter + reply cache. Single-process only — fine for this
// fake backend; swap for Redis if you ever go multi-instance.

const RATE_WINDOW_MS = 60_000;
const RATE_MAX_REQUESTS = Number(process.env.CHAT_RATE_PER_MIN ?? 30);

const CACHE_TTL_MS = Number(process.env.CHAT_CACHE_TTL_MS ?? 5 * 60_000);
const CACHE_MAX_ENTRIES = 500;

const requestLog = new Map<string, number[]>();

type CacheEntry = { value: unknown; expiresAt: number };
const replyCache = new Map<string, CacheEntry>();

export type RateCheckResult =
  | { ok: true; remaining: number; resetMs: number }
  | { ok: false; retryAfterMs: number };

export function checkRate(userId: string): RateCheckResult {
  if (RATE_MAX_REQUESTS <= 0) {
    return { ok: true, remaining: Number.POSITIVE_INFINITY, resetMs: 0 };
  }
  const now = Date.now();
  const cutoff = now - RATE_WINDOW_MS;
  const hits = (requestLog.get(userId) ?? []).filter((t) => t > cutoff);

  if (hits.length >= RATE_MAX_REQUESTS) {
    const retryAfterMs = Math.max(0, hits[0] + RATE_WINDOW_MS - now);
    requestLog.set(userId, hits);
    return { ok: false, retryAfterMs };
  }

  hits.push(now);
  requestLog.set(userId, hits);
  return {
    ok: true,
    remaining: Math.max(0, RATE_MAX_REQUESTS - hits.length),
    resetMs: RATE_WINDOW_MS,
  };
}

export function getCachedReply<T>(key: string): T | null {
  const entry = replyCache.get(key);
  if (!entry) return null;
  if (entry.expiresAt < Date.now()) {
    replyCache.delete(key);
    return null;
  }
  return entry.value as T;
}

export function setCachedReply<T>(key: string, value: T): void {
  if (CACHE_TTL_MS <= 0) return;
  if (replyCache.size >= CACHE_MAX_ENTRIES) {
    const oldestKey = replyCache.keys().next().value;
    if (oldestKey !== undefined) replyCache.delete(oldestKey);
  }
  replyCache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
}

export function buildChatCacheKey(parts: {
  userId: string;
  message: string;
  mode: string;
  useRag: boolean;
  personaHash: string;
  historyHash: string;
}): string {
  const normalized = parts.message.trim().toLowerCase().replace(/\s+/g, " ");
  return [
    parts.userId,
    parts.mode,
    parts.useRag ? "rag" : "norag",
    parts.personaHash,
    parts.historyHash,
    normalized,
  ].join("|");
}

export function hashHistory(
  messages: Array<{ role: string; text: string }>,
  maxTurns = 4,
): string {
  const tail = messages.slice(-maxTurns);
  if (tail.length === 0) return "h0";
  let h = 2166136261 >>> 0;
  for (const m of tail) {
    const s = `${m.role}:${m.text}`;
    for (let i = 0; i < s.length; i += 1) {
      h ^= s.charCodeAt(i);
      h = (h + ((h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24))) >>> 0;
    }
  }
  return `h${h.toString(36)}`;
}
