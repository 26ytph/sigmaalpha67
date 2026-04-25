import { NextResponse } from "next/server";
import { withAuth, readJson } from "@/lib/route";
import { apiError } from "@/lib/errors";
import { store, newId } from "@/lib/store";
import { generateChatReply } from "@/engines/chatReply";
import type { ChatConversation, ChatMessage } from "@/types/chat";

type Body = {
  conversationId?: string;
  message?: string;
  context?: { mode?: "career" | "startup"; useProfile?: boolean; useHistory?: boolean };
};

export const POST = withAuth(async (req, { auth }) => {
  const body = await readJson<Body>(req);
  if (!body?.message?.trim()) return apiError("bad_request", "`message` is required.");
  const mode = body.context?.mode ?? "career";

  const convId = body.conversationId ?? newId("c");
  const now = new Date().toISOString();
  const conv: ChatConversation =
    store.conversations.get(convId) ?? {
      id: convId,
      userId: auth.userId,
      mode,
      messages: [],
      createdAt: now,
      updatedAt: now,
    };
  if (conv.userId !== auth.userId) return apiError("not_found", "Conversation not found.");

  const userMsg: ChatMessage = {
    id: newId("m"),
    role: "user",
    text: body.message,
    createdAt: now,
  };
  conv.messages.push(userMsg);

  const profile = body.context?.useProfile === false ? null : store.profiles.get(auth.userId) ?? null;
  const persona = store.personas.get(auth.userId) ?? null;
  const { reply, shouldHandoff, tokensUsed } = generateChatReply({
    message: body.message,
    profile,
    persona,
    mode,
  });
  const replyMsg: ChatMessage = {
    id: newId("m"),
    role: "assistant",
    text: reply,
    createdAt: new Date().toISOString(),
  };
  conv.messages.push(replyMsg);
  conv.updatedAt = replyMsg.createdAt;
  store.conversations.set(convId, conv);

  return NextResponse.json({
    conversationId: convId,
    messageId: replyMsg.id,
    reply,
    shouldHandoff,
    tokensUsed,
  });
});
