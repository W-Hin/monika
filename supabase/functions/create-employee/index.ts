// Creates a new employee: an auth.users row (login account) + a matching
// profiles row, in one call. This can ONLY run here - never from the
// Flutter app - because creating another user's login account requires
// the service_role key, which must never be shipped in a client app (it
// bypasses every RLS policy).
//
// SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY are
// auto-injected into every Edge Function's environment - no manual secret
// configuration needed.
//
// EMAIL SENDING - sends the welcome email via Gmail's own SMTP server
// (smtp.gmail.com:465, implicit TLS), authenticated as a real Gmail
// account, rather than a third-party email API. This is genuinely more
// experimental than a provider API would be: Supabase Edge Functions
// block outbound ports 25 and 587 (the usual SMTP ports), but 465 is not
// documented as blocked - it should work, but this has not been verified
// against a live deployment. If it times out or fails, the fallback is a
// provider with single-sender email verification (e.g. Brevo, SendGrid)
// instead of a full domain.
//
// One-time setup required (on the Gmail account you want to send FROM):
//   1. Enable 2-Step Verification on that Google account (required for
//      App Passwords to be available at all).
//   2. Google Account -> Security -> 2-Step Verification -> App passwords
//      -> create one (name it anything, e.g. "MONIKA") -> copy the
//      16-character password shown (remove the spaces Google displays it
//      with when you paste it in below).
//   3. Supabase Dashboard -> Edge Functions -> Manage secrets -> add:
//        GMAIL_SENDER_EMAIL = the Gmail address itself
//        GMAIL_APP_PASSWORD = the 16-character app password, no spaces
//
// Deploy: Supabase Dashboard -> Edge Functions -> Create a new function
// named "create-employee" -> paste this ENTIRE file, exactly as-is, as
// its only source file -> Deploy. Deliberately self-contained (no
// imports from a shared file) since the Dashboard's function editor
// doesn't reliably support cross-function-folder imports the way the
// Supabase CLI does.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// --- Gmail SMTP client (raw protocol over Deno.connectTls) ---------------

const GMAIL_SMTP_HOST = 'smtp.gmail.com';
const GMAIL_SMTP_PORT = 465;
const GMAIL_SENDER = Deno.env.get('GMAIL_SENDER_EMAIL');
const GMAIL_APP_PASSWORD = Deno.env.get('GMAIL_APP_PASSWORD');

function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms)),
  ]);
}

async function readSmtpResponse(conn: Deno.TlsConn): Promise<{ code: number; text: string }> {
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const chunk = new Uint8Array(4096);
    const n = await conn.read(chunk);
    if (n === null) break;
    buffer += decoder.decode(chunk.subarray(0, n));
    const lines = buffer.split('\r\n').filter((l) => l.length > 0);
    const last = lines[lines.length - 1];
    if (last && /^\d{3} /.test(last)) break;
  }
  return { code: parseInt(buffer.slice(0, 3), 10) || 0, text: buffer };
}

async function smtpCommand(conn: Deno.TlsConn, command: string): Promise<{ code: number; text: string }> {
  await conn.write(new TextEncoder().encode(command + '\r\n'));
  return await readSmtpResponse(conn);
}

