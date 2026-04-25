# EmploYA Backend

Next.js (App Router, TypeScript) implementation of the API surface described in
[`API_REQUESTS.md`](./API_REQUESTS.md). Every endpoint is wired and returns the
shapes the Flutter app expects, but the underlying data and "AI" are
**fake / rule-based** — designed so you can replace them piece by piece with a
real database and LLM provider.

## Run

```bash
cd backend
npm install
npm run dev          # http://localhost:3001
```

Health check: <http://localhost:3001/api/health>

## Auth

Every non-`/api/auth/*` endpoint expects:

```
Authorization: Bearer <token>
```

The fake auth (`src/lib/auth.ts`) treats the token *as* the user id. So calling
`POST /api/auth/login` with `{"email":"a@b.com"}` hands back an `accessToken`
that the client then sends as a Bearer token; the rest of the API will scope
data to that user. To swap in real JWT/session auth, replace `authenticate()`
in `src/lib/auth.ts`.

For local debugging without a token, set `ALLOW_ANON=1`:

```bash
ALLOW_ANON=1 npm run dev
```

## Where the fake data lives (replace these later)

All fake/rule-based logic is grouped so you can swap files individually:

| Concern | File | Replace with |
|---|---|---|
| Role cards (swipe) | `src/data/roles.ts` | DB query / CMS |
| Daily questions | `src/data/dailyQuestions.ts` | CMS / editorial DB |
| Plan templates per top-tag | `src/data/planTemplates.ts` | LLM-generated plans |
| Startup resources catalogue | `src/data/startupResources.ts` | curated DB / external feed |
| Admin dashboard metrics | `src/data/adminMetrics.ts` | warehouse aggregations |
| Persona generation | `src/engines/persona.ts` | LLM call |
| Skill translation | `src/engines/skillTranslator.ts` | LLM call |
| Chat reply | `src/engines/chatReply.ts` | LLM call (Anthropic / OpenAI) |
| Intent normalisation | `src/engines/intentNormalizer.ts` | LLM call |
| Counselor brief | `src/engines/counselorBrief.ts` | LLM call |
| Plan generator | `src/engines/planGenerator.ts` | LLM call |
| Startup analyzer | `src/engines/startupAnalyzer.ts` | LLM call |
| User data store | `src/lib/store.ts` | Postgres / Mongo / Firestore / Supabase |

Every fake source has a `FAKE` banner at the top.

## Endpoint catalogue

Health: `GET /api/health`

### 1. Profile (§1)
- `GET    /api/users/me/profile`
- `PUT    /api/users/me/profile`
- `DELETE /api/users/me`     — GDPR account delete

### 2. Persona (§2)
- `POST /api/persona/generate`
- `POST /api/persona/refresh`
- `PUT  /api/persona`
- `GET  /api/persona`

### 3. Swipe (§3)
- `GET  /api/swipe/cards?mode=career&limit=20`
- `POST /api/swipe/record`
- `GET  /api/swipe/summary`

### 4. Skill translator (§4)
- `POST /api/skills/translate`
- `POST /api/skills/save`
- `GET  /api/skills/translations`

### 5. Chat (§5)
- `POST   /api/chat/messages`
- `POST   /api/chat/normalize`
- `GET    /api/chat/conversations/{id}/messages`
- `DELETE /api/chat/conversations/{id}`

### 6. Counselor brief (§6)
- `POST /api/counselor/cases`
- `GET  /api/counselor/cases?status=waiting_for_counselor`
- `PUT  /api/counselor/cases/{caseId}/reply`

### 7. Daily question (§7)
- `GET  /api/daily-question?date=YYYY-MM-DD`
- `POST /api/daily-question/answers`

### 8. Plan (§8)
- `POST /api/plan/generate`
- `PUT  /api/plan/todos/{key}`
- `PUT  /api/plan/weeks/{week}/note`

