from flask import Flask, render_template, request, jsonify, redirect, url_for, session
import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import timedelta

# ── Firebase Admin SDK ───────────────────────────────────────────────────────
# Requires: pip install firebase-admin
# Place your service account JSON at the path below, or set
# GOOGLE_APPLICATION_CREDENTIALS env var to point to it.
import firebase_admin
from firebase_admin import credentials, auth as fb_auth

_SERVICE_ACCOUNT_PATH = os.environ.get(
    'FIREBASE_SERVICE_ACCOUNT',
    os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json')
)

if not firebase_admin._apps:
    try:
        cred = credentials.Certificate(_SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
        print('✅ Firebase Admin SDK initialized')
    except Exception as _e:
        print(f'⚠️  Firebase Admin SDK not initialized: {_e}')
        print('   Place serviceAccountKey.json next to caltexautopro.py to enable Auth deletion.')

app = Flask(__name__)
app.secret_key = 'your-secret-key-change-this-in-production'
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=7)

# ── Email config (Gmail SMTP) ────────────────────────────────
# Set SMTP_APP_PASSWORD as an environment variable, or paste the
# 16-character Gmail App Password directly below.
# To generate: Gmail → Settings → Security → 2-Step Verification → App Passwords
SMTP_HOST     = 'smtp.gmail.com'
SMTP_PORT     = 587
SMTP_USER     = 'caltexautopro2026@gmail.com'
SMTP_PASSWORD = os.environ.get('SMTP_APP_PASSWORD', 'kvvp uflz pbdc rcyv')
SMTP_FROM     = 'Caltex AutoPro <caltexautopro2026@gmail.com>'

