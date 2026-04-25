import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({
    ok: true,
    service: "employa-backend",
    time: new Date().toISOString(),
  });
}
