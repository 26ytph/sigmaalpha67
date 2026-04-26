# EmploYA !

> ❤️🔥青年職涯導遊 - 從探索到行動🔥❤️

**賽題 B**：行善台北<br>
**團隊**：尖銳吉吉今晚吃吉<br>
**作品定位**：AI 青年職涯與創業個案服務平台<br>
**目標使用者**：台北青年、第一線諮詢師、青年政策單位

![EmploYA! demo overview](docs/readme/demo-overview.svg)

<img src="images%20(1).gif" alt="EmploYA demo gif" width="360" />

## 30 秒看懂這個專案

EmploYA ! 不只是一個資訊平台或聊天機器人，而是一款同時服務**青年**、**諮詢師**與**政府機構**三端的 AI 個案服務系統。<br>
我們做了**技能翻譯**、**滑動式興趣探索**、依照使用者興趣擬合個人化 **To-Do List** 等功能，給迷茫的求職青年及創業者，解決「不知道下一步該做什麼」的問題，一步一步帶領青年從探索到行動。<br>

主要功能：

- **技能翻譯**：將文組青年經歷轉譯為職場可用的軟實力。
- **職涯探索**：
  - **滑動探索**：右滑/左滑蒐集職涯偏好，讓青年能輕鬆接收資訊，並動態更新 Persona。
  - **個人化職涯路徑**：依興趣及個人目標生成 To-Do List，並可客製化調整，引領青年在職涯中一步步前進。
  - **AI Chat + RAG**：串Gemini API 結合 RAG，同時提供使用者情緒支持及需要資源連結。
- **諮商師與公部門**：
  - **諮詢師接手**：把模糊問題正規化，整理成諮詢師可快速理解的重點；並將不同種類的問題分配給對應專業的諮詢師。
  - **政策儀表板**：彙整熱門問題、職涯趨勢、創業需求與政策建議等，讓政府機關快速了解目前青少年問題、生成詳細報告與 AI 自動化建議。

## Demo 入口

本專案可完整本機 Demo：


| 入口                 | URL                                     |
| -------------------- | --------------------------------------- |
| 青年端 Flutter App   | `http://127.0.0.1:8081`                 |
| Backend Health Check | `http://localhost:3001/api/health`      |
| 政策端 Dashboard     | `http://localhost:3001/admin/dashboard` |
| 諮詢師端 Web         | `http://localhost:3001/counselor`       |

> Demo 登入：若沒有設定 Supabase，前端會走 mock login。輸入任一合法 email 與 4 碼以上密碼即可進入。

## 快速啟動

### 1. 啟動後端

```powershell
cd backend
npm install
npm run dev
```

後端預設跑在：

```txt
http://localhost:3001
```

### 2. 設定 AI 金鑰

後端會讀取：

```txt
backend/.env.local
```

必要或建議環境變數：

```env
GEMINI_API_KEY=your-gemini-api-key
GEMINI_MODEL=gemini-2.5-flash
```

Supabase 是 optional。若未設定 Supabase，系統會使用 in-memory demo store，仍可完整展示主要流程。

### 3. 啟動 Flutter Web

在專案根目錄執行：

```powershell
flutter pub get
flutter run -d chrome `
  --web-hostname 127.0.0.1 `
  --web-port 8081 `
  --dart-define=EMPLOYA_API_BASE_URL=http://localhost:3001
```

打開：

```txt
http://127.0.0.1:8081
```

## 系統架構

```txt
Flutter 青年端 App
  ├─ Auth / Onboarding
  ├─ Persona
  ├─ Swipe Explore
  ├─ Skill Translator
  ├─ To-do List
  ├─ AI Chat
  └─ Policy Dashboard
        ↓ HTTP API
Next.js Backend
  ├─ User / Profile / Persona API
  ├─ Swipe / Skill / Plan API
  ├─ Chat / RAG / Knowledge API
  ├─ Counselor API
  ├─ Startup API
  └─ Admin Dashboard API
        ↓
