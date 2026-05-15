# SYSTEM TECHNICAL SPECIFICATION

---

## 1. Project Overview

### Table 1.1 – Project Team Details

| Field | Details |
|---|---|
| **Project Title** | Caltex AutoPro – Vehicle Maintenance and Inventory Management System |
| **Project Type** | Web and Mobile Application |
| **Duration** | April 2026 – November 2026 |
| **Development Approach** | Agile (Iterative Development) |
| **Project Leader** | |
| **Developers** | TOLENTINO, RONDILLA, VILLAFRANCE, PEILAGO, MIRANDA |
| **UI/UX Designer** | |
| **Adviser** | |
| **System Expert** | |

---

### Table 1.2 – Project Details

| Field | Details |
|---|---|
| **Brief Description** | Caltex AutoPro is a web- and mobile-based platform developed for JA Noble Enterprise Inc. to efficiently monitor vehicle maintenance schedules, manage spare parts inventory, track repair histories, and generate reports in real time. The system automates maintenance reminders, monitors inventory stock levels, and centralizes service documentation to improve operational efficiency, reduce manual errors, and support data-driven decision-making. The web portal serves Administrators and Staff, while the mobile application (Flutter/Android) serves Customers and Staff for on-the-go access. |
| **Target Users / Roles** | Customers – View their vehicle's PMS history, receive maintenance reminders, and interact with the Smart AI assistant via the mobile app. Staff – Manage vehicle lists, log maintenance records, and monitor inventory through both the web portal and mobile app. Administrators – Full system access including user management, inventory control, smart reports, DSS analytics, and domain configuration via the web portal. |
| **System Objectives** | • Apply Agile development in building a real-world vehicle maintenance and inventory system. • Automate vehicle maintenance scheduling to ensure timely Preventive Maintenance Service (PMS). • Improve inventory control by monitoring stock levels and triggering replenishment decisions. • Enhance operational efficiency through real-time data tracking and management. • Reduce vehicle downtime by ensuring availability of required parts and services. • Support decision-making using accurate reports and system-generated DSS recommendations. • Streamline maintenance and inventory processes through a centralized platform accessible via web and mobile. • Provide customers with transparent access to their vehicle service history and AI-powered support. |
| **Related Policies / Standards** | • Data Privacy Act of 2012 (RA 10173) • ISO/IEC 25010 (Software Quality Standards) • WCAG 2.1 (Accessibility Guidelines) • ISO 9001:2015 (Quality Management System) • ISO 27001 (Information Security Management System) • ITIL (Information Technology Infrastructure Library) |

---

## 2. Project Gantt Chart

### Table 2.1 – Gantt Chart April–November 2026

| Task | Owner | Start | End | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | % Progress |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Planning | VILLAFRANCE | Apr 15 | May 10 | ■ | ■ | | | | | | | 80% |
| Requirements | TOLENTINO | May 11 | Jun 10 | | ■ | ■ | | | | | | 70% |
| Design | RONDILLA | Jun 11 | Jul 10 | | | ■ | ■ | | | | | 60% |
| Development | TOLENTINO | Jul 11 | Sep 15 | | | | ■ | ■ | ■ | | | 50% |
| Testing | PEILAGO | Sep 16 | Oct 20 | | | | | | ■ | ■ | | 30% |
| Deployment | MIRANDA | Oct 21 | Nov 30 | | | | | | | ■ | ■ | 10% |

---

## 3. Software Requirements Specification

### 3.1 Business Requirements and User Requirements

Business requirements describe what the organization (JA Noble Enterprise Inc.) needs from the system. The main business need is to improve vehicle fleet management and inventory control through a single, centralized platform where maintenance can be scheduled, monitored, and documented. The following table presents the organizational needs and user-level requirements per role.

#### Table 3.1 – Business Requirements and User Requirements List

