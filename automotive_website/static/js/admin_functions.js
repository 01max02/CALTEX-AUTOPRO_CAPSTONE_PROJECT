// admin_functions.js — All functions required by admin.html

// ── Toast notification ──────────────────────────────────────
function showToast(msg, type) {
    var toast = document.getElementById('toast');
    if (!toast) return;
    toast.textContent = msg;
    toast.className = 'toast-visible toast-' + (type || 'success');
    clearTimeout(window._toastTimer);
    window._toastTimer = setTimeout(function() {
        toast.className = '';
    }, 3000);
}

// ── Shared state ────────────────────────────────────────────
var currentEditingAsset = null;
var currentEditingInventoryItem = null;
var currentEditingItemMaster = null;
var currentEditingDomain = null;
var currentEditingUser = null;
var currentEditingService = null;
var nextAssetId = (window.assets ? window.assets.length : 0) + 1;
var nextInventoryId = (window.inventory ? window.inventory.length : 0) + 1;
var nextServiceId = (window.serviceTransactions ? window.serviceTransactions.length : 0) + 1;
var nextIssuanceId = (window.issuances ? window.issuances.length : 0) + 1;
var nextItemMasterId = (window.itemMaster ? window.itemMaster.length : 0) + 1;

// ── Users ───────────────────────────────────────────────────
window.users = window.users || [
    { id: 1, name: 'Administrator', username: 'admin',    email: 'admin@janoble.com',    role: 'admin',    status: 'active', password: 'admin123',    createdAt: '2025-01-01' },
    { id: 2, name: 'Staff User',    username: 'staff',    email: 'staff@janoble.com',    role: 'staff',    status: 'active', password: 'staff123',    createdAt: '2025-01-01' },
    { id: 3, name: 'Customer One',  username: 'customer', email: 'customer@janoble.com', role: 'customer', status: 'active', password: 'customer123', createdAt: '2025-01-01' }
];
var users = window.users;
var nextUserId = users.length + 1;

// ── Navigation ──────────────────────────────────────────────
function switchAdminSection(sectionName) {
    var dashboard = document.getElementById('adminDashboard');
    if (!dashboard) return;

    dashboard.querySelectorAll('.admin-nav-btn').forEach(function(btn) { btn.classList.remove('active'); });
    var activeBtn = dashboard.querySelector('[data-section="' + sectionName + '"]');
    if (activeBtn) activeBtn.classList.add('active');

    dashboard.querySelectorAll('.admin-section').forEach(function(s) { s.classList.remove('active'); });
    var activeSection = dashboard.querySelector('#' + sectionName);
    if (activeSection) activeSection.classList.add('active');

    var titles = {
        'overview': 'Dashboard Overview',
        'assets': 'Vehicle List',
        'asset-servicing': 'Vehicle Maintenance',
        'issuance': 'Issuances',
        'inventory': 'Stock Inventory',
        'item-master': 'Item Master',
        'inventory-transactions': 'Inventory Transactions',
        'users': 'User Management',
        'smart-reports': 'Reports',
        'domains': 'Domain Management',
        'dss': 'Stock Replenishment DSS',
        'dss-pms': 'Preventive Maintenance Scheduling DSS'
    };
    var titleEl = document.getElementById('currentSectionTitle');
    if (titleEl) titleEl.textContent = titles[sectionName] || 'Admin Panel';

    // Show/hide header controls
    var txnCtrl = document.getElementById('txnHeaderControls');
    var issCtrl = document.getElementById('issuanceHeaderControls');
    if (txnCtrl) txnCtrl.style.display = sectionName === 'inventory-transactions' ? 'flex' : 'none';
    if (issCtrl) issCtrl.style.display = sectionName === 'issuance' ? 'flex' : 'none';

    if (sectionName === 'assets') renderAssetsList();
    if (sectionName === 'asset-servicing') renderServicesList();
    if (sectionName === 'issuance') renderIssuancesList();
    if (sectionName === 'item-master') { populateItemMasterDropdowns(); renderItemMasterList(); }
    if (sectionName === 'inventory-transactions') renderInventoryTransactions();
    if (sectionName === 'domains') renderDomainsList();
    if (sectionName === 'dss' && typeof renderDSS === 'function') renderDSS();
    if (sectionName === 'dss-pms' && typeof renderDSSPMS === 'function') renderDSSPMS();
    if (sectionName === 'users') renderUsersList();
}

function toggleAssetSubmenu(event) {
    event.stopPropagation();
    var submenu = document.getElementById('assetSubmenu');
    var isHidden = submenu.style.display === 'none';
    submenu.style.display = isHidden ? 'block' : 'none';
    var arrow = event.currentTarget.querySelector('span:last-child');
    if (arrow) arrow.textContent = isHidden ? '▲' : '▼';
}

function toggleInventorySubmenu(event) {
    event.stopPropagation();
    var submenu = document.getElementById('inventorySubmenu');
    var isHidden = submenu.style.display === 'none';
    submenu.style.display = isHidden ? 'block' : 'none';
    var arrow = event.currentTarget.querySelector('span:last-child');
    if (arrow) arrow.textContent = isHidden ? '▲' : '▼';
}

function toggleReportsSubmenu(event) {
    event.stopPropagation();
    var submenu = document.getElementById('reportsSubmenu');
    var isHidden = submenu.style.display === 'none';
    submenu.style.display = isHidden ? 'block' : 'none';
    var arrow = event.currentTarget.querySelector('span:last-child');
    if (arrow) arrow.textContent = isHidden ? '▲' : '▼';
}

function toggleDSSSubmenu(event) {
    event.stopPropagation();
    var submenu = document.getElementById('dssSubmenu');
    var isHidden = submenu.style.display === 'none';
    submenu.style.display = isHidden ? 'block' : 'none';
    var arrow = event.currentTarget.querySelector('span:last-child');
    if (arrow) arrow.textContent = isHidden ? '▲' : '▼';
}

// ── Modal helpers ───────────────────────────────────────────
function closeModal(modalId) {
    var el = document.getElementById(modalId);
    if (el) el.classList.remove('active');
}

