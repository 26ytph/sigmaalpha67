# EmploYA! — 後端 API 需求清單

> 本文件整理目前 Flutter 端**所有用「假 AI」或本機計算**的位置，
> 對應到接上後端後該打的 endpoint。每個項目都標明：
> - 觸發位置（哪個檔案 / 函式）
> - 建議 HTTP 方法 + 路徑
> - request payload 範例
> - response payload 範例
> - 取代目前的 logic 檔
>
> 全部都假設使用 Bearer token 驗證，回應格式為 JSON。

---

## 0. 共用前置

### 0.1 `Authorization` header
```
Authorization: Bearer <jwt>
```

### 0.2 通用錯誤格式
```json
{ "error": { "code": "string", "message": "string" } }
```

---

## 1. 使用者 / Profile

### 1.1 建立或更新 Profile
- **觸發**：[onboarding_screen.dart](lib/screens/onboarding_screen.dart) 的 `_finish()`、[persona_screen.dart](lib/screens/persona_screen.dart) 的個資 inline 編輯（`_savePersonalField`）與履歷段落編輯（`_saveListItem`）。
- **目前實作**：`AppRepository.update()` 寫入本機 SharedPreferences。
- **建議 API**：

```
PUT /api/users/me/profile
```

**Request**
```json
{
  "name": "小安",
  "age": "21",
  "contact": "anan@example.com",
  "department": "社會系",
  "grade": "大三",
  "location": "台北",
  "currentStage": "在學探索",
  "goals": ["找實習", "釐清方向"],
  "interests": ["UX Research", "行銷"],
  "experiences": ["系上迎新", "課內訪談報告"],
  "educationItems": ["社會系 大三"],
  "concerns": "不知道科系能做什麼",
  "startupInterest": false
}
```

**Response 200**
```json
{ "profile": { /* 同上加 createdAt, updatedAt */ } }
```

### 1.2 取得 Profile
```
GET /api/users/me/profile
```

---

## 2. Persona 生成 / 更新

### 2.1 生成 Persona（首次或重新生成）
- **觸發**：
  - Onboarding 完成後（[onboarding_screen.dart](lib/screens/onboarding_screen.dart) `_finish()`）。
  - Persona 頁面點「重新生成」（[persona_screen.dart](lib/screens/persona_screen.dart) `_regenerate()`）。
  - 加入新技能翻譯時（[skill_translator_screen.dart](lib/screens/skill_translator_screen.dart) `_save()`）。
- **目前實作**：`PersonaEngine.generate()` 規則式組裝。
- **建議 API**：

```
POST /api/persona/generate
```

**Request**
```json
{
  "profile": { /* 1.1 的 profile */ },
  "explore": {
    "likedRoleIds": ["uiux_designer", "data_analyst"],
    "dislikedRoleIds": ["accountant"]
  },
  "skillTranslations": [
    { "rawExperience": "辦過迎新", "groups": [...] }
  ],
  "previousPersona": null
}
```

**Response 200**
```json
{
  "persona": {
    "text": "你目前是一位社會系大三學生，正處於在學探索階段...",
    "careerStage": "在學探索",
    "mainInterests": ["設計", "數據"],
    "strengths": ["活動企劃", "訪談技巧"],
    "skillGaps": ["作品集敘事", "原型製作"],
    "mainConcerns": ["不知道科系能做什麼"],
    "recommendedNextStep": "先用「技能翻譯」整理過去經驗，再投 2–3 份實習。",
    "lastUpdated": "2026-04-25T11:30:00Z",
    "userEdited": false
  }
}
```

### 2.2 滑卡後輕量更新 Persona
- **觸發**：[explore_screen.dart](lib/screens/explore_screen.dart) `_swipe()` 內。
- **目前實作**：`PersonaEngine.refreshSoft()`。
- **建議 API**：

```
POST /api/persona/refresh
```

**Request**：同 2.1，但 server 應在 `userEdited=true` 時只更新 `mainInterests` 與 `lastUpdated`。

**Response**：同 2.1 的 `persona`。

