// =====================================================================
// send-push  —  Firebase Cloud Messaging (FCM HTTP v1) for the app.
//
// Called by the database (trigger on "Message" insert, via pg_net), never
// by the app. The request must carry the shared secret header:
//   x-push-secret: <PUSH_WEBHOOK_SECRET>
//
// Request (POST JSON), one of:
//   { "type": "chat_message", "messageID": "<uuid>" }  new chat message
//   { "type": "call",         "callID": "<uuid>" }     ring the receiver
//   { "type": "call_cancel",  "callID": "<uuid>" }     stop ringing (answered,
//                                                        declined or hung up)
//
// Response 200  { "sent": n, "removedTokens": n }  (or { "skipped": "<why>" })
//
// Secrets (supabase secrets set ...):
//   FIREBASE_SERVICE_ACCOUNT  the whole service-account JSON (one line)
//   PUSH_WEBHOOK_SECRET       random string, same as the Vault secret
//                             'push_webhook_secret' used by the trigger
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.
// =====================================================================

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const CHAT_CHANNEL_ID = "chat_messages";             // must match PushService in the app
const RECRUITMENT_CHANNEL_ID = "recruitment_updates"; // must match PushService in the app
const CALL_RING_SECONDS = 45;                        // a call push older than this is useless
const MAX_BODY_CHARS = 140;

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface MessageRow {
  messageID: string;
  roomID: string;
  senderID: string;
  content: string | null;
  mediaType: string | null;
  isDeleted: boolean | null;
}

// ---------------------------------------------------------------------
// Google OAuth access token from the service account (cached ~55 min)
// ---------------------------------------------------------------------
let cachedToken: { value: string; expiresAt: number } | null = null;