| Section | Sub-Section | Details |
|---|---|---|
| **Business Requirements** | Overall | JA Noble Enterprise Inc. needs to reduce vehicle downtime and manual errors by centralizing maintenance scheduling, inventory tracking, and service documentation in one platform accessible via web and mobile. |
| **User Requirements** | Customers | Easy access to vehicle PMS history, maintenance reminders, and an AI-powered assistant through the mobile app. |
| | Staff | Real-time dashboard to view, log, and manage vehicle maintenance records and inventory from both web and mobile. |
| | Administrators | Full control over user accounts, inventory, vehicle fleet, smart reports, DSS analytics, and system domain configuration via the web portal. |
| **System Objectives** | Key Objectives | 1. Automate PMS scheduling and reminders. 2. Improve inventory stock monitoring and replenishment. 3. Provide accurate, real-time vehicle and service data. 4. Support data-driven decision-making through DSS and Smart Reports. |
| **Major Capabilities** | Key Features | 1. Vehicle fleet management with PMS status tracking (Active, Due Soon, Overdue, Under Maintenance). 2. Preventive Maintenance Service (PMS) scheduling with calendar view. 3. Inventory management (Item Master, Stock Inventory, Issuances, Transactions). 4. Maintenance logging with service rows, material rows, and cost tracking. 5. Decision Support System (DSS) for inventory and PMS recommendations. 6. Smart Reports with charts (bar, donut, line) for fleet and inventory analytics. 7. Customer PMS history and Smart AI assistant (mobile). 8. Real-time push notifications via OneSignal (mobile) and web notifications. 9. User management with role-based access (Admin, Staff, Customer). 10. Google Sign-In and email/password authentication via Firebase Auth. |

---

## 4. System Architecture

### 4.1 Architecture Overview

Caltex AutoPro follows a **client-server architecture** with a shared Firebase backend. The web portal is a Flask-based multi-page application, and the mobile app is built with Flutter. Both platforms connect to the same Firebase Firestore database and Firebase Authentication service, ensuring data consistency across all user roles.

### Table 4.1 – System Architecture Summary

| Layer | Web Portal | Mobile App |
|---|---|---|
| **Frontend** | HTML5, CSS3, JavaScript (Vanilla) | Flutter (Dart) |
| **Backend / Server** | Python Flask (caltexautopro.py) | Firebase SDK (direct Firestore access) |
| **Database** | Firebase Firestore (NoSQL, real-time) | Firebase Firestore (NoSQL, real-time) |
| **Authentication** | Firebase Authentication (Email/Password, Google Sign-In) | Firebase Authentication (Email/Password, Google Sign-In) |
| **Push Notifications** | OneSignal Web Push | OneSignal Flutter SDK |
| **Email Service** | Gmail SMTP (via Flask backend) | N/A |
| **Background Tasks** | N/A | Workmanager (periodic DSS check every 15 min) |
| **Hosting / Runtime** | Flask dev server (localhost:5000) | Android / iOS device or emulator |
| **Charts** | Chart.js | Flutter custom widgets |
| **Barcode / QR** | N/A | flutter_barcode_scanner |

---

## 5. Functional Requirements

### 5.1 Web Portal – Admin Module

