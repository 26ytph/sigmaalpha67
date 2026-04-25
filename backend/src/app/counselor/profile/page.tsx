"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { colors, radii, gradients, shadows, fontStack } from "../theme";
import {
  apiFetch,
  clearSession,
  getEmail,
  getToken,
} from "../lib/api";
import { Header } from "../components/Header";

type CounselorProfile = {
  name: string;
  description: string;
  expertise: string[];
  email: string;
  createdAt: string;
  updatedAt: string;
};

type ProfileResponse = {
  profile: CounselorProfile;
  exists: boolean;
};

const PROFILE_CACHE_PREFIX = "employa.counselor.profile:";

function loadCachedProfile(email: string): CounselorProfile | null {
  if (typeof window === "undefined" || !email) return null;
  try {
    const raw = localStorage.getItem(PROFILE_CACHE_PREFIX + email);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as CounselorProfile;
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch {
    return null;
  }
}

function saveCachedProfile(email: string, p: CounselorProfile) {
  if (typeof window === "undefined" || !email) return;
  try {
    localStorage.setItem(PROFILE_CACHE_PREFIX + email, JSON.stringify(p));
  } catch {
    /* ignore quota / disabled storage */
  }
}

const SUGGESTED_EXPERTISE = [
  "資訊領域",
  "管理",
  "製造業",
  "金融",
  "行銷／品牌",
  "醫療／生技",
  "教育",
  "公部門",
  "新創／創業",
  "設計／創意",
  "法律",
  "心理／輔導",
];

export default function CounselorProfilePage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<string | null>(null);

  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [expertise, setExpertise] = useState<string[]>([]);
  const [customExpertise, setCustomExpertise] = useState("");

  const email = useMemo(() => getEmail() ?? "", []);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/counselor/login");
      return;
    }

    // 1) 先從 localStorage 撈：開頁面立刻看到上次填的內容，不會閃白
    const cached = loadCachedProfile(email);
    if (cached) {
      setName(cached.name ?? "");
      setDescription(cached.description ?? "");
      setExpertise(cached.expertise ?? []);
      setLoading(false);
    }
    let hadCache = !!cached;

    // 2) 再去 server 拉「真的最新」的資料覆蓋上去
    (async () => {
      try {
        const res = await apiFetch<ProfileResponse>(
          "/api/counselor/me/profile",
        );
        if (res.exists) {
          // server 有資料 → 用 server 的覆蓋
          setName(res.profile.name ?? "");
          setDescription(res.profile.description ?? "");
          setExpertise(res.profile.expertise ?? []);
          saveCachedProfile(email, res.profile);
        } else if (!hadCache) {
          // server 沒資料、本地也沒 → 維持空白讓使用者新填
        }
        // server 沒資料但 localStorage 有 → 沿用 localStorage 的，不覆蓋
      } catch (e) {
        const msg =
          typeof e === "object" && e && "message" in e
            ? String((e as { message?: string }).message ?? "")
            : "";
        if (
          (e as { status?: number })?.status === 401 ||
          msg.toLowerCase().includes("unauthor")
        ) {
          clearSession();
          router.replace("/counselor/login");
          return;
        }
        // 撈失敗就讓 localStorage 那份留著，使用者體感不會被打斷
      } finally {
        setLoading(false);
      }
    })();
  }, [router, email]);

  function toggleExpertise(item: string) {
    setExpertise((prev) =>
      prev.includes(item) ? prev.filter((x) => x !== item) : [...prev, item],
    );
  }

  function addCustomExpertise() {
    const t = customExpertise.trim();
    if (!t) return;
    if (!expertise.includes(t)) setExpertise((prev) => [...prev, t]);
    setCustomExpertise("");
  }

  async function save() {
    if (!name.trim()) {
      setError("請填姓名");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const res = await apiFetch<ProfileResponse>("/api/counselor/me/profile", {
        method: "PUT",
        body: JSON.stringify({
          name: name.trim(),
          description: description.trim(),
          expertise,
          email,
        }),
      });
      // 順便快取一份在瀏覽器，下次打開檔案頁面立刻看得到上次填的內容
      // （即使 backend 沒接好，也不會被打回空白）
      saveCachedProfile(email, res.profile);
      setSavedAt(new Date().toLocaleTimeString());
    } catch (e) {
      const msg =
        typeof e === "object" && e && "message" in e
          ? String((e as { message?: string }).message ?? "")
          : "儲存失敗";
      setError(msg || "儲存失敗");
    } finally {
      setBusy(false);
    }
  }

  function logout() {
    clearSession();
    router.replace("/counselor/login");
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        background: gradients.bg,
        fontFamily: fontStack,
        color: colors.textPrimary,
      }}
    >
      <Header onLogout={logout} active="profile" />

      <div
        style={{
          maxWidth: 720,
          margin: "0 auto",
          padding: "24px 20px 64px",
        }}
      >
        <div
          style={{
            background: gradients.hero,
            borderRadius: radii.xl,
            padding: "20px 22px",
            boxShadow: shadows.soft,
          }}
        >
          <div
            style={{
              fontSize: 22,
              fontWeight: 800,
              letterSpacing: -0.4,
              color: colors.textPrimary,
            }}
          >
            建立諮詢師檔案
          </div>
          <div style={{ height: 4 }} />
          <div style={{ fontSize: 13, color: colors.textSecondary }}>
            填上姓名、簡介與你的專長領域，個案頁就會用這份資料介紹你。
          </div>
        </div>

        <div style={{ height: 18 }} />

        {loading ? (
          <Card>
            <div style={{ color: colors.textTertiary, fontSize: 13 }}>
              載入中…
            </div>
          </Card>
        ) : (
          <Card>
            <Field label="姓名">
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="例如：林心理"
                style={inputStyle}
              />
            </Field>

            <Field label="敘述／自我介紹">
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="講講你的諮詢風格、擅長處理的議題、對個案的期待。"
                rows={5}
                style={{
                  ...inputStyle,
                  resize: "vertical",
                  lineHeight: 1.55,
                  fontFamily: "inherit",
                }}
              />
            </Field>

            <Field label="專長領域">
              <div
                style={{
                  display: "flex",
                  flexWrap: "wrap",
                  gap: 8,
                  marginBottom: 10,
                }}
              >
                {SUGGESTED_EXPERTISE.map((tag) => {
                  const on = expertise.includes(tag);
                  return (
                    <button
                      key={tag}
                      type="button"
                      onClick={() => toggleExpertise(tag)}
                      style={{
                        padding: "8px 14px",
                        borderRadius: radii.pill,
                        border: on
                          ? "none"
                          : `1px solid ${colors.borderStrong}`,
                        background: on ? gradients.brand : "transparent",
                        color: on ? "#fff" : colors.textSecondary,
                        fontSize: 13,
                        fontWeight: 700,
                        cursor: "pointer",
                        boxShadow: on ? shadows.soft : "none",
                      }}
                    >
                      {on ? "❤ " : ""}
                      {tag}
                    </button>
                  );
                })}
              </div>

              {expertise.filter((t) => !SUGGESTED_EXPERTISE.includes(t))
                .length > 0 && (
                <div
                  style={{
                    display: "flex",
                    flexWrap: "wrap",
                    gap: 8,
                    marginBottom: 10,
                  }}
                >
                  {expertise
                    .filter((t) => !SUGGESTED_EXPERTISE.includes(t))
                    .map((tag) => (
                      <span
                        key={tag}
                        style={{
                          padding: "8px 14px",
                          borderRadius: radii.pill,
                          background: gradients.brand,
                          color: "#fff",
                          fontSize: 13,
                          fontWeight: 700,
                          boxShadow: shadows.soft,
                          display: "inline-flex",
                          alignItems: "center",
                          gap: 6,
                        }}
                      >
                        ❤ {tag}
                        <button
                          type="button"
                          onClick={() => toggleExpertise(tag)}
                          style={{
                            background: "rgba(255,255,255,0.25)",
                            border: "none",
                            color: "#fff",
                            borderRadius: "50%",
                            width: 18,
                            height: 18,
                            fontSize: 12,
                            cursor: "pointer",
                            lineHeight: 1,
                          }}
                          aria-label={`移除 ${tag}`}
                        >
                          ×
                        </button>
                      </span>
                    ))}
                </div>
              )}

              <div style={{ display: "flex", gap: 8 }}>
                <input
                  value={customExpertise}
                  onChange={(e) => setCustomExpertise(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      addCustomExpertise();
                    }
                  }}
                  placeholder="自訂領域（例：半導體製程）"
                  style={{ ...inputStyle, flex: 1 }}
                />
                <button
                  type="button"
                  onClick={addCustomExpertise}
                  style={{
                    padding: "0 16px",
                    borderRadius: radii.md,
                    border: "none",
                    background: colors.brandStart,
                    color: "#fff",
                    fontWeight: 700,
                    cursor: "pointer",
                    boxShadow: shadows.soft,
                  }}
                >
                  加入
                </button>
              </div>
            </Field>

            {error && (
              <div
                style={{
                  fontSize: 12,
                  fontWeight: 600,
                  color: colors.iosRed,
                  marginBottom: 8,
                }}
              >
                {error}
              </div>
            )}

            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 12,
                marginTop: 8,
              }}
            >
              <button
                onClick={save}
                disabled={busy}
                style={{
                  padding: "12px 22px",
                  borderRadius: radii.md,
                  border: "none",
                  background: busy ? colors.borderStrong : colors.brandStart,
                  color: "#fff",
                  fontWeight: 800,
                  fontSize: 14,
                  letterSpacing: 0.4,
                  cursor: busy ? "not-allowed" : "pointer",
                  boxShadow: busy ? "none" : shadows.soft,
                }}
              >
                {busy ? "儲存中…" : "儲存資料 ❤"}
              </button>
              <button
                onClick={() => router.push("/counselor/chat")}
                style={{
                  padding: "12px 18px",
                  borderRadius: radii.md,
                  border: `1px solid ${colors.borderStrong}`,
                  background: "transparent",
                  color: colors.textSecondary,
                  fontWeight: 700,
                  fontSize: 14,
                  cursor: "pointer",
                }}
              >
                前往個案頁
              </button>
              {savedAt && (
                <span
                  style={{ fontSize: 12, color: colors.textTertiary }}
                >
                  已儲存（{savedAt}）
                </span>
              )}
            </div>
          </Card>
        )}
      </div>
    </main>
  );
}

const inputStyle: React.CSSProperties = {
  width: "100%",
  padding: "12px 14px",
  background: colors.surfaceMuted,
  border: `1px solid ${colors.border}`,
  borderRadius: radii.md,
  fontSize: 15,
  color: colors.textPrimary,
  outline: "none",
  boxSizing: "border-box",
};

function Card({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        padding: 22,
        background: "rgba(255,255,255,0.95)",
        borderRadius: radii.xl,
        boxShadow: shadows.soft,
      }}
    >
      {children}
    </div>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div style={{ marginBottom: 18 }}>
      <div
        style={{
          fontSize: 12,
          fontWeight: 700,
          color: colors.textSecondary,
          marginBottom: 6,
        }}
      >
        {label}
      </div>
      {children}
    </div>
  );
}

