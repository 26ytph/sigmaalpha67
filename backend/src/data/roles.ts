// =====================================================================
// FAKE DATA — career role cards for the swipe feature.
// Replace with a database query, CMS pull, or LLM-generated catalogue.
// Mirrors the structure of `lib/data/roles.dart` in the Flutter app.
// =====================================================================

import type { RoleCard } from "@/types/swipe";

export const ROLE_CARDS: RoleCard[] = [
  {
    id: "software_engineer",
    title: "軟體工程師",
    tagline: "把想法變成可運作的產品與系統",
    imageUrl: "https://placehold.co/600x800?text=Software+Engineer",
    skills: ["JavaScript", "API 設計", "版本控制"],
    dayToDay: ["實作功能", "Code Review", "修 bug"],
    tags: ["engineering"],
  },
  {
    id: "uiux_designer",
    title: "UI/UX 設計師",
    tagline: "用研究與介面打造好用的體驗",
    imageUrl: "https://placehold.co/600x800?text=UI%2FUX+Designer",
    skills: ["Figma", "使用者訪談", "原型製作"],
    dayToDay: ["畫 wireframe", "跑 usability test", "和工程師對齊"],
    tags: ["design", "research"],
  },
  {
    id: "data_analyst",
    title: "資料分析師",
    tagline: "從數據中找出可行動的洞察",
    imageUrl: "https://placehold.co/600x800?text=Data+Analyst",
    skills: ["SQL", "Excel", "資料視覺化"],
    dayToDay: ["拉 dashboard", "做 A/B 報告", "回答業務問題"],
    tags: ["data"],
  },
  {
    id: "product_manager",
    title: "產品經理",
    tagline: "決定要做什麼、為什麼做、以及何時做",
    imageUrl: "https://placehold.co/600x800?text=Product+Manager",
    skills: ["需求拆解", "優先排序", "跨組溝通"],
    dayToDay: ["寫 spec", "和工程設計對齊", "看數據定 roadmap"],
    tags: ["product"],
  },
  {
    id: "marketing_specialist",
    title: "行銷企劃",
    tagline: "讓對的人在對的時刻看到對的訊息",
    imageUrl: "https://placehold.co/600x800?text=Marketing",
    skills: ["文案", "活動企劃", "成效分析"],
    dayToDay: ["寫貼文", "規劃活動檔期", "看廣告數據"],
    tags: ["marketing"],
  },
  {
    id: "ux_researcher",
    title: "使用者研究員",
    tagline: "用訪談和觀察理解使用者",
    imageUrl: "https://placehold.co/600x800?text=UX+Researcher",
    skills: ["訪談技巧", "質性分析", "報告整理"],
    dayToDay: ["跑訪談", "做 affinity map", "向團隊分享 insight"],
    tags: ["research", "design"],
  },
  {
    id: "accountant",
    title: "會計",
    tagline: "讓帳本說真話",
    imageUrl: "https://placehold.co/600x800?text=Accountant",
    skills: ["會計準則", "Excel", "稅務"],
    dayToDay: ["記帳", "對發票", "報稅"],
    tags: ["finance"],
  },
  {
    id: "founder",
    title: "創業者",
    tagline: "從零打造一個解決真實問題的事業",
    imageUrl: "https://placehold.co/600x800?text=Founder",
    skills: ["商業模式", "募資", "團隊建構"],
    dayToDay: ["客戶訪談", "決策", "什麼都做一點"],
    tags: ["startup", "product"],
  },
];

export function getRoleCardById(id: string): RoleCard | undefined {
  return ROLE_CARDS.find((c) => c.id === id);
}

export function getRoleCards(mode: "career" | "startup", limit?: number): RoleCard[] {
  const filtered =
    mode === "startup" ? ROLE_CARDS.filter((c) => c.tags.includes("startup") || c.tags.includes("product")) : ROLE_CARDS;
  return typeof limit === "number" ? filtered.slice(0, limit) : filtered;
}