async function sendViaGmail(to: string, subject: string, html: string): Promise<{ ok: boolean; error?: string }> {
  if (!GMAIL_SENDER || !GMAIL_APP_PASSWORD) {
    return { ok: false, error: 'GMAIL_SENDER_EMAIL / GMAIL_APP_PASSWORD is not configured - email not sent' };
  }

  let conn: Deno.TlsConn | null = null;
  try {
    conn = await withTimeout(
      Deno.connectTls({ hostname: GMAIL_SMTP_HOST, port: GMAIL_SMTP_PORT }),
      10000,
      'SMTP connection',
    );

    const greeting = await readSmtpResponse(conn);
    if (greeting.code !== 220) throw new Error(`Unexpected greeting: ${greeting.text}`);

    let res = await smtpCommand(conn, 'EHLO monika.app');
    if (res.code !== 250) throw new Error(`EHLO failed: ${res.text}`);

    res = await smtpCommand(conn, 'AUTH LOGIN');
    if (res.code !== 334) throw new Error(`AUTH LOGIN failed: ${res.text}`);

    res = await smtpCommand(conn, btoa(GMAIL_SENDER));
    if (res.code !== 334) throw new Error(`Username rejected: ${res.text}`);

    res = await smtpCommand(conn, btoa(GMAIL_APP_PASSWORD));
    if (res.code !== 235) throw new Error(`Authentication failed - check GMAIL_APP_PASSWORD: ${res.text}`);

    res = await smtpCommand(conn, `MAIL FROM:<${GMAIL_SENDER}>`);
    if (res.code !== 250) throw new Error(`MAIL FROM failed: ${res.text}`);

    res = await smtpCommand(conn, `RCPT TO:<${to}>`);
    if (res.code !== 250 && res.code !== 251) throw new Error(`RCPT TO failed: ${res.text}`);

    res = await smtpCommand(conn, 'DATA');
    if (res.code !== 354) throw new Error(`DATA failed: ${res.text}`);

    // Dot-stuffing per RFC 5321: a line starting with '.' must be escaped
    // as '..' so it isn't mistaken for the end-of-message marker below.
    const stuffedHtml = html.replace(/^\./gm, '..');
    // Date and Message-ID are standard RFC 5322 headers every real MTA
    // includes - a manually composed message missing them is a common
    // spam-filter signal, separate from whether the SMTP transaction
    // itself succeeds (Gmail accepting the message with a 250 response
    // only means it was handed off, not that the recipient's server
    // won't still flag it as spam).
    const messageId = `<${crypto.randomUUID()}@${GMAIL_SENDER.split('@')[1]}>`;
    const message =
      `From: MONIKA HR <${GMAIL_SENDER}>\r\n` +
      `To: ${to}\r\n` +
      `Subject: ${subject}\r\n` +
      `Date: ${new Date().toUTCString()}\r\n` +
      `Message-ID: ${messageId}\r\n` +
      `MIME-Version: 1.0\r\n` +
      `Content-Type: text/html; charset=UTF-8\r\n` +
      `\r\n` +
      `${stuffedHtml}\r\n.\r\n`;

    await conn.write(new TextEncoder().encode(message));
    res = await readSmtpResponse(conn);
    if (res.code !== 250) throw new Error(`Message not accepted: ${res.text}`);

    await smtpCommand(conn, 'QUIT');
    conn.close();
    return { ok: true };
  } catch (e) {
    try {
      conn?.close();
    } catch (_closeError) {
      // already closed or never opened - nothing to do
    }
    return { ok: false, error: String(e) };
  }
}

// --- Email template --------------------------------------------------------