| ID | Feature | Description |
|---|---|---|
| WA-01 | Dashboard Overview | Displays stat cards: Total Vehicles, Due for PMS, Low Stock, Services Today, Total Users. Includes bar, donut, and line charts for fleet and inventory analytics. |
| WA-02 | Vehicle List Management | Add, edit, delete vehicles. Fields: Asset Number, Plate Number, Description, Type, Owner, Odometer, Last Service Date, Service Frequency, Next PMS Due. Auto-computes PMS status (Active, Due Soon, Overdue). |
| WA-03 | Vehicle Maintenance | Log maintenance records with service rows (labor) and material rows (parts). Tracks mechanic, date, status (Pending, Ongoing, Completed), and total cost. |
| WA-04 | Inventory – Item Master | Manage item catalog: Item Number, Name, Description, Commodity Group, UOM, Cost, Item Type (Material/Service), Barcode, QR Code, SKU. |
| WA-05 | Inventory – Stock | Monitor stock levels per item. Tracks current stock, min/max levels, reorder quantity, and status (OK/Low). |
| WA-06 | Inventory – Issuances | Record parts and services issued per vehicle. Tracks item, quantity, unit cost, subtotal, and issuing staff. |
| WA-07 | Inventory – Transactions | Log all stock IN (receives) and stock OUT (issuances) movements with timestamps. |
| WA-08 | User Management | Create, approve, deactivate, and delete user accounts. Assign roles (Admin, Staff, Customer). Send welcome and approval emails via SMTP. |
| WA-09 | Smart Reports | Generate and display analytics reports: service trends, top used parts, stock movement, fleet health. Printable via browser. |
| WA-10 | DSS – Inventory | Decision Support System for inventory: identifies low-stock items and recommends reorder quantities based on usage history. |
| WA-11 | DSS – PMS | Decision Support System for PMS: identifies vehicles due or overdue for maintenance and recommends scheduling priority. |
| WA-12 | Domain Management | Manage dropdown/domain values used across the system (e.g., vehicle types, commodity groups, service types). |
| WA-13 | Notifications | View and manage system notifications (PMS alerts, low stock alerts). Unread badge on header. |
| WA-14 | PMS Calendar | Calendar view showing scheduled PMS dates per vehicle with color-coded status dots. |
| WA-15 | Profile & Settings | View and update admin profile. Change password. |

### 5.2 Web Portal – Staff Module

| ID | Feature | Description |
|---|---|---|
| WS-01 | Staff Dashboard | Overview of assigned tasks, vehicle statuses, and maintenance schedule. |
| WS-02 | Vehicle List | View vehicle fleet list with PMS status. |
| WS-03 | Maintenance Logging | Log and update maintenance records for assigned vehicles. |
| WS-04 | Inventory View | View stock inventory levels and item details. |
| WS-05 | Notifications | Receive and view maintenance and inventory alerts. |

### 5.3 Web Portal – Customer Module

| ID | Feature | Description |
|---|---|---|
| WC-01 | Customer Dashboard | View registered vehicles and their current PMS status. |
| WC-02 | PMS History | View full service history per vehicle with date, services performed, parts used, mechanic, and cost. |
| WC-03 | PMS History Details | Drill-down view of a specific maintenance record. |
| WC-04 | Smart AI Widget | AI-powered assistant for answering vehicle maintenance questions. |

### 5.4 Mobile App – Customer Module (Flutter)

| ID | Feature | Description |
|---|---|---|
| MA-01 | Login / Register | Email/password and Google Sign-In. OTP email verification on registration. |
| MA-02 | Customer Dashboard | View vehicle PMS status and upcoming maintenance reminders. |
| MA-03 | PMS History | View service history per vehicle. |
| MA-04 | PMS History Details | Detailed view of a specific maintenance record. |
| MA-05 | Smart AI Assistant | AI chatbot for vehicle maintenance guidance. |
| MA-06 | Push Notifications | Receive OneSignal push notifications for PMS reminders and system alerts. |
| MA-07 | Profile | View and update personal profile. Change password. |
| MA-08 | Help & Support | In-app help and support page. |

### 5.5 Mobile App – Staff Module (Flutter)

| ID | Feature | Description |
|---|---|---|
| MS-01 | Staff Dashboard | View today's maintenance schedule and vehicle statuses. |
| MS-02 | Vehicle List | View and search the vehicle fleet. |
| MS-03 | Maintenance | Log and update maintenance records. |
| MS-04 | Inventory | View stock inventory and item details. |
| MS-05 | Notifications | Receive and view maintenance and inventory alerts. |
| MS-06 | Barcode / QR Scanner | Scan item barcodes or QR codes for quick inventory lookup. |

### 5.6 Mobile App – Admin Module (Flutter)