### 2.3 使用者手動編輯 Persona
- **觸發**：[persona_screen.dart](lib/screens/persona_screen.dart) `_saveSummary()`。
- **建議 API**：

```
PUT /api/persona
```

**Request**
```json
{
  "text": "我自己改寫的版本…",
  "userEdited": true
}
```

---

## 3. 滑卡探索 Swipe

### 3.1 取得卡片清單
- **目前實作**：硬編碼於 [data/roles.dart](lib/data/roles.dart)。
- **建議 API**：

```
GET /api/swipe/cards?mode=career&limit=20
```

**Response**
```json
{
  "cards": [
    {
      "id": "software_engineer",
      "title": "軟體工程師",
      "tagline": "把想法變成可運作的產品與系統",
      "imageUrl": "https://cdn/.../se.jpg",
      "skills": ["JavaScript", "API 設計"],
      "dayToDay": ["實作功能", "Code Review"],
      "tags": ["engineering"]
    }
  ]
}
```

### 3.2 紀錄一筆滑卡
- **觸發**：[explore_screen.dart](lib/screens/explore_screen.dart) `_swipe()`。
- **目前實作**：直接寫入 `AppStorage.explore`。
- **建議 API**：

```
POST /api/swipe/record
```

**Request**
```json
{
  "cardId": "uiux_designer",
  "action": "right",   // "left" | "right"
  "swipedAt": "2026-04-25T11:35:00Z"
}
```

**Response**：可空，或回傳更新後的累積結果。

### 3.3 取得探索結果摘要（重新登入時恢復）
```
GET /api/swipe/summary
```

---

## 4. 技能翻譯 Skill Translator

### 4.1 翻譯單筆經驗
- **觸發**：[skill_translator_screen.dart](lib/screens/skill_translator_screen.dart) `_translate()`。
- **目前實作**：`SkillTranslatorEngine.translate()`。
- **建議 API**：

```
POST /api/skills/translate
```

**Request**
```json
{
  "raw": "我曾經辦過迎新活動，也參加過課內訪談報告。"
}
```

**Response**
```json
{
  "translation": {
    "id": "st_1714045200",
    "rawExperience": "我曾經辦過迎新活動，也參加過課內訪談報告。",
    "groups": [
      {
        "experience": "辦過迎新活動",
        "skills": ["活動企劃", "流程把控", "跨組溝通"]
      },
      {
        "experience": "課內訪談報告",
        "skills": ["訪談技巧", "資料整理", "結論歸納"]
      }
    ],
    "resumeSentence": "曾於辦過迎新活動中展現活動企劃、流程把控、跨組溝通的能力，並於課內訪談報告中累積跨情境協作經驗，能將實作經驗轉化為可量化交付。",
    "createdAt": "2026-04-25T11:40:00Z"
  }
}
```

### 4.2 加入到 Persona（持久化翻譯）
- **觸發**：[skill_translator_screen.dart](lib/screens/skill_translator_screen.dart) `_save()`。
- **建議 API**：先呼叫 4.1 拿到翻譯結果，再呼叫：

```
POST /api/skills/save
```

**Request**：同 4.1 response 的 `translation`。

**Response**
```json
{ "translationId": "st_xxx", "updatedPersona": { ... } }
```

### 4.3 列出歷史翻譯
```
GET /api/skills/translations
```

---

## 5. AI 諮詢對話

### 5.1 送出訊息（取得 AI 回覆）
- **觸發**：[chat_screen.dart](lib/screens/chat_screen.dart) `_send()`。
- **目前實作**：`_mockReply()` 的 keyword fallback。
- **建議 API**：

```
POST /api/chat/messages
```

**Request**
```json
{
  "conversationId": "c_001",
  "message": "我畢業是不是很難找到好工作？",
  "context": {
    "mode": "career",            // career | startup
    "useProfile": true,          // 由 server 端用使用者目前 profile 增強
    "useHistory": true
  }
}
```

**Response**
```json
{
  "messageId": "m_999",
  "reply": "你不是沒有能力，而是需要把過去經驗翻譯成職場可理解的語言…",
  "shouldHandoff": true,
  "tokensUsed": 412
}
```

