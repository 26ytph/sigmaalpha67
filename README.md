# employa

Flutter app + Next.js backend for EmploYA.

## Getting Started

Run the backend first:

```powershell
cd backend
npm install
npm run dev
```

Then run the Flutter web app against that backend:

```powershell
flutter pub get
flutter run -d chrome --dart-define=EMPLOYA_API_BASE_URL=http://localhost:3001
```

The backend uses fake Bearer auth for the hackathon MVP. The Flutter app sends
`demo-user` by default; override it with:

```powershell
flutter run -d chrome `
  --dart-define=EMPLOYA_API_BASE_URL=http://localhost:3001 `
  --dart-define=EMPLOYA_API_TOKEN=demo-user
```
