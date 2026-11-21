import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@^9";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function adminKey(): string | null {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (raw) {
    try { const keys = JSON.parse(raw); if (keys.default) return keys.default; } catch { /* fallback */ }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}
function escapeHtml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/\'/g, "&#39;");
}
function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}
async function hashToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}
function inviteUrl(token: string): string {
  const base = (Deno.env.get("APP_BASE_URL") ?? "").replace(/\/$/, "");
  if (!base) throw new Error("APP_BASE_URL_NOT_CONFIGURED");
  return base + "/?invite=" + encodeURIComponent(token);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = adminKey();
  if (!url || !key) return json({ error: "SERVER_CONFIGURATION_ERROR" }, 500);
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token || token === auth) return json({ error: "UNAUTHORIZED" }, 401);

  const admin = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  const caller = authData.user;
  if (authError || !caller) return json({ error: "UNAUTHORIZED" }, 401);

  let body: { action?: string; project_id?: string; invitation_id?: string; email?: string; role?: string; token?: string };
  try { body = await req.json(); } catch { return json({ error: "INVALID_JSON" }, 400); }

  if (body.action === "accept") {
    const rawToken = body.token?.trim() ?? "";
    if (!/^[a-f0-9]{64}$/.test(rawToken)) return json({ error: "INVALID_INVITATION" }, 400);
    const tokenHash = await hashToken(rawToken);
    const { data: invitation, error } = await admin.from("project_invitations")
      .select("id,project_id,email,role,status,expires_at")
      .eq("token_hash", tokenHash).maybeSingle();
    if (error || !invitation) return json({ error: "INVITATION_NOT_FOUND" }, 404);
    if (invitation.status === "accepted" && invitation.accepted_by === caller.id) return json({ success: true, project_id: invitation.project_id, already_accepted: true });
    if (invitation.status !== "pending") return json({ error: "INVITATION_NOT_PENDING" }, 409);
    if (new Date(invitation.expires_at).getTime() <= Date.now()) {
      await admin.from("project_invitations").update({ status: "expired" }).eq("id", invitation.id);
      return json({ error: "INVITATION_EXPIRED" }, 410);
    }
    if (caller.email?.toLowerCase() !== invitation.email.toLowerCase()) {
      return json({ error: "INVITATION_EMAIL_MISMATCH", invited_email: invitation.email }, 403);
    }
    const { data: existing } = await admin.from("project_members").select("id")
      .eq("project_id", invitation.project_id).eq("user_id", caller.id).maybeSingle();
    if (!existing) {
      const { error: addError } = await admin.from("project_members").upsert({
        project_id: invitation.project_id, user_id: caller.id, role: invitation.role,
      }, { onConflict: "project_id,user_id", ignoreDuplicates: true });
      if (addError) return json({ error: "MEMBERSHIP_CREATE_FAILED" }, 500);
    }
    const { data: acceptedRow, error: updateError } = await admin.from("project_invitations").update({
      status: "accepted", accepted_by: caller.id, accepted_at: new Date().toISOString(),
    }).eq("id", invitation.id).eq("status", "pending").select("id").maybeSingle();
    if (updateError) return json({ error: "INVITATION_ACCEPT_FAILED" }, 500);
    if (!acceptedRow) {
      const { data: latest } = await admin.from("project_invitations")
        .select("status,accepted_by").eq("id", invitation.id).maybeSingle();
      if (latest?.status !== "accepted" || latest.accepted_by !== caller.id) {
        return json({ error: "INVITATION_NOT_PENDING" }, 409);
      }
    }
    await admin.from("project_activity").insert({
      project_id: invitation.project_id, actor_id: caller.id,
      event_type: "invitation_accepted", title: "Invitation acceptée",
      metadata: { role: invitation.role },
    });
    return json({ success: true, project_id: invitation.project_id });
  }

  const projectId = body.project_id?.trim();
  if (!projectId) return json({ error: "PROJECT_REQUIRED" }, 400);
  const { data: project, error: projectError } = await admin.from("projects")
    .select("id,name,owner_id").eq("id", projectId).maybeSingle();
  if (projectError || !project) return json({ error: "PROJECT_NOT_FOUND" }, 404);

  if (body.action === "list") {
    const { data: membership } = await admin.from("project_members").select("id")
      .eq("project_id", projectId).eq("user_id", caller.id).maybeSingle();
    if (project.owner_id !== caller.id && !membership) return json({ error: "FORBIDDEN" }, 403);
    const { data, error } = await admin.from("project_invitations")
      .select("id,email,role,status,expires_at,created_at")
      .eq("project_id", projectId).order("created_at", { ascending: false });
    if (error) return json({ error: "INVITATIONS_LOAD_FAILED" }, 500);
    const now = Date.now();
    const invitations = data ?? [];
    for (const invitation of invitations) {
      if (invitation.status === "pending" && new Date(invitation.expires_at).getTime() <= now) {
        invitation.status = "expired";
        await admin.from("project_invitations").update({ status: "expired" })
          .eq("id", invitation.id).eq("status", "pending");
      }
    }
    return json({ invitations });
  }

  if (project.owner_id !== caller.id) return json({ error: "OWNER_ONLY" }, 403);
  if (!["invite", "resend", "revoke"].includes(body.action ?? "")) return json({ error: "UNKNOWN_ACTION" }, 400);

  if (body.action === "revoke") {
    const id = body.invitation_id?.trim();
    if (!id) return json({ error: "INVITATION_REQUIRED" }, 400);
    const { data, error } = await admin.from("project_invitations").update({ status: "revoked" })
      .eq("id", id).eq("project_id", projectId).eq("status", "pending").select("id").maybeSingle();
    if (error || !data) return json({ error: "INVITATION_REVOKE_FAILED" }, 400);
    await admin.from("project_activity").insert({
      project_id: projectId, actor_id: caller.id, event_type: "invitation_revoked",
      title: "Invitation révoquée", metadata: {},
    });
    return json({ success: true });
  }

  const id = body.invitation_id?.trim();
  let email = body.email?.trim().toLowerCase() ?? "";
  let role = body.role ?? "editor";
  if (body.action === "resend") {
    if (!id) return json({ error: "INVITATION_REQUIRED" }, 400);
    const { data: old } = await admin.from("project_invitations").select("email,role")
      .eq("id", id).eq("project_id", projectId).maybeSingle();
    if (!old) return json({ error: "INVITATION_NOT_FOUND" }, 404);
    email = old.email; role = old.role;
    await admin.from("project_invitations").update({ status: "revoked" }).eq("id", id).eq("status", "pending");
  }
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: "INVALID_EMAIL" }, 400);
  if (!["editor", "viewer"].includes(role)) return json({ error: "INVALID_ROLE" }, 400);
  if (email === caller.email?.toLowerCase()) return json({ error: "CANNOT_INVITE_SELF" }, 400);

  const users = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (users.error) return json({ error: "USER_LOOKUP_FAILED" }, 500);
  const existingUser = users.data.users.find((u) => u.email?.toLowerCase() === email);
  if (existingUser?.id === project.owner_id) return json({ error: "ALREADY_OWNER" }, 409);
  if (existingUser) {
    const { data: membership } = await admin.from("project_members").select("id")
      .eq("project_id", projectId).eq("user_id", existingUser.id).maybeSingle();
    if (membership) return json({ error: "ALREADY_MEMBER" }, 409);
  }

  const { count: pendingCount } = await admin.from("project_invitations")
    .select("id", { count: "exact", head: true })
    .eq("project_id", projectId).eq("status", "pending");
  if ((pendingCount ?? 0) >= 30) return json({ error: "PROJECT_INVITATION_LIMIT" }, 429);
  const { count: recentCount } = await admin.from("project_invitations")
    .select("id", { count: "exact", head: true })
    .eq("invited_by", caller.id).gte("created_at", new Date(Date.now() - 60 * 60 * 1000).toISOString());
  if ((recentCount ?? 0) >= 10) return json({ error: "INVITATION_RATE_LIMIT" }, 429);
  const { data: duplicate } = await admin.from("project_invitations").select("id")
    .eq("project_id", projectId).eq("email", email).eq("status", "pending").maybeSingle();
  if (duplicate) return json({ error: "INVITATION_ALREADY_PENDING" }, 409);

  const rawToken = randomToken();
  const tokenHash = await hashToken(rawToken);
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  const { data: invitation, error: insertError } = await admin.from("project_invitations").insert({
    project_id: projectId, email, role, token_hash: tokenHash,
    invited_by: caller.id, expires_at: expiresAt,
  }).select("id").single();
  if (insertError || !invitation) return json({ error: "INVITATION_CREATE_FAILED" }, 500);

  let link: string;
  try { link = inviteUrl(rawToken); } catch { 
    await admin.from("project_invitations").delete().eq("id", invitation.id);
    return json({ error: "APP_BASE_URL_NOT_CONFIGURED" }, 500);
  }

  const smtpHost = Deno.env.get("SMTP_HOST");
  const smtpUser = Deno.env.get("SMTP_USER");
  const smtpPassword = Deno.env.get("SMTP_PASSWORD");
  const smtpFrom = Deno.env.get("SMTP_FROM");
  if (!smtpHost || !smtpUser || !smtpPassword || !smtpFrom) {
    await admin.from("project_invitations").delete().eq("id", invitation.id);
    return json({ error: "SMTP_NOT_CONFIGURED" }, 503);
  }
  const transport = nodemailer.createTransport({
    host: smtpHost, port: Number(Deno.env.get("SMTP_PORT") ?? "465"),
    secure: (Deno.env.get("SMTP_SECURE") ?? "true").toLowerCase() === "true",
    auth: { user: smtpUser, pass: smtpPassword },
  });
  try {
    const inviterName = caller.user_metadata?.full_name ?? caller.email ?? "Un membre de Cookidea";
    await transport.sendMail({
      from: smtpFrom, to: email, replyTo: caller.email ?? undefined,
      subject: "Invitation à collaborer sur « " + project.name + " »",
      text: inviterName + " vous invite à rejoindre le projet « " + project.name +
        " » comme " + (role === "editor" ? "Éditeur" : "Lecteur") +
        ". Cette invitation expire dans 7 jours. Ouvrez ce lien pour l'accepter : " + link,
      html: "<p>" + inviterName + " vous invite à rejoindre <strong>" + project.name +
        "</strong> sur Cookidea.</p><p>Rôle : " + (role === "editor" ? "Éditeur" : "Lecteur") +
        ".</p><p><a href=\"" + link + "\">Accepter l’invitation</a></p><p>Ce lien expire dans 7 jours.</p>",
    });
  } catch (error) {
    console.error("Invitation email failed", error);
    await admin.from("project_invitations").delete().eq("id", invitation.id);
    return json({ error: "INVITATION_EMAIL_FAILED" }, 502);
  } finally { transport.close(); }

  await admin.from("project_activity").insert({
    project_id: projectId, actor_id: caller.id, event_type: "invitation_sent",
    title: "Invitation envoyée", metadata: { email, role },
  });
  return json({ success: true, invitation_id: invitation.id, expires_at: expiresAt });
});
