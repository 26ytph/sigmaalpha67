export default function Page() {
  return (
    <main style={{ fontFamily: "system-ui", padding: 32, lineHeight: 1.6 }}>
      <h1>EmploYA Backend</h1>
      <p>
        This service exposes the EmploYA REST API. See <code>backend/README.md</code> for the
        endpoint catalogue.
      </p>
      <p>
        Health check: <a href="/api/health">/api/health</a>
      </p>
      <p>
        Counselor console: <a href="/counselor/login">/counselor/login</a>
      </p>
    </main>
  );
}
