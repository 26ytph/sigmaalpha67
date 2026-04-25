"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { getToken } from "./lib/api";
import { colors, gradients, fontStack } from "./theme";

export default function CounselorIndexPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace(getToken() ? "/counselor/profile" : "/counselor/login");
  }, [router]);
  return (
    <main
      style={{
        minHeight: "100vh",
        background: gradients.bg,
        fontFamily: fontStack,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        color: colors.textTertiary,
        fontSize: 14,
      }}
    >
      ❤ 跳轉中…
    </main>
  );
}
