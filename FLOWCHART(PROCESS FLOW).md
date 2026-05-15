# FLOWCHART (PROCESS FLOW)

---

### 3.2 Business Processes / Operational Scenarios

The following section presents the key business processes of the Caltex AutoPro system. Each process includes a Service ID, objective, requirements, fees, processing time, and a three-column flowchart table showing the Process Flow, Persons Involved, and Description.

---

**1. Vehicle Registration and PMS Setup**
Service ID: JA-VMIS-01
Objective: To register a vehicle into the system and configure its Preventive Maintenance Service (PMS) schedule.
Requirements:
- Vehicle details (plate number, description, vehicle type, owner, current odometer reading, last service date, service frequency (in months))

Fees: None
Processing Time: 5–15 minutes

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Open Vehicle List | Admin | Admin navigates to the Vehicle List page (web or mobile app). |
| ↓ **Click Add Vehicle** | Admin | Admin taps the floating Add (+) button to open the Add Vehicle form. |
| ↓ **Fill in Vehicle Details** | Admin | Admin enters plate number, description, vehicle type, owner, odometer, last service date, and service frequency. |
| ↓ **Validate Required Fields** | System | System checks that plate number and description are not empty. Duplicate plate check is performed against Firestore. |
| ↓ **Resolve Owner ID** | System | System looks up the owner's UID from the `users` collection (role: customer) by name and attaches it as `ownerId`. |
| ↓ **Compute PMS Status** | System | Next PMS Due is calculated from last service date + frequency. Status is set to Active, PMS Due Soon (≤30 days), or Overdue. |
| ↓ **Save to Firestore → End** | System | Vehicle record is saved to the `vehicles` collection. Success message is shown and the list refreshes in real time. |

---

**2. View Vehicle Details**
Service ID: JA-VMIS-02
Objective: To view the complete details of a registered vehicle including its current PMS status and next scheduled maintenance date.
Requirements:
- Existing vehicle record in the system

Fees: None
Processing Time: Instant (real-time data load)

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Open Vehicle List | Admin | Admin opens the Vehicle List page on web or mobile. |
| ↓ **Search / Browse Vehicles** | Admin | Admin searches by plate number, description, or owner name using the search bar. |
| ↓ **Select a Vehicle** | Admin | Admin clicks or taps a vehicle card or row to open the details view. |
| ↓ **Load Vehicle Data** | System | System retrieves the vehicle's full record from Firestore in real time. |
| ↓ **Display Details → End** | System | Modal or bottom sheet shows: Plate Number, Description, Owner, Odometer, Vehicle Type, Last Service Date, and computed Next PMS Due date. |

---

**3. Edit Vehicle Record**
Service ID: JA-VMIS-03
Objective: To update an existing vehicle's information such as odometer reading, service date, or owner details.
Requirements:
- Existing vehicle record
- Updated vehicle details

Fees: None
Processing Time: 5–10 minutes

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Select Vehicle to Edit | Admin | Admin clicks Edit from the vehicle card (web: Actions column; mobile: three-dot menu). |
| ↓ **Load Existing Data into Form** | System | Current vehicle data is pre-filled into the Add/Edit Vehicle form fields. |
| ↓ **Modify Vehicle Details** | Admin | Admin updates the desired fields (e.g., odometer, last service date, service frequency, owner). |
| ↓ **Validate Required Fields** | System | System checks that plate number and description are still present and valid. |
| ↓ **Resolve Owner ID** | System | System re-looks up the owner's UID from the `users` collection if the owner name was changed. |
| ↓ **Update Firestore → End** | System | Updated fields are written to the existing vehicle document. Success message is shown and the list refreshes in real time. |

---

**4. Delete Vehicle Record**
Service ID: JA-VMIS-04
Objective: To permanently remove a vehicle record from the system when it is no longer in service or was entered in error.
Requirements:
- Existing vehicle record
- Admin confirmation

Fees: None
Processing Time: Instant

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Select Vehicle to Delete | Admin | Admin clicks Delete from the vehicle card (web: Actions column; mobile: three-dot menu). |
| ↓ **Confirm Deletion** | Admin | A confirmation dialog is shown: "Delete [Plate Number]? This cannot be undone." Admin must confirm. |
| ↓ **Delete from Firestore → End** | System | Vehicle document is permanently deleted from the `vehicles` collection. Success message is shown and the list updates in real time. |

---

**5. Auto-Compute PMS Status on App Start**
Service ID: JA-VMIS-05
Objective: To automatically re-evaluate and update the PMS status of all vehicles when the mobile app is launched, ensuring statuses reflect the current date.
Requirements:
- Existing vehicle records with `lastSvcDate` and `svcFreq` fields

Fees: None
Processing Time: Runs automatically on app initialization (background, a few seconds)

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → App Launches (Mobile) | System | `AdminVehiclesList` widget initializes and calls `_autoActivateVehicles()`. |
| ↓ **Query Completed Vehicles** | System | Firestore fetches all vehicles with `status == 'Completed'` that were completed at least 1 day ago. |
| ↓ **Evaluate Each Vehicle** | System | For each vehicle, `_computeStatus()` recalculates PMS status from `lastSvcDate` and `svcFreq`. |
| ↓ **Determine New Status** | System | Status is set to: Overdue (past due), PMS Due Soon (≤30 days), or Active (more than 30 days remaining). |
| ↓ **Update Firestore → End** | System | Vehicle document is updated with the new computed status. Real-time listener refreshes the list and dashboard automatically. |

---

**6. Search and Filter Vehicles**
Service ID: JA-VMIS-06
Objective: To allow administrators to quickly locate a specific vehicle by searching across plate number, description, or owner name.
Requirements:
- Existing vehicle records in the system

Fees: None
Processing Time: Instant (client-side filtering)

| Flowchart (Process Flow) | Persons Involved | Description |
|---|---|---|
| Start → Open Vehicle List | Admin | Admin opens the Vehicle List page on web or mobile. |
| ↓ **Activate Search** | Admin | Admin clicks the search icon (mobile) or types in the search bar (web). |
| ↓ **Enter Search Query** | Admin | Admin types a plate number, vehicle description, or owner name. |
| ↓ **Filter Vehicle List** | System | System filters the loaded vehicle list client-side, matching the query against plate, description, and owner fields (case-insensitive). |
| ↓ **Display Results → End** | System | Matching vehicles are shown in the list. If no match is found, "No vehicles found." message is displayed. |
