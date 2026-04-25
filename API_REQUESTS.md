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

## 1. 帳號 / Auth ★ MVP 必接

### 1.1 註冊
- **觸發**：[auth_screen.dart](lib/screens/auth_screen.dart) `_submit()`，當 `_register == true`。
- **目前實作**：mock — 不打 server，直接寫進本機 `AppStorage.account`。
- **建議 API**：

```
POST /api/auth/register
```

**Request**
```json
{ "email": "you@example.com", "password": "********" }
```

**Response 200**
```json
{
  "token": "jwt-string",
  "refreshToken": "refresh-jwt",
  "account": { "email": "you@example.com", "createdAt": "2026-04-25T..." }
}
```

### 1.2 登入
- **觸發**：[auth_screen.dart](lib/screens/auth_screen.dart) `_submit()`，當 `_register == false`。

```
POST /api/auth/login
```

**Request / Response**：同 1.1。

### 1.3 重整 token
```
POST /api/auth/refresh
```

### 1.4 登出
```
DELETE /api/auth/logout
```

### 1.5 刪除帳號（GDPR）
```
DELETE /api/users/me
```

---

## 2. 使用者 / Profile

### 2.1 建立 / 更新 Profile
- **觸發**：
  - [onboarding_screen.dart](lib/screens/onboarding_screen.dart) `_finish()`
  - [persona_screen.dart](lib/screens/persona_screen.dart) inline 編輯（`_savePersonalField` / `_saveListItem`、`_pickBirthday` 完成時）
- **目前實作**：寫入本機 SharedPreferences。
- **建議 API**：

```
PUT /api/users/me/profile
```

**Request**
```json
{
  "name": "王小安",
  "school": "國立台灣大學",
  "birthday": "2003-04-25",
  "contact": "anan@example.com",
  "department": "社會系",
  "grade": "大三",
  "location": "台北",
  "currentStage": "在學探索",
  "goals": ["找實習", "釐清方向"],
  "interests": ["UX Research", "行銷"],
  "experiences": ["系上迎新", "課內訪談報告"],
  "educationItems": ["國立台灣大學 社會系 大三"],
  "concerns": "不知道科系能做什麼",
  "startupInterest": false
}
```

> **注意**：`birthday` 必須為合法 `YYYY-MM-DD`；server 端應驗證並回算 `age`。

**Response 200**
```json
{ "profile": { /* 同上加 createdAt, updatedAt */ } }
```

### 2.2 取得 Profile
```
GET /api/users/me/profile
```

---

## 3. 興趣方向分析（科系 → 推薦選項）★ MVP 必接

> 對應 onboarding Step 1 完成後的「正在分析你的科系」載入動畫。

### 3.1 分析興趣選項
- **觸發**：[onboarding_screen.dart](lib/screens/onboarding_screen.dart) `_kickInterestAnalysis()`。
- **目前實作**：1.2 秒延遲 + [`recommendedInterestsFor()`](lib/data/interests_catalog.dart) 規則映射。
- **建議 API**：

```
POST /api/profile/analyze-interests
```

**Request**
```json
{
  "department": "社會系",
  "grade": "大三",
  "school": "國立台灣大學",
  "startupInterest": false,
  "stage": "在學探索",
  "goals": ["找實習"]
}
```

**Response 200**
```json
{
  "recommended": [
    "UI/UX 設計",
    "使用者研究",
    "人資／教育訓練",
    "社群經營",
    "行銷／內容",
    "客戶服務"
  ],
  "rationale": "你目前就讀社會系大三，過去經驗以人群觀察與訪談為主...",
  "preselect": ["UI/UX 設計", "使用者研究", "人資／教育訓練"]
}
```

> Server 應回 `preselect`（給 onboarding 預先勾選 3 個），加快使用者下一步的速度。

---

## 4. Persona 結構化欄位

> ⚠️ **重要**：`persona.text`（自介）一律由使用者自己填寫，**不要** 由 server 改寫。

