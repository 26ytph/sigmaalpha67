import { NextResponse } from "next/server";

// FAKE: stateless server, nothing to invalidate. Client just discards token.
// Replace with token-revocation logic when you add a real auth provider.
export async function DELETE() {
  return NextResponse.json({ ok: true });
}
