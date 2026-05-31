// Login page logic — standalone, no dependency on script.js

const accounts = {
    customer: { username: 'customer', password: 'customer123', name: 'John Doe', role: 'customer', avatar: 'JD' },
    staff:    { username: 'staff',    password: 'staff123',    name: 'Staff Member',  role: 'staff',    avatar: 'ST' },
    admin:    { username: 'admin',    password: 'admin123',    name: 'Administrator', role: 'admin',    avatar: 'AD' }
};

// Tab switching
document.getElementById('customerTab').addEventListener('click', () => switchTab('customer'));
document.getElementById('staffTab').addEventListener('click',    () => switchTab('staff'));
document.getElementById('adminTab').addEventListener('click',    () => switchTab('admin'));

function switchTab(type) {
    document.querySelectorAll('.login-tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.login-form-container').forEach(c => c.classList.remove('active'));
    document.getElementById(type + 'Tab').classList.add('active');
    document.getElementById(type + 'Login').classList.add('active');
}

// Customer login
document.getElementById('customerLoginForm').addEventListener('submit', function(e) {
    e.preventDefault();
    const u = document.getElementById('customerUsername').value.trim();
    const p = document.getElementById('customerPassword').value;
    if (u === accounts.customer.username && p === accounts.customer.password) {
        sessionStorage.setItem('cpUser', JSON.stringify(accounts.customer));
        window.location.href = 'customer_mobileview.html';
    } else {
        showError('customerLoginForm', 'Invalid username or password.');
    }
});

// Staff login
document.getElementById('staffLoginForm').addEventListener('submit', function(e) {
    e.preventDefault();
    const u = document.getElementById('staffUsername').value.trim();
    const p = document.getElementById('staffPassword').value;
    if (u === accounts.staff.username && p === accounts.staff.password) {
        sessionStorage.setItem('spUser', JSON.stringify(accounts.staff));
        window.location.href = 'staff_mobileview.html';
    } else {
        showError('staffLoginForm', 'Invalid username or password.');
    }
});

// Admin login
document.getElementById('adminLoginForm').addEventListener('submit', function(e) {
    e.preventDefault();
    const u = document.getElementById('adminUsername').value.trim();
    const p = document.getElementById('adminPassword').value;
    if (u === accounts.admin.username && p === accounts.admin.password) {
        sessionStorage.setItem('apUser', JSON.stringify(accounts.admin));
        window.location.href = 'admin.html';
    } else {
        showError('adminLoginForm', 'Invalid username or password.');
    }
});

function showError(formId, msg) {
    const form = document.getElementById(formId);
    let err = form.querySelector('.login-error');
    if (!err) {
        err = document.createElement('p');
        err.className = 'login-error';
        err.style.cssText = 'color:#E31E24;font-size:0.85rem;text-align:center;margin-top:0.75rem;font-weight:600;';
        form.appendChild(err);
    }
    err.textContent = msg;
}