@app.route('/api/send-push-notification', methods=['POST'])
def send_push_notification():
    """Send OneSignal push notification to specific subscription IDs."""
    import urllib.request, json as _json
    data             = request.get_json(silent=True) or {}
    subscription_ids = data.get('subscription_ids', [])
    title            = data.get('title', 'AutoPro Notification')
    message          = data.get('message', '')
    notif_type       = data.get('type', 'info')

    if not subscription_ids or not message:
        return jsonify({'ok': False, 'error': 'Missing subscription_ids or message'}), 400

    ONESIGNAL_APP_ID  = 'c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea'
    ONESIGNAL_API_KEY = 'os_v7_app_yt4cvr2f1hkhvh5ldu4k637i51snjeyuythen3fd61ae1yhnprpy6kbxvn9kjd1pqdhygsqmlrouas4kfuydft32nkgj5flbra3oo5q'

    payload = {
        'app_id':                   ONESIGNAL_APP_ID,
        'include_subscription_ids': subscription_ids,
        'headings':                 {'en': title},
        'contents':                 {'en': message},
        'data':                     {'type': notif_type},
    }
    req = urllib.request.Request(
        'https://onesignal.com/api/v1/notifications',
        data=_json.dumps(payload).encode('utf-8'),
        headers={
            'Authorization': f'Basic {ONESIGNAL_API_KEY}',
            'Content-Type':  'application/json; charset=utf-8',
        },
        method='POST'
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode('utf-8')
            print(f'✅ OneSignal push sent → {resp.status}: {body}')
            return jsonify({'ok': True, 'status': resp.status})
    except Exception as e:
        print(f'❌ OneSignal push error: {e}')
        return jsonify({'ok': False, 'error': str(e)}), 500


@app.route('/api/delete-user', methods=['POST'])
def delete_user():
    """Delete a Firebase Auth user by UID. Firestore doc is deleted client-side."""
    data = request.get_json(silent=True) or {}
    uid  = data.get('uid', '').strip()

    if not uid:
        return jsonify({'ok': False, 'error': 'Missing uid'}), 400

    if not firebase_admin._apps:
        return jsonify({'ok': False, 'error': 'Firebase Admin SDK not initialized. Add serviceAccountKey.json.'}), 503

    try:
        fb_auth.delete_user(uid)
        print(f'✅ Deleted Auth user: {uid}')
        return jsonify({'ok': True})
    except fb_auth.UserNotFoundError:
        # Already deleted — treat as success
        print(f'ℹ️  Auth user not found (already deleted?): {uid}')
        return jsonify({'ok': True})
    except Exception as e:
        print(f'❌ delete_user error: {e}')
        return jsonify({'ok': False, 'error': str(e)}), 500


@app.route('/api/send-approval-email', methods=['POST'])
def send_approval_email():
    data     = request.get_json(silent=True) or {}
    to_email = data.get('to_email', '').strip()
    to_name  = data.get('to_name', 'User').strip()

    if not to_email:
        print('❌ send-approval-email: missing to_email')
        return jsonify({'ok': False, 'error': 'Missing email'}), 400

    print(f'📧 Sending approval email → {to_email} ({to_name})')

    subject   = 'Your Caltex AutoPro Account Has Been Approved!'
    html_body = f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"/></head>
<body style="margin:0;padding:0;background:#f0f2f5;font-family:'Segoe UI',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f2f5;padding:40px 0;">
  <tr><td align="center">
    <table width="520" cellpadding="0" cellspacing="0"
           style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.10);">
      <tr>
        <td style="background:#E8001C;padding:30px 40px 0;text-align:center;">
          <div style="font-size:13px;font-weight:700;letter-spacing:4px;color:rgba(255,255,255,.8);margin-bottom:6px;">CALTEX</div>
          <div style="font-size:22px;font-weight:800;color:#fff;letter-spacing:2px;">AutoPro</div>
          <div style="background:#fff;border-radius:24px 24px 0 0;height:22px;margin-top:20px;"></div>
        </td>
      </tr>
      <tr>
        <td style="padding:8px 40px 40px;">
          <h1 style="margin:0 0 8px;text-align:center;font-size:22px;font-weight:800;color:#1a202c;">Account Approved!</h1>
          <p style="margin:0 0 26px;text-align:center;font-size:13px;color:#718096;line-height:1.6;">
            Hi <strong>{to_name}</strong>, great news!<br/>
            Your Caltex AutoPro account has been approved by the administrator.
          </p>
          <div style="background:#f0fff4;border:1px solid #9ae6b4;border-radius:12px;padding:20px 24px;margin-bottom:26px;text-align:center;">
            <p style="margin:0;font-size:15px;font-weight:700;color:#276749;">You're all set!</p>
            <p style="margin:6px 0 0;font-size:13px;color:#2f855a;">
              Your account <strong>{to_email}</strong> is now active.<br/>
              You can sign in to the AutoPro app right now.
            </p>
          </div>
          <p style="margin:0 0 10px;font-size:13px;font-weight:700;color:#4a5568;">Getting started:</p>
          <table cellpadding="0" cellspacing="0" width="100%">
            <tr><td style="padding:5px 0;">
              <span style="display:inline-block;width:22px;height:22px;background:#E8001C;border-radius:50%;color:#fff;font-size:11px;font-weight:700;text-align:center;line-height:22px;margin-right:10px;">1</span>
              <span style="font-size:13px;color:#4a5568;">Open the <strong>AutoPro</strong> mobile app</span>
            </td></tr>
            <tr><td style="padding:5px 0;">
              <span style="display:inline-block;width:22px;height:22px;background:#E8001C;border-radius:50%;color:#fff;font-size:11px;font-weight:700;text-align:center;line-height:22px;margin-right:10px;">2</span>
              <span style="font-size:13px;color:#4a5568;">Sign in with your registered email and password</span>
            </td></tr>
            <tr><td style="padding:5px 0;">
              <span style="display:inline-block;width:22px;height:22px;background:#E8001C;border-radius:50%;color:#fff;font-size:11px;font-weight:700;text-align:center;line-height:22px;margin-right:10px;">3</span>
              <span style="font-size:13px;color:#4a5568;">Explore your dashboard and manage your vehicles</span>
            </td></tr>
          </table>
          <hr style="border:none;border-top:1px solid #e2e8f0;margin:26px 0;"/>
          <p style="margin:0;font-size:12px;color:#a0aec0;text-align:center;line-height:1.6;">
            Need help? Contact us at <a href="mailto:caltexautopro2026@gmail.com" style="color:#E8001C;">caltexautopro2026@gmail.com</a>
          </p>
        </td>
      </tr>
      <tr>
        <td style="background:#f7f8fa;padding:18px 40px;text-align:center;border-top:1px solid #e2e8f0;">
          <p style="margin:0;font-size:11px;color:#a0aec0;line-height:1.6;">
            &copy; 2025 Caltex AutoPro &middot; JA Noble Enterprise INC<br/>
            This is an automated message &mdash; please do not reply.
          </p>
        </td>
      </tr>
    </table>
  </td></tr>