> 後端應該在 server 端取使用者最新 Profile / Persona，不需 client 上傳。

### 5.2 問題正規化 Intent Normalize
- **觸發**：[chat_screen.dart](lib/screens/chat_screen.dart) `_send()` 內的 `IntentNormalizer.normalize()`。
- **目前實作**：規則式判斷關鍵字。
- **建議 API**（可與 5.1 合併到一個 endpoint，或拆出來給諮詢師端用）：

```
POST /api/chat/normalize
```

**Request**
```json
{ "question": "我畢業是不是很難找到好工作？" }
```

**Response**
```json
{
  "normalized": {
    "userStage": "應屆畢業生",
    "intents": ["職涯探索", "履歷協助"],
    "emotion": "焦慮、有壓力",
    "knownInfo": ["科系：社會系"],
    "missingInfo": ["過去經驗", "目標產業"],
    "suggestedQuestions": [
      "你目前就讀什麼科系？",
      "過去有哪些社團、課程或實習經驗？"
    ],
    "urgency": "中高",
    "counselorSummary": "使用者為社會系學生，目前處於應屆畢業生階段..."
  }
}
```

### 5.3 取得歷史對話
```
GET /api/chat/conversations/{conversationId}/messages
```

### 5.4 清空對話
```
DELETE /api/chat/conversations/{conversationId}
```

---

## 6. 諮詢師交接單 Counselor Brief

### 6.1 產生交接單
- **觸發**：[chat_screen.dart](lib/screens/chat_screen.dart) `_showCounselorBrief()`。
- **目前實作**：`CounselorBriefEngine.build()`。
- **建議 API**：

```
POST /api/counselor/cases
```

**Request**
```json
{
  "fromMessageId": "m_999",
  "userQuestion": "我畢業是不是很難找到好工作？",
  "normalizedQuestion": { /* 5.2 response.normalized */ }
}
```

**Response**
```json
{
  "case": {
    "id": "case_777",
    "status": "waiting_for_counselor",
    "urgency": "中高",
    "userBackground": "社會系・大三・在學探索",
    "personaSummary": "你目前是一位社會系大三...",
    "recentActivities": "近期右滑了 5 個職位；興趣集中在 設計、數據",
    "mainQuestion": "我畢業是不是很難找到好工作？",
    "aiAnalysis": "意圖：職涯探索、履歷協助；情緒：焦慮...",
    "suggestedTopics": ["先以同理回應...", "優先確認：過去經驗"],
    "recommendedResources": ["一頁式履歷模板", "STAR 結構問答庫"],
    "aiDraftReply": "嗨小安，聽起來目前有些壓力...",
    "createdAt": "2026-04-25T11:42:00Z"
  }
}
```

### 6.2 諮詢師端：列出待處理 case
```
GET /api/counselor/cases?status=waiting_for_counselor
```

### 6.3 諮詢師端：送出回覆（修改 AI 回稿後）
```
PUT /api/counselor/cases/{caseId}/reply
```

**Request**
```json
{
  "reply": "嗨小安，我看了你的近況...",
  "savedToKnowledgeBase": true
}
```

---

## 7. 每日問題 Daily Question

### 7.1 取得今日題目
- **觸發**：[plan_screen.dart](lib/screens/plan_screen.dart) `_pickQuestion()`。
- **目前實作**：硬編碼於 [data/daily_questions.dart](lib/data/daily_questions.dart) + hash 挑選。
- **建議 API**：

```
GET /api/daily-question?date=2026-04-25
```

**Response**
```json
{
  "question": {
    "id": "q_engineer_01",
    "text": "工程師整天都在寫程式嗎？",
    "answer": "其實寫程式只佔 30–50%...",
    "options": ["...", "...", "...", "..."],
    "roleTags": ["engineering"]
  },
  "alreadyAnswered": false,
  "myAnswer": null
}
```

### 7.2 提交答案 + 累積 streak
- **觸發**：[plan_screen.dart](lib/screens/plan_screen.dart) `_answer()`。

```
POST /api/daily-question/answers
```

**Request**
```json
{ "questionId": "q_engineer_01", "answer": "30–50%" }
```

