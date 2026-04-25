export type SwipeMode = "career" | "startup";

export type RoleCard = {
  id: string;
  title: string;
  tagline: string;
  imageUrl: string;
  skills: string[];
  dayToDay: string[];
  tags: string[];
};

export type SwipeAction = "left" | "right";

export type SwipeRecord = {
  cardId: string;
  action: SwipeAction;
  swipedAt: string;
};

export type SwipeSummary = {
  likedRoleIds: string[];
  dislikedRoleIds: string[];
  topTags: Array<{ tag: string; score: number }>;
  total: number;
};
