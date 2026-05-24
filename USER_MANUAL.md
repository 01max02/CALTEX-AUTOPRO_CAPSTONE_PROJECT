# Caltex AutoPro — User Manual

## System Overview

Caltex AutoPro is an automotive service management system developed for **JA Noble Enterprise INC** in partnership with Caltex Philippines. The system provides a comprehensive platform for managing vehicle maintenance, inventory, and fleet operations through both a **web application** and a **mobile application (Android/iOS)**.

The system supports three user roles:
- **Admin** — Full system control (inventory, vehicles, maintenance, users, reports, DSS)
- **Staff** — Day-to-day operations (services, inventory receiving, vehicle management)
- **Customer** — Vehicle monitoring and PMS (Preventive Maintenance Schedule) tracking

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Website — Admin Portal](#2-website--admin-portal)
3. [Website — Staff Portal](#3-website--staff-portal)
4. [Website — Customer Portal](#4-website--customer-portal)
5. [Mobile App — General](#5-mobile-app--general)
6. [Mobile App — Admin](#6-mobile-app--admin)
7. [Mobile App — Staff](#7-mobile-app--staff)
8. [Mobile App — Customer](#8-mobile-app--customer)
9. [Notifications & Alerts](#9-notifications--alerts)
10. [Profile & Account Settings](#10-profile--account-settings)
11. [Troubleshooting & FAQ](#11-troubleshooting--faq)

---

## 1. Getting Started

### 1.1 Accessing the Website

Open your browser and navigate to the Caltex AutoPro web application URL. The system supports modern browsers (Chrome, Firefox, Edge, Safari).

### 1.2 Logging In

1. Enter your **email address** and **password**.
2. Click **Sign In**.
3. Alternatively, click **Sign in with Google** to use your Google account.

The system will redirect you to the appropriate dashboard based on your role (Admin, Staff, or Customer).

### 1.3 Creating an Account (Customer Registration)

1. Click **Sign Up** on the login page.
2. Fill in your **Full Name**, **Email**, and **Password**.
3. Confirm your password.
4. Click **Create Account**.
5. Your account will be created and you can log in immediately.

> **Note:** Admin and Staff accounts are created by the system administrator. You will receive a welcome email with your temporary login credentials.

### 1.4 Forgot Password

1. Click **Forgot Password?** on the login page.
2. Enter your registered email address.
3. A password reset link will be sent to your email.
4. Follow the link to set a new password.

### 1.5 First-Time Login (Admin/Staff)

If your account was created by an administrator, you will be required to change your temporary password on first login. Enter a new password and confirm it to proceed.

---

## 2. Website — Admin Portal

### 2.1 Dashboard Overview

The Admin Dashboard provides a high-level summary of operations:

| Stat Card | Description |
|-----------|-------------|
| Total Vehicles | Number of registered vehicles in the fleet |
| Due for PMS | Vehicles due for preventive maintenance |
| Low Stock | Inventory items below minimum stock level |
| Services Today | Maintenance services scheduled for today |
| Total Users | Number of registered users in the system |

The dashboard also includes:
- **Charts** — Services by type, vehicle status distribution, stock in/out trends, top 10 consumed parts
- **Today's Service Schedule** — Quick view of ongoing and pending services
- **Issuances** — Recent material and service issuances
- **Inventory Transactions** — Recent stock movements (IN/OUT)

### 2.2 Inventory — Item Master

The Item Master is the central catalog of all items (materials and services).

**Features:**
- **Add Item** — Create new items with: Item Number, Name, Commodity Group, UOM (Unit of Measure), Cost, Type (Material/Service), Barcode, QR Code
- **Edit Item** — Update item details
- **Delete Item** — Remove items from the catalog
- **Search** — Find items by name, number, or group
- **Barcode/QR Generation** — Auto-generate scannable codes for items
- **Scan Lookup** — Use barcode scanner to find items quickly

### 2.3 Inventory — Stock

Manages current stock levels for all material items.

**Features:**
- **View Stock** — See all items with current stock, min/max levels, and status (OK/Low/Over)
- **Add Stock Item** — Register a new item in the stock inventory
- **Receive Items** — Record incoming stock (increases quantity)
- **Stock Status** — Automatic status calculation:
  - **OK** — Stock is between min and max levels
  - **Low** — Stock is below minimum level
  - **Over** — Stock exceeds maximum level
- **Search & Filter** — Find items by name, number, or group

### 2.4 Vehicle List

Manages the fleet of vehicles.

**Features:**
- **Add Vehicle** — Register with: Plate Number, Description, Vehicle Type, Owner (autocomplete from customers), Odometer, Service Frequency (months)
- **Edit Vehicle** — Update vehicle information
- **View Details** — See full vehicle profile including last service date and next PMS due
- **PMS Tracking** — Automatic calculation of next maintenance date based on service frequency
- **Status Indicators** — Active, PMS Due Soon, Overdue
- **Duplicate Prevention** — System prevents adding vehicles with existing plate numbers

### 2.5 Vehicle Maintenance

Full service transaction management.

**Creating a New Service:**
1. Click **+ New Service**
2. Select or scan the **Plate Number** (vehicle details auto-populate)
3. Enter **Mechanic Name**
4. Select **Service Date**
5. Tag **Vehicle Issues** (preset list + custom issues)
6. Add **Services Rendered** — Select from service catalog, set quantity
7. Add **Materials Used** — Search/scan materials, set quantity (validates against available stock)
8. Review **Total Cost** (auto-calculated)
9. Click **Save**

**Service Status Workflow:**
```
Pending → Ongoing → Completed
```

- **Pending** — Newly created, awaiting admin approval
- **Ongoing** — Approved and in progress (admin sets this)
- **Completed** — Service finished; triggers:
  - Stock deduction for materials used
  - Issuance records created
  - Transaction history updated
  - Vehicle last service date updated

**Additional Features:**
- **Edit Service** — Modify pending/ongoing services
- **Search** — Find services by ID, plate, or mechanic
- **Stock Validation** — Prevents using more materials than available

### 2.6 User Management

Manage all system users.

**Features:**
- **Add User** — Create accounts for admin/staff/customer with auto-generated temporary password
- **Edit User** — Update name, email, role
- **Approve Pending** — Approve customer registrations that require approval
- **Activate/Deactivate** — Toggle user access
- **Delete User** — Remove user accounts (with Firebase Auth cleanup)
- **Welcome Email** — Automatically sends login credentials to new users
- **Search & Filter** — Find users by name, email, or role

### 2.7 Decision Support System (DSS)

Provides data-driven recommendations for inventory and maintenance decisions.

**Stock Replenishment:**
| Column | Description |
|--------|-------------|
| Item | Item name and number |
| Stock Status | Current level vs. min/max |
| Consumption Rate | Average daily usage based on issuance history |
| Days of Stock Left | Estimated days before stockout |
| Recommended Order | Suggested quantity to order |
| Priority | Critical / High / Medium / Low |
| Decision | Actionable recommendation |

**Filter Options:** All, Out of Stock, Low Stock, Adequate

**PMS Scheduling:**
| Column | Description |
|--------|-------------|
| Plate Number | Vehicle identifier |
| Last Service | Date of last maintenance |
| Next PMS Due | Calculated next service date |
| Days Until/Overdue | Countdown or overdue days |
| Priority | Based on urgency |
| Recommendation | Suggested action |

**Filter Options:** All, Overdue, Due Today, Due This Week, Due Soon, Active

### 2.8 Smart Reports (AI)

An AI-powered reporting assistant that queries live system data.

**How to Use:**
1. Navigate to **Smart Reports**
2. Type a question in natural language, e.g.:
   - "What are the top 5 most consumed items this month?"
   - "Show me all vehicles overdue for PMS"
   - "Generate a summary of maintenance costs for March"
3. The AI responds with data-driven answers
4. Export results as **PDF** or **Excel**

### 2.9 Domain Management

Configure system-wide settings such as vehicle types and other domain values used across the application.

---

## 3. Website — Staff Portal

### 3.1 Dashboard

The Staff Dashboard shows:
- **Total Services** — All services assigned to you
- **Ongoing** — Currently active services
- **Completed** — Finished services
- **Low Stock** — Items needing replenishment

**Today's Service Schedule** — Lists services scheduled for today with status indicators.

### 3.2 Inventory

- **View Stock** — Browse all inventory items with stock levels
- **Receive Items** — Record incoming stock deliveries
- **Search** — Find items by name, number, or group
- **Status Indicators** — Visual indicators for Low/OK/Over stock

### 3.3 Maintenance

- **Create Service** — Same workflow as admin (plate lookup, services, materials, issues)
- **View Services** — See all maintenance records
- **Mark as Completed** — Complete ongoing services (triggers stock deduction and issuance creation)
- **Edit Services** — Modify pending/ongoing services
- **Stock Validation** — Prevents over-issuing materials

### 3.4 Vehicles

- **View All Vehicles** — Browse the fleet with search
- **Add Vehicle** — Register new vehicles
- **Edit Vehicle** — Update vehicle information
- **Vehicle Details** — View full profile with PMS information

---

## 4. Website — Customer Portal

### 4.1 Dashboard

The Customer Dashboard displays your vehicles and their status:
- **Total Vehicles** — Number of your registered vehicles
- **Active** — Vehicles in good standing
- **Maintenance** — Vehicles currently being serviced
- **PMS Overdue** — Vehicles past their maintenance due date
- **Due This Week** — Vehicles due for service this week
- **Due Soon** — Vehicles approaching their service date

**Vehicle Cards** — Click any vehicle to view full details including service history.

### 4.2 PMS History

View the complete maintenance history for your vehicles:
- **Service Records** — Date, services performed, materials used, costs
- **Search & Filter** — Find specific service records
- **Total Cost Tracking** — See cumulative maintenance expenses

### 4.3 Smart AI Assistant

A floating chatbot widget that answers questions about your fleet:
- "What's the status of my vehicles?"
- "When is my next PMS due?"
- "Show my maintenance history"
- "Give me a fleet summary"

### 4.4 Book Service

Schedule a maintenance appointment for your vehicle through the booking system.

---

## 5. Mobile App — General

### 5.1 Welcome Screen

On first launch, you'll see the JA Noble / Caltex AutoPro branding with two options:
- **Sign In** — For existing users
- **Create Account** — For new customer registration

### 5.2 Login

1. Enter your **Email** and **Password**
2. Tap **Sign In**
3. Or use **Sign in with Google**

The app redirects to the appropriate dashboard based on your role.

### 5.3 Registration

1. Tap **Create Account**
2. Fill in Full Name, Email, Password, Confirm Password
3. Tap **Register**
4. Log in with your new credentials

### 5.4 Push Notifications

The mobile app uses **OneSignal** for push notifications. You'll receive real-time alerts for:
- Low stock warnings
- PMS due/overdue reminders
- Service status updates
- Admin announcements

---

## 6. Mobile App — Admin

### 6.1 Dashboard

Overview of fleet and operations with stat cards and quick navigation.

### 6.2 Vehicle Maintenance

Full maintenance management:
- **View All Services** — List with search and status filters
- **Approve Services** — Change status from Pending to Ongoing
- **Complete Services** — Mark as completed with automatic stock deduction
- **Create/Edit Services** — Full service form with barcode scanning

### 6.3 User Management

- View and manage all system users
- Approve pending registrations
- Activate/deactivate accounts

### 6.4 Notifications & DSS Alerts

- **Generate DSS Alerts** — Trigger daily stock and PMS analysis
- **View Notifications** — See all system alerts
- **Alert Preferences** — Configure which notifications to receive

---

## 7. Mobile App — Staff

### 7.1 Dashboard

The Staff Dashboard shows:
- **Today's Services** — Count of services scheduled today
- **Ongoing** — Active services count
- **Pending** — Services awaiting approval
- **Low Stock** — Items below minimum level

**Today's Service Schedule** — Tap any service card to view full details and mark as completed.

### 7.2 Bottom Navigation

| Tab | Function |
|-----|----------|
| Dashboard | Main overview (home screen) |
| Inventory | Opens Stock Inventory page |
| 🔴 Scan (center) | Opens barcode/QR scanner |
| Maintenance | Opens Vehicle Maintenance page |
| Vehicle | Opens Vehicle List page |

### 7.3 Barcode Scanner

The center scan button opens the camera for barcode/QR scanning:
1. Point camera at a barcode or QR code
2. System looks up the item in the Item Master
3. Shows item details (name, number, group, UOM, cost, type)
4. If item is in stock, shows current quantity and option to **Receive Stock**
5. If not in stock, shows a notice to contact admin

### 7.4 Inventory

- **View Stock** — All items with stock levels, min/max, and status
- **Search** — Find items by name, number, or group
- **Stat Cards** — Total Items, Low Stock, In Stock counts
- **Item Details** — Tap any item to see full details
- **Receive Stock** — Add incoming quantities to existing items

### 7.5 Maintenance

- **View Services** — All maintenance records with search
- **Create Service** — Full form with:
  - Plate number autocomplete + barcode scan
  - Vehicle details auto-populate
  - Mechanic name (pre-filled with your name)
  - Service date picker
  - Vehicle issues (preset tags + custom)
  - Services rendered (dropdown from service catalog)
  - Materials used (search/scan with stock validation)
  - Auto-calculated total cost
- **Mark as Completed** — Triggers stock deduction and issuance creation
- **Edit Service** — Modify pending/ongoing services
- **Stat Cards** — Total, Ongoing, Completed, Pending counts

### 7.6 Vehicle List

- **View Vehicles** — All fleet vehicles with search
- **Add Vehicle** — Register new vehicles with:
  - Plate number (formatted: AAA-1234)
  - Description
  - Vehicle type (dropdown from domain settings)
  - Owner (autocomplete from customer list)
  - Odometer
  - Service frequency
- **Edit Vehicle** — Update vehicle information
- **Vehicle Details** — Full profile with PMS information
- **Stat Cards** — Total, Cars, Trucks counts

---

## 8. Mobile App — Customer

### 8.1 Dashboard

View your vehicles with PMS status indicators:
- **Active** — Vehicle is in good standing
- **PMS Due Soon** — Approaching maintenance date
- **Overdue** — Past maintenance due date

### 8.2 Notifications

Receive alerts about your vehicles:
- PMS overdue reminders
- PMS due soon notifications
- Service completion updates

---

## 9. Notifications & Alerts

### 9.1 In-App Notifications

All roles receive notifications within the app:
- **Bell Icon** — Shows unread count badge
- **Notification List** — View all notifications with timestamps
- **Mark as Read** — Tap to mark individual notifications as read

### 9.2 Push Notifications (Mobile)

Real-time push notifications via OneSignal for:
- Stock alerts (admin)
- PMS reminders (admin + customer)
- Service status changes (all roles)

### 9.3 Alert Preferences

Configure which alerts you receive:

| Preference | Available To | Description |
|------------|-------------|-------------|
| Low Stock | Admin | When items fall below minimum level |
| PMS Overdue | Admin, Customer | When vehicles are past due |
| PMS Due This Week | Admin, Customer | Weekly PMS reminders |
| PMS Due Soon | Admin, Customer | Upcoming maintenance alerts |
| Service Updates | Staff, Customer | Status changes on services |

### 9.4 DSS Alert Generation

Admins can trigger daily Decision Support System alerts that analyze:
- **Stock levels** — Identifies out-of-stock and low-stock items with recommended order quantities
- **PMS schedules** — Identifies overdue and upcoming maintenance with priority levels

Alerts are generated once per day to prevent duplicates.

---

## 10. Profile & Account Settings

### 10.1 Viewing Your Profile

1. Click/tap your **avatar** or navigate to **Profile**
2. View your account information: Name, Email, Role

### 10.2 Editing Profile

1. Click **Edit Profile**
2. Update your **Name** or **Profile Photo**
3. Save changes

### 10.3 Changing Password

1. Navigate to **Change Password**
2. Enter your **Current Password**
3. Enter and confirm your **New Password**
4. Click **Update Password**

### 10.4 Notification Settings

1. Go to **Profile → Notifications**
2. Toggle alert preferences on/off
3. Changes take effect immediately

---

## 11. Troubleshooting & FAQ

### Q: I can't log in. What should I do?
- Verify your email and password are correct
- Check if your account is active (contact admin if deactivated)
- Use "Forgot Password" to reset your credentials
- If you're a new staff/admin user, check your email for temporary credentials

### Q: I'm not receiving push notifications on mobile.
- Ensure notifications are enabled in your phone settings
- Check that alert preferences are turned on in the app
- Make sure you have an active internet connection

### Q: The barcode scanner isn't working.
- Grant camera permission when prompted
- Ensure adequate lighting
- Hold the device steady and align the barcode within the frame
- Clean the camera lens

### Q: I can't add materials to a service — it says "Insufficient stock."
- The system validates material quantities against available stock
- Check current stock levels in the Inventory section
- Receive stock first if items need replenishment
- Contact admin if stock records seem incorrect

### Q: A vehicle shows "PMS Overdue" but it was recently serviced.
- Ensure the service was marked as **Completed** (not just Ongoing)
- Verify the vehicle's **Service Frequency** is set correctly
- Check that the **Last Service Date** was updated after completion

### Q: How do I approve a pending service? (Admin)
- Open the service details
- Change status from **Pending** to **Ongoing**
- The staff member can then proceed with the service

### Q: How do I export reports?
- Use the **Smart Reports** AI feature
- Ask for the data you need
- Click **Export as PDF** or **Export as Excel**
- Alternatively, use the **Print** button on DSS pages

---

## System Requirements

### Website
- Modern web browser (Chrome 90+, Firefox 88+, Edge 90+, Safari 14+)
- Stable internet connection
- JavaScript enabled

### Mobile App
- Android 6.0+ or iOS 13.0+
- Camera access (for barcode scanning)
- Internet connection
- Push notification permissions (recommended)

---

## Contact & Support

For technical support or account issues, contact the system administrator at:
- **Email:** caltexautopro2026@gmail.com

---

*© 2026 JA Noble Enterprise INC. All rights reserved.*