| ID | Feature | Description |
|---|---|---|
| AA-01 | Admin Dashboard | Overview stats and charts for fleet and inventory. |
| AA-02 | Vehicle Management | Add, edit, delete vehicles. |
| AA-03 | Vehicle Maintenance | Log and manage maintenance records. |
| AA-04 | Inventory – Item Master | Manage item catalog. |
| AA-05 | Inventory – Stock | Monitor stock levels. |
| AA-06 | User Management | Manage user accounts and roles. |
| AA-07 | Smart Reports | View analytics reports. |
| AA-08 | DSS | View DSS recommendations for inventory and PMS. |
| AA-09 | Domain Management | Manage system domain/dropdown values. |
| AA-10 | Background DSS Check | Workmanager task runs every 15 minutes to check for PMS and inventory alerts and trigger push notifications. |

---

## 6. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NF-01 | Performance | Real-time Firestore listeners must reflect data changes within 2 seconds under normal network conditions. |
| NF-02 | Scalability | Firebase Firestore scales automatically; the system must support concurrent access by multiple users across web and mobile. |
| NF-03 | Security | All authentication is handled by Firebase Auth. Role-based access control is enforced at the UI level. Sensitive credentials (API keys, SMTP passwords) are stored as environment variables. |
| NF-04 | Availability | The web portal runs on a local Flask server (localhost:5000). The mobile app connects directly to Firebase. |
| NF-05 | Usability | The UI follows WCAG 2.1 accessibility guidelines. The web portal is responsive. The mobile app follows Material Design principles. |
| NF-06 | Maintainability | Code is organized by role and feature. Firebase collections are clearly named (vehicles, maintenance, stock_inventory, item_master, issuances, transactions, users, domains, notifications). |
| NF-07 | Data Privacy | Compliant with the Data Privacy Act of 2012 (RA 10173). User PII is stored in Firestore and accessed only by authorized roles. |
| NF-08 | Reliability | Background DSS checks run every 15 minutes on mobile via Workmanager to ensure timely alerts even when the app is not in the foreground. |

---

## 7. Database Design

### 7.1 Firebase Firestore Collections

| Collection | Key Fields | Description |
|---|---|---|
| `users` | uid, name, email, role, status, createdAt, photoUrl, oneSignalId | All system users (Admin, Staff, Customer). |
| `vehicles` | assetNum, plate, desc, type, owner, odometer, lastSvcDate, svcFreq, nextPMSDue, status | Fleet vehicle records. |
| `maintenance` | assetNum, plate, mechanic, date, status, svcRows[], matRows[], totalCost, createdBy, createdAt | Maintenance/service records per vehicle. |
| `stock_inventory` | num, name, group, uom, price, stock, min, max, reorder, status, barcode, qr | Current stock levels per inventory item. |
| `item_master` | num, name, desc, group, uom, cost, type, barcode, qr, sku | Master catalog of all items and services. |
| `issuances` | date, assetNum, plate, itemNum, itemName, itemType, commodityGroup, uom, qty, unitCost, subtotal, createdBy | Parts and services issued per vehicle. |
| `transactions` | date, item, desc, type (IN/OUT), qty, performedBy, createdAt | All stock movement transactions. |
| `domains` | name, values[] | Dropdown/domain value lists used across the system. |
| `notifications` | title, message, type, targetRole, targetUid, readBy{}, createdAt | System notifications for all roles. |

---

## 8. System Interfaces

### 8.1 External Integrations

| Integration | Purpose | Details |
|---|---|---|
| **Firebase Authentication** | User login, registration, password reset | Email/password and Google Sign-In. Firebase Admin SDK used server-side for user deletion. |
| **Firebase Firestore** | Primary database | Real-time NoSQL database shared by web and mobile. |
| **OneSignal** | Push notifications | App ID: c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea. Used for PMS reminders and system alerts on mobile and web. |
| **Gmail SMTP** | Transactional email | Sends welcome emails (with temp password), account approval emails, OTP emails, and password reset links via caltexautopro2026@gmail.com. |
| **Google Sign-In** | OAuth authentication | Available on both web and mobile for customer and staff login. |
| **EmailJS** | Client-side email (web) | Used for OTP, welcome, and reset link email templates on the web portal. |
| **Chart.js** | Data visualization (web) | Renders bar, donut, and line charts on the admin dashboard and smart reports. |
| **Workmanager (Flutter)** | Background tasks (mobile) | Runs DSS background check every 15 minutes on Android/iOS. |
| **flutter_barcode_scanner** | Barcode/QR scanning (mobile) | Used by staff to scan item barcodes and QR codes for inventory lookup. |

