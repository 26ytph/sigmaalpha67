"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { colors, radii, gradients, shadows, fontStack } from "../theme";
import { apiFetch, saveSession, getToken } from "../lib/api";
import { getSupabaseBrowser } from "../lib/supabaseBrowser";

type AuthResponse = {
  accessToken: string;
  user: { id: string; email: string };
};

const EMAIL_RE = /^[\w.+\-]+@([\w-]+\.)+[\w-]{2,}$/;

export default function CounselorLoginPage() {
  const router = useRouter();
  const [register, setRegister] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (getToken()) router.replace("/counselor/profile");
  }, [router]);

  const canSubmit =
    EMAIL_RE.test(email.trim()) && password.length >= 4 && !busy;

  async function submit() {
    if (!canSubmit) return;
    setBusy(true);
    setError(null);

    const trimmedEmail = email.trim();
    const supabase = getSupabaseBrowser();

    // 路徑 A：有設定 Supabase env → 走真的 auth，拿到合法 JWT。
    // 路徑 B：沒設定 → 退回後端原本的 fake /api/auth/login（demo 模式）。
    if (supabase) {
      try {
        if (register) {
          // 走後端 service-role endpoint 直接建 user 並標 email 已確認，
          // 跳過 Supabase 預設的信箱確認流程。
          try {
            await apiFetch("/api/counselor/auth/register", {
              method: "POST",
              body: JSON.stringify({
                email: trimmedEmail,
                password,
              }),
            });
          } catch (e) {
            const status = (e as { status?: number })?.status;
            if (status !== 409) {
              // 409 = 已存在，視同登入處理
              const msg =
                typeof e === "object" && e && "message" in e
                  ? String((e as { message?: string }).message ?? "")
                  : "註冊失敗";
              throw new Error(msg);
            }
          }
          // 帳號建好（或已存在）→ 立刻登入拿 session
        }

        let { data, error } = await supabase.auth.signInWithPassword({
          email: trimmedEmail,
          password,
        });

        // 舊帳號可能還沒被 confirm（之前用 supabase 預設流程註冊的）。
        // 如果 GoTrue 回 "Email not confirmed" 我們就用 server admin 強制 confirm
        // 後再試一次。
        if (
          error &&
          /not\s*confirmed|email_not_confirmed/i.test(error.message)
        ) {
          try {
            await apiFetch("/api/counselor/auth/register", {
              method: "POST",
              body: JSON.stringify({
                email: trimmedEmail,
                password,
              }),
            });
          } catch {
            // 失敗就直接讓下面重新拋原本的錯
          }
          const retry = await supabase.auth.signInWithPassword({
            email: trimmedEmail,
            password,
          });
          data = retry.data;
          error = retry.error;
        }

        if (error) throw new Error(error.message);
        if (!data.session?.access_token) {
          throw new Error("沒有拿到 session token，請再試一次");
        }
        saveSession(data.session.access_token, trimmedEmail);
        // 確保自己在 public.counselors 名單裡（給 Realtime / RLS 用）
        try {
          await apiFetch("/api/counselor/auth/ensure-membership", {
            method: "POST",
            body: JSON.stringify({}),
          });
        } catch {
          // 失敗不擋登入流程
        }
        router.push("/counselor/profile");
        return;
      } catch (e) {
        const msg = e instanceof Error ? e.message : "登入失敗";
        setError(msg);
        setBusy(false);
        return;
      }
    }

    // 沒設定 Supabase → fake auth fallback
    try {
      const path = register ? "/api/auth/register" : "/api/auth/login";
      const body = register
        ? { email: trimmedEmail, password, name: "" }
        : { email: trimmedEmail, password, provider: "email" as const };
      const res = await apiFetch<AuthResponse>(path, {
        method: "POST",
        body: JSON.stringify(body),
      });
      saveSession(res.accessToken, res.user.email);
      router.push("/counselor/profile");
    } catch (e) {
      const msg =
        typeof e === "object" && e && "message" in e
          ? String((e as { message?: string }).message ?? "")
          : "登入失敗";
      setError(msg || "登入失敗");
      setBusy(false);
    }
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        background: gradients.bg,
        position: "relative",
        overflow: "hidden",
        fontFamily: fontStack,
        color: colors.textPrimary,
      }}
    >
      <FloatingHearts />
      <div
        style={{
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "32px 24px",
          position: "relative",
          zIndex: 1,
        }}
      >
        <div style={{ width: "100%", maxWidth: 420 }}>
          <Logo register={register} />
          <div style={{ height: 20 }} />
          <div
            style={{
              padding: 22,
              background: "rgba(255,255,255,0.92)",
              borderRadius: radii.xl,
              boxShadow: shadows.brand,
              backdropFilter: "blur(8px)",
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
              {register ? "建立諮詢師帳號" : "諮詢師登入"}
            </div>
            <div style={{ height: 4 }} />
            <div
              style={{
                fontSize: 12,
                lineHeight: 1.55,
                color: colors.textTertiary,
              }}
            >
              {register
                ? "輸入 email 跟一個只有你知道的密碼，建立你的諮詢師帳號。"
                : "輸入帳號跟密碼，繼續陪伴你的個案。"}
            </div>

            <div style={{ height: 16 }} />
            <Label>Email</Label>
            <Input
              type="email"
              placeholder="you@example.com"
              value={email}
              onChange={(v) => {
                setEmail(v);
                setError(null);
              }}
            />

            <div style={{ height: 12 }} />
            <Label>密碼</Label>
            <Input
              type="password"
              placeholder="至少 4 個字元"
              value={password}
              onChange={(v) => {
                setPassword(v);
                setError(null);
              }}
              onEnter={submit}
            />

            {error && (
              <>
                <div style={{ height: 10 }} />
                <div
                  style={{
                    fontSize: 12,
                    fontWeight: 600,
                    color: colors.iosRed,
                  }}
                >
                  {error}
                </div>
              </>
            )}

            <div style={{ height: 16 }} />
            <button
              onClick={submit}
              disabled={!canSubmit}
              style={{
                width: "100%",
                padding: "14px 12px",
                border: "none",
                borderRadius: radii.md,
                background: canSubmit ? colors.brandStart : colors.borderStrong,
                color: "#fff",
                fontSize: 15,
                fontWeight: 800,
                letterSpacing: 0.6,
                cursor: canSubmit ? "pointer" : "not-allowed",
                boxShadow: canSubmit ? shadows.soft : "none",
                transition: "background 120ms ease, box-shadow 120ms ease",
              }}
            >
              {busy ? "處理中…" : register ? "建立帳號 ❤" : "登入 ❤"}
            </button>

            <div style={{ height: 10 }} />
            <div
              style={{
                fontSize: 11,
                textAlign: "center",
                color: colors.textTertiary,
              }}
            >
              此為 demo 環境，密碼僅暫存於本地。
            </div>
          </div>

          <div style={{ height: 12 }} />
          <div style={{ textAlign: "center" }}>
            <button
              onClick={() => {
                setRegister((r) => !r);
                setError(null);
              }}
              style={{
                background: "transparent",
                border: "none",
                color: colors.brandStart,
                fontSize: 13,
                fontWeight: 700,
                cursor: "pointer",
                padding: "6px 12px",
              }}
            >
              {register
                ? "已經有帳號了？來登入吧"
                : "還沒帳號？建立一個一起出發"}
            </button>
          </div>
        </div>
      </div>
    </main>
  );
}

