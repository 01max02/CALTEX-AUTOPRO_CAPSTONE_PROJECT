# USE CASE SPECIFICATIONS

---

## B. Use Case Descriptions

---

### UC-01: User Login

**Use Case ID:** UC-01
**Use Case Name:** User Login
**Primary Actor:** Registered User (Customer, Staff, or Administrator)
**Stakeholders and Interests:**
- User – Wants secure and convenient access to the system using email/password or Google Sign-In.
- System Owner / JA Noble Enterprise Inc. – Wants only authorized and approved users to access protected functions and data.

**Brief Description:**
This use case describes how a registered user authenticates to the Caltex AutoPro system using valid credentials (email and password, or Google OAuth) to gain access to their role-based dashboard and authorized features.

**Preconditions:**
- The user account is registered and has an Active status in Firestore.
- The system is available and the login page (web or mobile app) is accessible.
- Firebase Authentication and Firestore services are online.

**Postconditions:**
- **Success:** User is authenticated, a session is created (sessionStorage on web; in-memory on mobile), OneSignal subscription ID is saved to Firestore, and the user is redirected to the appropriate role-based dashboard (Admin → `/admin_dashboard.html`, Staff → `/staff_dashboard.html`, Customer → `/customer_dashboard.html`).
- **Failure:** User remains unauthenticated; no secure resources are accessible; a relevant error or validation message is displayed.

**Basic Flow (Main Success Scenario):**
1. User navigates to the login page (web) or opens the mobile app.
2. System displays the login form with Email Address and Password fields, a Forgot Password link, and a "Continue with Google" button.
3. User enters a valid email address and password.
4. User clicks the Sign In button.
5. System sends credentials to Firebase Authentication via `signInWithEmailAndPassword()`.
6. Firebase Auth returns a valid credential with the user's UID.
7. System retrieves the user's document from Firestore `users` collection using the UID.
8. System checks the user's `status` field (must be `active`).
9. System checks the `mustChangePassword` flag; if true, redirects to the Change Password screen.
10. System stores user data in sessionStorage (web) or navigates to the role-based screen (mobile).
11. System calls `OneSignal.login(uid)` and saves the subscription ID to Firestore (mobile only).
12. System redirects the user to the appropriate dashboard based on their role.

**Alternative / Exception Flows:**

**A1 – Invalid Credentials**
3a. User enters an incorrect email and/or password.
4a. User clicks Sign In.
5a. Firebase Auth returns `auth/invalid-credential`, `auth/wrong-password`, or `auth/user-not-found`.
6a. System displays a generic error message: "Invalid email or password." (without revealing which field is wrong).
7a. User may try again; no lockout is enforced at the application level.

**A2 – Missing Required Fields**
3b. User leaves the email or password field blank and clicks Sign In.
4b. System detects empty fields before calling Firebase Auth.
5b. System displays: "Please enter email and password." and does not proceed with authentication.

**A3 – Account Inactive (Deactivated)**
8a. System retrieves the user document and finds `status == 'inactive'`.
9a. System calls `FirebaseAuth.signOut()` to terminate the Firebase session.
10a. System displays: "Your account has been deactivated. Please contact the administrator."
11a. User remains on the login page.

**A4 – Account Pending Approval**
8b. System retrieves the user document and finds `status == 'pending'`.
9b. System calls `FirebaseAuth.signOut()` to terminate the Firebase session.
10b. System displays: "Your account is pending admin approval. You will be notified by email once approved."
11b. User remains on the login page.

**A5 – Google Sign-In**
3c. User clicks "Continue with Google" instead of entering email/password.
4c. System initiates Google OAuth flow via `GoogleSignInHelper.signInWithGoogle()`.
5c. User selects a Google account and grants consent.
6c. Firebase Auth authenticates the user via Google OAuth token.
7c. System retrieves or creates the user's Firestore document.
8c. System checks `status` and `mustChangePassword` as in the main flow.
9c. System redirects the user to the appropriate role-based dashboard.

**A6 – First Login (Must Change Password)**
9a. System retrieves the user document and finds `mustChangePassword == true`.
10a. System redirects the user to the Change Password screen instead of the dashboard.
11a. User sets a new password; upon success, is redirected to the appropriate dashboard.

---

### UC-02: User Registration