---

## 9. User Interface Overview

### 9.1 Web Portal Pages

| Page | Route | Role |
|---|---|---|
| Landing Page | `/` | Public |
| Login | `/login.html` | All |
| Register | `/regsiter.html` | Customer |
| Forgot Password | `/forgot_password.html` | All |
| Admin Dashboard | `/admin_dashboard.html` | Admin |
| Admin Vehicle List | `/admin_vehicle_list.html` | Admin |
| Admin Vehicle Maintenance | `/admin_vehicle_maintenance.html` | Admin |
| Admin Inventory – Item Master | `/admin_inventory_itemaster.html` | Admin |
| Admin Inventory – Stock | `/admin_inventory_stock.html` | Admin |
| Admin Users | `/admin_users.html` | Admin |
| Admin Smart Reports | `/admin_smart_reports.html` | Admin |
| Admin DSS | `/admin_dss.html` | Admin |
| Admin Domain Management | `/admin_domain_management.html` | Admin |
| Staff Dashboard | `/staff_dashboard.html` | Staff |
| Staff Vehicle List | `/staff_vehicle_list.html` | Staff |
| Staff Maintenance | `/staff_maintenance.html` | Staff |
| Staff Inventory | `/staff_inventory.html` | Staff |
| Customer Dashboard | `/customer_dashboard.html` | Customer |
| Customer PMS History | `/customer_pms_history.html` | Customer |
| PMS History Details | `/pms_history_details.html` | Customer |
| Notifications | `/notifications.html` | Admin / Staff |
| Profile | `/profile.html` | All |
| Change Password | `/change_password.html` | All |
| Help & Support | `/help_support.html` | All |

### 9.2 Mobile App Screens (Flutter)

| Screen | Role |
|---|---|
| Login | All |
| Register | Customer |
| Forgot Password | All |
| Google Sign-In | All |
| Customer Dashboard | Customer |
| Customer PMS History | Customer |
| PMS History Details | Customer |
| Smart AI Assistant | Customer |
| Staff Dashboard | Staff |
| Staff Vehicle List | Staff |
| Staff Maintenance | Staff |
| Staff Inventory | Staff |
| Admin Dashboard | Admin |
| Admin Vehicle List | Admin |
| Admin Vehicle Maintenance | Admin |
| Admin Inventory – Item Master | Admin |
| Admin Inventory – Stock | Admin |
| Admin Users | Admin |
| Admin Smart Reports | Admin |
| Admin DSS | Admin |
| Admin Domain Management | Admin |
| Notifications | All |
| Profile | All |
| Change Password | All |
| Help & Support | All |
| Barcode Scanner | Staff / Admin |
| Alert Preferences | All |

---

## 10. Security Specifications

| Area | Implementation |
|---|---|
| **Authentication** | Firebase Authentication handles all login flows. Supports email/password and Google OAuth. |
| **Role-Based Access Control** | User roles (admin, staff, customer) are stored in Firestore `users` collection. UI routing enforces role-based page access. |
| **Session Management** | Web portal uses `sessionStorage` to persist user session data. Flask session lifetime is set to 7 days. |
| **API Security** | Flask backend API endpoints validate required fields before processing. Firebase Admin SDK is used server-side only. |
| **Credential Management** | SMTP password and Firebase service account credentials are loaded from environment variables. API keys are not hardcoded in client-facing code where avoidable. |
| **Data Privacy** | Compliant with RA 10173. User PII (name, email, role) is stored in Firestore and accessible only to authorized roles. |
| **Push Notification Security** | OneSignal API key is used server-side only (Flask backend). Client-side only uses the App ID. |

---

