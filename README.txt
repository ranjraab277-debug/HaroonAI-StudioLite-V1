HAROON AI STUDIO LITE V1 — RENDER

Render:
1. Upload this project to GitHub.
2. Render -> New -> Web Service.
3. Select the GitHub repo.
4. Build Command: npm install
5. Start Command: npm start
6. Add Environment Variables:
   BRIDGE_CONNECT_PASSWORD = your secret
   GEMINI_API_KEY = your Gemini key
   GEMINI_MODEL = gemini-3.6-flash
7. Deploy.
8. Copy your https://....onrender.com URL.

Roblox:
1. Put HaroonAI_Bridge.server.lua in ServerScriptService.
2. Set ONLY:
   RENDER_URL = "https://YOUR-SERVICE.onrender.com"
   BRIDGE_CONNECT_PASSWORD = "same password as Render"
3. Enable HTTP Requests if your Studio Lite environment exposes that setting.
4. Start the game.

SECURITY:
- Never put GEMINI_API_KEY in Roblox.
- Bridge password is shared only between Roblox and your server.
- Use a long random password.
- This V1 executes only a small allowlist of build operations.

IMPORTANT:
This requires Studio Lite to expose server-side HTTP requests. Roblox documents HttpService for Roblox experiences, but Studio Lite may have different restrictions.