**Use Case ID:** UC-02
**Use Case Name:** User Registration
**Primary Actor:** New Customer (self-registration via mobile app)
**Stakeholders and Interests:**
- New Customer – Wants to create an account to access vehicle PMS history and maintenance reminders.
- Administrator – Wants to review and approve new accounts before granting access.
- System – Wants to ensure only valid, non-duplicate accounts are created.

**Brief Description:**
This use case describes how a new customer registers an account in the Caltex AutoPro mobile app. The account is created in Firebase Auth and Firestore with a `pending` status, and the administrator is notified for approval.

**Preconditions:**
- The user does not already have an account with the same email address.
- The mobile app is installed and accessible.
- Firebase Authentication and Firestore services are online.

**Postconditions:**
- **Success:** A new Firebase Auth account and Firestore user document (status: `pending`) are created. Admin is notified via Firestore notification and OneSignal push. User is shown a pending approval dialog and returned to the login screen.
- **Failure:** Account is not created; relevant error message is displayed (e.g., duplicate email, weak password, missing fields).

**Basic Flow (Main Success Scenario):**
1. User taps "Sign Up" on the login screen.
2. System displays the registration form: First Name, Last Name, Email Address, Password, Confirm Password.
3. User fills in all required fields.
4. User taps "Create Account."
5. System validates that all fields are filled, passwords match, and password is at least 6 characters.
6. System calls `FirebaseAuth.createUserWithEmailAndPassword()` to create the Auth account.
7. System updates the Firebase Auth display name to `firstName + lastName`.
8. System saves the user document to Firestore `users` collection with `role: 'customer'` and `status: 'pending'`.
9. System creates a notification document in Firestore `notifications` collection targeting `targetRole: 'admin'`.
10. System sends a OneSignal push notification to all admin devices.
11. System signs out the new user (they cannot log in until approved).
12. System displays a pending approval dialog: "Your account is pending admin approval."
13. User taps "Back to Login" and is returned to the login screen.

**Alternative / Exception Flows:**

**A1 – Missing Required Fields**
3a. User leaves one or more fields blank and taps Create Account.
4a. System detects empty fields.
5a. System displays: "Please fill in all fields." and does not proceed.

**A2 – Passwords Do Not Match**
5a. System detects that Password and Confirm Password fields do not match.
6a. System displays: "Passwords do not match." and does not proceed.

**A3 – Weak Password**
5b. System detects that the password is fewer than 6 characters.
6b. System displays: "Password must be at least 6 characters." and does not proceed.

**A4 – Email Already in Use**
6a. Firebase Auth returns `email-already-in-use`.
7a. System displays: "An account with this email already exists." and does not proceed.

---

### UC-03: Vehicle Registration and PMS Setup

**Use Case ID:** UC-03
**Use Case Name:** Vehicle Registration and PMS Setup
**Primary Actor:** Administrator / Staff
**Stakeholders and Interests:**
- Administrator / Staff – Wants to register fleet vehicles and configure their PMS schedules for automated tracking.
- Customer – Wants their vehicle's maintenance history and reminders to be accurately tracked.
- System – Wants to auto-compute PMS status and next due dates from the provided data.

**Brief Description:**
This use case describes how an Administrator or Staff member registers a new vehicle into the system and configures its Preventive Maintenance Service (PMS) schedule, including plate number, vehicle type, owner, odometer, last service date, and service frequency.

**Preconditions:**
- The user is logged in as Admin or Staff.
- The vehicle's plate number does not already exist in the system.
- Firebase Firestore is accessible.

**Postconditions:**
- **Success:** Vehicle record is saved to Firestore `vehicles` collection with auto-computed PMS status and next due date. The vehicle appears on all dashboards in real time.
- **Failure:** Vehicle is not saved; error message is displayed (e.g., duplicate plate, missing required fields).

