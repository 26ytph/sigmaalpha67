import type { SwipeRecord, SwipeSummary } from "@/types/swipe";
import { getRoleCardById } from "@/data/roles";

export function buildSwipeSummary(records: SwipeRecord[]): SwipeSummary {
  const liked: string[] = [];
  const disliked: string[] = [];
  const tagCount = new Map<string, number>();
  for (const r of records) {
    if (r.action === "right") liked.push(r.cardId);
    else disliked.push(r.cardId);
    if (r.action === "right") {
      const card = getRoleCardById(r.cardId);
      if (card) for (const t of card.tags) tagCount.set(t, (tagCount.get(t) ?? 0) + 1);
    }
  }
  const topTags = [...tagCount.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([tag, score]) => ({ tag, score }));
  return { likedRoleIds: liked, dislikedRoleIds: disliked, topTags, total: records.length };
}
