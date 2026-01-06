# Psych Catalog Backend API

Node.js/Express backend for Psych Catalog application.

## Features

- ✅ RESTful API
- ✅ Firebase Authentication
- ✅ Gemini AI Integration
- ✅ Rate Limiting
- ✅ Error Handling
- ✅ CORS Support

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy `.env.example` to `.env` and configure:
```bash
cp .env.example .env
```

3. Set environment variables:
- `GEMINI_API_KEY`: Your Gemini API key
- `FIREBASE_SERVICE_ACCOUNT`: Firebase service account JSON (or use default credentials)
- `PORT`: Server port (default: 3000)
- `ALLOWED_ORIGINS`: Comma-separated list of allowed origins

4. Run server:
```bash
# Development (with auto-reload)
npm run dev

# Production
npm start
```

## API Endpoints

### POST /api/ai/analyze
Analyzes text using Gemini API.

**Headers:**
```
Authorization: Bearer <firebase_id_token>
```

**Body:**
```json
{
  "text": "Text to analyze"
}
```

**Response:**
```json
{
  "success": true,
  "analysis": "AI analysis result..."
}
```

### POST /api/test/analyze
Analyzes test answers (triggered when test is solved).

**Headers:**
```
Authorization: Bearer <firebase_id_token>
```

**Body:**
```json
{
  "testId": "test_document_id",
  "docId": "solved_test_document_id"
}
```

## Deployment

### Railway
1. Connect your GitHub repo
2. Set environment variables
3. Deploy!

### Render
1. Create new Web Service
2. Connect repo
3. Set environment variables
4. Deploy!

### Heroku
```bash
heroku create your-app-name
heroku config:set GEMINI_API_KEY=your_key
git push heroku main
```

## Environment Variables

- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment (development/production)
- `GEMINI_API_KEY`: Gemini API key
- `FIREBASE_SERVICE_ACCOUNT`: Firebase service account JSON
- `ALLOWED_ORIGINS`: Comma-separated allowed origins