**Basic Flow (Main Success Scenario):**
1. Admin/Staff navigates to the Vehicle List page (web or mobile).
2. Admin/Staff clicks/taps the Add (+) button.
3. System displays the Add Vehicle form.
4. Admin/Staff enters: Plate Number, Description, Vehicle Type, Owner Name, Current Odometer, Last Service Odometer, Last Service Date, and Service Frequency (months).
5. Admin/Staff submits the form.
6. System validates that Plate Number and Description are not empty.
7. System checks Firestore for a duplicate plate number.
8. System looks up the owner's UID from the `users` collection (role: customer) by name and attaches it as `ownerId`.
9. System computes the Next PMS Due date: Last Service Date + Service Frequency (months).
10. System computes the PMS Status: Overdue (past due), PMS Due Soon (≤30 days), or Active (>30 days).
11. System saves the vehicle document to Firestore `vehicles` collection with a server timestamp.
12. System displays a success message. The vehicle list refreshes in real time via Firestore listener.

**Alternative / Exception Flows:**

**A1 – Missing Required Fields**
5a. Admin/Staff submits the form with Plate Number or Description empty.
6a. System detects missing required fields.
7a. System does not submit; displays a validation message.

**A2 – Duplicate Plate Number**
7a. System finds an existing vehicle with the same plate number in Firestore.
8a. System displays: "A vehicle with this plate number already exists." and does not save.

**A3 – Owner Not Found**
8a. System cannot find a matching customer in the `users` collection by the entered owner name.
9a. System saves the vehicle without an `ownerId` (owner name is still stored as a string).

---

### UC-04: Log Maintenance Record

**Use Case ID:** UC-04
**Use Case Name:** Log Maintenance Record
**Primary Actor:** Administrator / Staff
**Stakeholders and Interests:**
- Administrator / Staff – Wants to document all maintenance activities performed on a vehicle, including labor and parts used.
- Customer – Wants an accurate and complete service history for their vehicle.
- System – Wants to update vehicle PMS status and compute total cost automatically.

**Brief Description:**
This use case describes how an Administrator or Staff member creates a maintenance record for a vehicle, logging the services performed (labor rows), materials used (parts rows), mechanic name, date, and status.

**Preconditions:**
- The user is logged in as Admin or Staff.
- The vehicle exists in the system.
- Firebase Firestore is accessible.

**Postconditions:**
- **Success:** Maintenance record is saved to Firestore `maintenance` collection. Vehicle's last service date and next PMS due are updated. Total cost is computed from service and material rows.
- **Failure:** Record is not saved; error message is displayed.

**Basic Flow (Main Success Scenario):**
1. Admin/Staff navigates to the Vehicle Maintenance page.
2. Admin/Staff clicks/taps "Add Maintenance Record."
3. System displays the maintenance form.
4. Admin/Staff selects the vehicle (plate number), enters the mechanic name, date, and sets status to Pending.
5. Admin/Staff adds service rows (labor): service name, description, cost.
6. Admin/Staff adds material rows (parts): item name, quantity, unit cost.
7. Admin/Staff submits the form.
8. System computes the total cost from all service and material rows.
9. System saves the maintenance document to Firestore `maintenance` collection.
10. System updates the vehicle's `lastSvcDate` and recomputes `nextPMSDue` in the `vehicles` collection.
11. System displays a success message. The maintenance list refreshes in real time.

**Alternative / Exception Flows:**

**A1 – Status Update (Ongoing / Completed)**
After saving, Admin/Staff updates the maintenance status to Ongoing or Completed.
System updates the `status` field in the Firestore maintenance document.
If status is set to Completed, the vehicle's PMS status is updated to Active (or recomputed on next app launch).

**A2 – Missing Required Fields**
7a. Admin/Staff submits without selecting a vehicle or entering a date.
8a. System detects missing required fields and displays a validation message.

---

### UC-05: Manage Inventory

**Use Case ID:** UC-05
**Use Case Name:** Manage Inventory
**Primary Actor:** Administrator / Staff
**Stakeholders and Interests:**
- Administrator – Wants full control over the item master catalog and stock levels.
- Staff – Wants to view stock levels and record issuances during maintenance.
- System – Wants to automatically flag low-stock items and update stock counts on issuance.

**Brief Description:**
This use case describes how the system manages spare parts inventory, including the item master catalog, stock monitoring, issuances, and stock transactions.

**Preconditions:**
- The user is logged in as Admin or Staff.
- Firebase Firestore is accessible.

**Postconditions:**
- **Success:** Item records are saved/updated in Firestore. Stock levels are updated in real time. Low-stock items are flagged and notifications are triggered.
- **Failure:** Record is not saved; error message is displayed.