</table>
</body>
</html>"""

    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From']    = SMTP_FROM
        msg['To']      = to_email
        msg.attach(MIMEText(html_body, 'html'))
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(SMTP_USER, to_email, msg.as_string())
        print(f'✅ Approval email delivered → {to_email}')
        return jsonify({'ok': True})
    except smtplib.SMTPAuthenticationError:
        print(f'❌ SMTP auth failed for approval email → {to_email}')
        return jsonify({'ok': False, 'error': 'SMTP auth failed'}), 500
    except Exception as e:
        print(f'❌ Approval email error → {to_email}: {e}')
        return jsonify({'ok': False, 'error': str(e)}), 500


@app.route('/api/send-welcome-email', methods=['POST'])
def send_welcome_email():
    data = request.get_json(silent=True) or {}
    to_email      = data.get('to_email', '').strip()
    to_name       = data.get('to_name', '').strip()
    temp_password = data.get('temp_password', '').strip()
    role          = data.get('role', '').strip()

    if not to_email or not temp_password:
        return jsonify({'ok': False, 'error': 'Missing required fields'}), 400

    subject = 'Welcome to Caltex AutoPro – Your Login Credentials'
    html_body = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>AutoPro — Welcome to Your Account</title>
</head>
<body style="margin:0;padding:0;background:#f0f2f5;font-family:'Segoe UI',Arial,sans-serif;">

<table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f2f5;padding:40px 0;">
  <tr><td align="center">

    <table width="520" cellpadding="0" cellspacing="0"
           style="background:#fff;border-radius:16px;overflow:hidden;
                  box-shadow:0 4px 24px rgba(0,0,0,.10);">

      <!-- ── Red Header ── -->
      <tr>
        <td style="background:#E8001C;padding:30px 40px 0;text-align:center;">
          <div style="font-size:13px;font-weight:700;letter-spacing:4px;
                      color:rgba(255,255,255,.8);margin-bottom:6px;">CALTEX</div>
          <div style="font-size:22px;font-weight:800;color:#fff;letter-spacing:2px;">AutoPro</div>
          <div style="background:#fff;border-radius:24px 24px 0 0;height:22px;margin-top:20px;"></div>
        </td>
      </tr>

      <!-- ── Body ── -->
      <tr>
        <td style="padding:8px 40px 40px;">

          <!-- Title -->
          <h1 style="margin:0 0 8px;text-align:center;font-size:22px;
                     font-weight:800;color:#1a202c;">Welcome to Caltex AutoPro!</h1>
          <p style="margin:0 0 26px;text-align:center;font-size:13px;
                    color:#718096;line-height:1.6;">
            Hi <strong>{to_name}</strong>, your account has been created.<br/>
            Here are your login credentials:
          </p>

          <!-- Credentials Box -->
          <div style="background:#f7f8fa;border:1px solid #e2e8f0;border-radius:12px;
                      padding:20px 24px;margin-bottom:26px;">
            <table cellpadding="0" cellspacing="0" width="100%">
              <tr>
                <td style="padding:8px 0;font-size:12px;color:#718096;
                           font-weight:700;text-transform:uppercase;width:130px;">
                  Email
                </td>
                <td style="padding:8px 0;font-size:13px;font-weight:600;color:#1a202c;">
                  {to_email}
                </td>
              </tr>
              <tr style="border-top:1px solid #e2e8f0;">
                <td style="padding:8px 0;font-size:12px;color:#718096;
                           font-weight:700;text-transform:uppercase;">
                  Temp Password
                </td>
                <td style="padding:8px 0;">
                  <span style="background:#E8001C;color:#fff;font-size:14px;
                               font-weight:700;padding:5px 14px;border-radius:6px;
                               letter-spacing:2px;">
                    {temp_password}
                  </span>
                </td>
              </tr>
              <tr style="border-top:1px solid #e2e8f0;">
                <td style="padding:8px 0;font-size:12px;color:#718096;
                           font-weight:700;text-transform:uppercase;">
                  Role
                </td>
                <td style="padding:8px 0;font-size:13px;font-weight:600;color:#1a202c;">
                  {role.capitalize()}
                </td>
              </tr>
            </table>
          </div>

          <!-- What's Next -->
          <table cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:26px;">
            <tr>
              <td style="padding:0 0 12px;">
                <div style="font-size:13px;font-weight:700;color:#1a202c;">What happens next?</div>
              </td>
            </tr>
            <tr>
              <td>
                <table cellpadding="0" cellspacing="0" width="100%">
                  <tr>
                    <td style="width:40px;vertical-align:top;padding:0 12px 14px 0;">
                      <div style="width:36px;height:36px;background:#fff0f0;border-radius:10px;
                                  text-align:center;line-height:36px;font-size:18px;">📱</div>
                    </td>
                    <td style="vertical-align:top;padding-bottom:14px;">
                      <div style="font-size:13px;font-weight:700;color:#1a202c;margin-bottom:2px;">Open the app</div>
                      <div style="font-size:12px;color:#718096;line-height:1.5;">Download or open the <strong>Caltex AutoPro</strong> mobile app on your device.</div>
                    </td>
                  </tr>
                  <tr>
                    <td style="width:40px;vertical-align:top;padding:0 12px 14px 0;">
                      <div style="width:36px;height:36px;background:#fff0f0;border-radius:10px;
                                  text-align:center;line-height:36px;font-size:18px;">🔑</div>
                    </td>
                    <td style="vertical-align:top;padding-bottom:14px;">
                      <div style="font-size:13px;font-weight:700;color:#1a202c;margin-bottom:2px;">Sign in with your credentials</div>
                      <div style="font-size:12px;color:#718096;line-height:1.5;">Use the email and temporary password above to log in for the first time.</div>
                    </td>
                  </tr>
                  <tr>
                    <td style="width:40px;vertical-align:top;padding:0 12px 0 0;">
                      <div style="width:36px;height:36px;background:#fff0f0;border-radius:10px;
                                  text-align:center;line-height:36px;font-size:18px;">🔒</div>
                    </td>
                    <td style="vertical-align:top;">
                      <div style="font-size:13px;font-weight:700;color:#1a202c;margin-bottom:2px;">Set your own password</div>
                      <div style="font-size:12px;color:#718096;line-height:1.5;">You'll be prompted to change your password immediately after your first login.</div>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>

          <hr style="border:none;border-top:1px solid #e2e8f0;margin:26px 0;"/>

          <p style="margin:0;font-size:12px;color:#a0aec0;text-align:center;line-height:1.6;">
            Need help? Contact us at
            <a href="mailto:caltexautopro2026@gmail.com"
               style="color:#E8001C;">caltexautopro2026@gmail.com</a>
          </p>

        </td>
      </tr>

    </table>

  </td></tr>
</table>

</body>
</html>"""

    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From']    = SMTP_FROM
        msg['To']      = to_email
        msg.attach(MIMEText(html_body, 'html'))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(SMTP_USER, to_email, msg.as_string())

        return jsonify({'ok': True})
    except smtplib.SMTPAuthenticationError:
        print('SMTP Authentication failed - check email credentials')
        return jsonify({'ok': False, 'error': 'Email service authentication failed. Please contact administrator.'}), 500
    except smtplib.SMTPException as e:
        print(f'SMTP error: {e}')
        return jsonify({'ok': False, 'error': 'Failed to send email. Please try again later.'}), 500
    except Exception as e:
        print(f'Email error: {e}')
        return jsonify({'ok': False, 'error': 'An error occurred while sending email.'}), 500