function base64UrlFromBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlFromJson(value: unknown): string {
  return base64UrlFromBytes(new TextEncoder().encode(JSON.stringify(value)));
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;

  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${base64UrlFromJson({ alg: "RS256", typ: "JWT" })}.${base64UrlFromJson({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );
  const assertion = `${unsigned}.${base64UrlFromBytes(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`oauth_failed ${res.status}: ${await res.text()}`);
  const json = await res.json() as { access_token: string; expires_in: number };

  cachedToken = { value: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
  return json.access_token;
}

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------
function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function previewText(m: MessageRow): string {
  const text = (m.content ?? "").trim();
  switch (m.mediaType) {
    case "image":
      return "📷 Photo";
    case "audio":
      return "🎤 Voice message";
    case "file":
      return `📎 ${text || "Attachment"}`;
    default: {
      // Cut by code point, never through an emoji (half of one is invalid text)
      const chars = Array.from(text);
      return chars.length > MAX_BODY_CHARS ? `${chars.slice(0, MAX_BODY_CHARS - 1).join("")}…` : text;
    }
  }
}

async function profileOf(
  admin: SupabaseClient,
  userId: string,
): Promise<{ name: string; photo: string }> {
  const [employer, seeker, user] = await Promise.all([
    admin.from("Employer").select("fullName, profilePictureURL").eq("employerID", userId).maybeSingle(),
    admin.from("JobSeeker").select("fullName, profilePictureURL").eq("seekerID", userId).maybeSingle(),
    admin.from("User").select("username").eq("userID", userId).maybeSingle(),
  ]);
  const name = (employer.data?.fullName ?? seeker.data?.fullName ?? user.data?.username ?? "")
    .toString()
    .trim();
  const photo = (employer.data?.profilePictureURL ?? seeker.data?.profilePictureURL ?? "")
    .toString()
    .trim();
  return { name: name || "Someone", photo };
}

/**
 * Sends [message] (an FCM v1 message without "token") to every device of the
 * user; removes tokens FCM says are dead.
 */
async function sendToUser(
  admin: SupabaseClient,
  sa: ServiceAccount,
  userId: string,
  message: Record<string, unknown>,
): Promise<{ sent: number; removedTokens: number }> {
  const { data: devices, error } = await admin
    .from("UserDevice")
    .select("token")
    .eq("userID", userId);
  if (error) throw new Error(`device_lookup_failed: ${error.message}`);
  if (!devices || devices.length === 0) return { sent: 0, removedTokens: 0 };

  const accessToken = await getAccessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  let sent = 0;
  const dead: string[] = [];

  await Promise.all(devices.map(async ({ token }: { token: string }) => {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: { ...message, token } }),
    });

    if (res.ok) {
      sent++;
      return;
    }
    const text = await res.text();
    // UNREGISTERED (404) or invalid token (400): the app was uninstalled or the token rotated.
    if (res.status === 404 || (res.status === 400 && text.includes("registration token"))) {
      dead.push(token);
    } else {
      console.error(`[send-push] FCM ${res.status}: ${text}`);
    }
  }));

  if (dead.length > 0) {
    await admin.from("UserDevice").delete().in("token", dead);
  }
  return { sent, removedTokens: dead.length };
}

// ---------------------------------------------------------------------
// Push types
// ---------------------------------------------------------------------

/** New chat message: a normal notification ("Sender name: text"). */
async function handleChatMessage(
  admin: SupabaseClient,
  sa: ServiceAccount,
  messageID: string | undefined,
): Promise<Response> {
  if (!messageID) return json(400, { error: "bad_request" });

  const { data: msg } = await admin
    .from("Message")
    .select("messageID, roomID, senderID, content, mediaType, isDeleted")
    .eq("messageID", messageID)
    .maybeSingle<MessageRow>();
  if (!msg) return json(200, { skipped: "message_not_found" });
  if (msg.isDeleted || msg.mediaType === "call_log") return json(200, { skipped: "not_notified" });

  const { data: room } = await admin
    .from("ChatRoom")
    .select("user1ID, user2ID")
    .eq("roomID", msg.roomID)
    .maybeSingle();
  if (!room) return json(200, { skipped: "room_not_found" });

  const receiverId = room.user1ID === msg.senderID ? room.user2ID : room.user1ID;
  const sender = await profileOf(admin, msg.senderID);

  const result = await sendToUser(admin, sa, receiverId, {
    notification: { title: sender.name, body: previewText(msg) },
    data: { // all values must be strings
      type: "chat_message",
      roomID: msg.roomID,
      senderID: msg.senderID,
      messageID: msg.messageID,
    },
    android: {
      priority: "high",
      notification: {
        channel_id: CHAT_CHANNEL_ID,
        tag: `chat_${msg.roomID}`, // a newer message from the same chat replaces the old one
        sound: "default",
      },
    },
  });
  return json(200, result);
}

interface CallRow {
  callID: string;
  callerID: string;
  receiverID: string;
  roomCode: string;
  status: string;
}

/**
 * Incoming call: a DATA-ONLY high-priority message, so the app itself shows
 * the full-screen ringing notification (with Answer / Decline) even when closed.
 */
async function handleCall(
  admin: SupabaseClient,
  sa: ServiceAccount,
  callID: string | undefined,
): Promise<Response> {
  if (!callID) return json(400, { error: "bad_request" });

  const { data: call } = await admin
    .from("Calls")
    .select("callID, callerID, receiverID, roomCode, status")
    .eq("callID", callID)
    .maybeSingle<CallRow>();
  if (!call) return json(200, { skipped: "call_not_found" });
  if (call.status !== "ringing") return json(200, { skipped: "not_ringing" });

  const caller = await profileOf(admin, call.callerID);
  const result = await sendToUser(admin, sa, call.receiverID, {
    data: {
      type: "call",
      callID: call.callID,
      roomCode: call.roomCode,
      callerID: call.callerID,
      callerName: caller.name,
      callerPhoto: caller.photo,
    },
    android: {
      priority: "high",
      ttl: `${CALL_RING_SECONDS}s`,
      collapse_key: `call_${call.callID}`,
    },
  });
  return json(200, result);
}

/** Call answered, declined or hung up: tell the receiver's phones to stop ringing. */
async function handleCallCancel(
  admin: SupabaseClient,
  sa: ServiceAccount,
  callID: string | undefined,
): Promise<Response> {
  if (!callID) return json(400, { error: "bad_request" });

  const { data: call } = await admin
    .from("Calls")
    .select("callID, callerID, receiverID, roomCode, status")
    .eq("callID", callID)
    .maybeSingle<CallRow>();
  if (!call) return json(200, { skipped: "call_not_found" });

  const result = await sendToUser(admin, sa, call.receiverID, {
    data: { type: "call_cancel", callID: call.callID, status: call.status },
    android: { priority: "high", ttl: `${CALL_RING_SECONDS}s` },
  });
  return json(200, result);
}

interface RecruitmentPushPayload {
  type?: string;
  notificationID?: string;
  userID?: string;
  eventType?: string;
  title?: string;
  body?: string;
  companyID?: string;
  jobID?: string;
  applicantID?: string;
  scheduleID?: string;
}

/** Recruitment pipeline notification (Apply -> Schedule -> Interview -> Offer -> Decision, plus Company Verification). */
async function handleRecruitmentEvent(
  admin: SupabaseClient,
  sa: ServiceAccount,
  payload: RecruitmentPushPayload,
): Promise<Response> {
  const userId = (payload.userID ?? "").trim();
  const title = (payload.title ?? "").trim() || "Recruitment Update";
  const body = (payload.body ?? "").trim();
  if (!userId || !body) return json(400, { error: "bad_request" });

  const notificationId = (payload.notificationID ?? "").trim();
  const eventType = (payload.eventType ?? "recruitment_update").trim();

  const result = await sendToUser(admin, sa, userId, {
    notification: { title, body },
    data: {
      type: "recruitment_event",
      notificationID: notificationId,
      eventType,
      title,
      body,
      companyID: (payload.companyID ?? "").toString(),
      jobID: (payload.jobID ?? "").toString(),
      applicantID: (payload.applicantID ?? "").toString(),
      scheduleID: (payload.scheduleID ?? "").toString(),
    },
    android: {
      priority: "high",
      notification: {
        channel_id: RECRUITMENT_CHANNEL_ID,
        tag: notificationId ? `rec_${notificationId}` : `rec_${eventType}_${Date.now()}`,
        sound: "default",
      },
    },
  });
  return json(200, result);
}

// ---------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const secret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-push-secret") !== secret) {
    return json(401, { error: "unauthorized" });
  }

  let sa: ServiceAccount;
  try {
    sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "");
    if (!sa.project_id || !sa.client_email || !sa.private_key) throw new Error("incomplete");
  } catch {
    console.error("[send-push] FIREBASE_SERVICE_ACCOUNT secret missing or invalid");
    return json(500, { error: "not_configured" });
  }

  let payload: RecruitmentPushPayload & { messageID?: string; callID?: string };
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "bad_request" });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  try {
    switch (payload.type) {
      case "chat_message":
        return await handleChatMessage(admin, sa, payload.messageID);
      case "call":
        return await handleCall(admin, sa, payload.callID);
      case "call_cancel":
        return await handleCallCancel(admin, sa, payload.callID);
      case "recruitment_event":
        return await handleRecruitmentEvent(admin, sa, payload);
      default:
        return json(400, { error: "unsupported_type" });
    }
  } catch (e) {
    console.error("[send-push] error:", e);
    return json(500, { error: "server_error" });
  }
});