**Basic Flow (Main Success Scenario):**
1. Admin navigates to the Inventory section (Item Master or Stock Inventory).
2. Admin adds or edits an item: Item Number, Name, Description, Commodity Group, UOM, Cost, Item Type (Material/Service), Barcode, QR Code, SKU.
3. System saves the item to Firestore `item_master` and/or `stock_inventory` collections.
4. System monitors stock levels in real time via Firestore listener.
5. System flags items where current stock < minimum level with status "Low."
6. System triggers a low-stock notification to Admin.
7. Staff records an issuance: selects vehicle, item, quantity, and unit cost.
8. System saves the issuance to Firestore `issuances` collection.
9. System deducts the issued quantity from `stock_inventory` and logs a Stock OUT transaction in `transactions`.
10. System updates the item's stock status (OK or Low).

**Alternative / Exception Flows:**

**A1 – Insufficient Stock**
7a. Staff attempts to issue a quantity greater than the current stock level.
8a. System detects insufficient stock and displays a warning message.

**A2 – Stock Replenishment (Stock IN)**
Admin records a stock receive: selects item and quantity received.
System adds the quantity to `stock_inventory` and logs a Stock IN transaction in `transactions`.
Stock status is recalculated (OK or Low).

---

### UC-06: View Smart Reports and DSS

**Use Case ID:** UC-06
**Use Case Name:** View Smart Reports and DSS Recommendations
**Primary Actor:** Administrator
**Stakeholders and Interests:**
- Administrator – Wants data-driven insights on fleet health, service trends, inventory movement, and actionable DSS recommendations.
- System – Wants to compute and display accurate analytics from real-time Firestore data.

**Brief Description:**
This use case describes how the Administrator views analytics reports and Decision Support System (DSS) recommendations for inventory replenishment and PMS scheduling priority.

**Preconditions:**
- The user is logged in as Administrator.
- Vehicle, maintenance, inventory, and issuance data exist in Firestore.

**Postconditions:**
- **Success:** Charts and DSS recommendations are rendered in real time. Admin can review and act on the recommendations.
- **Failure:** Charts display empty state if no data is available.

**Basic Flow (Main Success Scenario):**
1. Admin navigates to the Smart Reports or DSS page.
2. System loads data from Firestore via real-time listeners (vehicles, maintenance, stock_inventory, issuances, transactions).
3. System computes analytics: service trends by type (last 7 days), vehicle status distribution, stock IN vs. stock OUT movement, top 10 most used parts.
4. System renders charts using Chart.js (web) or Flutter custom widgets (mobile): stacked bar chart, donut chart, line chart, horizontal bar chart.
5. Admin reviews fleet health, service trends, and inventory analytics.
6. Admin navigates to the DSS section.
7. System analyzes inventory data: identifies low-stock items and computes reorder quantities based on usage history.
8. System analyzes PMS data: ranks vehicles by urgency (Overdue > PMS Due Soon > Active).
9. System displays prioritized DSS recommendations for inventory replenishment and PMS scheduling.
10. Admin uses recommendations to approve replenishment or schedule maintenance.

**Alternative / Exception Flows:**

**A1 – No Data Available**
2a. Firestore collections are empty or have insufficient data.
3a. System displays empty state messages (e.g., "No services recorded this month.") instead of charts.

**A2 – Background DSS Check (Mobile)**
System's Workmanager task runs every 15 minutes in the background.
If critical alerts are detected (Overdue vehicles or Low stock), System sends a OneSignal push notification to the Admin's device.

---

## 6. System Testing Plan

### 1. Objectives

System testing and evaluation aim to verify that the fully integrated Vehicle Maintenance and Inventory Management System satisfies all functional and non-functional requirements, is stable, secure, usable, and ready for deployment at JA Noble Enterprise Inc. Evaluation will determine whether the system meets user needs and agreed acceptance criteria.

### 2. Scope

System testing covers end-to-end workflows (user registration, vehicle management, maintenance logging, inventory issuance, report generation), including all interfaces, integrations (Firebase, OneSignal, Gmail SMTP), and role-based access controls.

---

### A. Functional Testing Table – Login

