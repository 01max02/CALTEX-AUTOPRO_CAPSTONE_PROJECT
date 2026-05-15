# UML DIAGRAMS: USE CASE, ACTIVITY, SEQUENCE

---

## 1. USE CASE DIAGRAM
*(Actors and Interactions)*

```mermaid
graph LR
    Customer(["👤\nCustomer"])
    Staff(["👤\nStaff"])
    Admin(["👤\nAdmin"])
    System(["👤\nSystem"])

    subgraph Caltex AutoPro System
        UC1(["Register / Login"])
        UC2(["View PMS History"])
        UC3(["Receive Notifications"])
        UC4(["Smart AI Assistant"])
        UC5(["Log Maintenance Record"])
        UC6(["Manage Vehicle List"])
        UC7(["Manage Inventory"])
        UC8(["Manage Users"])
        UC9(["View Smart Reports"])
        UC10(["DSS Recommendations"])
        UC11(["Domain Management"])
        UC12(["Generate PMS Alerts"])
    end

    Customer --- UC1
    Customer --- UC2
    Customer --- UC3
    Customer --- UC4

    Staff --- UC1
    Staff --- UC5
    Staff --- UC6
    Staff --- UC7
    Staff --- UC3

    Admin --- UC1
    Admin --- UC6
    Admin --- UC7
    Admin --- UC8
    Admin --- UC9
    Admin --- UC10
    Admin --- UC11
    Admin --- UC5

    System --- UC12
    System --- UC3
    System --- UC10
```

**Legend:**
- 👤 Actor
- `([ ])` Use Case
- `---` Association

---

## 2. ACTIVITY DIAGRAM
*(Process Flow)*

```mermaid
flowchart TD
    A([●  Start]) --> B[Open Application\nWeb or Mobile]
    B --> C[Login / Register]
    C --> D{Authentication\nSuccessful?}
    D -- No --> C
    D -- Yes --> E{User Role?}

    E -- Customer --> F[View Customer Dashboard]
    F --> G[View PMS History]
    G --> H[Interact with Smart AI Assistant]
    H --> Z

    E -- Staff --> I[View Staff Dashboard]
    I --> J[Log Maintenance Record]
    J --> K[Update Vehicle Status]
    K --> L[Monitor Inventory]
    L --> Z

    E -- Admin --> M[View Admin Dashboard]
    M --> N[Manage Vehicles / Maintenance]
    N --> O[Manage Inventory\nStock · Issuances · Transactions]
    O --> P[Review DSS Recommendations]
    P --> Q[Generate Smart Reports]
    Q --> R[Manage Users and Domains]
    R --> Z

    Z([● End])
```

---

## 3. SEQUENCE DIAGRAM
*(Interaction Over Time)*

```mermaid
sequenceDiagram
    actor User
    participant App as Mobile App / Web
    participant System as Flask / Firebase SDK
    participant DB as Firestore Database
    participant Notif as OneSignal

    User->>App: 1. Open App and Login
    App->>System: 2. Authenticate via Firebase Auth
    System-->>App: 3. Auth Token Returned
    App-->>User: 4. Redirect to Role Dashboard

    User->>App: 5. Perform Action\n(e.g. Add Vehicle / Log Maintenance)
    App->>System: 6. Validate Input Fields
    System->>DB: 7. Save Record to Firestore Collection
    DB-->>System: 8. Record Saved Confirmation
    System-->>App: 9. Success Response
    App-->>User: 10. Show Success Message / Refresh List

    System->>DB: 11. Check PMS Status / Stock Levels
    DB-->>System: 12. Return Vehicle / Inventory Data
    System->>Notif: 13. Trigger Push Notification\n(if PMS Overdue / Low Stock)
    Notif-->>App: 14. Deliver Push Notification
    App-->>User: 15. Display Alert / Notification Badge
```

**Legend:**
- `—→` Request / Message
- `- - →` Response

---

## Diagram Summary

| Diagram | Purpose | Key Elements |
|---|---|---|
| **Use Case** | Shows what each actor can do in the system | Actors: Customer, Staff, Admin, System. Use Cases: Login, PMS History, Maintenance Logging, Inventory, Reports, DSS, Notifications |
| **Activity** | Shows the step-by-step process flow from login to role-based actions | Start → Login → Role Check → Role-specific workflow → End |
| **Sequence** | Shows how components interact over time for a typical user action | User ↔ App ↔ Firebase Auth ↔ Firestore ↔ OneSignal |