AI Service Layer
  ├─ Gemini Chat
  ├─ RAG Answer Generator
  ├─ Question Normalizer
  ├─ User Insight Generator
  ├─ Counselor Brief Generator
  ├─ Persona Generator
  ├─ Skill Translator
  └─ Startup Analyzer
        ↓
Data Layer
  ├─ In-memory demo store
  └─ Optional Supabase write-through
```

## 技術選型


| 區塊     | 技術                                | 用途                                        |
| -------- | ----------------------------------- | ------------------------------------------- |
| 青年端   | Flutter / Dart                      | 跨平台 App 與 Web Demo                      |
| 前端狀態 | SharedPreferences + AppRepository   | 本地快取、離線 fallback、API 同步           |
| 後端     | Next.js 15 / TypeScript             | API routes、後台頁面、Server-side dashboard |
| AI       | Gemini API + local fallback         | Chat、RAG 回答、問題正規化、使用者洞察      |
| RAG      | Knowledge seed + chunk search       | 政策、課程、補助、創業資源、FAQ 檢索        |
| 資料層   | In-memory store + Supabase optional | 黑客松快速 Demo 與後續持久化擴充            |
| 管理端   | Next.js Web                         | 諮詢師端與政策端 dashboard                  |

## 主要目錄

```txt
sigmaalpha67/
├── lib/                         # Flutter app
│   ├── screens/                 # App 頁面
│   ├── services/                # BackendApi / AppRepository / Supabase config
│   ├── logic/                   # 前端 fallback 邏輯
│   ├── data/                    # 職涯卡片、興趣、補助等靜態資料
│   └── models/                  # Profile / Persona / Plan / Chat models
│
├── backend/                     # Next.js backend
│   ├── src/app/api/             # API routes
│   ├── src/app/counselor/       # 諮詢師端 Web
│   ├── src/app/admin/           # 政策端 Web dashboard
│   ├── src/engines/             # AI / RAG / Persona / Skill engines
│   ├── src/data/                # mock / seed data
│   ├── src/lib/                 # auth / db / store / route helpers
│   └── src/types/               # TypeScript types
│
├── supabase/migrations/         # Supabase schema migrations
└── jobs_img/                    # 職涯卡片圖片素材
```

## API 摘要


| 模組      | API                                                                                               |
| --------- | ------------------------------------------------------------------------------------------------- |
| Auth      | `POST /api/auth/login`, `POST /api/auth/register`, `POST /api/auth/refresh`                       |
| Profile   | `GET /api/users/me/profile`, `PUT /api/users/me/profile`                                          |
| Persona   | `GET /api/persona`, `POST /api/persona/generate`, `POST /api/persona/refresh`                     |
| Swipe     | `GET /api/swipe/cards`, `POST /api/swipe/record`, `GET /api/swipe/summary`                        |
| Skill     | `POST /api/skills/translate`, `POST /api/skills/save`                                             |
| Plan      | `POST /api/plan/generate`, `PUT /api/plan/todos/:key`                                             |
| Chat      | `POST /api/chat/messages`, `POST /api/chat/normalize`                                             |
| RAG       | `POST /api/rag/query`, `POST /api/rag/index`, `POST /api/rag/reindex`                             |
| Knowledge | `POST /api/knowledge`, `GET /api/knowledge/search`                                                |
| Counselor | `POST /api/counselor/cases`, `GET /api/counselor/cases`, `PUT /api/counselor/cases/:caseId/reply` |
| Admin     | `GET /api/admin/dashboard/*`, `POST /api/admin/dashboard/policy-suggestions`                      |

## RAG 如何運作

```txt
使用者提問
   ↓
判斷是否需要查政策 / 補助 / 課程 / 創業 / FAQ
   ↓
搜尋 Knowledge Base
   ↓
取回相關 chunks
   ↓
Gemini 根據檢索內容回答
   ↓
回傳答案、來源、信心分數、是否建議諮詢師介入
```

目前知識庫包含：

- 台北青年職涯與實習資源
- 課程與補助資訊
- 創業貸款、創業空間、創業諮詢
- 青年常見 FAQ
- 諮詢師可回存的知識來源

種子資料位置：

```txt
backend/src/data/knowledgeBase.ts
```


## 資料來源

[](https://github.com/ntuimytp/sigmaalpha67/tree/restore-chat-gemini-fallback#%E8%B3%87%E6%96%99%E4%BE%86%E6%BA%90)

* YTP 2026 黑客松賽題 B：行善台北補充資料
* 臺北市青年局政府公開網站資訊
* 專案內整理的 mock policy / course / startup / FAQ knowledge base
* 使用者互動資料：Profile、Swipe、Skill Translation、Chat、To-do 狀態

## Smoke Test

[](https://github.com/ntuimytp/sigmaalpha67/tree/restore-chat-gemini-fallback#smoke-test)

後端啟動後可用 PowerShell 測試：

```powershell
Invoke-RestMethod http://localhost:3001/api/health
```

測試 RAG：

```powershell
$body = @{
  question = "我想學資料分析，有沒有適合初學者的課程或補助？"
  topK = 3
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:3001/api/rag/query `
  -Headers @{ Authorization = "Bearer demo-user" } `
  -ContentType "application/json" `
  -Body $body
```

測試 Chat：

```powershell
$body = @{
  message = "我文組是不是不好找工作？"
  context = @{
    mode = "career"
    useRag = $true
  }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:3001/api/chat/messages `
  -Headers @{ Authorization = "Bearer demo-user" } `
  -ContentType "application/json" `
  -Body $body
```

## 目前限制

[](https://github.com/ntuimytp/sigmaalpha67/tree/restore-chat-gemini-fallback#%E7%9B%AE%E5%89%8D%E9%99%90%E5%88%B6)

* 目前 MVP 以 in-memory store 為主，Supabase 為 optional write-through。
* RAG 現階段使用 seed knowledge base 與簡易語意檢索，後續可升級為 Supabase pgvector。
* Dashboard 部分資料使用 mock fallback。

## 資料來源

[](https://github.com/ntuimytp/sigmaalpha67/tree/restore-chat-gemini-fallback#%E8%B3%87%E6%96%99%E4%BE%86%E6%BA%90)

* YTP 2026 黑客松賽題 B：行善台北補充資料
* 臺北市青年局政府公開網站資訊
* 專案內整理的 mock policy / course / startup / FAQ knowledge base
* 使用者互動資料：Profile、Swipe、Skill Translation、Chat、To-do 狀態

## Smoke Test

[](https://github.com/ntuimytp/sigmaalpha67/tree/restore-chat-gemini-fallback#smoke-test)

後端啟動後可用 PowerShell 測試：

```powershell
Invoke-RestMethod http://localhost:3001/api/health
```

測試 RAG：

```powershell
$body = @{
  question = "我想學資料分析，有沒有適合初學者的課程或補助？"
  topK = 3
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:3001/api/rag/query `
  -Headers @{ Authorization = "Bearer demo-user" } `
  -ContentType "application/json" `
  -Body $body
```

測試 Chat：

```powershell
$body = @{
  message = "我文組是不是不好找工作？"
  context = @{
    mode = "career"
    useRag = $true
  }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:3001/api/chat/messages `
  -Headers @{ Authorization = "Bearer demo-user" } `
  -ContentType "application/json" `
  -Body $body
```

## 目前限制

[](https://github.com/ntuimytp/sigmaalpha67/tree/restore-chat-gemini-fallback#%E7%9B%AE%E5%89%8D%E9%99%90%E5%88%B6)

* 目前 MVP 以 in-memory store 為主，Supabase 為 optional write-through。
* RAG 現階段使用 seed knowledge base 與簡易語意檢索，後續可升級為 Supabase pgvector。
* Dashboard 部分資料使用 mock fallback。
