"use client";

import { colors, gradients, shadows } from "../theme";

export function Header({
  onLogout,
  active,
}: {
  onLogout: () => void;
  active: "profile" | "chat";
}) {
  const tabs: Array<{ id: "profile" | "chat"; label: string; href: string }> =
    [
      { id: "profile", label: "我的檔案", href: "/counselor/profile" },
      { id: "chat", label: "個案", href: "/counselor/chat" },
    ];
  return (
    <header
      style={{
        background: "rgba(255,255,255,0.85)",
        borderBottom: `1px solid ${colors.separator}`,
        padding: "12px 20px",
        position: "sticky",
        top: 0,
        zIndex: 10,
        backdropFilter: "blur(12px)",
        display: "flex",
        alignItems: "center",
        gap: 16,
      }}
    >
      <a
        href="/counselor/profile"
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          textDecoration: "none",
          color: colors.brandStart,
          fontWeight: 800,
          fontSize: 18,
          letterSpacing: -0.3,
        }}
      >
        <span
          style={{
            width: 28,
            height: 28,
            borderRadius: "50%",
            background: gradients.heart,
            color: "#fff",
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 14,
            boxShadow: shadows.soft,
          }}
        >
          ❤
        </span>
        EmploYA · 諮詢師
      </a>
      <nav style={{ display: "flex", gap: 4, marginLeft: 12 }}>
        {tabs.map((t) => (
          <a
            key={t.id}
            href={t.href}
            style={{
              padding: "8px 14px",
              borderRadius: 999,
              fontSize: 13,
              fontWeight: 700,
              textDecoration: "none",
              color: active === t.id ? "#fff" : colors.textSecondary,
              background: active === t.id ? colors.brandStart : "transparent",
              boxShadow: active === t.id ? shadows.soft : "none",
            }}
          >
            {t.label}
          </a>
        ))}
      </nav>
      <div style={{ marginLeft: "auto" }}>
        <button
          onClick={onLogout}
          style={{
            padding: "8px 14px",
            borderRadius: 999,
            border: `1px solid ${colors.borderStrong}`,
            background: "transparent",
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: 700,
            cursor: "pointer",
          }}
        >
          登出
        </button>
      </div>
    </header>
  );
}