function escapeHtml(str) {
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ── Assets ──────────────────────────────────────────────────
function renderAssetsList() {
    var assetsList = document.getElementById('assetsList');
    if (!assetsList) return;
    var assets = window.assets || [];

    if (assets.length === 0) {
        assetsList.innerHTML = '<div class="table-row" style="text-align:center;color:#718096;padding:2rem;">No assets found.</div>';
        return;
    }

    // Apply search filter
    var search = (document.getElementById('assetSearch') || {}).value || '';
    var filtered = assets;
    if (search.trim()) {
        var q = search.toLowerCase();
        filtered = assets.filter(function(a) {
            return (a.plateNumber||'').toLowerCase().includes(q)
                || (a.type||'').toLowerCase().includes(q)
                || (a.owner||'').toLowerCase().includes(q)
                || (a.assetDescription||'').toLowerCase().includes(q);
        });
    }

    var today = new Date(); today.setHours(0,0,0,0);

    function getStatusBadge(asset) {
        // Auto-reset completed → active after 1 day
        if (asset.status === 'completed' && asset.completedAt) {
            var completedDate = new Date(asset.completedAt); completedDate.setHours(0,0,0,0);
            var daysSince = Math.floor((today - completedDate) / 86400000);
            if (daysSince >= 1) {
                asset.status = 'active';
                asset.completedAt = null;
            }
        }
        if (asset.status === 'inactive') return '<span class="status-badge status-completed">Inactive</span>';
        if (asset.status === 'maintenance') return '<span class="status-badge" style="background:#bee3f8;color:#1a365d;border:1px solid #90cdf4;display:inline-flex;align-items:center;gap:0.35rem;padding:0.35rem 0.85rem;border-radius:20px;font-size:0.78rem;font-weight:700;">Under Maintenance</span>';
        if (asset.status === 'completed') return '<span class="status-badge" style="background:#c6f6d5;color:#276749;border:1px solid #9ae6b4;display:inline-flex;align-items:center;gap:0.35rem;padding:0.35rem 0.85rem;border-radius:20px;font-size:0.78rem;font-weight:700;">✅ Service Completed</span>';
        if (asset.nextPMSDue) {
            var due = new Date(asset.nextPMSDue); due.setHours(0,0,0,0);
            var diff = Math.ceil((due - today) / 86400000);
            if (diff < 0)  return '<span class="status-badge status-overdue">PMS Overdue</span>';
            if (diff <= 14) return '<span class="status-badge status-pending">PMS Due Soon</span>';
        }
        return '<span class="status-badge status-active">Active</span>';
    }

    if (filtered.length === 0) {
        assetsList.innerHTML = '<div class="table-row" style="text-align:center;color:#718096;padding:2rem;">No vehicles found.</div>';
        return;
    }

    // Sort alphabetically by plate number (same as mobile app)
    filtered = filtered.slice().sort(function(a, b) {
        return (a.plateNumber || '').localeCompare(b.plateNumber || '');
    });

    assetsList.innerHTML = filtered.map(function(asset) {
        return '<div class="table-row" style="grid-template-columns:1fr 1fr 1fr 1fr 1fr 1fr 120px;">'
            + '<div>' + asset.plateNumber + '</div>'
            + '<div>' + (asset.icon||'') + ' ' + (asset.type||'-') + '</div>'
            + '<div>' + (asset.owner||'-') + '</div>'
            + '<div>' + (asset.odometer ? asset.odometer.toLocaleString() + ' km' : '-') + '</div>'
            + '<div>' + (asset.lastServiceDate ? new Date(asset.lastServiceDate).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '-') + '</div>'
            + '<div>' + (asset.nextPMSDue ? new Date(asset.nextPMSDue).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '-') + '</div>'
            + '<div style="display:flex;gap:0.4rem;">'
            +   '<button class="btn-small btn-primary" onclick="viewAssetDetails(\'' + asset.assetNum + '\')" title="View" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>'
            +   '<button class="btn-small btn-secondary" onclick="editAsset(\'' + asset.assetNum + '\')" title="Edit" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>'
            +   '<button class="btn-small btn-danger" onclick="deleteAsset(\'' + asset.assetNum + '\')" title="Delete" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg></button>'
            + '</div></div>';
    }).join('');
}

function openAssetPlateScanModal() {
    document.getElementById('assetPlateScanInput').value = '';
    document.getElementById('assetPlateScanResult').innerHTML = '';
    document.getElementById('assetPlateScanModal').classList.add('active');
}

function searchAssetByScanPlate(query) {
    var resultEl = document.getElementById('assetPlateScanResult');
    var q = (query || '').trim().toLowerCase();
    if (!q) { resultEl.innerHTML = ''; return; }
    var assets = window.assets || [];
    var found = assets.filter(function(a){ return (a.plateNumber||'').toLowerCase().includes(q); });
    if (found.length === 0) {
        resultEl.innerHTML = '<div style="text-align:center;padding:1.5rem;color:#718096;background:white;border-radius:12px;border:1px solid #e2e8f0;"><div style="font-weight:600;">No asset found</div><div style="font-size:0.82rem;margin-top:0.25rem;color:#a0aec0;">No plate matching "' + escapeHtml(query) + '"</div></div>';
        return;
    }
    // Exact or single match — open details modal directly
    var exact = found.find(function(a){ return (a.plateNumber||'').toLowerCase() === q; });
    if (exact || found.length === 1) {
        var target = exact || found[0];
        closeModal('assetPlateScanModal');
        viewAssetDetails(target.assetNum);
        return;
    }
    // Multiple partial matches — show a pick list
    resultEl.innerHTML = '<div style="font-size:0.78rem;color:#718096;margin-bottom:0.5rem;">Multiple assets found — tap to view:</div>'
        + found.map(function(a){
            return '<div style="background:white;border-radius:12px;padding:0.85rem 1rem;margin-bottom:0.5rem;border:1px solid #e2e8f0;display:flex;align-items:center;justify-content:space-between;cursor:pointer;" onclick="closeModal(\'assetPlateScanModal\');viewAssetDetails(\''+a.assetNum+'\')">'
                + '<div style="display:flex;align-items:center;gap:0.65rem;">'
                +   '<div style="font-size:1.5rem;">'+(a.icon||'🚗')+'</div>'
                +   '<div>'
                +     '<div style="font-weight:700;color:#1a202c;font-size:0.92rem;">'+escapeHtml(a.plateNumber)+'</div>'
                +     '<div style="font-size:0.78rem;color:#718096;">'+escapeHtml(a.assetNum)+' · '+escapeHtml(a.assetDescription||a.type||'-')+'</div>'
                +   '</div>'
                + '</div>'
                + '<span style="color:#E31E24;font-size:0.8rem;font-weight:600;">View →</span>'
                + '</div>';
        }).join('');
}


function openAddAssetModal() {
    currentEditingAsset = null;
    var modal = document.getElementById('addAssetModal');
    if (!modal) return;
    document.getElementById('assetModalTitle').textContent = 'Add New Vehicle';
    document.getElementById('addAssetForm').reset();
    document.getElementById('assetNumDisplay').value = 'ASSET-' + String(nextAssetId).padStart(3,'0');
    modal.classList.add('active');
}

function viewAssetDetails(assetNum) {
    var assets = window.assets || [];
    var asset = assets.find(function(a){ return a.assetNum === assetNum; });
    if (!asset) return;
    var today = new Date(); today.setHours(0,0,0,0);
    var totalCost = (asset.maintenanceHistory||[]).reduce(function(s,r){ return s+(r.cost||0); },0);

    var displayStatus = asset.status;
    if (asset.status === 'active' && asset.nextPMSDue) {
        var due = new Date(asset.nextPMSDue); due.setHours(0,0,0,0);
        var diff = Math.ceil((due - today) / 86400000);
        if (diff < 0) displayStatus = 'pms_overdue';
        else if (diff <= 14) displayStatus = 'pms_due';
    }
    var statusMap = {
        active:       { bg:'#c6f6d5', color:'#276749', label:'Active' },
        maintenance:  { bg:'#bee3f8', color:'#1a365d', label:'Under Maintenance' },
        pms_due:      { bg:'#fefcbf', color:'#744210', label:'PMS Due Soon' },
        pms_overdue:  { bg:'#fed7d7', color:'#742a2a', label:'PMS Overdue' },
        inactive:     { bg:'#e2e8f0', color:'#2d3748', label:'Inactive' }
    };
    var st = statusMap[displayStatus] || statusMap.active;

    document.getElementById('adIcon').textContent = asset.icon || '🚗';
    document.getElementById('adAssetDesc').textContent = asset.assetDescription || asset.type;
    document.getElementById('adPlate').textContent = '🪪 ' + asset.plateNumber;
    document.getElementById('adAssetNum').textContent = asset.assetNum;
    document.getElementById('adStatusBadge').innerHTML = '<span style="background:'+st.bg+';color:'+st.color+';padding:0.35rem 0.85rem;border-radius:20px;font-size:0.8rem;font-weight:700;">'+st.label+'</span>';
    document.getElementById('adOdometer').textContent = asset.odometer ? asset.odometer.toLocaleString()+' km' : 'N/A';
    document.getElementById('adLastService').textContent = asset.lastServiceDate ? new Date(asset.lastServiceDate).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : 'N/A';
    document.getElementById('adNextPMS').textContent = asset.nextPMSDue ? new Date(asset.nextPMSDue).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : 'N/A';

    var infoItems = [
        { label:'Asset Number',          value: asset.assetNum||'N/A' },
        { label:'Plate Number',          value: asset.plateNumber||'N/A' },
        { label:'Asset Description',     value: asset.assetDescription||'N/A' },
        { label:'Asset Type',            value: asset.type ? asset.type.charAt(0).toUpperCase()+asset.type.slice(1) : 'N/A' },
        { label:'Owner',                 value: asset.owner||'N/A' },
        { label:'Current Odometer',      value: asset.odometer ? asset.odometer.toLocaleString()+' km' : 'N/A' },
        { label:'Last Service Odometer', value: asset.lastServiceOdometer ? asset.lastServiceOdometer.toLocaleString()+' km' : 'N/A' },
        { label:'Service Frequency',     value: asset.serviceFrequency ? 'Every '+asset.serviceFrequency+' month(s)' : 'N/A' }
    ];
    document.getElementById('adInfoGrid').innerHTML = infoItems.map(function(item){
        return '<div style="background:#f7fafc;border-radius:10px;padding:0.85rem 1rem;"><div style="font-size:0.72rem;color:#718096;font-weight:700;text-transform:uppercase;margin-bottom:0.3rem;">'+item.label+'</div><div style="font-weight:700;color:#1a202c;font-size:0.92rem;">'+item.value+'</div></div>';
    }).join('');

    document.getElementById('adTotalServices').textContent = (asset.maintenanceHistory||[]).length;
    document.getElementById('adTotalCost').textContent = '₱' + totalCost.toLocaleString();

    var history = asset.maintenanceHistory || [];
    var histEl = document.getElementById('adMaintenanceHistory');
    if (history.length === 0) {
        histEl.innerHTML = '<div style="text-align:center;padding:1.5rem;color:#a0aec0;font-size:0.88rem;">No maintenance history recorded.</div>';
    } else {
        histEl.innerHTML = '<div style="display:grid;grid-template-columns:100px 1fr 1fr 80px;gap:0.5rem;padding:0.4rem 0.5rem;border-bottom:2px solid #e2e8f0;font-size:0.68rem;font-weight:700;color:#a0aec0;text-transform:uppercase;">'
            + '<div>Date</div><div>Service</div><div>Parts</div><div style="text-align:right;">Cost</div>'
            + '</div>'
            + history.map(function(h) {
                return '<div style="display:grid;grid-template-columns:100px 1fr 1fr 80px;gap:0.5rem;padding:0.65rem 0.5rem;border-bottom:1px solid #f0f4f8;font-size:0.83rem;align-items:start;">'
                    + '<div style="color:#718096;">' + (h.date ? new Date(h.date).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '-') + '</div>'
                    + '<div style="color:#1a202c;font-weight:600;">' + escapeHtml(h.service||'-') + '</div>'
                    + '<div style="color:#4a5568;">' + escapeHtml(h.parts||'-') + '</div>'
                    + '<div style="color:#E31E24;font-weight:700;text-align:right;">₱' + (h.cost||0).toLocaleString() + '</div>'
                    + '</div>';
            }).join('');
    }

    document.getElementById('assetDetailsModal').classList.add('active');
}

function editAsset(assetNum) {
    var assets = window.assets || [];
    var asset = assets.find(function(a){ return a.assetNum === assetNum; });
    if (!asset) return;
    currentEditingAsset = asset;
    var form = document.getElementById('addAssetForm');
    form.elements.assetNum.value = asset.assetNum;
    form.elements.plateNumber.value = asset.plateNumber;
    form.elements.assetDescription.value = asset.assetDescription || '';
    form.elements.assetType.value = asset.type || '';
    form.elements.ownerName.value = asset.owner || '';
    form.elements.currentOdometer.value = asset.odometer || '';
    form.elements.lastServiceOdometer.value = asset.lastServiceOdometer || '';
    form.elements.serviceFrequency.value = asset.serviceFrequency || '';
    document.getElementById('assetModalTitle').textContent = 'Edit Asset';
    document.getElementById('addAssetModal').classList.add('active');
}

function deleteAsset(assetNum) {
    var assets = window.assets || [];
    var asset = assets.find(function(a){ return a.assetNum === assetNum; });
    if (!asset) return;
    if (confirm('Delete ' + asset.assetNum + ' (' + asset.assetDescription + ')? This cannot be undone.')) {
        window.assets = assets.filter(function(a){ return a.assetNum !== assetNum; });
        renderAssetsList();
    }
}

document.addEventListener('DOMContentLoaded', function() {
    var addAssetForm = document.getElementById('addAssetForm');
    if (addAssetForm) {
        addAssetForm.addEventListener('submit', function(e) {
            e.preventDefault();
            var form = e.target;
            var assets = window.assets || [];
            var plateNum = form.elements.plateNumber.value.trim().toUpperCase();
            var assetDesc = form.elements.assetDescription.value.trim();
            var assetType = form.elements.assetType.value.trim().toLowerCase();
            var owner = form.elements.ownerName.value.trim();
            var odometer = parseInt(form.elements.currentOdometer.value) || 0;
            var lastServiceOdo = parseInt(form.elements.lastServiceOdometer.value) || 0;
            var serviceFreq = parseInt(form.elements.serviceFrequency.value) || null;

            var lastServiceDate = null;
            var nextPMSDue = null;
            if (serviceFreq) {
                lastServiceDate = new Date().toISOString().split('T')[0];
                var next = new Date();
                next.setMonth(next.getMonth() + serviceFreq);
                nextPMSDue = next.toISOString().split('T')[0];
            }

            var typeIcons = { truck:'🚛', car:'🚗' };
            var icon = typeIcons[assetType] || '🚗';

            if (currentEditingAsset) {
                var asset = assets.find(function(a){ return a.assetNum === currentEditingAsset.assetNum; });
                if (asset) {
                    asset.plateNumber = plateNum;
                    asset.assetDescription = assetDesc;
                    asset.type = assetType;
                    asset.icon = icon;
                    asset.owner = owner;
                    asset.odometer = odometer;
                    asset.lastServiceOdometer = lastServiceOdo;
                    asset.serviceFrequency = serviceFreq;
                    if (serviceFreq && !asset.nextPMSDue) asset.nextPMSDue = nextPMSDue;
                }
                showToast('Vehicle updated successfully!', 'success');
            } else {
                var newAsset = {
                    id: nextAssetId, assetNum: 'ASSET-' + String(nextAssetId).padStart(3,'0'),
                    plateNumber: plateNum, assetDescription: assetDesc, type: assetType, icon: icon,
                    owner: owner, odometer: odometer, lastServiceOdometer: lastServiceOdo, status: 'active',
                    lastServiceDate: lastServiceDate, nextPMSDue: nextPMSDue,
                    serviceFrequency: serviceFreq, assignedMechanic: null, image: null,
                    meters: odometer ? [{ name:'Odometer', type:'continuous', value:String(odometer), unit:'km' }] : [],
                    maintenanceHistory: []
                };
                assets.push(newAsset);
                window.assets = assets;
                nextAssetId++;
                showToast('Vehicle added successfully!', 'success');
            }
            closeModal('addAssetModal');
            renderAssetsList();
        });
    }
});

// ── Services ────────────────────────────────────────────────
function renderServicesList() {
    var list = document.getElementById('servicesList');
    if (!list) return;
    var serviceTransactions = window.serviceTransactions || [];

    updateServiceStats();

    if (serviceTransactions.length === 0) {
        list.innerHTML = '<div class="table-row" style="text-align:center;color:#718096;padding:2rem;">No service transactions found.</div>';
        return;
    }

    var search = (document.getElementById('serviceSearch') || {}).value || '';
    var filtered = serviceTransactions;
    if (search.trim()) {
        var q = search.toLowerCase();
        filtered = serviceTransactions.filter(function(s){
            return (s.assetNum||'').toLowerCase().includes(q)
                || (s.assetDescription||'').toLowerCase().includes(q)
                || (s.mechanicName||'').toLowerCase().includes(q);
        });
    }

    if (filtered.length === 0) {
        list.innerHTML = '<div class="table-row" style="text-align:center;color:#718096;padding:2rem;">No services found.</div>';
        return;
    }

    list.innerHTML = filtered.map(function(s) {
        var statusColors = {
            'completed': { bg: 'rgba(56,161,105,0.1)', color: '#38a169' },
            'ongoing':   { bg: 'rgba(214,158,46,0.1)', color: '#d69e2e' },
            'pending':   { bg: 'rgba(113,128,150,0.1)', color: '#718096' },
        };
        var sc = statusColors[(s.status||'').toLowerCase()] || statusColors['pending'];
        var statusLabel = s.status ? s.status.charAt(0).toUpperCase()+s.status.slice(1) : 'Pending';
        var statusBadge = '<span style="background:' + sc.bg + ';color:' + sc.color + ';padding:0.25rem 0.75rem;border-radius:20px;font-size:0.78rem;font-weight:700;">' + statusLabel + '</span>';
        var topActions = '<button class="btn-small btn-primary" onclick="viewServiceDetails(\''+s.serviceId+'\')" title="View" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>';
        if (s.status === 'pending' || s.status === 'ongoing') {
            topActions += '<button class="btn-small btn-secondary" onclick="svcEditFromList(\''+s.serviceId+'\')" title="Edit" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>';
        } else {
            topActions += '<button class="btn-small btn-secondary" disabled title="Cannot edit completed service" style="display:inline-flex;align-items:center;justify-content:center;opacity:0.4;cursor:not-allowed;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>';
        }
        topActions += '<button class="btn-small btn-danger" onclick="deleteService(\''+s.serviceId+'\')" title="Delete" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg></button>';

        return '<div class="table-row" style="grid-template-columns:1fr 1fr 1.5fr 1fr 1fr 1fr 160px;">'
            + '<div>' + (s.dateServiced ? new Date(s.dateServiced).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '-') + '</div>'
            + '<div><strong>' + (s.assetNum||'-') + '</strong></div>'
            + '<div>' + (s.assetDescription||'-') + '</div>'
            + '<div>' + (s.mechanicName||'-') + '</div>'
            + '<div>₱' + ((s.totalCost||0).toLocaleString()) + '</div>'
            + '<div>' + statusBadge + '</div>'
            + '<div style="display:flex;gap:0.3rem;">' + topActions + '</div>'
            + '</div>';
    }).join('');
}

function updateServiceStats() {
    var serviceTransactions = window.serviceTransactions || [];
    var s = function(id, val) { var el = document.getElementById(id); if (el) el.textContent = val; };
    s('totalServices', serviceTransactions.length);
    s('ongoingServices', serviceTransactions.filter(function(x){ return x.status==='ongoing'; }).length);
    s('completedServices', serviceTransactions.filter(function(x){ return x.status==='completed'; }).length);
    s('pendingServices', serviceTransactions.filter(function(x){ return x.status==='pending'; }).length);
}

function approveService(serviceId) {
    var serviceTransactions = window.serviceTransactions || [];
    var s = serviceTransactions.find(function(x){ return x.serviceId === serviceId; });
    if (s && s.status === 'pending') { s.status = 'ongoing'; renderServicesList(); }
}

function completeService(serviceId) {
    var serviceTransactions = window.serviceTransactions || [];
    var s = serviceTransactions.find(function(x){ return x.serviceId === serviceId; });
    if (!s || s.status !== 'ongoing') return;
    s.status = 'completed';

    // Update asset last service date and next PMS
    var assets = window.assets || [];
    var asset = assets.find(function(a){ return a.assetNum === s.assetNum; });
    if (asset) {
        asset.lastServiceDate = s.dateServiced;
        asset.status = 'completed';
        asset.completedAt = new Date().toISOString().split('T')[0];
        if (asset.serviceFrequency) {
            var next = new Date(s.dateServiced);
            next.setMonth(next.getMonth() + asset.serviceFrequency);
            asset.nextPMSDue = next.toISOString().split('T')[0];
        }
        if (!asset.maintenanceHistory) asset.maintenanceHistory = [];
        asset.maintenanceHistory.unshift({
            date: s.dateServiced,
            service: (s.servicesRendered||[]).map(function(r){ return r.description; }).join(', ') || 'Service',
            parts: (s.spareParts||[]).map(function(p){ return p.name; }).join(', ') || 'None',
            km: asset.odometer || 0,
            cost: s.totalCost || 0
        });
    }

    // ── Post spare parts to issuances + deduct inventory ───
    var inventory = window.inventory || [];
    (s.spareParts || []).forEach(function(p) {
        // Deduct from inventory stock
        var invItem = inventory.find(function(i){ return i.itemNum === p.itemNum; });
        if (invItem) {
            invItem.stock = Math.max(0, invItem.stock - (p.quantity || 0));
            invItem.status = invItem.stock <= invItem.minLevel ? 'low_stock' : 'in_stock';
        }
        // Push to issuances
        window.issuances = window.issuances || [];
        window.issuances.push({
            id: nextIssuanceId++,
            date: s.dateServiced,
            assetNum: s.assetNum,
            itemNum: p.itemNum || '-',
            itemName: p.name || p.itemNum || '-',
            itemType: 'Material',
            commodityGroup: (invItem && invItem.commodityGroup) || '-',
            uom: p.uom || (invItem && invItem.unit) || '-',
            quantity: p.quantity || 0,
            unitCost: p.cost && p.quantity ? Math.round((p.cost / p.quantity) * 100) / 100 : (invItem && invItem.price) || 0,
            serviceId: s.serviceId,
            issuedBy: s.createdBy || 'Staff'
        });
    });

    // ── Post services rendered to issuances ────────────────
    (s.servicesRendered || []).forEach(function(r) {
        window.issuances = window.issuances || [];
        window.issuances.push({
            id: nextIssuanceId++,
            date: s.dateServiced,
            assetNum: s.assetNum,
            itemNum: '-',
            itemName: r.description || 'Service',
            itemType: 'Service',
            commodityGroup: 'AutoService',
            uom: r.uom || 'Service',
            quantity: r.quantity || 1,
            unitCost: r.cost || 0,
            serviceId: s.serviceId,
            issuedBy: s.createdBy || 'Staff'
        });
    });

    renderServicesList();
    renderAssetsList();
    renderInventoryList();
    renderIssuancesList();
    renderInventoryTransactions();
    showToast('Service marked as completed!', 'success');
}

function deleteService(serviceId) {
    if (!confirm('Delete this service transaction?')) return;

    // Delete from Firestore
    firebase.firestore().collection('maintenance').doc(serviceId).delete()
        .then(function () {
            // Also remove from local cache so the list updates immediately
            window.serviceTransactions = (window.serviceTransactions || []).filter(function (s) {
                return s.serviceId !== serviceId;
            });
            renderServicesList();
            if (typeof showToast === 'function') showToast('Service deleted successfully.', 'success');
        })
        .catch(function (err) {
            if (typeof showToast === 'function') showToast('Delete failed: ' + err.message, 'error');
        });
}

function viewServiceDetails(serviceId) {
    // Delegate to the new Firestore-backed implementation in admin_vehicle_maintenance.html
    if (typeof window._svcViewDetails === 'function') {
        window._svcViewDetails(serviceId);
    }
}

// Thin wrappers so table action buttons work
function svcEditFromList(docId) {
    if (typeof editService === 'function') editService(docId);
}
function svcApproveFromList(docId) {
    var db = firebase.firestore();
    if (!confirm('Approve this service and set status to Ongoing?')) return;
    db.collection('maintenance').doc(docId).update({ status: 'Ongoing' }).then(function() {
        db.collection('maintenance').doc(docId).get().then(function(doc) {
            if (doc.exists) {
                var plate = (doc.data().plate || '').trim().toUpperCase();
                db.collection('vehicles').where('plate', '==', plate).limit(1).get().then(function(vSnap) {
                    if (!vSnap.empty) vSnap.docs[0].ref.update({ status: 'Under Maintenance' });
                });
            }
        });
        showToast('Service approved — status set to Ongoing!', 'success');
    }).catch(function(err) { showToast('Error: ' + err.message, 'error'); });
}
function svcCompleteFromList(docId) {
    if (!confirm('Mark this service as Completed?')) return;
    // Open the details modal which has the full complete logic
    viewServiceDetails(docId);
}

function svcParseToInputDate(dateStr) {
    if (!dateStr) return '';
    var d = new Date(dateStr);
    if (isNaN(d.getTime())) return '';
    var y = d.getFullYear();
    var m = String(d.getMonth() + 1).padStart(2, '0');
    var day = String(d.getDate()).padStart(2, '0');
    return y + '-' + m + '-' + day;
}

function editService(docId) {
    var db = firebase.firestore();
    db.collection('maintenance').doc(docId).get().then(function(doc) {
        if (!doc.exists) return;
        var s = doc.data();
        s._docId = doc.id;

        window._svcEditingId = doc.id;
        document.getElementById('svcModalTitle').textContent = 'Edit Service';
        document.getElementById('svcSubmitBtn').innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg> Update';
        document.getElementById('svcModalIcon').innerHTML = '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>';

        var plate = s.plate || '';
        var inp = document.getElementById('svcPlateInput');
        if (inp) { inp.value = plate; }
        var hidden = document.getElementById('svcPlateSelect');
        if (hidden) { hidden.value = plate; }
        svcPlateSelect(plate);

        document.getElementById('svcMechanic').value = s.mechanic || '';
        // Convert stored date string to YYYY-MM-DD for the date input
        document.getElementById('svcDate').value = svcParseToInputDate(s.date || '');
        document.getElementById('svcSvcRows').innerHTML = '';
        document.getElementById('svcMatRows').innerHTML = '';
        (s.svcRows || []).forEach(function(r){ svcAddSvcRow(r.name, r.qty, r.uom, r.cost); });
        if (!s.svcRows || !s.svcRows.length) svcAddSvcRow();
        (s.matRows || []).forEach(function(r){ svcAddMatRow(r.name, r.qty, r.uom, r.cost); });
        if (!s.matRows || !s.matRows.length) svcAddMatRow();
        svcCalcTotal();
        document.getElementById('svcAddModal').classList.add('active');
    });
}

function openAddServiceModal() {
    currentEditingService = null;
    document.getElementById('addServiceModal').classList.add('active');
    document.getElementById('serviceModalTitle').textContent = 'New Service Transaction';
    document.getElementById('addServiceForm').reset();
    document.getElementById('serviceAssetNumDisplay').value = '';
    document.getElementById('serviceAssetNumHidden').value = '';
    document.getElementById('serviceAssetTypeDisplay').value = '';
    document.getElementById('serviceAssetDescription').value = '';
    document.getElementById('serviceRowsContainer').innerHTML = '';
    document.getElementById('materialRowsContainer').innerHTML = '';
    document.getElementById('totalCostDisplay').textContent = '₱0.00';
    addServiceRow();
    addMaterialRow();
}

function searchAssetByPlate(value) {
    var suggestions = document.getElementById('plateSuggestions');
    var query = value.trim().toUpperCase();
    if (!query) { suggestions.style.display = 'none'; return; }
    var assets = window.assets || [];
    var matches = assets.filter(function(a){ return a.plateNumber.includes(query); });
    if (!matches.length) { suggestions.style.display = 'none'; return; }
    suggestions.style.display = 'block';
    suggestions.innerHTML = matches.map(function(a){
        return '<div style="padding:0.75rem 1rem;cursor:pointer;border-bottom:1px solid #f0f4f8;" onmousedown="selectAssetFromSuggestion(\''+a.assetNum+'\')">'
            + '<strong>' + a.plateNumber + '</strong> — ' + a.assetDescription + '</div>';
    }).join('');
}

function selectAssetFromSuggestion(assetNum) {
    var assets = window.assets || [];
    var asset = assets.find(function(a){ return a.assetNum === assetNum; });
    if (!asset) return;
    document.getElementById('servicePlateSearch').value = asset.plateNumber;
    document.getElementById('serviceAssetNumDisplay').value = asset.assetNum;
    document.getElementById('serviceAssetNumHidden').value = asset.assetNum;
    document.getElementById('serviceAssetTypeDisplay').value = asset.type || '';
    document.getElementById('serviceAssetDescription').value = asset.assetDescription || '';
    document.getElementById('plateSuggestions').style.display = 'none';
}

function openServiceScanModal() {
    document.getElementById('serviceScanInput').value = '';
    document.getElementById('serviceScanModal').classList.add('active');
}

function applyScannedPlate() {
    var val = document.getElementById('serviceScanInput').value.trim().toUpperCase();
    if (val) {
        document.getElementById('servicePlateSearch').value = val;
        searchAssetByPlate(val);
    }
    closeModal('serviceScanModal');
}

function addServiceRow(desc, qty, uom, cost) {
    desc = desc||''; qty = qty||1; uom = uom||''; cost = cost||'';
    var container = document.getElementById('serviceRowsContainer');
    var row = document.createElement('div');
    row.className = 'service-row';
    row.style.cssText = 'display:grid;grid-template-columns:minmax(0,3fr) 70px minmax(0,1fr) 90px 32px;gap:0.4rem;margin-bottom:0.4rem;align-items:center;';

    // Build dropdown from AutoService items in itemMaster
    var autoServices = (window.itemMaster || []).filter(function(i){ return i.commodityGroup === 'AutoService'; });
    var opts = '<option value="">Select service...</option>' + autoServices.map(function(i){
        return '<option value="'+escapeHtml(i.itemName)+'" data-uom="'+escapeHtml(i.uom||'Hour')+'" data-cost="'+escapeHtml(String(i.cost||0))+'">'+escapeHtml(i.itemName)+'</option>';
    }).join('');

    row.innerHTML = '<select class="svc-item" style="padding:0.5rem;border:1px solid #e2e8f0;border-radius:6px;font-size:0.85rem;" onchange="onServiceItemChange(this)">'+opts+'</select>'
        + '<input type="number" class="svc-qty" placeholder="1" value="'+qty+'" min="0" step="0.01" style="padding:0.5rem;border:1px solid #e2e8f0;border-radius:6px;font-size:0.85rem;" oninput="calculateTotalCost()">'
        + '<input type="text" class="svc-uom" placeholder="UOM" value="'+escapeHtml(uom)+'" style="padding:0.5rem;border:1px solid #e2e8f0;border-radius:6px;font-size:0.85rem;">'
        + '<input type="number" class="svc-cost" placeholder="0.00" value="'+escapeHtml(String(cost))+'" min="0" step="0.01" style="padding:0.5rem;border:1px solid #e2e8f0;border-radius:6px;font-size:0.85rem;" oninput="calculateTotalCost()">'
        + '<button type="button" onclick="this.closest(\'.service-row\').remove();calculateTotalCost();" style="background:#fed7d7;border:none;border-radius:6px;cursor:pointer;color:#c53030;font-size:1rem;width:32px;height:32px;">×</button>';

    container.appendChild(row);

    // Set selected value if desc provided
    if (desc) {
        var sel = row.querySelector('.svc-item');
        // Try to match by value
        for (var i = 0; i < sel.options.length; i++) {
            if (sel.options[i].value === desc) { sel.selectedIndex = i; break; }
        }
    }
}

function onServiceItemChange(select) {
    var opt = select.options[select.selectedIndex];
    var row = select.closest('.service-row');
    if (opt && opt.dataset.uom) row.querySelector('.svc-uom').value = opt.dataset.uom;
    if (opt && opt.dataset.cost) row.querySelector('.svc-cost').value = opt.dataset.cost;
    calculateTotalCost();
}

// ── Material row scan ────────────────────────────────────────
var _materialScanTargetRow = null;

function openMaterialScanForRow(btn) {
    _materialScanTargetRow = btn.closest('.material-row');
    document.getElementById('materialRowScanInput').value = '';
    document.getElementById('materialRowScanResult').innerHTML = '';
    document.getElementById('materialRowScanModal').classList.add('active');
}

function searchMaterialByScan() {
    var q = (document.getElementById('materialRowScanInput').value || '').trim().toLowerCase();
    var resultEl = document.getElementById('materialRowScanResult');
    if (!q) { resultEl.innerHTML = ''; return; }

    // Search itemMaster by barcode, qrcode, itemNum, or name
    var items = (window.itemMaster || []).filter(function(i){
        return (i.barcode||'').toLowerCase() === q
            || (i.qrcode||'').toLowerCase() === q
            || (i.itemNum||'').toLowerCase() === q
            || (i.itemName||'').toLowerCase().includes(q);
    });

    // Also cross-reference inventory
    if (items.length === 0) {
        resultEl.innerHTML = '<div style="text-align:center;padding:1.25rem;color:#718096;background:#f7fafc;border-radius:10px;font-size:0.88rem;">No item found for "<strong>'+escapeHtml(q)+'</strong>"</div>';
        return;
    }

    resultEl.innerHTML = items.map(function(im){
        // Find matching inventory item
        var inv = (window.inventory||[]).find(function(i){ return i.itemNum === im.itemNum; });
        var invNum = inv ? inv.itemNum : im.itemNum;
        var unitCost = inv ? inv.price : (im.cost||0);
        var uom = inv ? inv.unit : (im.uom||'');
        var stock = inv ? inv.stock : 'N/A';
        return '<div style="background:white;border:1px solid #e2e8f0;border-radius:10px;padding:0.85rem 1rem;margin-bottom:0.5rem;cursor:pointer;" onclick="applyMaterialScan(\''+escapeHtml(invNum)+'\',\''+escapeHtml(String(unitCost))+'\',\''+escapeHtml(uom)+'\')">'
            + '<div style="font-weight:700;color:#1a202c;font-size:0.92rem;">'+escapeHtml(im.itemName)+'</div>'
            + '<div style="font-size:0.78rem;color:#718096;margin-top:2px;">'+escapeHtml(im.itemNum)+' · Stock: '+stock+' · ₱'+parseFloat(unitCost).toLocaleString()+'</div>'
            + '<div style="font-size:0.72rem;color:#3182ce;margin-top:4px;font-weight:600;">Tap to add →</div>'
            + '</div>';
    }).join('');
}

function applyMaterialScan(itemNum, cost, uom) {
    if (!_materialScanTargetRow) return;
    var sel = _materialScanTargetRow.querySelector('.mat-item');
    if (sel) {
        sel.value = itemNum;
        // If not in options, it won't match — that's fine, cost/uom still set
    }
    _materialScanTargetRow.querySelector('.mat-cost').value = cost;
    _materialScanTargetRow.querySelector('.mat-uom').value = uom;
    if (!_materialScanTargetRow.querySelector('.mat-qty').value) {
        _materialScanTargetRow.querySelector('.mat-qty').value = 1;
    }
    calculateTotalCost();
    closeModal('materialRowScanModal');
    _materialScanTargetRow = null;
}
function addMaterialRow(itemNum, qty, uom, cost) {
    itemNum = itemNum||''; qty = qty||''; uom = uom||''; cost = cost||'';
    var container = document.getElementById('materialRowsContainer');
    var row = document.createElement('div');
    row.className = 'material-row';
    row.style.cssText = 'display:grid;grid-template-columns:minmax(0,3fr) 70px minmax(0,1fr) 90px 32px 32px;gap:0.4rem;margin-bottom:0.4rem;align-items:center;';
    var inventory = window.inventory || [];
    var opts = '<option value="">Select item...</option>' + inventory.map(function(i){
        return '<option value="'+i.itemNum+'" data-cost="'+i.price+'" data-uom="'+i.unit+'">'+i.itemName+'</option>';
    }).join('');
    row.innerHTML = '<select class="mat-item" style="padding:0.5rem;border:1px solid #e2e8f0;border-radius:6px;font-size:0.85rem;" onchange="onMaterialItemChange(this)">'+opts+'</select>'
        + '<input type="number" class="mat-qty" placeholder="1" value="'+escapeHtml(String(qty))+'" min="0" step="0.01" style="padding:0.5rem;border:1px solid #e2e8f0;border-radius:6px;font-size:0.85rem;" oninput="calculateTotalCost()">'
        + '<input type="text" class="mat-uom" placeholder="UOM" value="'+escapeHtml(uom)+'" style="padding:0.5rem;border:1px solid #e2e8f0;border-radius:6px;font-size:0.85rem;">'
        + '<input type="number" class="mat-cost" placeholder="0.00" value="'+escapeHtml(String(cost))+'" min="0" step="0.01" style="padding:0.5rem;border:1px solid #e2e8f0;border-radius:6px;font-size:0.85rem;" oninput="calculateTotalCost()">'
        + '<button type="button" onclick="openMaterialScanForRow(this)" title="Scan barcode/QR" style="background:#ebf8ff;border:1px solid #bee3f8;border-radius:6px;cursor:pointer;color:#2b6cb0;font-size:0.85rem;width:32px;height:32px;display:flex;align-items:center;justify-content:center;">📷</button>'
        + '<button type="button" onclick="this.closest(\'.material-row\').remove();calculateTotalCost();" style="background:#fed7d7;border:none;border-radius:6px;cursor:pointer;color:#c53030;font-size:1rem;width:32px;height:32px;">×</button>';
    container.appendChild(row);
    if (itemNum) {
        var sel = row.querySelector('.mat-item');
        if (sel) sel.value = itemNum;
    }
}

function onMaterialItemChange(select) {
    var opt = select.options[select.selectedIndex];
    var row = select.closest('.material-row');
    if (opt && opt.dataset.cost) row.querySelector('.mat-cost').value = opt.dataset.cost;
    if (opt && opt.dataset.uom) row.querySelector('.mat-uom').value = opt.dataset.uom;
    calculateTotalCost();
}

function calculateTotalCost() {
    var total = 0;
    document.querySelectorAll('.service-row').forEach(function(row){
        var qty = parseFloat(row.querySelector('.svc-qty').value)||0;
        var cost = parseFloat(row.querySelector('.svc-cost').value)||0;
        total += qty * cost || cost;
    });
    document.querySelectorAll('.material-row').forEach(function(row){
        var qty = parseFloat(row.querySelector('.mat-qty').value)||0;
        var cost = parseFloat(row.querySelector('.mat-cost').value)||0;
        total += qty * cost || cost;
    });
    var el = document.getElementById('totalCostDisplay');
    if (el) el.textContent = '₱' + total.toLocaleString('en-PH',{minimumFractionDigits:2});
}

document.addEventListener('DOMContentLoaded', function() {
    var addServiceForm = document.getElementById('addServiceForm');
    if (addServiceForm) {
        addServiceForm.addEventListener('submit', function(e) {
            e.preventDefault();
            var form = e.target;
            var assetNum = document.getElementById('serviceAssetNumHidden').value;
            var assetDesc = form.elements.assetDescription.value.trim();
            var mechanic = form.elements.mechanicName.value.trim();
            var dateServiced = form.elements.dateServiced.value;

            var servicesRendered = [];
            document.querySelectorAll('.service-row').forEach(function(row){
                var sel = row.querySelector('.svc-item');
                var desc = sel ? sel.value.trim() : '';
                if (!desc) return;
                servicesRendered.push({
                    description: desc,
                    quantity: parseFloat(row.querySelector('.svc-qty').value)||1,
                    uom: row.querySelector('.svc-uom').value||'Hour',
                    cost: parseFloat(row.querySelector('.svc-cost').value)||0
                });
            });

            var spareParts = [];
            document.querySelectorAll('.material-row').forEach(function(row){
                var sel = row.querySelector('.mat-item');
                var itemNum = sel ? sel.value : '';
                if (!itemNum) return;
                var opt = sel.options[sel.selectedIndex];
                spareParts.push({
                    itemNum: itemNum,
                    name: opt ? opt.textContent : itemNum,
                    quantity: parseFloat(row.querySelector('.mat-qty').value)||1,
                    uom: row.querySelector('.mat-uom').value||'',
                    cost: parseFloat(row.querySelector('.mat-cost').value)||0
                });
            });

            var totalCost = servicesRendered.reduce(function(s,r){ return s+r.cost; },0)
                          + spareParts.reduce(function(s,p){ return s+(p.quantity*p.cost); },0);

            if (currentEditingService) {
                // Update existing service
                currentEditingService.dateServiced    = dateServiced;
                currentEditingService.assetDescription = assetDesc;
                currentEditingService.mechanicName    = mechanic;
                currentEditingService.servicesRendered = servicesRendered;
                currentEditingService.spareParts      = spareParts;
                currentEditingService.totalCost       = totalCost;
                currentEditingService = null;
                closeModal('addServiceModal');
                renderServicesList();
                alert('✅ Service transaction updated!');
                return;
            }

            var newService = {
                serviceId: 'SVC-' + String(nextServiceId).padStart(3,'0'),
                dateServiced: dateServiced,
                assetNum: assetNum,
                assetDescription: assetDesc,
                mechanicName: mechanic,
                servicesRendered: servicesRendered,
                spareParts: spareParts,
                status: 'pending',
                totalCost: totalCost,
                createdBy: (window.currentUser && window.currentUser.name) || 'Administrator',
                createdOn: new Date().toISOString()
            };

            // Deduct inventory
            spareParts.forEach(function(p){
                var inv = (window.inventory||[]).find(function(i){ return i.itemNum === p.itemNum; });
                if (inv) {
                    inv.stock = Math.max(0, inv.stock - p.quantity);
                    inv.status = inv.stock <= inv.minLevel ? 'low_stock' : 'in_stock';
                }
            });

            // Update asset status
            var assets = window.assets || [];
            var asset = assets.find(function(a){ return a.assetNum === assetNum; });
            if (asset) asset.status = 'maintenance';

            if (!window.serviceTransactions) window.serviceTransactions = [];
            window.serviceTransactions.push(newService);
            nextServiceId++;

            closeModal('addServiceModal');
            renderServicesList();
            renderAssetsList();
            renderInventoryList();
            alert('✅ Service transaction created!');
        });
    }
});

// ── Inventory ───────────────────────────────────────────────
function renderInventoryList() {
    var inventoryList = document.getElementById('inventoryList');
    if (!inventoryList) return;
    var inventory = window.inventory || [];

    var search = (document.getElementById('inventorySearch') || {}).value || '';
    var filtered = inventory;
    if (search.trim()) {
        var q = search.toLowerCase();
        filtered = inventory.filter(function(i){ return (i.itemName||'').toLowerCase().includes(q) || (i.itemNum||'').toLowerCase().includes(q); });
    }

    // Update stats
    var s = function(id,val){ var el=document.getElementById(id); if(el) el.textContent=val; };
    s('totalInventoryItems', inventory.length);
    s('lowStockCount', inventory.filter(function(i){ return i.stock <= i.minLevel; }).length);
    s('inStockCount', inventory.filter(function(i){ return i.stock > i.minLevel; }).length);

    if (filtered.length === 0) {
        inventoryList.innerHTML = '<div class="table-row" style="text-align:center;color:#718096;padding:2rem;">No inventory items found.</div>';
        return;
    }

    inventoryList.innerHTML = filtered.map(function(item) {
        var isLow = item.stock <= item.minLevel;
        var statusBadge = isLow
            ? '<span class="status-badge status-overdue">Low Stock</span>'
            : '<span class="status-badge status-active">In Stock</span>';
        return '<div class="table-row" style="grid-template-columns:100px 1.5fr 1fr 100px 90px 90px 90px 110px 110px;">'
            + '<div><strong>' + item.itemNum + '</strong></div>'
            + '<div>' + item.itemName + '</div>'
            + '<div>' + (item.commodityGroup||'-') + '</div>'
            + '<div style="font-weight:700;color:'+(isLow?'#e53e3e':'#1a202c')+';">' + item.stock + ' ' + (item.unit||'') + '</div>'
            + '<div>' + (item.minLevel||0) + '</div>'
            + '<div>' + (item.maxLevel||0) + '</div>'
            + '<div>' + (item.reorderQty || item.reorderLevel || '—') + '</div>'
            + '<div>' + statusBadge + '</div>'
            + '<div style="display:flex;gap:0.4rem;">'
            +   '<button class="btn-small btn-primary" onclick="viewInventoryItem(\''+item.id+'\')" title="View" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>'
            +   '<button class="btn-small btn-secondary" onclick="editInventoryItem(\''+item.id+'\')" title="Edit" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>'
            +   '<button class="btn-small btn-danger" onclick="deleteInventoryItem(\''+item.id+'\')" title="Delete" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg></button>'
            + '</div></div>';
    }).join('');
}

function openAddInventoryModal() {
    currentEditingInventoryItem = null;
    document.getElementById('inventoryModalTitle').textContent = 'Add New Inventory Item';
    document.getElementById('addInventoryForm').reset();
    document.getElementById('invItemPreview').style.display = 'none';
    document.getElementById('invScanFeedback').textContent = '';
    document.getElementById('addInventoryModal').classList.add('active');
}

function editInventoryItem(id) {
    var inventory = window.inventory || [];
    var item = inventory.find(function(i){ return i.id === id; });
    if (!item) return;
    currentEditingInventoryItem = item;
    document.getElementById('inventoryModalTitle').textContent = 'Edit Inventory Item';
    var form = document.getElementById('addInventoryForm');
    form.elements.stock.value = item.stock;
    form.elements.minLevel.value = item.minLevel;
    form.elements.maxLevel.value = item.maxLevel;
    form.elements.reorderQty.value = item.reorderQty || item.reorderLevel || '';
    document.getElementById('invItemNum').value = item.itemNum;
    document.getElementById('invItemName').value = item.itemName;
    document.getElementById('invDescription').value = item.longDescription || '';
    document.getElementById('invCommodityGroup').value = item.commodityGroup || '';
    document.getElementById('invUnit').value = item.unit || '';
    document.getElementById('invPrice').value = item.price || '';
    // Show preview
    document.getElementById('invPreviewNum').textContent = item.itemNum;
    document.getElementById('invPreviewName').textContent = item.itemName;
    document.getElementById('invPreviewGroup').textContent = item.commodityGroup || '-';
    document.getElementById('invPreviewUnitCost').textContent = (item.unit||'') + ' · ₱' + (item.price||0);
    document.getElementById('invPreviewDesc').textContent = item.longDescription || '-';
    document.getElementById('invItemPreview').style.display = 'block';
    document.getElementById('addInventoryModal').classList.add('active');
}

function viewInventoryItem(id) {
    var inventory = window.inventory || [];
    var item = inventory.find(function(i){ return i.id === id; });
    if (!item) return;

    var isLow = item.stock <= item.minLevel;
    var isOut = item.stock === 0;
    var statusLabel = isOut ? 'Out of Stock' : isLow ? 'Low Stock' : 'In Stock';
    var statusBg    = isOut ? '#fff5f5' : isLow ? '#fffbeb' : '#f0fff4';
    var statusColor = isOut ? '#c53030' : isLow ? '#b7791f' : '#276749';
    var statusBorder= isOut ? '#fc8181' : isLow ? '#f6e05e' : '#9ae6b4';

    var stockPct = item.maxLevel > 0 ? Math.min(100, Math.round((item.stock / item.maxLevel) * 100)) : 0;
    var barColor = isOut ? '#e53e3e' : isLow ? '#d69e2e' : '#38a169';

    var totalValue = (item.stock * (item.price || 0)).toLocaleString('en-PH', { minimumFractionDigits: 2 });
    var unitCost   = item.price ? '₱' + item.price.toLocaleString('en-PH', { minimumFractionDigits: 2 }) : '—';

    document.getElementById('invDetailBody').innerHTML =
        '<div style="display:flex;align-items:center;gap:1rem;margin-bottom:1.5rem;">'
        +   '<div style="font-size:2.5rem;background:#f0f4f8;width:64px;height:64px;border-radius:16px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">📦</div>'
        +   '<div style="flex:1;">'
        +     '<div style="font-size:1.15rem;font-weight:800;color:#1a202c;margin-bottom:0.3rem;">' + item.itemName + '</div>'
        +     '<div style="display:flex;align-items:center;gap:0.5rem;flex-wrap:wrap;">'
        +       '<span style="font-size:0.75rem;font-weight:700;color:#718096;background:#f0f4f8;padding:0.2rem 0.55rem;border-radius:6px;">' + item.itemNum + '</span>'
        +       '<span style="font-size:0.75rem;font-weight:600;color:#4a5568;">' + (item.commodityGroup || '—') + '</span>'
        +       '<span style="font-size:0.75rem;font-weight:700;padding:0.2rem 0.65rem;border-radius:20px;background:' + statusBg + ';color:' + statusColor + ';border:1px solid ' + statusBorder + ';">' + statusLabel + '</span>'
        +     '</div>'
        +   '</div>'
        + '</div>'
        // Stock bar
        + '<div style="background:#f7fafc;border-radius:12px;padding:1.1rem 1.25rem;margin-bottom:1.25rem;">'
        +   '<div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:0.6rem;">'
        +     '<span style="font-size:0.75rem;font-weight:700;color:#718096;text-transform:uppercase;letter-spacing:0.4px;">Stock Level</span>'
        +     '<span style="font-size:1.3rem;font-weight:900;color:' + barColor + ';">' + item.stock + ' <span style="font-size:0.8rem;font-weight:600;color:#718096;">' + (item.unit || '') + '</span></span>'
        +   '</div>'
        +   '<div style="width:100%;height:10px;background:#e2e8f0;border-radius:5px;overflow:hidden;margin-bottom:0.5rem;">'
        +     '<div style="height:100%;width:' + stockPct + '%;background:' + barColor + ';border-radius:5px;transition:width 0.4s;"></div>'
        +   '</div>'
        +   '<div style="display:flex;justify-content:space-between;font-size:0.72rem;color:#a0aec0;font-weight:600;">'
        +     '<span>0</span><span>Min: ' + item.minLevel + '</span><span>Max: ' + item.maxLevel + '</span>'
        +   '</div>'
        + '</div>'
        // Info grid
        + '<div style="display:grid;grid-template-columns:1fr 1fr;gap:0.75rem;margin-bottom:1.25rem;">'
        + _invDetailCard('Min Level',    item.minLevel + ' ' + (item.unit || ''))
        + _invDetailCard('Max Level',    item.maxLevel + ' ' + (item.unit || ''))
        + _invDetailCard('Reorder Qty',  (item.reorderQty || item.reorderLevel || '—') + ' ' + (item.unit || ''))
        + _invDetailCard('Unit Cost',    unitCost)
        + _invDetailCard('Total Value',  '₱' + totalValue)
        + _invDetailCard('Item ID',      item.itemId || '—')
        + '</div>'
        // Description
        + (item.longDescription
            ? '<div style="background:#f7fafc;border-radius:10px;padding:0.9rem 1.1rem;">'
            +   '<div style="font-size:0.72rem;font-weight:700;color:#718096;text-transform:uppercase;margin-bottom:0.4rem;">Description</div>'
            +   '<div style="font-size:0.88rem;color:#4a5568;line-height:1.6;">' + item.longDescription + '</div>'
            + '</div>'
            : '');

    document.getElementById('invDetailEditBtn').onclick = function () {
        closeModal('inventoryDetailsModal');
        editInventoryItem(id);
    };

    document.getElementById('inventoryDetailsModal').classList.add('active');
}

function _invDetailCard(label, value) {
    return '<div style="background:#f7fafc;border-radius:10px;padding:0.85rem 1rem;">'
        + '<div style="font-size:0.7rem;color:#718096;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;margin-bottom:0.3rem;">' + label + '</div>'
        + '<div style="font-weight:700;color:#1a202c;font-size:0.92rem;">' + value + '</div>'
        + '</div>';
}

function deleteInventoryItem(id) {
    if (!confirm('Delete this inventory item?')) return;
    window.inventory = (window.inventory||[]).filter(function(i){ return i.id !== id; });
    renderInventoryList();
}

function autofillInventoryFromScan(value) {
    var feedback = document.getElementById('invScanFeedback');
    var preview = document.getElementById('invItemPreview');
    if (!value.trim()) { if(preview) preview.style.display='none'; return; }
    var itemMaster = window.itemMaster || [];
    var found = itemMaster.find(function(i){ return i.barcode === value || i.qrcode === value || i.itemNum === value; });
    if (found) {
        document.getElementById('invItemNum').value = found.itemNum;
        document.getElementById('invItemName').value = found.itemName;
        document.getElementById('invDescription').value = found.description || '';
        document.getElementById('invCommodityGroup').value = found.commodityGroup || '';
        document.getElementById('invUnit').value = found.uom || '';
        document.getElementById('invPrice').value = found.cost || '';
        document.getElementById('invBarcode').value = found.barcode || '';
        document.getElementById('invQrcode').value = found.qrcode || '';
        document.getElementById('invPreviewNum').textContent = found.itemNum;
        document.getElementById('invPreviewName').textContent = found.itemName;
        document.getElementById('invPreviewGroup').textContent = found.commodityGroup || '-';
        document.getElementById('invPreviewUnitCost').textContent = (found.uom||'') + ' · ₱' + (found.cost||0);
        document.getElementById('invPreviewDesc').textContent = found.description || '-';
        preview.style.display = 'block';
        if (feedback) feedback.textContent = '✅ Item found: ' + found.itemName;
    } else {
        preview.style.display = 'none';
        if (feedback) feedback.textContent = '⚠️ No item found for this code.';
    }
}

function openInvScanModal() {
    document.getElementById('invScanModal').classList.add('active');
}

function applyInvScanModal() {
    var val = document.getElementById('invScanModalInput').value.trim();
    if (val) {
        document.getElementById('invScanInput').value = val;
        autofillInventoryFromScan(val);
    }
    closeModal('invScanModal');
}

function exportInventory() {
    alert('📊 Export Inventory Report\n\nThis would generate an Excel or PDF report.');
}

document.addEventListener('DOMContentLoaded', function() {
    var addInventoryForm = document.getElementById('addInventoryForm');
    if (addInventoryForm) {
        addInventoryForm.addEventListener('submit', function(e) {
            e.preventDefault();
            var form = e.target;
            var inventory = window.inventory || [];
            var stock = parseInt(form.elements.stock.value)||0;
            var minLevel = parseInt(form.elements.minLevel.value)||0;
            var maxLevel = parseInt(form.elements.maxLevel.value)||0;
            var reorderQty = parseInt(form.elements.reorderQty.value)||0;
            var itemNum = document.getElementById('invItemNum').value;
            var itemName = document.getElementById('invItemName').value;

            if (!itemNum || !itemName) { alert('⚠️ Please scan or select an item first.'); return; }

            if (currentEditingInventoryItem) {
                var item = inventory.find(function(i){ return i.id === currentEditingInventoryItem.id; });
                if (item) {
                    item.stock = stock; item.minLevel = minLevel; item.maxLevel = maxLevel;
                    item.reorderQty = reorderQty; item.reorderLevel = reorderQty;
                    item.status = stock <= minLevel ? 'low_stock' : 'in_stock';
                }
                alert('✅ Inventory item updated!');
            } else {
                var newItem = {
                    id: nextInventoryId++,
                    itemNum: itemNum,
                    itemName: itemName,
                    longDescription: document.getElementById('invDescription').value,
                    commodityGroup: document.getElementById('invCommodityGroup').value,
                    unit: document.getElementById('invUnit').value,
                    price: parseFloat(document.getElementById('invPrice').value)||0,
                    barcode: document.getElementById('invBarcode').value,
                    qrcode: document.getElementById('invQrcode').value,
                    stock: stock, minLevel: minLevel, maxLevel: maxLevel,
                    reorderQty: reorderQty, reorderLevel: reorderQty,
                    status: stock <= minLevel ? 'low_stock' : 'in_stock',
                    lastPhysicalCount: new Date().toISOString().split('T')[0]
                };
                inventory.push(newItem);
                window.inventory = inventory;
                alert('✅ Inventory item added!');
            }
            closeModal('addInventoryModal');
            renderInventoryList();
        });
    }
});

function openStaffReceiveDeliveryModal() {
    document.getElementById('staffReceiveDeliveryModal').classList.add('active');
    var info = document.getElementById('deliveryItemInfo');
    if (info) info.style.display = 'none';
}

// ── Inventory Transactions ──────────────────────────────────
function renderInventoryTransactions(filter) {
    filter = filter || '';

    // Use Firebase transactions data
    var txns = (window._fbTransactions || []).map(function(t) {
        return {
            date: t.date || '',
            item: t.item || t.name || '—',
            description: (t.desc || t.description || '—')
                .replace(/for maintenance SVC-\d+\s*[—\-]\s*/gi, 'for ')
                .replace(/for maintenance SVC-\d+/gi, '')
                .replace(/\s*SVC-\d+\s*/gi, '')
                .trim() || '—',
            type: (t.type || 'IN').toUpperCase(),
            qty: t.qty || t.quantity || 0,
            by: t.by || t.performedBy || '—'
        };
    });

    var s = function(id, val) { var el = document.getElementById(id); if (el) el.textContent = val; };
    s('txnTotal', txns.length);
    s('txnIn',  txns.filter(function(t){ return t.type === 'IN'; }).length);
    s('txnOut', txns.filter(function(t){ return t.type === 'OUT'; }).length);

    var search = (document.getElementById('txnSearch') || {}).value || '';
    var filtered = txns;
    if (search.trim()) {
        var q = search.toLowerCase();
        filtered = txns.filter(function(t) {
            return (t.item + t.description + t.by).toLowerCase().includes(q);
        });
    }

    var list = document.getElementById('txnList');
    if (!list) return;
    if (filtered.length === 0) {
        list.innerHTML = '<div class="table-row" style="text-align:center;color:#718096;padding:2rem;">No transactions found.</div>';
        return;
    }
    list.innerHTML = filtered.map(function(t) {
        var isIn = t.type === 'IN';
        var typeColor = isIn ? '#003087' : '#E8001C';
        var typeBg    = isIn ? '#ebf8ff' : '#fed7d7';
        var dateStr = t.date ? t.date : '—';
        return '<div class="table-row" style="grid-template-columns:120px 1fr 1.5fr 80px 80px 100px;">'
            + '<div>' + dateStr + '</div>'
            + '<div><strong>' + t.item + '</strong></div>'
            + '<div>' + t.description + '</div>'
            + '<div><span style="background:' + typeBg + ';color:' + typeColor + ';padding:0.2rem 0.6rem;border-radius:20px;font-size:0.78rem;font-weight:700;">' + t.type + '</span></div>'
            + '<div>' + t.qty + '</div>'
            + '<div>' + t.by + '</div>'
            + '</div>';
    }).join('');
}

function exportInventoryTransactions() {
    window.print();
}

// ── Item Master ─────────────────────────────────────────────
function renderItemMasterList() {
    var list = document.getElementById('itemMasterList');
    if (!list) return;
    var itemMaster = window.itemMaster || [];

    var search = (document.getElementById('itemMasterSearch')||{}).value || '';
    var filtered = itemMaster;
    if (search.trim()) {
        var q = search.toLowerCase();
        filtered = itemMaster.filter(function(i){ return (i.itemName||'').toLowerCase().includes(q) || (i.itemNum||'').toLowerCase().includes(q); });
    }

    // Sort by item number sequentially (ITM-001, ITM-002, ...)
    filtered = filtered.slice().sort(function(a, b) {
        var na = parseInt((a.itemNum || '').replace(/[^0-9]/g, '')) || 0;
        var nb = parseInt((b.itemNum || '').replace(/[^0-9]/g, '')) || 0;
        return na - nb;
    });

    if (filtered.length === 0) {
        list.innerHTML = '<div class="table-row" style="text-align:center;color:#718096;padding:2rem;">No items found.</div>';
        return;
    }

    list.innerHTML = filtered.map(function(item) {
        return '<div class="table-row" style="grid-template-columns:1fr 1fr 1.5fr 1fr 1fr 1fr 1fr 120px;">'
            + '<div><strong>' + item.itemNum + '</strong></div>'
            + '<div>' + item.itemName + '</div>'
            + '<div>' + (item.description||'-') + '</div>'
            + '<div>' + (item.commodityGroup||'-') + '</div>'
            + '<div>' + (item.uom||'-') + '</div>'
            + '<div><span style="background:'+(item.itemType==='Service'?'#ebf8ff':'#f0fff4')+';color:'+(item.itemType==='Service'?'#2c5282':'#276749')+';padding:0.2rem 0.6rem;border-radius:20px;font-size:0.78rem;font-weight:700;">' + (item.itemType||'-') + '</span></div>'
            + '<div>₱' + (parseFloat(String(item.cost||0).replace(/[₱,]/g,''))||0).toLocaleString('en-PH',{minimumFractionDigits:2}) + '</div>'
            + '<div style="display:flex;gap:0.4rem;">'
            +   '<button class="btn-small btn-primary" onclick="viewItemMasterDetails(\'' + item.itemNum + '\')" title="View" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>'
            +   '<button class="btn-small btn-secondary" onclick="editItemMaster(\'' + item.itemNum + '\')" title="Edit" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>'
            +   '<button class="btn-small btn-danger" onclick="deleteItemMaster(\'' + item.itemNum + '\')" title="Delete" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg></button>'
            + '</div></div>';
    }).join('');
}

function populateItemMasterDropdowns() {
    var db = firebase.firestore();

    // Commodity Groups from Firestore domains/commodity_groups/items
    db.collection('domains').doc('commodity_groups').collection('items').orderBy('name').get().then(function(snap) {
        var cgList = snap.docs.map(function(d){ return d.data().name || ''; }).filter(Boolean);
        if (!cgList.length) cgList = ['Lubricants','Spare Parts','Filter','AutoService'];
        var cgSel = document.getElementById('itemMasterCommodityGroup');
        if (cgSel) cgSel.innerHTML = '<option value="">Select group</option>' + cgList.map(function(v){ return '<option value="'+v+'">'+v+'</option>'; }).join('');
    });

    // UOM from Firestore domains/uom/items
    db.collection('domains').doc('uom').collection('items').orderBy('name').get().then(function(snap) {
        var uomList = snap.docs.map(function(d){ return d.data().name || ''; }).filter(Boolean);
        if (!uomList.length) uomList = ['pcs','L','set','job','kg','box','pair','m'];
        var uomSel = document.getElementById('itemMasterUOM');
        if (uomSel) uomSel.innerHTML = '<option value="">Select UOM</option>' + uomList.map(function(v){ return '<option value="'+v+'">'+v+'</option>'; }).join('');
    });
}

function populateVehicleTypeDropdown(selectId, currentVal) {
    var sel = document.getElementById(selectId || 'assetTypeSelect');
    if (!sel) return;
    firebase.firestore().collection('domains').doc('vehicle_types').collection('items').orderBy('name').get().then(function(snap) {
        var types = snap.docs.map(function(d){ return d.data().name || ''; }).filter(Boolean);
        if (!types.length) types = ['Truck','SUV','Sedan','Van','Motorcycle','Bus','Pickup'];
        sel.innerHTML = '<option value="">Select type</option>' + types.map(function(v){
            return '<option value="'+v+'"' + (currentVal === v ? ' selected' : '') + '>'+v+'</option>';
        }).join('');
    });
}

function onItemMasterCommodityGroupChange(select) {
    var val = select.value;
    var typeEl = document.getElementById('itemMasterItemType');
    var uomEl = document.getElementById('itemMasterUOM');
    if (val === 'AutoService') {
        if (typeEl) typeEl.value = 'Service';
        if (uomEl) uomEl.value = 'Hour';
    } else if (val) {
        if (typeEl) typeEl.value = 'Material';
    }
    var barcodeRow = document.getElementById('imBarcodeQRRow');
    if (barcodeRow) barcodeRow.style.display = (val === 'AutoService') ? 'none' : 'grid';
}

function openAddItemMasterModal() {
    currentEditingItemMaster = null;
    document.getElementById('itemMasterModalTitle').textContent = 'Add Item';
    var submitBtn = document.getElementById('imSubmitBtn');
    if (submitBtn) submitBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg> Save';
    var icon = document.getElementById('imModalIcon');
    if (icon) icon.innerHTML = '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>';
    document.getElementById('addItemMasterForm').reset();
    populateItemMasterDropdowns();
    var itemMaster = window.itemMaster || [];
    // Find highest existing ITM-XXX number and increment — same as mobile app
    var maxNum = 0;
    itemMaster.forEach(function(i) {
        var n = parseInt((i.itemNum || '').replace(/[^0-9]/g, '')) || 0;
        if (n > maxNum) maxNum = n;
    });
    document.getElementById('itemMasterItemNum').value = 'ITM-' + String(maxNum + 1).padStart(3, '0');
    document.getElementById('addItemMasterModal').classList.add('active');
}

function editItemMaster(itemNum) {
    var itemMaster = window.itemMaster || [];
    var item = itemMaster.find(function(i){ return i.itemNum === itemNum; });
    if (!item) return;
    currentEditingItemMaster = item;

    document.getElementById('itemMasterModalTitle').textContent = 'Edit Item';
    var submitBtn = document.getElementById('imSubmitBtn');
    if (submitBtn) submitBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg> Update';
    var icon = document.getElementById('imModalIcon');
    if (icon) icon.innerHTML = '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>';

    var form = document.getElementById('addItemMasterForm');
    form.elements.itemNum.value = item.itemNum;
    form.elements.itemName.value = item.itemName;
    form.elements.description.value = item.description || '';
    form.elements.sku.value = item.sku || '';
    form.elements.cost.value = item.cost || '';
    form.elements.itemType.value = item.itemType || '';
    form.elements.barcode.value = item.barcode || '';
    form.elements.qrcode.value = item.qrcode || '';

    // Populate dropdowns from Firestore then set saved values
    var db = firebase.firestore();
    db.collection('domains').doc('commodity_groups').collection('items').orderBy('name').get().then(function(snap) {
        var cgList = snap.docs.map(function(d){ return d.data().name || ''; }).filter(Boolean);
        if (!cgList.length) cgList = ['Lubricants','Spare Parts','Filter','AutoService'];
        var cgSel = document.getElementById('itemMasterCommodityGroup');
        if (cgSel) {
            cgSel.innerHTML = '<option value="">Select group</option>' + cgList.map(function(v){
                return '<option value="'+v+'"' + (item.commodityGroup === v ? ' selected' : '') + '>'+v+'</option>';
            }).join('');
        }
    });
    db.collection('domains').doc('uom').collection('items').orderBy('name').get().then(function(snap) {
        var uomList = snap.docs.map(function(d){ return d.data().name || ''; }).filter(Boolean);
        if (!uomList.length) uomList = ['pcs','L','set','job','kg','box','pair','m'];
        var uomSel = document.getElementById('itemMasterUOM');
        if (uomSel) {
            uomSel.innerHTML = '<option value="">Select UOM</option>' + uomList.map(function(v){
                return '<option value="'+v+'"' + (item.uom === v ? ' selected' : '') + '>'+v+'</option>';
            }).join('');
        }
    });

    document.getElementById('addItemMasterModal').classList.add('active');
}

function deleteItemMaster(itemNum) {
    if (!confirm('Delete item ' + itemNum + '?')) return;
    var fbItem = (window._fbItemMaster || []).find(function(i){ return i.num === itemNum; });
    if (!fbItem || !fbItem._id) { alert('Item not found in database.'); return; }
    firebase.firestore().collection('item_master').doc(fbItem._id).delete()
        .then(function() { showToast('Item deleted successfully!', 'success'); })
        .catch(function(err) { showToast('Delete failed: ' + err.message, 'error'); });
}

function viewItemMasterDetails(itemNum) {
    var itemMaster = window.itemMaster || [];
    var item = itemMaster.find(function(i){ return i.itemNum === itemNum; });
    if (!item) return;
    var isSvc = item.itemType === 'Service';

    // Header color — red for Material, blue for Service
    var header = document.getElementById('imDetailHeader');
    if (header) header.style.background = isSvc
        ? 'linear-gradient(135deg,#003087,#00205b)'
        : 'linear-gradient(135deg,#E31E24,#C41E3A)';

    var iconWrap = document.getElementById('imDetailIconWrap');
    if (iconWrap) {
        var iconEl = document.getElementById('imDetailIcon');
        if (iconEl) {
            iconEl.innerHTML = isSvc
                ? '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>'
                : '<polyline points="21 8 21 21 3 21 3 8"/><rect x="1" y="3" width="22" height="5"/><line x1="10" y1="12" x2="14" y2="12"/>';
        }
    }

    var nameEl = document.getElementById('imItemName');
    if (nameEl) nameEl.textContent = item.itemName;

    var groupEl = document.getElementById('imGroupBadge');
    if (groupEl) groupEl.textContent = item.commodityGroup || '—';

    // Detail rows — same as mobile _detailRow
    var rows = [
        ['Item Number', item.itemNum || '—'],
        ['SKU', item.sku || '—'],
        ['Item Name', item.itemName || '—'],
        ['Description', item.description || '—'],
        ['Commodity Group', item.commodityGroup || '—'],
        ['UOM', item.uom || '—'],
        ['Cost', '₱' + (parseFloat(String(item.cost||0).replace(/[₱,]/g,''))||0).toLocaleString('en-PH',{minimumFractionDigits:2})],
        ['Type', item.itemType || '—'],
    ];
    var rowsEl = document.getElementById('imDetailRows');
    if (rowsEl) rowsEl.innerHTML = rows.map(function(r) {
        return '<div style="display:flex;padding:0.55rem 0;border-bottom:1px solid #f7fafc;">'
            + '<span style="width:130px;flex-shrink:0;font-size:0.8rem;color:#718096;font-weight:500;">' + r[0] + '</span>'
            + '<span style="font-size:0.85rem;font-weight:600;color:#1a202c;flex:1;">' + r[1] + '</span>'
            + '</div>';
    }).join('');

    // Barcode/QR — only for Material
    var scanSection = document.getElementById('imScanSection');
    if (scanSection) {
        if (!isSvc) {
            scanSection.style.display = 'block';
            var barcodeEl = document.getElementById('imBarcode');
            var qrEl = document.getElementById('imQR');
            if (barcodeEl) barcodeEl.textContent = item.barcode || '—';
            if (qrEl) qrEl.textContent = item.qrcode || '—';

            // Render barcode image
            var barcodeSvg = document.getElementById('imBarcodeImg');
            if (barcodeSvg && item.barcode && typeof JsBarcode !== 'undefined') {
                try {
                    JsBarcode(barcodeSvg, item.barcode, {
                        format: 'CODE128',
                        width: 1.8,
                        height: 60,
                        displayValue: false,
                        margin: 4,
                    });
                    barcodeSvg.style.display = 'block';
                } catch(e) {
                    barcodeSvg.style.display = 'none';
                }
            } else if (barcodeSvg) {
                barcodeSvg.style.display = 'none';
            }

            // Render QR code image
            var qrImgEl = document.getElementById('imQRImg');
            if (qrImgEl) {
                qrImgEl.innerHTML = '';
                if (item.qrcode && typeof QRCode !== 'undefined') {
                    try {
                        new QRCode(qrImgEl, {
                            text: item.qrcode,
                            width: 128,
                            height: 128,
                            colorDark: '#1a202c',
                            colorLight: '#ffffff',
                            correctLevel: QRCode.CorrectLevel.M,
                        });
                    } catch(e) {
                        qrImgEl.textContent = item.qrcode;
                    }
                } else if (qrImgEl && !item.qrcode) {
                    qrImgEl.textContent = '—';
                }
            }
        } else {
            scanSection.style.display = 'none';
        }
    }

    // Edit button
    var editBtn = document.getElementById('imDetailEditBtn');
    if (editBtn) {
        editBtn.onclick = function() {
            closeModal('itemMasterDetailsModal');
            editItemMaster(itemNum);
        };
    }

    document.getElementById('itemMasterDetailsModal').classList.add('active');
}

function generateItemMasterBarcode() {
    var el = document.getElementById('itemMasterBarcode');
    if (el) el.value = String(Math.floor(Math.random()*9000000000000)+1000000000000);
}

function generateItemMasterQRCode() {
    var el = document.getElementById('itemMasterQRCode');
    var num = document.getElementById('itemMasterItemNum');
    if (el) el.value = 'QR-' + (num ? num.value : 'ITM-' + Date.now());
}

function openItemMasterScanModal() {
    document.getElementById('itemMasterScanInput').value = '';
    document.getElementById('itemMasterScanModal').classList.add('active');
}

document.addEventListener('DOMContentLoaded', function() {
    var addItemMasterForm = document.getElementById('addItemMasterForm');
    if (addItemMasterForm) {
        addItemMasterForm.addEventListener('submit', function(e) {
            e.preventDefault();
            var form = e.target;
            var itemNum = form.elements.itemNum.value.trim();
            var itemName = form.elements.itemName.value.trim();
            if (!itemName) { alert('Item Name is required.'); return; }

            var data = {
                num:    itemNum,
                name:   itemName,
                desc:   form.elements.description.value.trim(),
                sku:    form.elements.sku.value.trim(),
                group:  form.elements.commodityGroup.value,
                uom:    form.elements.uom.value,
                cost:   parseFloat(form.elements.cost.value) || 0,
                type:   form.elements.itemType.value,
                barcode: form.elements.barcode.value.trim(),
                qr:     form.elements.qrcode.value.trim(),
            };

            var db = firebase.firestore();

            if (currentEditingItemMaster) {
                var fbItem = (window._fbItemMaster || []).find(function(i){ return i.num === currentEditingItemMaster.itemNum; });
                if (!fbItem || !fbItem._id) { alert('Item not found in database.'); return; }
                var submitBtn = document.getElementById('imSubmitBtn');
                if (submitBtn) { submitBtn.disabled = true; submitBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="animation:spin 0.8s linear infinite"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-.49-4.49"/></svg> Updating…'; }
                db.collection('item_master').doc(fbItem._id).update(data)
                    .then(function() {
                        showToast('Item updated successfully!', 'success');
                        closeModal('addItemMasterModal');
                    })
                    .catch(function(err) { showToast('Update failed: ' + err.message, 'error'); })
                    .finally(function() { if (submitBtn) { submitBtn.disabled = false; submitBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg> Update'; } });
            } else {
                var isDuplicate = (window.itemMaster || []).some(function(i){ return i.itemNum === itemNum; });
                if (isDuplicate) { alert('Item Number already exists.'); return; }
                data.createdAt = firebase.firestore.FieldValue.serverTimestamp();
                var submitBtn2 = document.getElementById('imSubmitBtn');
                if (submitBtn2) { submitBtn2.disabled = true; submitBtn2.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="animation:spin 0.8s linear infinite"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-.49-4.49"/></svg> Saving…'; }
                db.collection('item_master').add(data)
                    .then(function() {
                        showToast('Item added successfully!', 'success');
                        closeModal('addItemMasterModal');
                    })
                    .catch(function(err) { showToast('Save failed: ' + err.message, 'error'); })
                    .finally(function() { if (submitBtn2) { submitBtn2.disabled = false; submitBtn2.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg> Save'; } });
            }
        });
    }
});

// ── Issuances ───────────────────────────────────────────────
function renderIssuancesList() {
    var list = document.getElementById('issuancesList');
    if (!list) return;
    var issuances = window.issuances || [];

    var s = function(id,val){ var el=document.getElementById(id); if(el) el.textContent=val; };
    s('totalIssuances', issuances.length);
    s('totalIssuanceServices', issuances.filter(function(i){ return i.itemType==='Service'; }).length);
    s('totalMaterials', issuances.filter(function(i){ return i.itemType!=='Service'; }).length);

    // Filter by search
    var q = ((document.getElementById('issuanceSearch') || {}).value || '').trim().toLowerCase();
    var filtered = q ? issuances.filter(function(i) {
        return (i.assetNum||'').toLowerCase().includes(q)
            || (i.itemNum||'').toLowerCase().includes(q)
            || (i.itemName||'').toLowerCase().includes(q)
            || (i.itemType||'').toLowerCase().includes(q)
            || (i.commodityGroup||'').toLowerCase().includes(q)
            || (i.date||'').toLowerCase().includes(q);
    }) : issuances;

    if (filtered.length === 0) {
        list.innerHTML = '<div style="text-align:center;color:#718096;padding:2rem;">No issuances found.</div>';
        return;
    }

    list.innerHTML = filtered.map(function(i) {
        return '<div class="table-row" style="min-width:1100px;grid-template-columns:110px 130px 120px 1fr 100px 140px 70px 80px 110px 110px;">'
            + '<div>' + (i.date ? new Date(i.date).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '-') + '</div>'
            + '<div>' + (i.assetNum||'-') + '</div>'
            + '<div>' + (i.itemNum||'-') + '</div>'
            + '<div>' + (i.itemName||'-') + '</div>'
            + '<div>' + (i.itemType||'-') + '</div>'
            + '<div>' + (i.commodityGroup||'-') + '</div>'
            + '<div>' + (i.uom||'-') + '</div>'
            + '<div>' + (i.quantity||0) + '</div>'
            + '<div>₱' + ((i.unitCost||0).toLocaleString('en-PH',{minimumFractionDigits:2})) + '</div>'
            + '<div>₱' + (((i.quantity||0)*(i.unitCost||0)).toLocaleString('en-PH',{minimumFractionDigits:2})) + '</div>'
            + '</div>';
    }).join('');
}

function deleteIssuance(id) {
    if (!confirm('Delete this issuance record?')) return;
    window.issuances = (window.issuances||[]).filter(function(i){ return i.id !== id; });
    renderIssuancesList();
}

// ── Users ───────────────────────────────────────────────────
function renderUsersList() {
    var users = window.users || [];
    var search = (document.getElementById('userSearch')||{}).value || '';
    var filtered = users;
    if (search.trim()) {
        var q = search.toLowerCase();
        filtered = users.filter(function(u){
            return (u.name||'').toLowerCase().includes(q)
                || (u.username||'').toLowerCase().includes(q)
                || (u.email||'').toLowerCase().includes(q);
        });
    }

    var s = function(id,val){ var el=document.getElementById(id); if(el) el.textContent=val; };
    s('userStatTotal', users.length);
    s('userStatAdmin', users.filter(function(u){ return u.role==='admin'; }).length);
    s('userStatCustomer', users.filter(function(u){ return u.role==='customer'; }).length);
    s('userStatStaff', users.filter(function(u){ return u.role==='staff'; }).length);

    var container = document.getElementById('userCardsList');
    if (!container) return;

    if (filtered.length === 0) {
        container.innerHTML = '<div style="text-align:center;padding:3rem;color:#718096;">No users found.</div>';
        return;
    }

    var roleColors = { admin:'#E31E24', staff:'#003087', customer:'#38a169' };
    container.innerHTML = filtered.map(function(u, idx) {
        var roleColor = roleColors[(u.role||'').toLowerCase()] || '#718096';
        var statusLower = (u.status||'').toLowerCase();
        var statusBadge = statusLower === 'active'
            ? '<span style="background:rgba(56,161,105,0.1);color:#38a169;padding:0.2rem 0.6rem;border-radius:20px;font-size:0.78rem;font-weight:700;">Active</span>'
            : '<span style="background:rgba(113,128,150,0.1);color:#718096;padding:0.2rem 0.6rem;border-radius:20px;font-size:0.78rem;font-weight:700;">Inactive</span>';
        var roleLabel = (u.role||'');
        roleLabel = roleLabel.charAt(0).toUpperCase() + roleLabel.slice(1);
        return '<div class="table-row" style="grid-template-columns:40px 1.5fr 1fr 1.5fr 1fr 1fr 140px;">'
            + '<div style="color:#a0aec0;font-size:0.85rem;">' + (idx+1) + '</div>'
            + '<div><strong>' + u.name + '</strong></div>'
            + '<div>' + u.username + '</div>'
            + '<div>' + (u.email||'-') + '</div>'
            + '<div><span style="background:'+roleColor+'20;color:'+roleColor+';padding:0.2rem 0.6rem;border-radius:20px;font-size:0.78rem;font-weight:700;">' + roleLabel + '</span></div>'
            + '<div>' + statusBadge + '</div>'
            + '<div style="display:flex;gap:0.4rem;">'
            +   '<button class="btn-small btn-primary" onclick="viewUser(\''+u.id+'\')" title="View" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg></button>'
            +   '<button class="btn-small btn-secondary" onclick="editUser(\''+u.id+'\')" title="Edit" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>'
            +   '<button class="btn-small btn-danger" onclick="toggleUserStatus(\''+u.id+'\')" title="'+(statusLower==='active'?'Deactivate':'Activate')+'" style="display:inline-flex;align-items:center;justify-content:center;">'+(statusLower==='active'?'<svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>':'<svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>')+'</button>'
            + '</div></div>';
    }).join('');
}

function openAddUserModal() {
    currentEditingUser = null;
    document.getElementById('userModalTitle').textContent = 'Add User';
    document.getElementById('addUserForm').reset();
    document.getElementById('userPasswordLabel').textContent = 'Password *';
    document.getElementById('userPasswordInput').required = true;
    document.getElementById('addUserModal').classList.add('active');
}

function viewUser(userId) {
    // Delegated to inline script in admin_users.html
    var users = window.users || [];
    var u = users.find(function(x){ return x.id === userId; });
    if (!u) return;
    var roleColors = { admin:'#E31E24', staff:'#003087', customer:'#38a169' };
    var rc = roleColors[(u.role||'').toLowerCase()] || '#718096';
    var header = document.getElementById('vuHeader');
    if (header) header.style.background = 'linear-gradient(135deg,#E31E24,#C41E3A)';
    var avatar = document.getElementById('vuAvatar');
    if (avatar) avatar.textContent = (u.name||'?').split(' ').map(function(n){ return n[0]; }).join('').toUpperCase().slice(0,2);
    var nameEl = document.getElementById('vuName'); if (nameEl) nameEl.textContent = u.name || '—';
    var unEl = document.getElementById('vuUsername'); if (unEl) unEl.textContent = u.username || '—';
    var roleLabel = (u.role||''); roleLabel = roleLabel.charAt(0).toUpperCase() + roleLabel.slice(1);
    var statusLower = (u.status||'').toLowerCase();
    var statusColor = statusLower === 'active' ? '#38a169' : '#718096';
    var statusLabel = statusLower === 'active' ? 'Active' : 'Inactive';
    var infoGrid = document.getElementById('vuInfoGrid');
    if (infoGrid) infoGrid.innerHTML = [
        ['Email', u.email||'—'],
        ['Role', '<span style="background:'+rc+'20;color:'+rc+';padding:0.2rem 0.6rem;border-radius:20px;font-size:0.78rem;font-weight:700;">'+roleLabel+'</span>'],
        ['Status', '<span style="background:'+statusColor+'20;color:'+statusColor+';padding:0.2rem 0.6rem;border-radius:20px;font-size:0.78rem;font-weight:700;">'+statusLabel+'</span>'],
        ['Username', u.username||'—'],
    ].map(function(item){
        return '<div style="background:white;border-radius:10px;padding:0.85rem;border:1px solid #e2e8f0;">'
            + '<div style="font-size:0.7rem;color:#718096;font-weight:700;text-transform:uppercase;margin-bottom:0.3rem;">'+item[0]+'</div>'
            + '<div style="font-weight:600;color:#1a202c;font-size:0.85rem;">'+item[1]+'</div>'
            + '</div>';
    }).join('');
    var editBtn = document.getElementById('vuEditBtn');
    if (editBtn) editBtn.onclick = function(){ closeModal('viewUserModal'); editUser(userId); };
    var modal = document.getElementById('viewUserModal');
    if (modal) modal.classList.add('active');
}

function editUser(userId) {
    var users = window.users || [];
    var u = users.find(function(x){ return x.id === userId; });
    if (!u) return;
    var titleEl = document.getElementById('userModalTitle');
    if (titleEl) titleEl.textContent = 'Edit User';
    var iconEl = document.getElementById('userModalIcon');
    if (iconEl) iconEl.innerHTML = '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>';
    var form = document.getElementById('addUserForm');
    if (!form) return;
    form.elements.name.value = u.name || '';
    form.elements.username.value = u.username || '';
    form.elements.email.value = u.email || '';
    form.elements.role.value = (u.role||'staff').toLowerCase();
    var statusVal = (u.status||'active').toLowerCase();
    form.elements.status.value = statusVal === 'active' ? 'Active' : 'Inactive';
    form.elements.password.value = '';
    var pwLabel = document.getElementById('userPasswordLabel');
    if (pwLabel) pwLabel.textContent = 'Password (leave blank to keep)';
    var pwInput = document.getElementById('userPasswordInput');
    if (pwInput) pwInput.required = false;
    // Store editing ID for the submit handler
    if (typeof window._editingUserId !== 'undefined') window._editingUserId = userId;
    var modal = document.getElementById('addUserModal');
    if (modal) modal.classList.add('active');
}

function toggleUserStatus(userId) {
    var users = window.users || [];
    var u = users.find(function(x){ return x.id === userId; });
    if (!u) return;
    var statusLower = (u.status||'active').toLowerCase();
    var action = statusLower === 'active' ? 'deactivate' : 'activate';
    if (!confirm(action.charAt(0).toUpperCase()+action.slice(1)+' user "'+u.name+'"?')) return;
    var newStatus = statusLower === 'active' ? 'inactive' : 'active';
    firebase.firestore().collection('users').doc(userId).update({ status: newStatus })
        .then(function(){ showToast('User status updated!', 'success'); })
        .catch(function(err){ showToast('Error: ' + err.message, 'error'); });
}

// ── Domains ─────────────────────────────────────────────────
function renderDomainsList() {
    var list = document.getElementById('domainsList');
    if (!list) return;
    var domains = window.domains || [];

    var search = (document.getElementById('domainSearch')||{}).value || '';
    var filtered = domains;
    if (search.trim()) {
        var q = search.toLowerCase();
        filtered = domains.filter(function(d){ return (d.name||'').toLowerCase().includes(q); });
    }

    if (filtered.length === 0) {
        list.innerHTML = '<div class="table-row" style="text-align:center;color:#718096;padding:2rem;">No domains found.</div>';
        return;
    }

    list.innerHTML = filtered.map(function(d, idx) {
        var chips = (d.list||[]).map(function(v){
            return '<span style="background:#e2e8f0;color:#4a5568;padding:0.2rem 0.6rem;border-radius:20px;font-size:0.78rem;font-weight:600;margin:0.1rem;">'+v+'</span>';
        }).join('');
        return '<div class="table-row" style="grid-template-columns:40px 1.5fr 3fr 120px;">'
            + '<div style="color:#a0aec0;">' + (idx+1) + '</div>'
            + '<div><strong>' + d.name + '</strong></div>'
            + '<div style="display:flex;flex-wrap:wrap;gap:0.25rem;">' + chips + '</div>'
            + '<div style="display:flex;gap:0.3rem;">'
            +   '<button class="btn-small btn-primary" onclick="editDomain(\'' + d.id + '\')" title="Edit" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg></button>'
            +   '<button class="btn-small btn-danger" onclick="deleteDomain(\'' + d.id + '\')" title="Delete" style="display:inline-flex;align-items:center;justify-content:center;"><svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/></svg></button>'
            + '</div></div>';
    }).join('');
}

function openAddDomainModal() {
    currentEditingDomain = null;
    document.getElementById('domainModalTitle').textContent = 'Add Domain';
    document.getElementById('addDomainForm').reset();
    document.getElementById('addDomainModal').classList.add('active');
}

function editDomain(domainId) {
    var domains = window.domains || [];
    var d = domains.find(function(x){ return x.id === domainId; });
    if (!d) return;
    currentEditingDomain = d;
    document.getElementById('domainModalTitle').textContent = 'Edit Domain';
    var form = document.getElementById('addDomainForm');
    form.elements.domainName.value = d.name;
    form.elements.domainList.value = (d.list||[]).join(', ');
    document.getElementById('addDomainModal').classList.add('active');
}

function deleteDomain(domainId) {
    if (!confirm('Delete this domain?')) return;
    window.domains = (window.domains||[]).filter(function(d){ return d.id !== domainId; });
    renderDomainsList();
}

document.addEventListener('DOMContentLoaded', function() {
    var addDomainForm = document.getElementById('addDomainForm');
    if (addDomainForm) {
        addDomainForm.addEventListener('submit', function(e) {
            e.preventDefault();
            var form = e.target;
            var domains = window.domains || [];
            var name = form.elements.domainName.value.trim();
            var list = form.elements.domainList.value.split(',').map(function(v){ return v.trim(); }).filter(Boolean);

            if (currentEditingDomain) {
                var d = domains.find(function(x){ return x.id === currentEditingDomain.id; });
                if (d) { d.name = name; d.list = list; }
                alert('✅ Domain updated!');
            } else {
                var id = name.replace(/\s+/g,'');
                domains.push({ id: id, name: name, list: list });
                window.domains = domains;
                alert('✅ Domain added!');
            }
            closeModal('addDomainModal');
            renderDomainsList();
        });
    }
});

// ── Smart Reports ───────────────────────────────────────────
function clearSmartChat() {
    var messages = document.getElementById('srChatMessages');
    if (!messages) return;
    messages.innerHTML = '<div class="sr-welcome-bubble"><div class="sr-avatar-ai">🤖</div><div class="sr-bubble-ai">'
        + '<div style="font-weight:700;margin-bottom:0.4rem;font-size:0.95rem;">Hello! I\'m your Smart Reports assistant. 👋</div>'
        + '<div style="color:#4a5568;font-size:0.88rem;line-height:1.6;margin-bottom:1rem;">Ask me anything about your fleet — assets, inventory, maintenance costs, and more.</div>'
        + '<div class="sr-welcome-chips">'
        + '<button class="sr-suggest-chip" onclick="setAndRunQuery(\'Which assets are frequently under maintenance?\')">🔧 Frequently maintained assets</button>'
        + '<button class="sr-suggest-chip" onclick="setAndRunQuery(\'What items are low in stock?\')">📦 Low stock items</button>'
        + '<button class="sr-suggest-chip" onclick="setAndRunQuery(\'Total repair cost this month\')">💰 Repair cost this month</button>'
        + '<button class="sr-suggest-chip" onclick="setAndRunQuery(\'Assets with PMS overdue\')">⚠️ PMS overdue assets</button>'
        + '</div></div></div>';
}

function setAndRunQuery(text) {
    var input = document.getElementById('smartQueryInput');
    if (input) { input.value = text; input.style.height = 'auto'; }
    runSmartQuery();
}

function runSmartQuery() {
    var input = document.getElementById('smartQueryInput');
    var query = input ? input.value.trim() : '';
    if (!query) return;

    var messages = document.getElementById('srChatMessages');
    if (!messages) return;

    var userRow = document.createElement('div');
    userRow.className = 'sr-msg-row sr-msg-user';
    userRow.innerHTML = '<div class="sr-bubble-user">' + escapeHtml(query) + '</div><div class="sr-avatar-user">👤</div>';
    messages.appendChild(userRow);
    if (input) { input.value = ''; input.style.height = 'auto'; }

    var typingId = 'sr_typing_' + Date.now();
    var typingRow = document.createElement('div');
    typingRow.className = 'sr-msg-row sr-msg-ai';
    typingRow.id = typingId;
    typingRow.innerHTML = '<div class="sr-avatar-ai">🤖</div><div class="sr-bubble-ai sr-typing"><span></span><span></span><span></span></div>';
    messages.appendChild(typingRow);
    messages.scrollTop = messages.scrollHeight;

    setTimeout(function() {
        var el = document.getElementById(typingId);
        if (el) el.remove();
        var result = processAdminSmartQuery(query);
        var aiRow = document.createElement('div');
        aiRow.className = 'sr-msg-row sr-msg-ai';
        aiRow.innerHTML = '<div class="sr-avatar-ai">🤖</div><div class="sr-bubble-ai">' + result + '</div>';
        messages.appendChild(aiRow);
        messages.scrollTop = messages.scrollHeight;
    }, 600);
}

function processAdminSmartQuery(query) {
    var q = query.toLowerCase();
    var assets = window.assets || [];
    var inventory = window.inventory || [];
    var serviceTransactions = window.serviceTransactions || [];
    var today = new Date(); today.setHours(0,0,0,0);

    if (q.includes('low') && q.includes('stock')) {
        var low = inventory.filter(function(i){ return i.stock <= i.minLevel; });
        if (!low.length) return '<strong>✅ All stock levels are adequate.</strong>';
        return '<strong>⚠️ Low Stock Items (' + low.length + ')</strong><br>' + low.map(function(i){
            return '• ' + i.itemName + ': <strong>' + i.stock + ' ' + i.unit + '</strong> (min: ' + i.minLevel + ')';
        }).join('<br>');
    }
    if (q.includes('overdue') || (q.includes('pms') && q.includes('overdue'))) {
        var overdue = assets.filter(function(a){
            if (!a.nextPMSDue || a.status==='maintenance') return false;
            return new Date(a.nextPMSDue) < today;
        });
        if (!overdue.length) return '<strong>✅ No assets with overdue PMS.</strong>';
        return '<strong>🔴 PMS Overdue Assets (' + overdue.length + ')</strong><br>' + overdue.map(function(a){
            return '• ' + a.assetDescription + ' (' + a.plateNumber + ')';
        }).join('<br>');
    }
    if (q.includes('maintenance') || q.includes('under maintenance')) {
        var maint = assets.filter(function(a){ return a.status==='maintenance'; });
        if (!maint.length) return '<strong>✅ No assets currently under maintenance.</strong>';
        return '<strong>🔵 Under Maintenance (' + maint.length + ')</strong><br>' + maint.map(function(a){
            return '• ' + a.assetDescription + ' (' + a.plateNumber + ')';
        }).join('<br>');
    }
    if (q.includes('cost') || q.includes('repair')) {
        var total = serviceTransactions.reduce(function(s,t){ return s+(t.totalCost||0); },0);
        return '<strong>💰 Total Repair Cost</strong><br>All time: <strong>₱' + total.toLocaleString('en-PH',{minimumFractionDigits:2}) + '</strong> across ' + serviceTransactions.length + ' service(s).';
    }
    if (q.includes('fast') && q.includes('moving')) {
        var inv = window.inventory || [];
        var issuances = window.issuances || [];
        var counts = {};
        issuances.forEach(function(i){ counts[i.itemName] = (counts[i.itemName]||0) + (i.quantity||0); });
        var sorted = Object.keys(counts).sort(function(a,b){ return counts[b]-counts[a]; }).slice(0,5);
        if (!sorted.length) return '<strong>📦 No issuance data yet.</strong>';
        return '<strong>⚡ Fast Moving Items</strong><br>' + sorted.map(function(k){ return '• ' + k + ': ' + counts[k] + ' units'; }).join('<br>');
    }
    return '<strong>🤔 I couldn\'t find a match for "' + escapeHtml(query) + '".</strong><br>Try asking about: low stock, PMS overdue, under maintenance, repair cost, or fast moving items.';
}

// ── Receive Delivery ────────────────────────────────────────
var _deliverySelectedItem = null;

function openStaffReceiveDeliveryModal() {
    _deliverySelectedItem = null;
    document.getElementById('deliveryItemSearch').value = '';
    document.getElementById('deliveryQuantity').value = '';
    document.getElementById('deliveryItemInfo').style.display = 'none';
    document.getElementById('deliveryPreview').style.display = 'none';
    document.getElementById('staffReceiveDeliveryModal').classList.add('active');
}

function openDeliveryScanModal() {
    document.getElementById('deliveryScanInput').value = '';
    document.getElementById('deliveryScanModal').classList.add('active');
}

function searchDeliveryScannedItem() {
    var val = document.getElementById('deliveryScanInput').value.trim();
    closeModal('deliveryScanModal');
    if (val) {
        document.getElementById('deliveryItemSearch').value = val;
        searchDeliveryItem(val);
    }
}

function searchDeliveryItem(query) {
    if (!query) query = document.getElementById('deliveryItemSearch').value.trim();
    if (!query) { _deliverySelectedItem = null; document.getElementById('deliveryItemInfo').style.display = 'none'; return; }

    var inventory = window.inventory || [];
    var itemMaster = window.itemMaster || [];
    var q = query.toLowerCase().trim();

    // 1. Direct match on inventory fields
    var found = inventory.find(function(i) {
        return (i.itemNum||'').toLowerCase() === q
            || (i.itemName||'').toLowerCase().includes(q);
    });

    // 2. If not found directly, try matching barcode/qrcode via itemMaster → then link to inventory by itemNum
    if (!found) {
        var masterMatch = itemMaster.find(function(m) {
            return (m.barcode && m.barcode === query)
                || (m.qrcode && m.qrcode === query)
                || (m.itemNum||'').toLowerCase() === q
                || (m.itemName||'').toLowerCase().includes(q);
        });
        if (masterMatch) {
            // Match inventory by itemNum suffix (INV-001 ↔ ITM-001 share the same sequence)
            var seq = masterMatch.itemNum.replace(/\D/g,'');
            found = inventory.find(function(i) {
                return i.itemNum.replace(/\D/g,'') === seq;
            });
            // Fallback: match by name
            if (!found) {
                found = inventory.find(function(i) {
                    return (i.itemName||'').toLowerCase() === (masterMatch.itemName||'').toLowerCase();
                });
            }
        }
    }

    if (found) {
        _deliverySelectedItem = found;
        document.getElementById('deliveryItemName').textContent = found.itemName;
        document.getElementById('deliveryItemCode').textContent = found.itemNum;
        document.getElementById('deliveryCurrentStock').textContent = found.stock + ' ' + (found.unit || '');
        document.getElementById('deliveryUnit').textContent = found.unit || '-';
        document.getElementById('deliveryItemInfo').style.display = 'block';
        updateDeliveryPreview();
    } else {
        _deliverySelectedItem = null;
        document.getElementById('deliveryItemInfo').style.display = 'none';
        document.getElementById('deliveryPreview').style.display = 'none';
        alert('⚠️ No item found for: "' + query + '"');
    }
}

function updateDeliveryPreview() {
    if (!_deliverySelectedItem) return;
    var qty = parseInt(document.getElementById('deliveryQuantity').value) || 0;
    var preview = document.getElementById('deliveryPreview');
    if (qty <= 0) { preview.style.display = 'none'; return; }

    var item = _deliverySelectedItem;
    var oldStock = item.stock;
    var newStock = oldStock + qty;
    var unit = item.unit || '';
    var maxLevel = item.maxLevel || 0;
    var oldPct = maxLevel > 0 ? Math.min(100, Math.round((oldStock / maxLevel) * 100)) : 0;
    var newPct = maxLevel > 0 ? Math.min(100, Math.round((newStock / maxLevel) * 100)) : 0;
    var newColor = newStock <= item.minLevel ? '#e53e3e' : newStock >= maxLevel ? '#3182ce' : '#38a169';

    document.getElementById('deliveryPreviewMessage').innerHTML =
        '<div style="display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:0.75rem;margin-bottom:1rem;">'
        +   '<div style="background:#f7fafc;border-radius:10px;padding:0.85rem;text-align:center;">'
        +     '<div style="font-size:0.68rem;color:#718096;font-weight:700;text-transform:uppercase;margin-bottom:0.3rem;">Current Stock</div>'
        +     '<div style="font-size:1.5rem;font-weight:800;color:#e53e3e;">' + oldStock + '</div>'
        +     '<div style="font-size:0.75rem;color:#a0aec0;">' + unit + '</div>'
        +   '</div>'
        +   '<div style="font-size:1.5rem;color:#3182ce;font-weight:700;">→</div>'
        +   '<div style="background:#ebf8ff;border-radius:10px;padding:0.85rem;text-align:center;border:2px solid #bee3f8;">'
        +     '<div style="font-size:0.68rem;color:#2c5282;font-weight:700;text-transform:uppercase;margin-bottom:0.3rem;">New Stock</div>'
        +     '<div style="font-size:1.5rem;font-weight:800;color:' + newColor + ';">' + newStock + '</div>'
        +     '<div style="font-size:0.75rem;color:#a0aec0;">' + unit + '</div>'
        +   '</div>'
        + '</div>'
        + '<div style="background:#f7fafc;border-radius:8px;padding:0.6rem 0.85rem;display:flex;justify-content:space-between;align-items:center;margin-bottom:0.75rem;">'
        +   '<span style="font-size:0.8rem;color:#718096;">Adding</span>'
        +   '<span style="font-size:0.88rem;font-weight:700;color:#38a169;">+' + qty + ' ' + unit + '</span>'
        + '</div>'
        + '<div>'
        +   '<div style="display:flex;justify-content:space-between;font-size:0.7rem;color:#a0aec0;font-weight:600;margin-bottom:0.3rem;">'
        +     '<span>Before</span><span>After</span>'
        +   '</div>'
        +   '<div style="position:relative;height:8px;background:#e2e8f0;border-radius:4px;overflow:hidden;margin-bottom:0.3rem;">'
        +     '<div style="position:absolute;height:100%;width:' + oldPct + '%;background:#e53e3e;border-radius:4px;opacity:0.4;"></div>'
        +     '<div style="position:absolute;height:100%;width:' + newPct + '%;background:' + newColor + ';border-radius:4px;transition:width 0.4s;"></div>'
        +   '</div>'
        +   '<div style="display:flex;justify-content:space-between;font-size:0.7rem;color:#a0aec0;">'
        +     '<span>Min: ' + item.minLevel + '</span><span>Max: ' + maxLevel + '</span>'
        +   '</div>'
        + '</div>';

    preview.style.display = 'block';
}

function submitDeliveryReceived() {
    if (!_deliverySelectedItem) { alert('⚠️ Please search and select an item first.'); return; }
    var qty = parseInt(document.getElementById('deliveryQuantity').value) || 0;
    if (qty <= 0) { alert('⚠️ Please enter a valid quantity.'); return; }

    var inventory = window.inventory || [];
    var item = inventory.find(function(i) { return i.id === _deliverySelectedItem.id; });
    if (!item) { alert('⚠️ Item not found in inventory.'); return; }

    item.stock += qty;
    item.status = item.stock <= item.minLevel ? 'low_stock' : 'in_stock';

    // Log to delivery records
    if (!window.deliveryRecords) window.deliveryRecords = [];
    window.deliveryRecords.push({
        date: new Date().toISOString().split('T')[0],
        itemNum: item.itemNum,
        itemName: item.itemName,
        quantity: qty,
        supplier: 'Manual Receive',
        receivedBy: (window.currentUser && window.currentUser.name) || 'Administrator'
    });

    closeModal('staffReceiveDeliveryModal');
    renderInventoryList();
    renderInventoryTransactions();
    alert('✅ Stock updated! ' + item.itemName + ' is now ' + item.stock + ' ' + (item.unit || '') + '.');
}

// Wire up live search + preview on input
document.addEventListener('DOMContentLoaded', function() {
    var searchInput = document.getElementById('deliveryItemSearch');
    if (searchInput) {
        searchInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') { e.preventDefault(); searchDeliveryItem(this.value.trim()); }
        });
    }
    var qtyInput = document.getElementById('deliveryQuantity');
    if (qtyInput) qtyInput.addEventListener('input', updateDeliveryPreview);
});

// ── Inventory List Scan ─────────────────────────────────────
function openInventoryListScanModal() {
    document.getElementById('inventoryListScanInput').value = '';
    document.getElementById('inventoryListScanModal').classList.add('active');
}

function searchInventoryByScan() {
    var val = document.getElementById('inventoryListScanInput').value.trim();
    if (!val) return;

    var inventory = window.inventory || [];
    var itemMaster = window.itemMaster || [];
    var q = val.toLowerCase();

    // Direct match on inventory
    var found = inventory.find(function(i) {
        return (i.itemNum||'').toLowerCase() === q
            || (i.itemName||'').toLowerCase().includes(q);
    });

    // Cross-reference via itemMaster barcode/qrcode
    if (!found) {
        var master = itemMaster.find(function(m) {
            return (m.barcode && m.barcode === val)
                || (m.qrcode && m.qrcode === val)
                || (m.itemNum||'').toLowerCase() === q;
        });
        if (master) {
            var seq = master.itemNum.replace(/\D/g,'');
            found = inventory.find(function(i) {
                return i.itemNum.replace(/\D/g,'') === seq;
            }) || inventory.find(function(i) {
                return (i.itemName||'').toLowerCase() === (master.itemName||'').toLowerCase();
            });
        }
    }

    closeModal('inventoryListScanModal');

    if (found) {
        // Populate the search bar and filter the list
        var searchBar = document.getElementById('inventorySearch');
        if (searchBar) { searchBar.value = found.itemName; }
        renderInventoryList();
        // Highlight by briefly showing view details
        viewInventoryItem(found.id);
    } else {
        alert('⚠️ No inventory item found for: "' + val + '"');
    }
}

// ── Item Master Scan (search) ───────────────────────────────
function searchItemMasterByScan() {
    var val = document.getElementById('itemMasterScanInput').value.trim();
    if (!val) return;

    var itemMaster = window.itemMaster || [];
    var q = val.toLowerCase();
    var found = itemMaster.find(function(m) {
        return (m.barcode && m.barcode === val)
            || (m.qrcode && m.qrcode === val)
            || (m.itemNum||'').toLowerCase() === q
            || (m.itemName||'').toLowerCase().includes(q);
    });

    closeModal('itemMasterScanModal');

    if (found) {
        var searchBar = document.getElementById('itemMasterSearch');
        if (searchBar) { searchBar.value = found.itemName; }
        renderItemMasterList();
        viewItemMasterDetails(found.itemNum);
    } else {
        alert('⚠️ No item found for: "' + val + '"');
    }
}