### 4.1 重新計算 Persona facets
- **觸發**：
  - Onboarding 完成（[onboarding_screen.dart](lib/screens/onboarding_screen.dart) `_finish()`）。
  - 滑卡每 10 張使用者點「現在更新」（[explore_screen.dart](lib/screens/explore_screen.dart) `_askForUpdate()`）。
  - 加入新技能翻譯時（[skill_translator_screen.dart](lib/screens/skill_translator_screen.dart) `_save()`）。
- **目前實作**：[`PersonaEngine.generate()`](lib/logic/persona_engine.dart) 規則式組裝。

```
POST /api/persona/refresh
```

**Request**
```json
{
  "profile": { /* 2.1 的 profile */ },
  "explore": {
    "likedRoleIds": ["uiux_designer", "data_analyst"],
    "dislikedRoleIds": ["accountant"],
    "swipeCount": 23
  },
  "skillTranslations": [ /* 6.1 的結果 */ ],
  "userEdited": true
}
```

**Response 200**
```json
{
  "persona": {
    "careerStage": "在學探索",
    "mainInterests": ["設計", "數據"],
    "strengths": ["活動企劃", "訪談技巧"],
    "skillGaps": ["作品集敘事", "原型製作"],
    "mainConcerns": ["不知道科系能做什麼"],
    "recommendedNextStep": "先用「技能翻譯」整理過去經驗...",
    "lastUpdated": "2026-04-25T11:30:00Z"
  }
}
```

> Server **不應** 回 `text` 欄位 — 自介的 source of truth 是使用者的編輯。

### 4.2 更新自介（純使用者編輯）
- **觸發**：[persona_screen.dart](lib/screens/persona_screen.dart) `_saveSummary()`。

```
PUT /api/persona/text
```

**Request**
```json
{ "text": "我自己改寫的版本…" }
```

---

## 5. 滑卡探索（無限滑卡 + 每 10 張提示）

### 5.1 取得卡片清單
```
GET /api/swipe/cards?mode=career&limit=20
```

> 因為改成無限滑卡，client 會循環使用，建議 server 隨需 stream 新卡（pagination）。

### 5.2 紀錄一筆滑卡
- **觸發**：[explore_screen.dart](lib/screens/explore_screen.dart) `_swipe()`。

```
POST /api/swipe/record
```

**Request**
```json
{
  "cardId": "uiux_designer",
  "action": "right",
  "swipedAt": "2026-04-25T11:35:00Z",
  "swipeCount": 24
}
```

> Server 端維護 `swipeCount`，當 `swipeCount % 10 == 0` 時 client 會跳「要更新嗎」對話框；
> 確認後再呼叫 4.1。

### 5.3 取得探索摘要
```
GET /api/swipe/summary
```

---

## 6. 技能翻譯 Skill Translator

### 6.1 翻譯經驗
```
POST /api/skills/translate
```

**Request**
```json
{ "raw": "我曾經辦過迎新活動，也參加過課內訪談報告。" }
```

**Response 200**：見舊版（保留）。

### 6.2 加入到 Persona
```
POST /api/skills/save
```

### 6.3 列出歷史
```
GET /api/skills/translations
```

---

## 7. 字典：技能 / 興趣

> **新需求**：技能 / 興趣不再允許自由輸入；client 從固定字典挑。

### 7.1 取得技能字典
- **目前實作**：[`skillsCatalog`](lib/data/skills_catalog.dart) 寫死於 client。
- **建議 API**（之後可加 i18n / 動態擴充）：

```
GET /api/catalog/skills
```

**Response 200**
```json
{
  "items": ["溝通協調", "活動企劃", "Figma", "..."]
}
```

### 7.2 取得興趣字典
```
GET /api/catalog/interests
```

---

## 8. 履歷匯出（PDF / LaTeX）

> 新需求：將 Profile 套到 LaTeX 模板並匯出可下載 PDF。
> 目前 client 端用 `pdf` + `printing` 直接渲染含中文字型的 PDF（[resume_pdf.dart](lib/services/resume_pdf.dart)），
> 同時提供 LaTeX 原碼讓使用者複製貼到 Overleaf。

