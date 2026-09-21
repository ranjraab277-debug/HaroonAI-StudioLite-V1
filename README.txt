HAROON AI STUDIO LITE V2
=========================
- Chat UI with an explicit "إغلاق المحادثات" button.
- One integrated Roblox server script.
- Gemini retry for 429/5xx errors.
- Deterministic build/edit operations.
- Render-ready.

IMPORTANT:
Roblox documents that in-game HttpService requests are disabled by default and require HTTP requests to be allowed in experience settings. Studio Lite is a separate simplified editor, so this V2 does NOT fake a connection if your Studio Lite environment does not expose outbound HTTP.

If your Studio Lite session supports HttpService, set:
RENDER_URL = "https://YOUR-APP.onrender.com"
BRIDGE_CONNECT_PASSWORD = "same password as Render"

Do not put GEMINI_API_KEY in Roblox.