*End of System Technical Specification*

---

### 3.2 Business Processes / Operational Scenarios

The following section presents the key business processes of the Caltex AutoPro system. Each process includes a Service ID, objective, requirements, fees, processing time, and a three-column flowchart table showing the Process Flow, Persons Involved, and Description.

---

**1. Vehicle Registration and PMS Setup**
Service ID: CAP-01
Objective: To register a vehicle into the system and configure its Preventive Maintenance Service (PMS) schedule.
Requirements:
- Vehicle details (plate number, asset number, type, owner, odometer reading)
- Service frequency (in months)

Fees: None
Processing Time: 5–10 minutes

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Submit Vehicle Details | Admin / Staff | Vehicle information is entered into the system. |
| ↓ **Validate Information** | Admin | Details are reviewed for completeness and accuracy. |
| ↓ **Create Vehicle Record** | System | Vehicle is saved to Firestore `vehicles` collection. |
| ↓ **Compute Next PMS Due** | System | Next PMS date is auto-calculated from last service date and frequency. |
| ↓ **Set PMS Status** | System | Status is assigned: Active, Due Soon, or Overdue. |
| ↓ **Confirm & Notify → End** | Admin, Customer | Vehicle is visible on dashboards and customer is notified. |

---

**2. Preventive Maintenance Service (PMS) Scheduling and Logging**
Service ID: CAP-02
Objective: To schedule and document a vehicle's preventive maintenance service, including labor and parts used.
Requirements:
- Vehicle plate number / asset number
- Mechanic name
- Service rows (labor/services performed)
- Material rows (parts used with quantity and cost)

Fees: None (internal process)
Processing Time: 10–20 minutes (logging and documentation)

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Identify Vehicle for PMS | Admin / Staff | Vehicle due for PMS is identified from the dashboard or DSS. |
| ↓ **Create Maintenance Record** | Admin / Staff | New maintenance entry is created with date, mechanic, and status set to Pending. |
| ↓ **Add Service Rows** | Admin / Staff | Labor/services performed are listed with descriptions and costs. |
| ↓ **Add Material Rows** | Admin / Staff | Parts and materials used are recorded with quantity and unit cost. |
| ↓ **Update Status to Ongoing** | Admin / Staff | Maintenance status is updated as work begins. |
| ↓ **Complete and Save Record** | Admin / Staff | Status set to Completed; total cost is computed and saved to Firestore. |
| ↓ **Update Vehicle PMS Date → End** | System | Vehicle's last service date and next PMS due are updated automatically. |

---

**3. Inventory Stock Monitoring and Replenishment**
Service ID: CAP-03
Objective: To monitor spare parts inventory levels and trigger replenishment decisions when stock falls below the minimum threshold.
Requirements:
- Item master catalog (item number, name, UOM, cost)
- Current stock levels
- Minimum and maximum stock levels

Fees: None
Processing Time: Real-time monitoring; replenishment decision within 1–2 days

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Monitor Stock Levels | System | Firestore listener continuously tracks stock quantities in real time. |
| ↓ **Detect Low Stock** | System | Items with stock below minimum level are flagged with status "Low". |
| ↓ **Trigger Alert** | System | Low stock notification is sent to Admin via web and push notification. |
| ↓ **Review DSS Recommendation** | Admin | Admin reviews DSS-generated reorder quantity recommendation. |
| ↓ **Approve Replenishment** | Admin | Admin approves and initiates stock replenishment. |
| ↓ **Record Stock IN Transaction** | Admin / Staff | New stock received is logged as a Stock IN transaction in Firestore. |
| ↓ **Update Stock Level → End** | System | Inventory stock count is updated; status returns to OK. |

---

**4. Parts and Services Issuance**
Service ID: CAP-04
Objective: To record the issuance of spare parts and services to a specific vehicle during a maintenance activity.
Requirements:
- Vehicle plate number / asset number
- Item number and name
- Quantity and unit cost

