import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@^9";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getSecretKey(): string | null {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (raw) {
    try {
      const keys = JSON.parse(raw);
      if (keys.default) return keys.default;
    } catch {
      // Fall through to the legacy variable when the injected JSON is unavailable.
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const secretKey = getSecretKey();
  if (!supabaseUrl || !secretKey) return json({ error: "SERVER_CONFIGURATION_ERROR" }, 500);

  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\\s+/i, "");
  if (!token || token === authorization) return json({ error: "UNAUTHORIZED" }, 401);

  const admin = createClient(supabaseUrl, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  const caller = authData.user;
  if (authError || !caller) return json({ error: "UNAUTHORIZED" }, 401);

  let payload: {
    project_id?: string;
    recipient_user_id?: string;
    subject?: string;
    message?: string;
  };
  try {
    payload = await request.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  const projectId = payload.project_id?.trim();
  const recipientId = payload.recipient_user_id?.trim();
  const subject = payload.subject?.trim();
  const message = payload.message?.trim();
  if (!projectId || !recipientId || !subject || !message) {
    return json({ error: "MISSING_FIELDS" }, 400);
  }
  if (subject.length > 140 || /[\\r\\n]/.test(subject) || message.length > 8000) {
    return json({ error: "INVALID_MESSAGE_LENGTH" }, 400);
  }
  if (recipientId === caller.id) return json({ error: "CANNOT_EMAIL_SELF" }, 400);

  const smtpHost = Deno.env.get("SMTP_HOST");
  const smtpPort = Number(Deno.env.get("SMTP_PORT") ?? "465");
  const smtpUser = Deno.env.get("SMTP_USER");
  const smtpPassword = Deno.env.get("SMTP_PASSWORD");
  const smtpFrom = Deno.env.get("SMTP_FROM");
  const smtpSecure = (Deno.env.get("SMTP_SECURE") ?? "true").toLowerCase() === "true";
  if (!smtpHost || !smtpUser || !smtpPassword || !smtpFrom || !Number.isInteger(smtpPort)) {
    return json({ error: "EMAIL_SERVICE_NOT_CONFIGURED" }, 503);
  }

  const { data: project, error: projectError } = await admin
    .from("projects")
    .select("id, owner_id, name")
    .eq("id", projectId)
    .maybeSingle();
  if (projectError || !project) return json({ error: "PROJECT_NOT_FOUND" }, 404);

  const callerIsOwner = project.owner_id === caller.id;
  const { data: callerMembership } = await admin
    .from("project_members")
    .select("role")
    .eq("project_id", projectId)
    .eq("user_id", caller.id)
    .maybeSingle();
  if (!callerIsOwner && callerMembership?.role !== "editor") {
    return json({ error: "FORBIDDEN" }, 403);
  }

  const recipientIsOwner = project.owner_id === recipientId;
  const { data: recipientMembership } = await admin
    .from("project_members")
    .select("user_id")
    .eq("project_id", projectId)
    .eq("user_id", recipientId)
    .maybeSingle();
  if (!recipientIsOwner && !recipientMembership) {
    return json({ error: "RECIPIENT_NOT_IN_PROJECT" }, 403);
  }

  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  const { count } = await admin
    .from("project_activity")
    .select("id", { count: "exact", head: true })
    .eq("project_id", projectId)
    .eq("actor_id", caller.id)
    .eq("event_type", "project_email_sent")
    .gte("created_at", tenMinutesAgo);
  if ((count ?? 0) >= 5) return json({ error: "RATE_LIMITED" }, 429);

  const { data: recipientData, error: recipientError } =
    await admin.auth.admin.getUserById(recipientId);
  const recipientEmail = recipientData.user?.email;
  if (recipientError || !recipientEmail) return json({ error: "RECIPIENT_EMAIL_NOT_FOUND" }, 404);

  const transport = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpSecure,
    auth: { user: smtpUser, pass: smtpPassword },
  });

  try {
    await transport.sendMail({
      from: smtpFrom,
      to: recipientEmail,
      replyTo: caller.email ?? undefined,
      subject: `Cookidea · ${project.name}: ${subject}`,
      text: `${message}\\n\\n— ${caller.user_metadata?.full_name ?? caller.email ?? "Un membre"}\\nProjet : ${project.name}\\n\\nVous recevez cet e-mail car vous participez à ce projet sur Cookidea.`,
    });
  } catch (error) {
    console.error("Project email delivery failed", error);
    return json({ error: "EMAIL_DELIVERY_FAILED" }, 502);
  } finally {
    transport.close();
  }

  await admin.from("project_activity").insert({
    project_id: projectId,
    actor_id: caller.id,
    event_type: "project_email_sent",
    title: "E-mail envoyé à un membre du projet",
    metadata: { recipient_user_id: recipientId },
  });

  return json({ success: true });
});