### 8.1 後端如果要做（選擇性）
讓 server 用 `xelatex` 編譯，回傳 PDF binary，可以解決 client 字型下載慢的問題：

```
POST /api/resume/render
```

**Request**
```json
{
  "profileId": "user_123",
  "template": "modern-cn",
  "format": "pdf"
}
```

**Response**：`Content-Type: application/pdf`（或 `application/x-tex`）

### 8.2 取得 LaTeX 原碼
```
GET /api/resume/latex?template=modern-cn
```

> 若 8.1 完成，client 可移除本地 `pdf` 套件依賴。

---

## 9. 每日問題（Home 頁面）

> ⚠️ 已從 Plan 頁移到 [home_screen.dart](lib/screens/home_screen.dart)。

### 9.1 取得今日題目
```
GET /api/daily-question?date=2026-04-25
```

### 9.2 提交答案 + 累積 streak
```
POST /api/daily-question/answers
```

---

## 10. 行動計畫 / 課程任務 / 路線圖

> 新需求：每門推薦課程／證照 = 一個任務（checkbox）；同一門課跨多週時共用一個 done 狀態。
> 計畫頁新增 `路線圖` 子分頁。

### 10.1 生成個人化路線
```
POST /api/plan/generate
```

**Response 200**
```json
{
  "plan": {
    "headline": "...",
    "weeks": [
      {
        "week": 1,
        "title": "...",
        "goals": [...],
        "resources": [...],
        "outputs": [...]
      }
    ],
    "courses": [
      {
        "id": "c_design_gux",
        "title": "Google UX Design 專業證照",
        "provider": "Coursera × Google",
        "type": "證照",
        "weeks": [3, 4, 5, 6],
        "detail": "7 門課 + 3 個作品集案例..."
      }
    ]
  }
}
```

> `courses[*].weeks` 是一個 list — 同一筆課程會出現在 client 列出的所有指定週數中。

### 10.2 任務勾選（含課程任務）
```
PUT /api/plan/todos/{key}
```

**Request**
```json
{ "done": true }
```

**Key 格式**：
- 一般任務：`w{week}:{section}:{index}`，例如 `w3:goals:0`
- 課程任務：`course:{courseId}`，例如 `course:c_design_gux`（**不綁週**，跨週共用狀態）

### 10.3 週心得
```
PUT /api/plan/weeks/{week}/note
```

### 10.4 取得當前進度（roadmap 用）
```
GET /api/plan/progress
```

**Response 200**
```json
{
  "byWeek": [
    { "week": 1, "done": 3, "total": 5, "completed": false },
    { "week": 2, "done": 5, "total": 5, "completed": true }
  ],
  "courses": [
    { "id": "c_design_gux", "done": false, "weeksApplicable": [3,4,5,6] }
  ]
}
```

---

## 11. AI 諮詢對話

### 11.1 送出訊息
```
POST /api/chat/messages
```

### 11.2 問題正規化
```
POST /api/chat/normalize
```

### 11.3 / 11.4 歷史與清空（同舊版）

---

## 12. 諮詢師交接單 Counselor Brief

### 12.1 產生交接單
```
POST /api/counselor/cases
```

### 12.2 諮詢師端：列出待處理 case
```
GET /api/counselor/cases?status=waiting_for_counselor
```

### 12.3 諮詢師端：送出回覆
```
PUT /api/counselor/cases/{caseId}/reply
```

---

## 13. 創業版本 / 政策端 dashboard
（沿用舊版，未變動）

---

## 14. 整理：所有 endpoint 總覽