Fees: None
Processing Time: 5–10 minutes per issuance record

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Select Vehicle and Item | Admin / Staff | Staff selects the vehicle and item to be issued. |
| ↓ **Verify Stock Availability** | System | System checks current stock level before allowing issuance. |
| ↓ **Enter Issuance Details** | Admin / Staff | Quantity, unit cost, and commodity group are entered. |
| ↓ **Save Issuance Record** | System | Issuance is saved to Firestore `issuances` collection. |
| ↓ **Deduct from Stock** | System | Stock quantity is reduced; a Stock OUT transaction is logged. |
| ↓ **Update Inventory Status → End** | System | Stock status is recalculated (OK or Low) and dashboard is updated. |

---

**5. User Account Management**
Service ID: CAP-05
Objective: To create, approve, and manage user accounts for Administrators, Staff, and Customers within the system.
Requirements:
- User full name and email address
- Assigned role (Admin, Staff, Customer)
- Temporary password (for Admin/Staff accounts created by Admin)

Fees: None
Processing Time: 5–10 minutes (account creation and email delivery)

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Submit Registration / Create Account | Customer / Admin | Customer self-registers or Admin creates a Staff/Admin account. |
| ↓ **Validate Details** | System / Admin | Email format and required fields are validated. |
| ↓ **Create Firebase Auth Account** | System | Firebase Authentication account is created with email and password. |
| ↓ **Save User Record to Firestore** | System | User profile (name, email, role, status) is saved to `users` collection. |
| ↓ **Send Welcome / Approval Email** | System (SMTP) | Welcome email with credentials or approval notification is sent via Gmail SMTP. |
| ↓ **Admin Reviews Pending Accounts** | Admin | Admin reviews and approves or deactivates accounts as needed. |
| ↓ **Account Activated → End** | System | User status is set to Active; user can log in and access their dashboard. |

---

**6. Smart Reports Generation**
Service ID: CAP-06
Objective: To generate and display analytics reports for fleet health, service trends, inventory movement, and top used parts to support management decision-making.
Requirements:
- Existing vehicle, maintenance, inventory, and issuance data in Firestore

Fees: None
Processing Time: Real-time (data loads automatically on page access)

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Access Smart Reports | Admin | Admin navigates to the Smart Reports section. |
| ↓ **Load Firestore Data** | System | Real-time listeners fetch vehicles, maintenance, inventory, and issuance records. |
| ↓ **Compute Analytics** | System | Charts are calculated: service trends (bar), vehicle status (donut), stock movement (line), top parts (bar). |
| ↓ **Render Charts and Tables** | System | Chart.js renders all visualizations on the admin dashboard and reports page. |
| ↓ **Review Reports** | Admin | Admin reviews fleet health, service trends, and inventory analytics. |
| ↓ **Print or Export → End** | Admin | Admin prints the report via browser print function. |

---

**7. Decision Support System (DSS) Recommendation**
Service ID: CAP-07
Objective: To provide automated, data-driven recommendations for inventory replenishment and PMS scheduling priority to assist administrators in operational decision-making.
Requirements:
- Current stock levels and usage history (issuances)
- Vehicle PMS status and next due dates

Fees: None
Processing Time: Real-time (web); every 15 minutes (mobile background check)

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Trigger DSS Analysis | System | DSS runs on page load (web) or via Workmanager background task (mobile, every 15 min). |
| ↓ **Analyze Inventory Data** | System | Low-stock items are identified; reorder quantities are computed from usage history. |
| ↓ **Analyze PMS Data** | System | Vehicles with Overdue or Due Soon status are ranked by urgency. |
| ↓ **Generate Recommendations** | System | DSS outputs prioritized lists: items to reorder and vehicles to schedule for PMS. |
| ↓ **Display to Admin** | System | Recommendations are shown on the DSS page (web) and DSS screen (mobile). |
| ↓ **Admin Reviews and Acts** | Admin | Admin uses recommendations to approve replenishment or schedule maintenance. |
| ↓ **Send Push Notification → End** | System (OneSignal) | If critical alerts are detected, push notifications are sent to relevant users. |