**Response**
```json
{
  "strike": { "current": 5, "lastAnsweredDate": "2026-04-25" },
  "explanation": "其實寫程式只佔 30–50%..."
}
```

---

## 8. 行動計畫 Plan

### 8.1 生成個人化路線
- **觸發**：[plan_screen.dart](lib/screens/plan_screen.dart) build 時 `generatePlan()`、[plan_todos_screen.dart](lib/screens/plan_todos_screen.dart) 同。
- **目前實作**：[logic/generate_plan.dart](lib/logic/generate_plan.dart) 寫死的模板。
- **建議 API**：

```
POST /api/plan/generate
```

**Request**
```json
{
  "mode": "career",
  "likedRoleIds": ["uiux_designer", "data_analyst"],
  "persona": { /* 2.1 response.persona */ }
}
```

**Response**
```json
{
  "plan": {
    "headline": "做出好用的體驗：研究、流程與介面設計",
    "basedOnTopTags": [{"tag": "design", "score": 2}],
    "recommendedRoles": [{ /* card */ }],
    "weeks": [
      {
        "week": 1,
        "title": "自我盤點與目標定義",
        "goals": ["..."],
        "resources": ["..."],
        "outputs": ["..."]
      }
    ]
  }
}
```

### 8.2 任務勾選
- **觸發**：[plan_todos_screen.dart](lib/screens/plan_todos_screen.dart) `_toggleTodo()`。

```
PUT /api/plan/todos/{key}
```

**Request**
```json
{ "done": true }
```

### 8.3 週心得
- **觸發**：[plan_todos_screen.dart](lib/screens/plan_todos_screen.dart) `_setWeekNote()`。

```
PUT /api/plan/weeks/{week}/note
```

**Request**
```json
{ "note": "這週把訪談摘要整理完了..." }
```

---

## 9. 創業版本專屬

> 觸發點：使用者的 `profile.startupInterest = true`。

### 9.1 創業階段判斷 + 推薦資源
- **建議 API**：

```
POST /api/startup/analyze
```

**Request**
```json
{
  "idea": "想開寵物友善咖啡廳",
  "profile": { /* 1.1 */ }
}
```

**Response**
```json
{
  "stage": "想法期",       // 想法期 | 驗證期 | 籌備期 | 營運初期
  "missingInfo": ["客群定義", "市場驗證"],
  "recommendedResources": [
    { "type": "loan", "name": "青年創業貸款", "url": "..." },
    { "type": "consulting", "name": "一站式創業諮詢", "url": "..." }
  ],
  "todos": [ /* 8.1 weeks 同樣結構 */ ]
}
```

### 9.2 政策補助 / 貸款查詢
```
GET /api/startup/resources?stage=想法期&type=loan
```

---

## 10. 政策端 / 管理者 Dashboard

> 給政策端 / 政府單位看的儀表板（提案 §15）。

### 10.1 高頻問題趨勢
```
GET /api/admin/dashboard/top-questions?from=2026-01-01&to=2026-04-25
```

### 10.2 熱門職涯方向
```
GET /api/admin/dashboard/top-career-paths
```

### 10.3 常見技能缺口
```
GET /api/admin/dashboard/skill-gaps
```

### 10.4 卡關任務統計
```
GET /api/admin/dashboard/stuck-tasks
```

### 10.5 創業資源需求分布
```
GET /api/admin/dashboard/startup-needs
```

### 10.6 AI 政策建議
```
POST /api/admin/dashboard/policy-suggestions
```

---

## 11. 帳號 / Auth（提案未明確要求，但實際上線需要）

| 路徑 | 用途 |
|---|---|
| `POST /api/auth/login` | Email / Google / Apple 登入 |
| `POST /api/auth/register` | 註冊 |
| `POST /api/auth/refresh` | refresh token |
| `DELETE /api/auth/logout` | 登出 |
| `DELETE /api/users/me` | 刪除帳號（GDPR） |

---

## 12. Front-end 該怎麼接