# ── Landing / Home ──────────────────────────────────────────
@app.route('/')
@app.route('/index.html')
def index():
    return render_template('index.html')

# ── Auth ────────────────────────────────────────────────────
@app.route('/login.html')
def login():
    return render_template('login.html')

@app.route('/api/redirect-to-dashboard', methods=['POST'])
def redirect_to_dashboard():
    """
    Endpoint for login.html to redirect to the appropriate dashboard.
    Expects: { role: 'admin' | 'staff' | 'customer' }
    """
    data = request.get_json(silent=True) or {}
    role = data.get('role', 'customer').lower()
    
    # Map role to dashboard
    dashboard_map = {
        'admin': '/admin_dashboard.html',
        'staff': '/staff_dashboard.html',
        'customer': '/customer_dashboard.html',
    }
    
    target = dashboard_map.get(role, '/customer_dashboard.html')
    print(f'Redirecting user with role "{role}" to {target}')
    
    return jsonify({'ok': True, 'redirect': target})

@app.route('/forgot_password.html')
def forgot_password():
    return render_template('forgot_password.html')

@app.route('/regsiter.html')
def register():
    return render_template('regsiter.html')

# ── Admin ────────────────────────────────────────────────────
@app.route('/admin_dashboard.html')
def admin_dashboard():
    return render_template('admin_dashboard.html')

