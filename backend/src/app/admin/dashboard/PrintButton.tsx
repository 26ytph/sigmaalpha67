"use client";

// Client Component because window.print() is browser-only and React 19
// blocks `javascript:` URLs in <a href> for security.
export function PrintButton() {
  return (
    <button
      type="button"
      className="cta-print"
      onClick={() => {
        // Slight delay so any focus / scroll settle before the print dialog
        // opens — prevents jank on Chrome/Edge.
        requestAnimationFrame(() => window.print());
      }}
      aria-label="列印或匯出 PDF 政策簡報"
    >
      🖨️ 列印 / 匯出 PDF 政策簡報
    </button>
  );
}
