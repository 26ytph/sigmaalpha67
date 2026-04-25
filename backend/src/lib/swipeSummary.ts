import type { SwipeRecord, SwipeSummary } from "@/types/swipe";
import { getRoleCardById } from "@/data/roles";

export function buildSwipeSummary(records: SwipeRecord[]): SwipeSummary {
  // 同一張卡可能被滑很多次（無限 deck shuffling）— 只保留「最後一次動作」當
  // 該卡的最終立場；同一張卡也只在 likedRoleIds / dislikedRoleIds 出現一次。
  const lastAction = new Map<string, "right" | "left">();
  for (const r of records) {
    lastAction.set(r.cardId, r.action);
  }
  const liked: string[] = [];
  const disliked: string[] = [];
  const tagCount = new Map<string, number>();
  for (const [cardId, action] of lastAction) {
    if (action === "right") {
      liked.push(cardId);
      const card = getRoleCardById(cardId);
      if (card) {
        for (const t of card.tags) tagCount.set(t, (tagCount.get(t) ?? 0) + 1);
      }
    } else {
      disliked.push(cardId);
    }
  }
  const topTags = [...tagCount.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([tag, score]) => ({ tag, score }));
  return {
    likedRoleIds: liked,
    dislikedRoleIds: disliked,
    topTags,
    total: records.length,
  };
}
