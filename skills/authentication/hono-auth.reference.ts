/**
 * Complete Hono auth module — middleware + routes.
 *
 * Copy to apps/api/src/auth.ts and adapt. Key things to get right:
 * - Mount authRoutes BEFORE requireAuth middleware (otherwise login requires a session)
 * - Google's userinfo API returns `hd` for Workspace domains — check it server-side
 * - jose's jwtVerify throws on expired/invalid tokens — catch returns 401
 */

import { Hono } from "hono";
import { createMiddleware } from "hono/factory";
import { SignJWT, jwtVerify } from "jose";

// --- Config ---

if (!process.env.SESSION_SECRET) {
  // Fail closed: a missing secret must never fall back to a guessable default —
  // session JWTs signed with a known string are forgeable by anyone.
  throw new Error(
    "SESSION_SECRET is not set. Generate one with `openssl rand -hex 32` and set it in .env (local) or Railway (prod)."
  );
}
const SESSION_SECRET = new TextEncoder().encode(process.env.SESSION_SECRET);
const ALLOWED_DOMAIN = "traba.work";
const SESSION_DURATION = "7d";

// --- Types ---

interface UserPayload {
  email: string;
  name: string;
  picture: string;
}

// --- Middleware ---

/**
 * Verifies the session JWT from the Authorization header.
 * Sets c.get("user") on success, returns 401 on failure.
 *
 * Mount AFTER auth routes so the login endpoint is accessible:
 *   app.route("/api/auth", authRoutes);  // no middleware
 *   app.use("/api/*", requireAuth);      // everything else
 */
export const requireAuth = createMiddleware(async (c, next) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer "))
    return c.json({ error: "Unauthorized" }, 401);
  try {
    const { payload } = await jwtVerify(header.slice(7), SESSION_SECRET);
    c.set("user", payload as unknown as UserPayload);
    await next();
  } catch {
    return c.json({ error: "Unauthorized" }, 401);
  }
});

// --- Routes ---

export const authRoutes = new Hono();

/**
 * POST /api/auth/verify
 *
 * Accepts a Google access token (from useGoogleLogin's implicit flow),
 * verifies it against Google's userinfo API, checks the hosted domain,
 * and returns a session JWT.
 *
 * The Google access token is opaque — it cannot be decoded client-side.
 * That's why the server calls userinfo and returns the user profile.
 */
authRoutes.post("/verify", async (c) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer "))
    return c.json({ error: "Missing token" }, 401);

  // Verify with Google
  const res = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
    headers: { Authorization: header },
  });
  if (!res.ok) return c.json({ error: "Invalid token" }, 401);

  const info = await res.json();

  // hosted_domain on the client is a UX hint, not enforcement.
  // This is the actual security check.
  if (info.hd !== ALLOWED_DOMAIN)
    return c.json(
      { error: `Access restricted to @${ALLOWED_DOMAIN} accounts` },
      401
    );

  const user: UserPayload = {
    email: info.email,
    name: info.name,
    picture: info.picture,
  };

  // Issue session JWT — this replaces the short-lived Google token
  const token = await new SignJWT(user as unknown as Record<string, unknown>)
    .setProtectedHeader({ alg: "HS256" })
    .setExpirationTime(SESSION_DURATION)
    .setIssuedAt()
    .sign(SESSION_SECRET);

  return c.json({ ...user, token });
});

/**
 * GET /api/auth/me
 *
 * Returns the current user from the session JWT, or 401.
 * Frontend calls this on page load to verify the stored token
 * server-side before trusting localStorage.
 */
authRoutes.get("/me", async (c) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer "))
    return c.json({ error: "Not authenticated" }, 401);
  try {
    const { payload } = await jwtVerify(header.slice(7), SESSION_SECRET);
    const user: UserPayload = {
      email: payload.email as string,
      name: payload.name as string,
      picture: payload.picture as string,
    };
    return c.json(user);
  } catch {
    return c.json({ error: "Invalid session" }, 401);
  }
});