function Logo({ register }: { register: boolean }) {
  return (
    <div style={{ textAlign: "center" }}>
      <div
        style={{
          width: 88,
          height: 88,
          margin: "0 auto",
          borderRadius: "50%",
          background: gradients.heart,
          boxShadow: shadows.brand,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "#fff",
          fontSize: 42,
        }}
        aria-hidden
      >
        ❤
      </div>
      <div style={{ height: 12 }} />
      <div
        style={{
          fontSize: 30,
          fontWeight: 800,
          letterSpacing: -0.6,
          color: colors.brandStart,
        }}
      >
        EmploYA!
      </div>
      <div style={{ height: 4 }} />
      <div
        style={{
          fontSize: 13,
          fontWeight: 600,
          color: colors.textSecondary,
        }}
      >
        {register ? "陪你陪伴更多人" : "回來啦？個案在等你"}
      </div>
    </div>
  );
}

function Label({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        fontSize: 12,
        fontWeight: 700,
        color: colors.textSecondary,
        marginBottom: 6,
      }}
    >
      {children}
    </div>
  );
}

function Input({
  type,
  value,
  placeholder,
  onChange,
  onEnter,
}: {
  type: "email" | "password" | "text";
  value: string;
  placeholder?: string;
  onChange: (v: string) => void;
  onEnter?: () => void;
}) {
  return (
    <input
      type={type}
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      onKeyDown={(e) => {
        if (e.key === "Enter" && onEnter) onEnter();
      }}
      style={{
        width: "100%",
        padding: "12px 14px",
        background: colors.surfaceMuted,
        border: `1px solid ${colors.border}`,
        borderRadius: radii.md,
        fontSize: 15,
        color: colors.textPrimary,
        outline: "none",
        boxSizing: "border-box",
      }}
    />
  );
}

function FloatingHearts() {
  const spec: Array<[string, string, number, number]> = [
    ["8%", "10%", 22, 0.18],
    ["85%", "12%", 16, 0.14],
    ["5%", "78%", 28, 0.16],
    ["78%", "72%", 20, 0.18],
    ["92%", "42%", 14, 0.14],
    ["18%", "45%", 12, 0.12],
  ];
  return (
    <div
      aria-hidden
      style={{
        position: "absolute",
        inset: 0,
        pointerEvents: "none",
        zIndex: 0,
      }}
    >
      {spec.map(([left, top, size, alpha], i) => (
        <span
          key={i}
          style={{
            position: "absolute",
            left,
            top,
            fontSize: size,
            color: `rgba(254,60,114,${alpha})`,
          }}
        >
          ❤
        </span>
      ))}
    </div>
  );
}