| Test Case ID | Module / Feature | Test Scenario / Objective | Pre-conditions | Test Steps (Summary) | Expected Result | Priority | Status |
|---|---|---|---|---|---|---|---|
| FT-LOGIN-01 | Login | Verify successful login with valid email/password | Active user account exists in Firebase Auth & Firestore | 1) Open login page 2) Enter valid email & password 3) Click Sign In | User authenticated; redirected to role-based dashboard; session stored in sessionStorage | High | Not Run |
| FT-LOGIN-02 | Login | Verify error message on invalid password | Active user account exists | 1) Open login page 2) Enter valid email, invalid password 3) Click Sign In | System displays "Invalid email or password" (generic); no redirect; no session created | High | Not Run |
| FT-LOGIN-03 | Login | Verify Google Sign-In flow | Google account exists; Firebase OAuth configured | 1) Open login page 2) Click "Continue with Google" 3) Complete Google consent | User authenticated via Firebase; profile synced to Firestore; redirected to dashboard | High | Not Run |
| FT-LOGIN-04 | Login | Verify role-based redirect after login | User accounts with different roles exist | 1) Login as Admin → check redirect 2) Login as Staff → check redirect 3) Login as Customer → check redirect | Admin → `/admin_dashboard.html`; Staff → `/staff_dashboard.html`; Customer → `/customer_dashboard.html` | High | Not Run |
| FT-LOGIN-05 | Login | Verify session persistence (7-day expiry) | User logged in; sessionStorage used | 1) Login successfully 2) Close & reopen browser within 7 days 3) Navigate to protected page | User remains logged in; no re-authentication required; session cleared after 7 days of inactivity | Medium | Not Run |
| FT-LOGIN-06 | Login | Verify inactive account is blocked | User account exists with `status: inactive` | 1) Open login page 2) Enter credentials of inactive account 3) Click Sign In | System displays "Your account has been deactivated. Please contact the administrator."; no session created | High | Not Run |
| FT-LOGIN-07 | Login | Verify pending account is blocked | User account exists with `status: pending` | 1) Open login page 2) Enter credentials of pending account 3) Click Sign In | System displays "Your account is pending admin approval."; no session created | High | Not Run |
| FT-LOGIN-08 | Login | Verify first-login password change redirect | User account has `mustChangePassword: true` | 1) Login with valid credentials 2) Observe redirect | System redirects to Change Password screen instead of dashboard | High | Not Run |

---

### B. Functional Testing Table – Vehicle Management

| Test Case ID | Module / Feature | Test Scenario / Objective | Pre-conditions | Test Steps (Summary) | Expected Result | Priority | Status |
|---|---|---|---|---|---|---|---|
| FT-VEH-01 | Vehicle Registration | Verify new vehicle can be added with valid data | User logged in as Admin/Staff | 1) Navigate to Vehicle List → Add New 2) Fill all required fields with valid data 3) Submit form | Vehicle saved to Firestore; appears in list; PMS status computed correctly; success message shown | High | Not Run |
| FT-VEH-02 | Vehicle Registration | Verify duplicate plate number is rejected | Vehicle with plate "ABC123" exists | 1) Attempt to add new vehicle with plate "ABC123" 2) Submit form | System displays error: "A vehicle with this plate number already exists"; form not submitted; no duplicate record created | High | Not Run |
| FT-VEH-03 | PMS Status | Verify status auto-updates based on dates | Vehicle with `lastSvcDate = 2026-01-01`, `svcFreq = 3` months | 1) View vehicle on 2026-03-15 → expect "PMS Due Soon" 2) View on 2026-04-02 → expect "Overdue" | Status badge updates automatically; color coding matches (yellow = Due Soon, red = Overdue) | High | Not Run |
| FT-VEH-04 | Vehicle Edit | Verify vehicle details can be updated | Vehicle exists; user has edit permission | 1) Open vehicle details 2) Edit odometer and description 3) Save changes | Updated values saved to Firestore; UI reflects new values immediately; success message shown | Medium | Not Run |
| FT-VEH-05 | Vehicle Delete | Verify vehicle can be deleted with confirmation | Vehicle exists | 1) Click Delete on vehicle 2) Confirm deletion in dialog | Vehicle document deleted from Firestore; removed from list in real time; success message shown | Medium | Not Run |
| FT-VEH-06 | Vehicle Search | Verify search filters vehicles correctly | Multiple vehicles exist | 1) Type plate number in search bar 2) Type owner name 3) Clear search | Only matching vehicles shown; "No vehicles found." shown when no match; full list restored on clear | Low | Not Run |