@app.route('/admin_inventory_itemaster.html')
def admin_inventory_items():
    return render_template('admin_inventory_itemaster.html')

@app.route('/admin_inventory_stock.html')
def admin_inventory_stock():
    return render_template('admin_inventory_stock.html')

@app.route('/admin_vehicle_list.html')
def admin_vehicles():
    return render_template('admin_vehicle_list.html')

@app.route('/admin_vehicle_maintenance.html')
def admin_vehicle_maintenance():
    return render_template('admin_vehicle_maintenance.html')

@app.route('/admin_users.html')
def admin_users():
    return render_template('admin_users.html')

@app.route('/admin_dss.html')
def admin_dss():
    return render_template('admin_dss.html')

@app.route('/admin_smart_reports.html')
def admin_smart_reports():
    return render_template('admin_smart_reports.html')

@app.route('/admin_domain_management.html')
def admin_domains():
    return render_template('admin_domain_management.html')

@app.route('/admin_sidebar.html')
def admin_sidebar():
    return render_template('admin_sidebar.html')

@app.route('/admin_header.html')
def admin_header():
    return render_template('admin_header.html')

@app.route('/notifications.html')
def notifications():
    return render_template('notifications.html')

@app.route('/profile.html')
def profile():
    return render_template('profile.html')

@app.route('/change_password.html')
def change_password():
    return render_template('change_password.html')

@app.route('/help_support.html')
def help_support():
    return render_template('help_support.html')

# ── Staff ────────────────────────────────────────────────────
@app.route('/staff_dashboard.html')
def staff_dashboard():
    return render_template('staff_dashboard.html')

@app.route('/staff_inventory.html')
def staff_inventory():
    return render_template('staff_inventory.html')

@app.route('/staff_maintenance.html')
def staff_maintenance():
    return render_template('staff_maintenance.html')

@app.route('/staff_vehicle_list.html')
def staff_vehicle_list():
    return render_template('staff_vehicle_list.html')

# ── Customer ─────────────────────────────────────────────────
@app.route('/customer_dashboard.html')
def customer_dashboard():
    return render_template('customer_dashboard.html')

@app.route('/customer_pms_history.html')
def customer_pms_history():
    return render_template('customer_pms_history.html')

@app.route('/pms_history_details.html')
def pms_history_details():
    return render_template('pms_history_details.html')

@app.route('/customer_smart_ai.html')
def customer_smart_ai():
    return render_template('customer_smart_ai.html')

@app.route('/customer_header.html')
def customer_header():
    return render_template('customer_header.html')

# ── Run ──────────────────────────────────────────────────────
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)


# ── Setup / Admin Tools ──────────────────────────────────────
@app.route('/setup_notifications.html')
def setup_notifications():
    """Setup page to create notifications collection in Firestore"""
    return render_template('setup_notifications.html')
