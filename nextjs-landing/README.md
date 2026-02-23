# Lona Landing Page

Next.js landing page with Flutter app integration.

## Setup

```bash
npm install
```

## Development (Landing Page Only)

```bash
npm run dev
```

Visit http://localhost:3000 to see the landing page.

## Production Build (Landing Page + Flutter App)

```bash
./build.sh
```

This will:
1. Build Flutter web app with `/app/` base href
2. Copy Flutter build to `public/app/`
3. Build Next.js static site
4. Output everything to `out/` directory

## Test Production Build Locally

After running `./build.sh`:

```bash
npm run start
```

Or use a static server:
```bash
npx serve out
```

## Deployment

After building, deploy to Firebase Hosting:

```bash
# From project root
firebase deploy --only hosting
```

## Routes

- `/` - Landing page (Next.js)
- `/app` - Flutter app
- `/app/*` - Flutter app routes