### 12.1 建議資料夾結構
```
lib/
  services/
    app_repository.dart        // 既有，本機 cache
    api/
      api_client.dart          // dio / http 包裝 + 401 refresh
      profile_api.dart         // 1.x
      persona_api.dart         // 2.x
      swipe_api.dart           // 3.x
      skill_api.dart           // 4.x
      chat_api.dart            // 5.x
      counselor_api.dart       // 6.x
      daily_question_api.dart  // 7.x
      plan_api.dart            // 8.x
      startup_api.dart         // 9.x
```

### 12.2 取代規則式 logic 的對應表
| 現在的檔案 | 改成 |
|---|---|
| `lib/logic/persona_engine.dart` | `persona_api.generate()` / `refresh()` |
| `lib/logic/skill_translator.dart` | `skill_api.translate()` |
| `lib/logic/intent_normalizer.dart` | `chat_api.normalize()` |
| `lib/logic/counselor_brief.dart` | `counselor_api.createCase()` |
| `lib/logic/generate_plan.dart` | `plan_api.generate()` |
| `lib/data/daily_questions.dart` | `daily_question_api.today()` |
| `lib/data/roles.dart` | `swipe_api.cards()` |

### 12.3 樂觀更新策略
寫入類 endpoint（profile 編輯、滑卡、todo 勾選）建議走「樂觀更新」：
1. 立刻寫入本機 `AppStorage`
2. 背景送 request
3. 失敗時回滾並提示

讀取類（生成 Persona、產出 brief）目前的「點按鈕→等待→顯示」UX 是合適的，加上 loading state 即可。

---

## 13. 整理：所有 endpoint 總覽

| 區塊 | Method | Path |
|---|---|---|
| Profile | PUT | `/api/users/me/profile` |
| Profile | GET | `/api/users/me/profile` |
| Persona | POST | `/api/persona/generate` |
| Persona | POST | `/api/persona/refresh` |
| Persona | PUT | `/api/persona` |
| Swipe | GET | `/api/swipe/cards` |
| Swipe | POST | `/api/swipe/record` |
| Swipe | GET | `/api/swipe/summary` |
| Skill | POST | `/api/skills/translate` |
| Skill | POST | `/api/skills/save` |
| Skill | GET | `/api/skills/translations` |
| Chat | POST | `/api/chat/messages` |
| Chat | POST | `/api/chat/normalize` |
| Chat | GET | `/api/chat/conversations/{id}/messages` |
| Chat | DELETE | `/api/chat/conversations/{id}` |
| Counselor | POST | `/api/counselor/cases` |
| Counselor | GET | `/api/counselor/cases` |
| Counselor | PUT | `/api/counselor/cases/{id}/reply` |
| Daily Q | GET | `/api/daily-question?date=` |
| Daily Q | POST | `/api/daily-question/answers` |
| Plan | POST | `/api/plan/generate` |
| Plan | PUT | `/api/plan/todos/{key}` |
| Plan | PUT | `/api/plan/weeks/{week}/note` |
| Startup | POST | `/api/startup/analyze` |
| Startup | GET | `/api/startup/resources` |
| Admin | GET | `/api/admin/dashboard/top-questions` |
| Admin | GET | `/api/admin/dashboard/top-career-paths` |
| Admin | GET | `/api/admin/dashboard/skill-gaps` |
| Admin | GET | `/api/admin/dashboard/stuck-tasks` |
| Admin | GET | `/api/admin/dashboard/startup-needs` |
| Admin | POST | `/api/admin/dashboard/policy-suggestions` |
| Auth | POST | `/api/auth/login` |
| Auth | POST | `/api/auth/register` |
| Auth | POST | `/api/auth/refresh` |
| Auth | DELETE | `/api/auth/logout` |
| Auth | DELETE | `/api/users/me` |

> **MVP Demo 必接的 P0**：
> `1.1`、`2.1`、`3.2`、`4.1`、`5.1` + `5.2`、`6.1`、`8.1`。
>
> **可後接（mock 即可 demo）的 P1**：3.1、4.2、7.x、8.2/8.3、9.x。
>
> **正式上線才需要的 P2**：`Auth` 全部、`10.x` 政策端 dashboard、4.3、5.3/5.4。