function emailShell(title: string, bodyHtml: string): string {
  return `
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background-color:#F7F9F8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F7F9F8;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background-color:#FFFFFF;border-radius:16px;overflow:hidden;max-width:480px;width:100%;">
          <tr>
            <td style="background-color:#1DB954;padding:28px 32px;">
              <span style="color:#FFFFFF;font-size:20px;font-weight:800;letter-spacing:1px;">MONIKA</span>
              <div style="color:#E6F9EE;font-size:12px;margin-top:2px;">Intelligent Mobile HR Management</div>
            </td>
          </tr>
          <tr>
            <td style="padding:32px;">
              <h1 style="margin:0 0 16px 0;font-size:18px;color:#15211B;">${title}</h1>
              ${bodyHtml}
            </td>
          </tr>
          <tr>
            <td style="padding:20px 32px;background-color:#F1F4F2;border-top:1px solid #E3E8E5;">
              <p style="margin:0;font-size:11.5px;color:#93A39B;line-height:1.5;">
                This is an automated message from MONIKA HR - please do not reply to this email.<br/>
                For inquiries, contact <a href="mailto:monika.hr@gmail.com" style="color:#169C46;">monika.hr@gmail.com</a>.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function welcomeEmailHtml(name: string, email: string, tempPassword: string, jobTitle: string, departmentName: string, userRole: string): string {
  const roleDescription = userRole === 'hr_admin'
    ? `an <strong style="color:#15211B;">HR Administrator</strong> account (role: <strong style="color:#15211B;">${jobTitle}</strong>, ${departmentName})`
    : `your employee account as <strong style="color:#15211B;">${jobTitle}</strong> in <strong style="color:#15211B;">${departmentName}</strong>`;
  const body = `
    <p style="margin:0 0 16px 0;font-size:14px;color:#5B6B63;line-height:1.6;">
      Hi ${name},
    </p>
    <p style="margin:0 0 16px 0;font-size:14px;color:#5B6B63;line-height:1.6;">
      Welcome to MONIKA! We've created ${roleDescription}. You can now log in to the
      MONIKA app using the credentials below. You'll be asked to set your own password
      the first time you log in.
    </p>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F1F4F2;border-radius:12px;margin:0 0 16px 0;">
      <tr><td style="padding:16px 20px;">
        <p style="margin:0 0 4px 0;font-size:11.5px;color:#93A39B;text-transform:uppercase;letter-spacing:0.5px;">Email</p>
        <p style="margin:0 0 14px 0;font-size:14px;color:#15211B;font-weight:700;">${email}</p>
        <p style="margin:0 0 4px 0;font-size:11.5px;color:#93A39B;text-transform:uppercase;letter-spacing:0.5px;">Temporary Password</p>
        <p style="margin:0;font-size:16px;color:#15211B;font-weight:800;letter-spacing:1px;">${tempPassword}</p>
      </td></tr>
    </table>
    <p style="margin:0;font-size:13px;color:#5B6B63;line-height:1.6;">
      For security, please log in and change your password as soon as possible.
    </p>
  `;
  return emailShell('Welcome to MONIKA', body);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      email,
      password,
      name,
      employeeCode,
      userRole,
      jobTitle,
      departmentName,
      avatarInitials,
      hireDate,
      baseSalary,
    } = await req.json();

    if (!email || !password || !name || !employeeCode || !userRole || !jobTitle || !departmentName || !avatarInitials || !hireDate) {
      return jsonResponse({ error: 'Missing required field' }, 400);
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return jsonResponse({ error: 'Not authenticated' }, 401);
    }

    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user: caller } } = await callerClient.auth.getUser();
    if (!caller) {
      return jsonResponse({ error: 'Not authenticated' }, 401);
    }

    const { data: callerProfile } = await callerClient
      .from('profiles')
      .select('user_role')
      .eq('id', caller.id)
      .single();

    if (callerProfile?.user_role !== 'hr_admin') {
      return jsonResponse({ error: 'Only HR admins can create employee accounts' }, 403);
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: created, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (createError || !created?.user) {
      return jsonResponse({ error: createError?.message ?? 'Could not create the account' }, 400);
    }

    const { data: dept } = await adminClient
      .from('departments')
      .select('id')
      .eq('name', departmentName)
      .single();

    const { error: profileError } = await adminClient.from('profiles').insert({
      id: created.user.id,
      employee_code: employeeCode,
      name,
      email,
      user_role: userRole,
      job_title: jobTitle,
      department_id: dept?.id ?? null,
      avatar_initials: avatarInitials,
      hire_date: hireDate,
      base_salary: baseSalary ?? null,
      must_change_password: true,
    });

    if (profileError) {
      await adminClient.auth.admin.deleteUser(created.user.id);
      return jsonResponse({ error: profileError.message }, 400);
    }

    // Default leave entitlement for the current year - without this the
    // Leave screens have nothing to show until HR manually adjusts it.
    // Best-effort: a failure here shouldn't undo the account creation
    // that already succeeded, migration 0009 can backfill it later if
    // this somehow doesn't go through.
    await adminClient.from('leave_balances').insert({
      user_id: created.user.id,
      year: new Date().getFullYear(),
      annual_total: 14,
      annual_used: 0,
      medical_total: 14,
      medical_used: 0,
      emergency_total: 3,
      emergency_used: 0,
    });

    const emailResult = await sendViaGmail(
      email,
      'Welcome to MONIKA - your account is ready',
      welcomeEmailHtml(name, email, password, jobTitle, departmentName, userRole),
    );

    return jsonResponse({
      success: true,
      userId: created.user.id,
      emailSent: emailResult.ok,
      emailError: emailResult.ok ? undefined : emailResult.error,
    }, 200);
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