---

### C. Functional Testing Table – Inventory & Decision Support System

| Test Case ID | Module / Feature | Test Scenario / Objective | Pre-conditions | Test Steps (Summary) | Expected Result | Priority | Status |
|---|---|---|---|---|---|---|---|
| FT-INV-01 | Stock Monitoring | Verify low-stock detection and alert | Item with `stock = 5`, `min = 10` exists | 1) View Stock Inventory page 2) Observe item status | Item displayed with red "Low" badge; appears in Low Stock filter; admin notification triggered | High | Not Run |
| FT-INV-02 | Parts Issuance | Verify stock deduction on issuance | Item in stock; vehicle exists; user has Staff role | 1) Open Issuance form 2) Select item, qty = 2 3) Save issuance | Stock reduced by 2; transaction logged in `transactions`; issuance saved to `issuances`; UI updates in real time | High | Not Run |
| FT-INV-03 | Stock IN | Verify stock increases on receive transaction | Item exists in inventory | 1) Open Stock IN form 2) Select item, enter qty = 10 3) Save | Stock increased by 10; Stock IN transaction logged in `transactions`; status recalculated (OK or Low) | High | Not Run |
| FT-INV-04 | Item Master | Verify new item can be added to catalog | User logged in as Admin | 1) Navigate to Item Master → Add Item 2) Fill all fields 3) Submit | Item saved to `item_master` collection; appears in catalog list; success message shown | Medium | Not Run |
| FT-DSS-01 | DSS Inventory | Verify reorder recommendation logic | Item with 30-day usage history exists | 1) Navigate to DSS → Inventory tab 2) Review recommendation | System suggests reorder qty = (avg daily usage × lead time) + safety stock; explanation tooltip available | Medium | Not Run |
| FT-DSS-02 | DSS PMS | Verify PMS scheduling priority | 3 vehicles: 1 Overdue, 1 Due Soon, 1 Active | 1) Navigate to DSS → PMS tab 2) Review prioritized list | Overdue vehicle ranked 1st with highest priority score; Due Soon ranked 2nd; Active not listed or lowest priority | Medium | Not Run |

---

### D. Functional Testing Table – User Management & Notifications

| Test Case ID | Module / Feature | Test Scenario / Objective | Pre-conditions | Test Steps (Summary) | Expected Result | Priority | Status |
|---|---|---|---|---|---|---|---|
| FT-USR-01 | User Registration | Verify new customer account is created with pending status | No existing account with same email | 1) Open Register screen 2) Fill all fields 3) Tap Create Account | Firebase Auth account created; Firestore document saved with `status: pending`; admin notified via Firestore + OneSignal; pending dialog shown | High | Not Run |
| FT-USR-02 | User Approval | Verify admin can approve a pending account | Pending user account exists | 1) Admin opens User Management 2) Finds pending user 3) Clicks Approve | User `status` updated to `active` in Firestore; approval email sent via Gmail SMTP; user can now log in | High | Not Run |
| FT-USR-03 | User Deactivation | Verify admin can deactivate an active account | Active user account exists | 1) Admin opens User Management 2) Finds active user 3) Clicks Deactivate | User `status` updated to `inactive`; user cannot log in; system displays deactivation message on login attempt | High | Not Run |
| FT-USR-04 | Welcome Email | Verify welcome email is sent when admin creates Staff/Admin account | SMTP configured; valid email address | 1) Admin creates new Staff account with temp password 2) Observe email delivery | Welcome email with credentials and role delivered to the specified email address via Gmail SMTP | Medium | Not Run |
| FT-NOTIF-01 | Notifications | Verify PMS alert notification is created | Vehicle with Overdue status exists | 1) System runs PMS check 2) Admin opens Notifications page | Notification document created in Firestore `notifications` with `targetRole: admin`; unread badge shown on header | High | Not Run |
| FT-NOTIF-02 | Push Notifications | Verify OneSignal push notification is delivered | User has OneSignal subscription ID saved; app installed | 1) Trigger a PMS or low-stock alert 2) Observe mobile device | Push notification received on device with correct title and message; notification badge updated in app | High | Not Run |