| 區塊 | Method | Path | 優先度 |
|---|---|---|---|
| Auth | POST | `/api/auth/register` | P0 |
| Auth | POST | `/api/auth/login` | P0 |
| Auth | POST | `/api/auth/refresh` | P1 |
| Auth | DELETE | `/api/auth/logout` | P1 |
| Auth | DELETE | `/api/users/me` | P2 |
| Profile | PUT | `/api/users/me/profile` | P0 |
| Profile | GET | `/api/users/me/profile` | P0 |
| Interest | POST | `/api/profile/analyze-interests` | P0 |
| Persona | POST | `/api/persona/refresh` | P0 |
| Persona | PUT | `/api/persona/text` | P0 |
| Swipe | GET | `/api/swipe/cards` | P0 |
| Swipe | POST | `/api/swipe/record` | P0 |
| Swipe | GET | `/api/swipe/summary` | P1 |
| Skill | POST | `/api/skills/translate` | P0 |
| Skill | POST | `/api/skills/save` | P0 |
| Skill | GET | `/api/skills/translations` | P1 |
| Catalog | GET | `/api/catalog/skills` | P1 |
| Catalog | GET | `/api/catalog/interests` | P1 |
| Resume | POST | `/api/resume/render` | P2 |
| Resume | GET | `/api/resume/latex` | P2 |
| DailyQ | GET | `/api/daily-question` | P0 |
| DailyQ | POST | `/api/daily-question/answers` | P0 |
| Plan | POST | `/api/plan/generate` | P0 |
| Plan | PUT | `/api/plan/todos/{key}` | P0 |
| Plan | PUT | `/api/plan/weeks/{week}/note` | P1 |
| Plan | GET | `/api/plan/progress` | P1 |
| Chat | POST | `/api/chat/messages` | P0 |
| Chat | POST | `/api/chat/normalize` | P0 |
| Counselor | POST | `/api/counselor/cases` | P0 |
| Counselor | GET | `/api/counselor/cases` | P1 |
| Counselor | PUT | `/api/counselor/cases/{id}/reply` | P1 |

---

## 15. Front-end 該怎麼接

### 15.1 新增的取代規則式 logic 對應表
| 現在的檔案 | 改成 |
|---|---|
| [`lib/logic/persona_engine.dart`](lib/logic/persona_engine.dart) | `persona_api.refresh()` |
| [`lib/logic/skill_translator.dart`](lib/logic/skill_translator.dart) | `skill_api.translate()` |
| [`lib/logic/intent_normalizer.dart`](lib/logic/intent_normalizer.dart) | `chat_api.normalize()` |
| [`lib/logic/counselor_brief.dart`](lib/logic/counselor_brief.dart) | `counselor_api.createCase()` |
| [`lib/logic/generate_plan.dart`](lib/logic/generate_plan.dart) | `plan_api.generate()` |
| [`lib/data/daily_questions.dart`](lib/data/daily_questions.dart) | `daily_question_api.today()` |
| [`lib/data/roles.dart`](lib/data/roles.dart) | `swipe_api.cards()` |
| [`lib/data/interests_catalog.dart`](lib/data/interests_catalog.dart) `recommendedInterestsFor()` | `profile_api.analyzeInterests()` |
| [`lib/data/skills_catalog.dart`](lib/data/skills_catalog.dart) `skillsCatalog` | `catalog_api.skills()` |
| [`lib/data/interests_catalog.dart`](lib/data/interests_catalog.dart) `interestsCatalog` | `catalog_api.interests()` |
| [`lib/services/resume_pdf.dart`](lib/services/resume_pdf.dart) | （可選）`resume_api.render()` |

### 15.2 樂觀更新策略
- 寫入類（profile 編輯、滑卡、todo 勾選）：先寫本機 → 背景 sync → 失敗回滾。
- 讀取類（生成 plan、refresh persona）：show loading → 收到資料才更新。

### 15.3 Auth flow
1. 使用者打開 app → AppShell 檢查 `account.isAuthenticated`
2. 沒登入 → AuthScreen → 呼叫 1.1 / 1.2 → 拿到 token 存到 secure storage
3. 已登入但 `profile.isEmpty` → OnboardingScreen
4. 完成 onboarding 後 → 主介面（5 tabs）

> **MVP Demo 必接的 P0**：
> Auth 1.1+1.2、Profile 2.1、Interest 3.1、Persona 4.1、
> Swipe 5.1+5.2、Skill 6.1、DailyQ 9.1+9.2、Plan 10.1+10.2、
> Chat 11.1+11.2、Counselor 12.1。
