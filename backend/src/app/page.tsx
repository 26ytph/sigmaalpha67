export default function Page() {
  return (
    <main style={{ fontFamily: "system-ui", padding: 32, lineHeight: 1.6 }}>
      <h1>EmploYA Backend</h1>
      <p>
        This service exposes the EmploYA REST API. See <code>backend/README.md</code> for the
        endpoint catalogue.
      </p>
      <ul>
        <li>
          <a href="/api/health">/api/health</a> — health check
        </li>
        <li>
          <a href="/counselor/login">/counselor/login</a> — 諮詢師後台
        </li>
        <li>
          <a href="/admin/dashboard">/admin/dashboard</a> — 政策端 Policy Dashboard (web)
        </li>
        <li>
          <a href="/admin/report">/admin/report</a> — 政策正式報告（A4 / PDF）
        </li>
      </ul>
    </main>
  );
}
