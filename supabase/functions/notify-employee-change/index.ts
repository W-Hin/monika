// Emails an employee when HR changes their job title, department, and/or
// salary. Does NOT perform the actual profiles update - that already
// happened via the normal RLS-respecting Flutter client before this is
// called (updating your own team's records is something HR's own session
// is already allowed to do; no service_role needed for that part). This
// function exists purely because sending email needs the Gmail App
// Password secret, which - like service_role - must never be in the
// Flutter app.
//
// EMAIL SENDING - see create-employee/index.ts for the full explanation
// of the Gmail-SMTP-over-port-465 approach and its setup steps
// (GMAIL_SENDER_EMAIL / GMAIL_APP_PASSWORD secrets). Same experimental
// caveat applies here: not verified against a live deployment yet.
//
// Business-logic assumptions made here (flagged for review, not something
// there was firm HR-process guidance for):
//   - The database change is already live by the time this email sends -
//     HR sees the new title/department/salary immediately in the app.
//   - The email frames the change as "officially effective" on the 1st of
//     next month (computed by the Flutter caller, passed in as
//     effectiveDate) - common practice for administrative/payroll
//     changes to be announced ahead of the pay-period boundary, even
//     though the system of record already reflects it.
//   - "Promotion" / "demotion" is never asserted from the job title text
//     alone (there's no seniority ranking to compare titles against, so
//     guessing would risk mislabeling a lateral move). A salary increase
//     IS unambiguous, so that gets a warmer, explicit note; a salary
//     decrease is stated plainly and neutrally; title/department changes
//     are just reported as fact, old -> new, either way.
//
// Deploy: Supabase Dashboard -> Edge Functions -> new function named
// "notify-employee-change" -> paste this ENTIRE file, exactly as-is, as
// its only source file -> Deploy. Deliberately self-contained (no shared
// imports) since the Dashboard's function editor doesn't reliably support
// cross-function-folder imports the way the Supabase CLI does.

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

    const stuffedHtml = html.replace(/^\./gm, '..');
    const message =
      `From: MONIKA HR <${GMAIL_SENDER}>\r\n` +
      `To: ${to}\r\n` +
      `Subject: ${subject}\r\n` +
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

function formatDate(iso: string): string {
  const d = new Date(iso);
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return `${d.getUTCDate()} ${months[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

function formatRM(amount: number): string {
  return `RM ${amount.toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function changeEmailHtml(
  name: string,
  oldJobTitle: string,
  newJobTitle: string,
  oldDepartment: string,
  newDepartment: string,
  oldSalary: number | null,
  newSalary: number | null,
  effectiveDate: string,
): string {
  const rows: string[] = [];

  if (oldJobTitle !== newJobTitle) {
    rows.push(`
      <tr>
        <td style="padding:10px 0;border-bottom:1px solid #E3E8E5;font-size:13px;color:#5B6B63;">Job Title</td>
        <td style="padding:10px 0;border-bottom:1px solid #E3E8E5;font-size:13px;color:#15211B;text-align:right;">
          <span style="color:#93A39B;text-decoration:line-through;">${oldJobTitle}</span> &rarr; <strong>${newJobTitle}</strong>
        </td>
      </tr>`);
  }

  if (oldDepartment !== newDepartment) {
    rows.push(`
      <tr>
        <td style="padding:10px 0;border-bottom:1px solid #E3E8E5;font-size:13px;color:#5B6B63;">Department</td>
        <td style="padding:10px 0;border-bottom:1px solid #E3E8E5;font-size:13px;color:#15211B;text-align:right;">
          <span style="color:#93A39B;text-decoration:line-through;">${oldDepartment}</span> &rarr; <strong>${newDepartment}</strong>
        </td>
      </tr>`);
  }

  let salaryNote = '';
  if (newSalary != null && oldSalary !== newSalary) {
    rows.push(`
      <tr>
        <td style="padding:10px 0;font-size:13px;color:#5B6B63;">Basic Monthly Salary</td>
        <td style="padding:10px 0;font-size:13px;color:#15211B;text-align:right;">
          ${oldSalary != null ? `<span style="color:#93A39B;text-decoration:line-through;">${formatRM(oldSalary)}</span> &rarr; ` : ''}<strong>${formatRM(newSalary)}</strong>
        </td>
      </tr>`);

    if (oldSalary != null && newSalary > oldSalary) {
      salaryNote = `<p style="margin:16px 0 0 0;font-size:13px;color:#169C46;line-height:1.6;">
        This includes a salary increase - congratulations, and thank you for your continued contribution.
      </p>`;
    }
  }

  const body = `
    <p style="margin:0 0 16px 0;font-size:14px;color:#5B6B63;line-height:1.6;">
      Hi ${name},
    </p>
    <p style="margin:0 0 16px 0;font-size:14px;color:#5B6B63;line-height:1.6;">
      Your employment details have been updated by HR. This change is officially
      effective <strong style="color:#15211B;">${formatDate(effectiveDate)}</strong>.
    </p>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 8px 0;">
      ${rows.join('')}
    </table>
    ${salaryNote}
    <p style="margin:20px 0 0 0;font-size:13px;color:#5B6B63;line-height:1.6;">
      If you have any questions about this change, please contact HR.
    </p>
  `;
  return emailShell('Your Employment Details Have Been Updated', body);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      email,
      name,
      oldJobTitle,
      newJobTitle,
      oldDepartment,
      newDepartment,
      oldSalary,
      newSalary,
      effectiveDate,
    } = await req.json();

    if (!email || !name || !oldJobTitle || !newJobTitle || !oldDepartment || !newDepartment || !effectiveDate) {
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
      return jsonResponse({ error: 'Only HR admins can send this notification' }, 403);
    }

    const result = await sendViaGmail(
      email,
      'Your Employment Details Have Been Updated',
      changeEmailHtml(
        name,
        oldJobTitle,
        newJobTitle,
        oldDepartment,
        newDepartment,
        oldSalary ?? null,
        newSalary ?? null,
        effectiveDate,
      ),
    );

    return jsonResponse({ success: result.ok, emailError: result.ok ? undefined : result.error }, 200);
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
