from flask import Flask, render_template, request, jsonify, redirect, url_for, session
import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import timedelta

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

          <!-- Icon -->
          <div style="text-align:center;margin-bottom:18px;">
            <div style="display:inline-block;width:64px;height:64px;background:#fff0f0;
                        border-radius:16px;line-height:64px;font-size:32px;">👋</div>
          </div>

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

          <!-- Security Warning -->
          <div style="background:#fffbeb;border-left:4px solid #f6ad55;
                      border-radius:8px;padding:13px 16px;margin-bottom:26px;">
            <p style="margin:0;font-size:12px;color:#744210;line-height:1.6;">
              🔒 For your security, please <strong>change your password</strong>
              after your first login.<br/>
              Go to <strong>Profile → Change Password</strong> in the app.
            </p>
          </div>

          <!-- Getting Started Steps -->
          <p style="margin:0 0 12px;font-size:13px;font-weight:700;color:#4a5568;">
            Getting started:
          </p>
          <table cellpadding="0" cellspacing="0" width="100%">
            <tr>
              <td style="padding:6px 0;">
                <span style="display:inline-block;width:22px;height:22px;background:#E8001C;
                             border-radius:50%;color:#fff;font-size:11px;font-weight:700;
                             text-align:center;line-height:22px;margin-right:10px;">1</span>
                <span style="font-size:13px;color:#4a5568;">
                  Open the <strong>Caltex AutoPro</strong> mobile app
                </span>
              </td>
            </tr>
            <tr>
              <td style="padding:6px 0;">
                <span style="display:inline-block;width:22px;height:22px;background:#E8001C;
                             border-radius:50%;color:#fff;font-size:11px;font-weight:700;
                             text-align:center;line-height:22px;margin-right:10px;">2</span>
                <span style="font-size:13px;color:#4a5568;">
                  Sign in with your email and temporary password above
                </span>
              </td>
            </tr>
            <tr>
              <td style="padding:6px 0;">
                <span style="display:inline-block;width:22px;height:22px;background:#E8001C;
                             border-radius:50%;color:#fff;font-size:11px;font-weight:700;
                             text-align:center;line-height:22px;margin-right:10px;">3</span>
                <span style="font-size:13px;color:#4a5568;">
                  Go to <strong>Profile → Change Password</strong> to set your own password
                </span>
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