### 9. Startup (§9)
- `POST /api/startup/analyze`
- `GET  /api/startup/resources?stage=想法期&type=loan`

### 10. Admin / policy dashboard (§10)
- `GET  /api/admin/dashboard/top-questions?from=&to=`
- `GET  /api/admin/dashboard/top-career-paths`
- `GET  /api/admin/dashboard/skill-gaps`
- `GET  /api/admin/dashboard/stuck-tasks`
- `GET  /api/admin/dashboard/startup-needs`
- `POST /api/admin/dashboard/policy-suggestions`

### 11. Auth (§11)
- `POST   /api/auth/login`
- `POST   /api/auth/register`
- `POST   /api/auth/refresh`
- `DELETE /api/auth/logout`
- `DELETE /api/users/me`

## Project layout

```
backend/
├── package.json
├── tsconfig.json
├── next.config.js
├── README.md
├── API_REQUESTS.md           ← spec (untouched)
└── src/
    ├── app/
    │   ├── layout.tsx        ← minimal app shell (this is API-mostly)
    │   ├── page.tsx          ← landing page pointing at /api/health
    │   └── api/
    │       ├── health/route.ts
    │       ├── auth/{login,register,refresh,logout}/route.ts
    │       ├── users/me/route.ts            (DELETE)
    │       ├── users/me/profile/route.ts
    │       ├── persona/{generate,refresh}/route.ts
    │       ├── persona/route.ts             (PUT/GET)
    │       ├── swipe/{cards,record,summary}/route.ts
    │       ├── skills/{translate,save,translations}/route.ts
    │       ├── chat/messages/route.ts
    │       ├── chat/normalize/route.ts
    │       ├── chat/conversations/[conversationId]/route.ts
    │       ├── chat/conversations/[conversationId]/messages/route.ts
    │       ├── counselor/cases/route.ts
    │       ├── counselor/cases/[caseId]/reply/route.ts
    │       ├── daily-question/route.ts
    │       ├── daily-question/answers/route.ts
    │       ├── plan/generate/route.ts
    │       ├── plan/todos/[key]/route.ts
    │       ├── plan/weeks/[week]/note/route.ts
    │       ├── startup/{analyze,resources}/route.ts
    │       └── admin/dashboard/{top-questions,top-career-paths,skill-gaps,stuck-tasks,startup-needs,policy-suggestions}/route.ts
    ├── lib/
    │   ├── auth.ts           ← fake Bearer auth — REPLACE
    │   ├── errors.ts         ← `apiError(code, message)` helper
    │   ├── route.ts          ← `withAuth()` + `readJson()` helpers
    │   ├── store.ts          ← in-memory store — REPLACE
    │   └── swipeSummary.ts
    ├── data/                 ← FAKE data sources, swap individually
    ├── engines/              ← FAKE rule-based "AI" engines, swap individually
    └── types/
```

## Quick smoke test

```bash
# 1. Login (fake) — token equals the userId
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"alice@example.com"}' | jq -r .accessToken)

# 2. Save a profile
curl -s -X PUT http://localhost:3001/api/users/me/profile \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"name":"小安","department":"社會系","grade":"大三","currentStage":"在學探索"}' | jq

# 3. Generate a persona
curl -s -X POST http://localhost:3001/api/persona/generate \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"explore":{"likedRoleIds":["uiux_designer","data_analyst"]}}' | jq

# 4. Send a chat message
curl -s -X POST http://localhost:3001/api/chat/messages \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"message":"我畢業是不是很難找到好工作？","context":{"mode":"career"}}' | jq
```

## Notes

- **In-memory only.** Restarting `next dev` clears all state. Hot reload preserves
  state via a `globalThis` cache (see `src/lib/store.ts`).
- **No CORS config.** Add `headers()` in `next.config.js` if you call this from
  the Flutter web build on a different origin.
- **No rate limiting / no input validation library.** Add `zod` (or similar) at
  request boundaries before going to production.
