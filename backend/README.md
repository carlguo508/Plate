# Plate nutrition AI proxy

This Vercel function keeps the OpenAI API key out of the iOS app.

## Deploy

1. Import the `backend` directory as a Vercel project.
2. Add `OPENAI_API_KEY` in Vercel project environment variables.
3. Optionally add a random `PLATE_APP_TOKEN` and `OPENAI_MODEL`.
   The default model is `gpt-5-mini`.
4. Deploy and copy:
   `https://YOUR-PROJECT.vercel.app/api/analyze-meal`
5. In Plate, open **Today > target icon > AI nutrition estimate** and paste
   the endpoint. If configured, paste the matching app token.

The app token prevents casual use of the endpoint but is not a substitute for
provider-side rate limits. Keep a usage limit on the OpenAI project and add
Vercel rate limiting before distributing the app broadly.
