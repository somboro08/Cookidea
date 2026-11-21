import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@^9";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function secretKey(): string | null {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (raw) {
    try {
      const keys = JSON.parse(raw);
      if (keys.default) return keys.default;
    } catch { /* legacy fallback */ }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const key = secretKey();
  if (!url || !key) return json({ error: "SERVER_CONFIGURATION_ERROR" }, 500);
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token || token === auth) return json({ error: "UNAUTHORIZED" }, 401);
  const admin = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  const caller = authData.user;
  if (authError || !caller) return json({ error: "UNAUTHORIZED" }, 401);

  let body: { action?: string; project_id?: string; email?: string; role?: string; user_id?: string };
  try { body = await req.json(); } catch { return json({ error: "INVALID_JSON" }, 400); }
  const projectId = body.project_id?.trim();
  if (!projectId) return json({ error: "PROJECT_REQUIRED" }, 400);
  const { data: project, error: projectError } = await admin.from("projects")
    .select("id,name,owner_id").eq("id", projectId).maybeSingle();
  if (projectError || !project) return json({ error: "PROJECT_NOT_FOUND" }, 404);
  if (project.owner_id !== caller.id && body.action !== "list") return json({ error: "OWNER_ONLY" }, 403);
  if (body.action === "list" && project.owner_id !== caller.id) {
    const { data: callerMembership } = await admin.from("project_members")
      .select("id").eq("project_id", projectId).eq("user_id", caller.id).maybeSingle();
    if (!callerMembership) return json({ error: "FORBIDDEN" }, 403);
  }

  const logActivity = async (event: string, title: string, metadata: Record<string, unknown>) => {
    await admin.from("project_activity").insert({
      project_id: projectId, actor_id: caller.id, event_type: event, title, metadata,
    });
  };

  if (body.action === "list") {
    const { data, error } = await admin.from("project_members")
      .select("id,user_id,role,joined_at").eq("project_id", projectId).order("joined_at");
    if (error) return json({ error: "MEMBERS_LOAD_FAILED" }, 500);
    const members = [];
    for (const member of data ?? []) {
      const { data: profile } = await admin.from("profiles")
        .select("full_name,avatar_url").eq("id", member.user_id).maybeSingle();
      const { data: userData } = await admin.auth.admin.getUserById(member.user_id);
      members.push({
        ...member,
        full_name: profile?.full_name ?? userData.user?.user_metadata?.full_name ?? null,
        email: userData.user?.email ?? null,
        avatar_url: profile?.avatar_url ?? null,
      });
    }
    const { data: ownerProfile } = await admin.from("profiles")
      .select("full_name,avatar_url").eq("id", project.owner_id).maybeSingle();
    const { data: ownerData } = await admin.auth.admin.getUserById(project.owner_id);
    members.unshift({ id: null, user_id: project.owner_id, role: "owner", joined_at: null,
      full_name: ownerProfile?.full_name ?? ownerData.user?.user_metadata?.full_name ?? null,
      email: ownerData.user?.email ?? null, avatar_url: ownerProfile?.avatar_url ?? null, is_owner: true });
    return json({ members });
  }

  if (body.action === "invite") {
    const email = body.email?.trim().toLowerCase();
    const role = body.role ?? "editor";
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: "INVALID_EMAIL" }, 400);
    if (!["editor", "viewer"].includes(role)) return json({ error: "INVALID_ROLE" }, 400);
    if (email === caller.email?.toLowerCase()) return json({ error: "CANNOT_INVITE_SELF" }, 400);
    const users = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    if (users.error) return json({ error: "USER_LOOKUP_FAILED" }, 500);
    const invitedUser = users.data.users.find((u) => u.email?.toLowerCase() === email);
    if (!invitedUser) return json({ error: "USER_NOT_FOUND", message: "Cette adresse ne possède pas encore de compte Cookidea." }, 404);
    if (invitedUser.id === project.owner_id) return json({ error: "ALREADY_OWNER" }, 409);
    const { data: membership } = await admin.from("project_members")
      .select("id").eq("project_id", projectId).eq("user_id", invitedUser.id).maybeSingle();
    if (membership) return json({ error: "ALREADY_MEMBER" }, 409);
    const { error: insertError } = await admin.from("project_members").insert({
      project_id: projectId, user_id: invitedUser.id, role,
    });
    if (insertError) return json({ error: "MEMBER_ADD_FAILED" }, 500);
    await logActivity("member_added", "Un membre a rejoint le projet", { role });
    let emailSent = false;
    const smtpHost = Deno.env.get("SMTP_HOST");
    const smtpUser = Deno.env.get("SMTP_USER");
    const smtpPassword = Deno.env.get("SMTP_PASSWORD");
    const smtpFrom = Deno.env.get("SMTP_FROM");
    if (smtpHost && smtpUser && smtpPassword && smtpFrom) {
      const transport = nodemailer.createTransport({
        host: smtpHost, port: Number(Deno.env.get("SMTP_PORT") ?? "465"),
        secure: (Deno.env.get("SMTP_SECURE") ?? "true").toLowerCase() === "true",
        auth: { user: smtpUser, pass: smtpPassword },
      });
      try {
        await transport.sendMail({
          from: smtpFrom, to: email, replyTo: caller.email ?? undefined,
          subject: "Vous avez rejoint « " + project.name + " » sur Cookidea",
          text: (caller.user_metadata?.full_name ?? caller.email ?? "Un membre") + " vous a ajouté au projet « " + project.name + " » avec le rôle " + (role === "editor" ? "Éditeur" : "Lecteur") + ". Connectez-vous à Cookidea pour le retrouver.",
        });
        emailSent = true;
      } catch (error) { console.error("Member notification failed", error); }
      finally { transport.close(); }
    }
    return json({ success: true, email_sent: emailSent });
  }

  if (body.action === "change_role") {
    const userId = body.user_id?.trim();
    const role = body.role;
    if (!userId || !["editor", "viewer"].includes(role ?? "")) return json({ error: "INVALID_ROLE_CHANGE" }, 400);
    const { data: member, error } = await admin.from("project_members").update({ role })
      .eq("project_id", projectId).eq("user_id", userId).select("id").maybeSingle();
    if (error || !member) return json({ error: "ROLE_UPDATE_FAILED" }, 500);
    await logActivity("member_role_changed", "Le rôle d'un membre a été modifié", { role });
    return json({ success: true });
  }

  if (body.action === "remove") {
    const userId = body.user_id?.trim();
    if (!userId || userId === project.owner_id) return json({ error: "INVALID_MEMBER" }, 400);
    const { data: member, error } = await admin.from("project_members").delete()
      .eq("project_id", projectId).eq("user_id", userId).select("id").maybeSingle();
    if (error || !member) return json({ error: "MEMBER_REMOVE_FAILED" }, 500);
    await logActivity("member_removed", "Un membre a été retiré du projet", {});
    return json({ success: true });
  }
  return json({ error: "UNKNOWN_ACTION" }, 400);
});
