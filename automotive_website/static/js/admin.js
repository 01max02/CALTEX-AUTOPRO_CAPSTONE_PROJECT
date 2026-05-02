// Admin Portal - Standalone page initialization

document.addEventListener('DOMContentLoaded', function () {
    // Check session
    const user = sessionStorage.getItem('apUser');
    if (!user) {
        console.log('No apUser in sessionStorage, redirecting to login');
        window.location.href = '/login.html';
        return;
    }

    const adminUser = JSON.parse(user);
    console.log('Auth guard passed, adminUser:', adminUser);
    window.currentUser = adminUser;

    // Set admin name
    const nameEl = document.getElementById('adminName');
    if (nameEl) nameEl.textContent = adminUser.name;

    // Initialize admin sections
    renderAssetsList();
    renderInventoryList();

    // Admin navigation
    document.querySelectorAll('#adminDashboard .admin-nav-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const section = e.currentTarget.dataset.section;
            if (section) switchAdminSection(section);
        });
    });

    // Logout
    document.getElementById('adminLogoutBtn')?.addEventListener('click', () => {
        if (confirm('Are you sure you want to logout?')) {
            sessionStorage.removeItem('apUser');
            if (typeof firebase !== 'undefined' && firebase.auth) {
                firebase.auth().signOut().finally(() => {
                    window.location.href = '/login.html';
                });
            } else {
                window.location.href = '/login.html';
            }
        }
    });

    // Build notifications on load
    renderAdminNotifications();

    // Close panel when clicking outside
    document.addEventListener('click', function (e) {
        const panel = document.getElementById('adminNotifPanel');
        const btn   = document.getElementById('adminHeaderNotifBtn');
        if (panel && btn && !panel.contains(e.target) && !btn.contains(e.target)) {
            panel.style.display = 'none';
        }
    });
});

// ── Build notification list from live data ──────────────────
function buildAdminNotifications() {
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const notifs = [];

    // Under maintenance
    (window.assets || []).filter(a => a.status === 'maintenance').forEach(a => {
        notifs.push({
            icon: '🔵', type: 'info', unread: false,
            title: 'Under Maintenance',
            msg: `${a.assetDescription} (${a.plateNumber}) is currently being serviced.`,
            time: 'Ongoing',
            action: () => switchAdminSection('asset-servicing')
        });
    });

    // Low stock
    (window.inventory || []).filter(i => i.stock <= i.minLevel).forEach(i => {
        const isOut = i.stock === 0;
        notifs.push({
            icon: isOut ? '🚨' : '⚠️', type: isOut ? 'danger' : 'warning', unread: true,
            title: isOut ? 'Out of Stock' : 'Low Stock',
            msg: `${i.itemName} — ${i.stock} ${i.unit} remaining (min: ${i.minLevel})`,
            time: 'Inventory alert',
            action: () => switchAdminSection('inventory')
        });
    });

    // Pending services
    const pending = (window.serviceTransactions || []).filter(s => s.status === 'pending');
    if (pending.length > 0) {
        notifs.push({
            icon: '⏳', type: 'info', unread: false,
            title: 'Pending Services',
            msg: `${pending.length} service transaction(s) awaiting approval.`,
            time: 'Action required',
            action: () => switchAdminSection('asset-servicing')
        });
    }

    return notifs;
}

// ── Render panel ────────────────────────────────────────────
function renderAdminNotifications() {
    const notifs    = buildAdminNotifications();
    const unread    = notifs.filter(n => n.unread).length;
    const badge     = document.getElementById('adminNotifBadge');
    const countEl   = document.getElementById('adminNotifPanelCount');
    const listEl    = document.getElementById('adminNotifList');

    // Badge on button
    if (badge) {
        badge.textContent = unread;
        badge.style.display = unread > 0 ? 'inline-flex' : 'none';
    }

    // ── Also update the header badge to include local PMS/stock alerts ──
    const headerBadge = document.getElementById('adminHeaderNotifBadge');
    if (headerBadge) {
        const fbUnread = (window._fbNotifications || []).filter(n => {
            const uid = (firebase.auth().currentUser || {}).uid;
            return uid && (n.readBy || {})[uid] !== true;
        }).length;
        const totalUnread = unread + fbUnread;
        headerBadge.textContent = totalUnread > 9 ? '9+' : totalUnread;
        headerBadge.style.display = totalUnread > 0 ? 'flex' : 'none';
    }
    if (countEl) countEl.textContent = notifs.length + ' alert' + (notifs.length !== 1 ? 's' : '');

    if (!listEl) return;

    if (notifs.length === 0) {
        listEl.innerHTML = '<div class="admin-notif-empty"><div class="admin-notif-empty-icon">🔔</div><div class="admin-notif-empty-text">No notifications</div></div>';
        return;
    }

    listEl.innerHTML = notifs.map((n, i) => {
        return `<div class="admin-notif-item${n.unread ? ' unread' : ''}" onclick="adminNotifClick(${i})">
            <div class="admin-notif-icon">${n.icon}</div>
            <div>
                <div class="admin-notif-title">${n.title}</div>
                <div class="admin-notif-msg">${n.msg}</div>
                <div class="admin-notif-time">${n.time}</div>
            </div>
        </div>`;
    }).join('');

    // Store actions for click handler
    window._adminNotifActions = notifs.map(n => n.action);
}

window.adminNotifClick = function (i) {
    const actions = window._adminNotifActions || [];
    if (actions[i]) actions[i]();
    document.getElementById('adminNotifPanel').style.display = 'none';
};

window.toggleAdminNotifPanel = function () {
    const panel = document.getElementById('adminNotifPanel');
    if (!panel) return;
    const isOpen = panel.style.display === 'block';
    panel.style.display = isOpen ? 'none' : 'block';
    if (!isOpen) {
        // If _fbNotifications is already loaded, render immediately
        if (window._fbNotifications && window._fbNotifications.length > 0) {
            _renderAdminNotifPanel();
        } else {
            // Fetch directly from Firestore (handles profile page where snapshot may not have fired yet)
            const user = typeof firebase !== 'undefined' && firebase.auth().currentUser;
            if (user) {
                firebase.firestore().collection('notifications')
                    .where('targetRole', '==', 'admin')
                    .limit(50)
                    .get()
                    .then(function(snap) {
                        window._fbNotifications = snap.docs
                            .map(function(d) { return Object.assign({ _id: d.id }, d.data()); })
                            .sort(function(a, b) {
                                const aMs = a.createdAt && a.createdAt.toMillis ? a.createdAt.toMillis() : 0;
                                const bMs = b.createdAt && b.createdAt.toMillis ? b.createdAt.toMillis() : 0;
                                return bMs - aMs;
                            });
                        _renderAdminNotifPanel();
                        // Update badge
                        const uid = user.uid;
                        const unread = window._fbNotifications.filter(function(n) {
                            return (n.readBy || {})[uid] !== true;
                        }).length;
                        window._adminUnreadCount = unread;
                        const badge = document.getElementById('adminHeaderNotifBadge');
                        if (badge) {
                            badge.textContent = unread > 9 ? '9+' : unread;
                            badge.style.display = unread > 0 ? 'flex' : 'none';
                        }
                    })
                    .catch(function() { _renderAdminNotifPanel(); });
            } else {
                _renderAdminNotifPanel();
            }
        }
        // Re-apply badge in case it was missed during async header load
        if (typeof window._adminUnreadCount !== 'undefined') {
            const badge = document.getElementById('adminHeaderNotifBadge');
            if (badge) {
                const u = window._adminUnreadCount;
                badge.textContent = u > 9 ? '9+' : u;
                badge.style.display = u > 0 ? 'flex' : 'none';
            }
        }
    }
};

function _renderAdminNotifPanel() {
    const listEl  = document.getElementById('adminNotifList');
    const countEl = document.getElementById('adminNotifPanelCount');
    if (!listEl) return;

    // Local-data alerts (PMS, stock, services) — from Firestore-backed window.assets
    const localNotifs = buildAdminNotifications();

    // Firestore notifications
    const uid = (firebase.auth().currentUser || {}).uid;
    const fbNotifs = (window._fbNotifications || []).map(n => ({
        icon: n.type === 'warning' ? '⚠️' : n.type === 'success' ? '✅' : n.type === 'danger' ? '🚨' : '🔔',
        type: n.type || 'info',
        unread: uid ? (n.readBy || {})[uid] !== true : false,
        title: n.title || '',
        msg: n.message || '',
        time: _fbTimeAgo(n.createdAt),
        action: null,
        _docId: n._id,
    }));

    const all = [...fbNotifs, ...localNotifs];
    const unread = all.filter(n => n.unread).length;

    const badge = document.getElementById('adminHeaderNotifBadge');
    if (badge) {
        badge.textContent = unread > 9 ? '9+' : unread;
        badge.style.display = unread > 0 ? 'flex' : 'none';
    }
    if (countEl) countEl.textContent = all.length + ' notification' + (all.length !== 1 ? 's' : '');

    if (all.length === 0) {
        listEl.innerHTML = '<div class="admin-notif-empty"><div class="admin-notif-empty-icon">🔔</div><div class="admin-notif-empty-text">No notifications</div></div>';
        return;
    }

    listEl.innerHTML = all.map((n, i) => `
        <div class="admin-notif-item${n.unread ? ' unread' : ''}" style="position:relative;padding-right:2rem;" onclick="_adminNotifClick(${i})">
            <div class="admin-notif-icon">${n.icon}</div>
            <div style="flex:1;min-width:0;">
                <div class="admin-notif-title">${n.title}</div>
                <div class="admin-notif-msg">${n.msg}</div>
                <div class="admin-notif-time">${n.time}</div>
            </div>
            ${n.unread ? '<div style="width:8px;height:8px;border-radius:50%;background:#E8001C;flex-shrink:0;margin-top:4px;"></div>' : ''}
            ${n._docId ? `<button onclick="event.stopPropagation();_adminDeleteNotif('${n._docId}')" title="Delete" style="position:absolute;top:0.5rem;right:0.4rem;background:none;border:none;cursor:pointer;color:#a0aec0;font-size:1rem;line-height:1;padding:2px 4px;border-radius:4px;" onmouseover="this.style.color='#e53e3e'" onmouseout="this.style.color='#a0aec0'">&times;</button>` : ''}
        </div>`).join('');

    window._adminNotifAll = all;
}

function _fbTimeAgo(ts) {
    if (!ts || !ts.toMillis) return '';
    const diff = Date.now() - ts.toMillis();
    const mins = Math.floor(diff / 60000);
    if (mins < 1)  return 'Just now';
    if (mins < 60) return mins + ' min ago';
    const hrs = Math.floor(mins / 60);
    if (hrs < 24)  return hrs + ' hr ago';
    const days = Math.floor(hrs / 24);
    return days === 1 ? 'Yesterday' : days + ' days ago';
}

window._adminNotifClick = function(i) {
    const all = window._adminNotifAll || [];
    const n = all[i];
    if (!n) return;
    // Mark Firestore notification as read
    if (n._docId) {
        const uid = (firebase.auth().currentUser || {}).uid;
        if (uid) {
            firebase.firestore().collection('notifications').doc(n._docId)
                .update({ [`readBy.${uid}`]: true }).catch(() => {});
        }
    }
    // Run local action
    if (n.action) n.action();
    document.getElementById('adminNotifPanel').style.display = 'none';
};

window._adminDeleteNotif = function(docId) {
    firebase.firestore().collection('notifications').doc(docId).delete().catch(() => {});
    // Remove from local cache and re-render
    if (window._fbNotifications) {
        window._fbNotifications = window._fbNotifications.filter(n => n._id !== docId);
    }
    _renderAdminNotifPanel();
};

window.clearAdminNotifications = function () {
    // Delete ALL Firestore notifications shown in the panel
    const db = firebase.firestore();
    const batch = db.batch();
    (window._fbNotifications || []).forEach(n => {
        batch.delete(db.collection('notifications').doc(n._id));
    });
    batch.commit().catch(() => {});
    window._fbNotifications = [];

    const listEl  = document.getElementById('adminNotifList');
    const countEl = document.getElementById('adminNotifPanelCount');
    const badge   = document.getElementById('adminHeaderNotifBadge');
    if (listEl)  listEl.innerHTML = '<div class="admin-notif-empty"><div class="admin-notif-empty-icon">🔔</div><div class="admin-notif-empty-text">No notifications</div></div>';
    if (badge)   badge.style.display = 'none';
    if (countEl) countEl.textContent = '0 notifications';
};

// ── DSS — Stock Replenishment Decision Support System ───────

var _dssFilter = 'all';
var _dssData   = [];

// ── Core analysis engine ────────────────────────────────────
function dssAnalyze() {
    const inv      = window.inventory  || [];
    const issued   = window.issuances  || [];
    const services = window.serviceTransactions || [];
    const today    = new Date();

    // Build consumption map from issuances + service spare parts
    const consumptionMap = {}; // itemNum -> [{ date, qty }]

    issued.forEach(function (i) {
        if (!i.itemNum) return;
        if (!consumptionMap[i.itemNum]) consumptionMap[i.itemNum] = [];
        consumptionMap[i.itemNum].push({ date: new Date(i.date), qty: parseFloat(i.quantity) || 0 });
    });

    services.forEach(function (s) {
        (s.spareParts || []).forEach(function (p) {
            if (!p.itemNum) return;
            if (!consumptionMap[p.itemNum]) consumptionMap[p.itemNum] = [];
            consumptionMap[p.itemNum].push({ date: new Date(s.dateServiced || today), qty: parseFloat(p.quantity) || 0 });
        });
    });

    return inv.map(function (item) {
        const records = consumptionMap[item.itemNum] || [];

        // Total consumed & date range
        const totalConsumed = records.reduce(function (s, r) { return s + r.qty; }, 0);
        const dates = records.map(function (r) { return r.date; });
        const earliest = dates.length ? new Date(Math.min.apply(null, dates)) : null;
        const daySpan  = earliest ? Math.max(1, Math.ceil((today - earliest) / 86400000)) : 30;

        // Daily consumption rate (avg)
        const dailyRate = totalConsumed > 0 ? totalConsumed / daySpan : 0;

        // Days of stock remaining
        const daysLeft = dailyRate > 0 ? Math.floor(item.stock / dailyRate) : (item.stock > 0 ? 999 : 0);

        // Recommended order qty: fill to maxLevel, at least reorderQty
        const deficit      = Math.max(0, item.maxLevel - item.stock);
        const recommendQty = Math.max(deficit, item.reorderQty || 0);

        // Lead time buffer (assume 7 days lead time)
        const leadTimeDemand = Math.ceil(dailyRate * 7);

        // Priority scoring — 3-Tier Color-Coded System
        // 0 = Out of Stock  🔴 Red    (stock = 0)
        // 1 = Low Stock     🟡 Yellow (stock ≤ min qty)
        // 2 = Adequate      🟢 Green  (stock > min qty)
        let priority, priorityLabel, priorityColor;
        if (item.stock === 0) {
            priority = 0; priorityLabel = 'OUT OF STOCK'; priorityColor = '#e53e3e';
        } else if (item.stock <= item.minLevel) {
            priority = 1; priorityLabel = 'LOW STOCK';    priorityColor = '#d69e2e';
        } else {
            priority = 2; priorityLabel = 'ADEQUATE';     priorityColor = '#38a169';
        }

        // Decision text — 3-tier
        let decision;
        if (priority === 0) {
            decision = 'URGENT: Emergency order';
        } else if (priority === 1) {
            decision = 'SOON: Plan to order';
        } else {
            decision = 'MONITOR: No action needed';
        }

        // Stock bar pct
        const stockPct = Math.min(100, Math.round((item.stock / item.maxLevel) * 100));

        return {
            item,
            totalConsumed,
            dailyRate,
            daysLeft,
            recommendQty,
            leadTimeDemand,
            priority,
            priorityLabel,
            priorityColor,
            decision,
            stockPct
        };
    }).sort(function (a, b) { return a.priority - b.priority; });
}

// ── Render full DSS section ─────────────────────────────────
window.renderDSS = function () {
    _dssData = dssAnalyze();
    renderDSSKpis();
    renderDSSTable();
    renderDSSInsights();
};

function renderDSSKpis() {
    const el = document.getElementById('dssKpiGrid');
    if (!el) return;
    const d = _dssData;
    const outOfStock = d.filter(function (x) { return x.priority === 0; }).length;
    const lowStock   = d.filter(function (x) { return x.priority === 1; }).length;
    const adequate   = d.filter(function (x) { return x.priority === 2; }).length;

    el.innerHTML = [
        { svg: '<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
          label: 'Out of Stock', val: outOfStock, color: '#e53e3e', bg: 'rgba(229,62,62,0.10)' },
        { svg: '<polyline points="23 18 13.5 8.5 8.5 13.5 1 6"/><polyline points="17 18 23 18 23 12"/>',
          label: 'Low Stock', val: lowStock, color: '#d69e2e', bg: 'rgba(214,158,46,0.10)' },
        { svg: '<polyline points="20 6 9 17 4 12"/>',
          label: 'Adequate', val: adequate, color: '#38a169', bg: 'rgba(56,161,105,0.10)' },
    ].map(function (k) {
        return '<div class="stat-card">'
            + '<div class="stat-icon" style="background:' + k.bg + ';color:' + k.color + ';">'
            +   '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + k.svg + '</svg>'
            + '</div>'
            + '<div class="stat-number" style="color:' + k.color + ';">' + k.val + '</div>'
            + '<div class="stat-label">' + k.label + '</div>'
            + '</div>';
    }).join('');
}

function renderDSSTable() {
    const body = document.getElementById('dssTableBody');
    if (!body) return;

    const search = (document.getElementById('dssSearch') || {}).value || '';
    let rows = _dssData;

    if (_dssFilter !== 'all') {
        rows = rows.filter(function (x) {
            if (_dssFilter === 'critical')  return x.priority <= 1;
            if (_dssFilter === 'low-stock') return x.priority === 1;
            if (_dssFilter === 'ok')        return x.priority === 2;
            return true;
        });
    }

    if (search.trim()) {
        const q = search.toLowerCase();
        rows = rows.filter(function (x) {
            return x.item.itemName.toLowerCase().includes(q) || x.item.itemNum.toLowerCase().includes(q);
        });
    }

    if (rows.length === 0) {
        body.innerHTML = '<tr><td colspan="7" class="dss-empty">No items match the current filter.</td></tr>';
        return;
    }

    body.innerHTML = rows.map(function (x) {
        const i = x.item;
        const barColor = x.priority === 0 ? '#e53e3e'
            : x.priority === 1 ? '#d69e2e'
            : '#38a169';
        const daysText = x.daysLeft >= 999 ? '<span style="color:#a0aec0;">∞ no usage</span>' : '<span style="color:' + barColor + ';font-weight:800;">' + x.daysLeft + ' days</span>';
        const rateText = x.dailyRate > 0 ? x.dailyRate.toFixed(2) + '<span style="color:#a0aec0;font-size:0.72rem;"> / day</span>' : '<span style="color:#a0aec0;">No data</span>';

        const priorityBadge = '<span class="dss-priority-badge" style="background:' + x.priorityColor + '18;color:' + x.priorityColor + ';border:1.5px solid ' + x.priorityColor + '40;">'
            + x.priorityLabel + '</span>';

        const decisionIcon = x.priority === 0 ? '🚨' : x.priority === 1 ? '⚠️' : '✅';

        return '<tr class="dss-tr">'
            // Item
            + '<td class="dss-td">'
            + '<div class="dss-item-name">' + i.itemName + '</div>'
            + '<div class="dss-item-sub">' + i.itemNum + ' &nbsp;·&nbsp; ' + i.commodityGroup + '</div>'
            + '</td>'
            // Stock status
            + '<td class="dss-td">'
            + '<div class="dss-stock-nums"><span style="font-size:1.05rem;font-weight:900;color:' + barColor + ';">' + i.stock + '</span><span class="dss-stock-sep"> / </span><span class="dss-stock-max">' + i.maxLevel + ' ' + i.unit + '</span></div>'
            + '<div class="dss-bar-track"><div class="dss-bar-fill" style="width:' + x.stockPct + '%;background:' + barColor + ';"></div></div>'
            + '<div class="dss-stock-hint">Min: ' + i.minLevel + ' &nbsp;·&nbsp; Reorder pt: ' + (i.reorderLevel || i.reorderQty || '—') + '</div>'
            + '</td>'
            // Consumption rate
            + '<td class="dss-td">'
            + '<div class="dss-rate">' + rateText + '</div>'
            + '<div class="dss-item-sub">Used: ' + x.totalConsumed + ' ' + i.unit + '</div>'
            + '</td>'
            // Days left
            + '<td class="dss-td">'
            + '<div>' + daysText + '</div>'
            + (x.leadTimeDemand > 0 ? '<div class="dss-item-sub">Lead need: ' + x.leadTimeDemand + ' ' + i.unit + '</div>' : '<div class="dss-item-sub">—</div>')
            + '</td>'
            // Recommended order
            + '<td class="dss-td">'
            + (x.priority <= 1
                ? '<div class="dss-order-qty" style="color:' + barColor + ';">' + x.recommendQty + ' <span style="font-size:0.78rem;font-weight:600;color:#718096;">' + i.unit + '</span></div>'
                + '<div class="dss-item-sub">≈ ₱' + (x.recommendQty * (i.price || 0)).toLocaleString('en-PH', { minimumFractionDigits: 2 }) + '</div>'
                : '<div style="color:#a0aec0;font-weight:700;font-size:0.85rem;">—</div>')
            + '</td>'
            // Priority
            + '<td class="dss-td">' + priorityBadge + '</td>'
            // Decision
            + '<td class="dss-td"><div class="dss-decision">' + decisionIcon + ' ' + x.decision + '</div></td>'
            + '</tr>';
    }).join('');
}

function renderDSSInsights() {
    const el = document.getElementById('dssInsightsGrid');
    if (!el) return;

    const d = _dssData;
    const topConsumed = d.slice().sort(function (a, b) { return b.totalConsumed - a.totalConsumed; }).slice(0, 5);
    const fastMoving  = d.filter(function (x) { return x.dailyRate > 0; }).sort(function (a, b) { return b.dailyRate - a.dailyRate; }).slice(0, 5);
    const needOrder   = d.filter(function (x) { return x.priority <= 1; });

    el.innerHTML = '<div class="dss-insight-card">'
        + '<div class="dss-insight-title">📦 Top Consumed Items</div>'
        + (topConsumed.length === 0
            ? '<div class="dss-insight-empty">No consumption data yet.</div>'
            : topConsumed.map(function (x, i) {
                return '<div class="dss-insight-row">'
                    + '<span class="dss-insight-rank">' + (i + 1) + '</span>'
                    + '<span class="dss-insight-name">' + x.item.itemName + '</span>'
                    + '<span class="dss-insight-val">' + x.totalConsumed + ' ' + x.item.unit + '</span>'
                    + '</div>';
            }).join(''))
        + '</div>'

        + '<div class="dss-insight-card">'
        + '<div class="dss-insight-title">⚡ Fastest Moving Items</div>'
        + (fastMoving.length === 0
            ? '<div class="dss-insight-empty">No usage rate data yet.</div>'
            : fastMoving.map(function (x, i) {
                return '<div class="dss-insight-row">'
                    + '<span class="dss-insight-rank">' + (i + 1) + '</span>'
                    + '<span class="dss-insight-name">' + x.item.itemName + '</span>'
                    + '<span class="dss-insight-val">' + x.dailyRate.toFixed(2) + '/day</span>'
                    + '</div>';
            }).join(''))
        + '</div>'

        + '<div class="dss-insight-card">'
        + '<div class="dss-insight-title">🛒 Items to Order Now</div>'
        + (needOrder.length === 0
            ? '<div class="dss-insight-empty" style="color:#38a169;">✅ All stock levels are adequate.</div>'
            : needOrder.map(function (x) {
                return '<div class="dss-insight-row">'
                    + '<span class="dss-priority-dot" style="background:' + x.priorityColor + ';"></span>'
                    + '<span class="dss-insight-name">' + x.item.itemName + '</span>'
                    + '<span class="dss-insight-val" style="color:' + x.priorityColor + ';">' + x.recommendQty + ' ' + x.item.unit + '</span>'
                    + '</div>';
            }).join(''))
        + '</div>';
}

window.dssSetFilter = function (filter, btn) {
    _dssFilter = filter;
    document.querySelectorAll('.dss-pill').forEach(function (p) { p.classList.remove('active'); });
    if (btn) btn.classList.add('active');
    renderDSSTable();
};

window.dssApplySearch = function () { renderDSSTable(); };

window.dssPrintReport = function () {
    const rows = _dssData.filter(function (x) { return x.priority <= 3; });
    if (rows.length === 0) { alert('All stock levels are adequate. No replenishment needed.'); return; }

    const today = new Date();
    const poNumber = 'PO-' + today.getFullYear() + '-' + String(today.getMonth()+1).padStart(2,'0') + String(today.getDate()).padStart(2,'0') + '-' + String(Math.floor(Math.random()*900)+100);
    const dateStr  = today.toLocaleDateString('en-PH', { year:'numeric', month:'long', day:'numeric' });
    const totalValue = rows.reduce(function(s,x){ return s + (x.recommendQty * (x.item.price||0)); }, 0);

    const lineItems = rows.map(function(x, idx){
        const unitCost = x.item.price || 0;
        const total    = x.recommendQty * unitCost;
        const urgency  = x.priority === 0 ? 'OUT OF STOCK' : x.priority === 1 ? 'CRITICAL' : x.priority === 2 ? 'WARNING' : 'REORDER';
        const urgencyColor = x.priority <= 1 ? '#c53030' : x.priority === 2 ? '#b7791f' : '#2b6cb0';
        return '<tr style="border-bottom:1px solid #e2e8f0;">'
            + '<td style="padding:10px 12px;text-align:center;color:#718096;font-size:11px;">' + (idx+1) + '</td>'
            + '<td style="padding:10px 12px;font-size:11px;color:#718096;font-family:monospace;">' + x.item.itemNum + '</td>'
            + '<td style="padding:10px 12px;"><div style="font-weight:700;color:#1a202c;font-size:12px;">' + x.item.itemName + '</div>'
            +   '<div style="font-size:10px;color:#a0aec0;margin-top:2px;">' + (x.item.commodityGroup||'') + '</div></td>'
            + '<td style="padding:10px 12px;text-align:center;font-size:12px;">' + x.item.unit + '</td>'
            + '<td style="padding:10px 12px;text-align:center;font-size:12px;color:#718096;">' + x.item.stock + '</td>'
            + '<td style="padding:10px 12px;text-align:center;font-weight:800;font-size:13px;color:#1a202c;">' + x.recommendQty + '</td>'
            + '<td style="padding:10px 12px;text-align:right;font-size:12px;">₱' + unitCost.toLocaleString('en-PH',{minimumFractionDigits:2}) + '</td>'
            + '<td style="padding:10px 12px;text-align:right;font-weight:700;font-size:12px;color:#1a202c;">₱' + total.toLocaleString('en-PH',{minimumFractionDigits:2}) + '</td>'
            + '<td style="padding:10px 12px;text-align:center;"><span style="background:' + urgencyColor + '18;color:' + urgencyColor + ';border:1px solid ' + urgencyColor + '40;padding:2px 8px;border-radius:20px;font-size:9px;font-weight:800;letter-spacing:0.3px;">' + urgency + '</span></td>'
            + '</tr>';
    }).join('');

    const html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Purchase Order ' + poNumber + '</title>'
        + '<style>'
        + '*{margin:0;padding:0;box-sizing:border-box;}'
        + 'body{font-family:"Segoe UI",Arial,sans-serif;font-size:12px;color:#1a202c;background:white;}'
        + '@page{size:A4;margin:15mm 12mm;}'
        + '@media print{body{-webkit-print-color-adjust:exact;print-color-adjust:exact;}}'
        + '.page{max-width:780px;margin:0 auto;padding:24px;}'
        + '</style>'
        + '</head><body><div class="page">'

        // ── Header ──
        + '<table style="width:100%;margin-bottom:24px;border-bottom:3px solid #E31E24;padding-bottom:16px;">'
        + '<tr>'
        + '<td style="width:160px;vertical-align:middle;">'
        +   '<img src="img/logo_caltex.png" style="width:140px;height:auto;object-fit:contain;" onerror="this.style.display=\'none\'">'
        + '</td>'
        + '<td style="vertical-align:middle;padding-left:20px;">'
        +   '<div style="font-size:9px;color:#718096;font-weight:700;text-transform:uppercase;letter-spacing:1px;margin-bottom:4px;">JA Noble Enterprise</div>'
        +   '<div style="font-size:22px;font-weight:900;color:#1a202c;letter-spacing:-0.5px;">PURCHASE ORDER</div>'
        +   '<div style="font-size:11px;color:#718096;margin-top:4px;">Stock Replenishment Request</div>'
        + '</td>'
        + '<td style="text-align:right;vertical-align:top;">'
        +   '<div style="background:#E31E24;color:white;padding:8px 16px;border-radius:8px;display:inline-block;margin-bottom:8px;">'
        +     '<div style="font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;opacity:0.85;">PO Number</div>'
        +     '<div style="font-size:14px;font-weight:900;letter-spacing:0.5px;">' + poNumber + '</div>'
        +   '</div>'
        +   '<div style="font-size:10px;color:#718096;margin-top:4px;">Date: <strong>' + dateStr + '</strong></div>'
        +   '<div style="font-size:10px;color:#718096;margin-top:2px;">Generated by: <strong>DSS System</strong></div>'
        + '</td>'
        + '</tr></table>'

        // ── Info Row ──
        + '<table style="width:100%;margin-bottom:20px;border-collapse:collapse;">'
        + '<tr>'
        + '<td style="width:48%;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:12px 16px;vertical-align:top;">'
        +   '<div style="font-size:9px;font-weight:800;color:#718096;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:8px;border-bottom:1px solid #e2e8f0;padding-bottom:6px;">Bill To / Requesting Party</div>'
        +   '<div style="font-weight:700;font-size:12px;color:#1a202c;">JA Noble Enterprise</div>'
        +   '<div style="font-size:11px;color:#718096;margin-top:3px;">Caltex Service Station</div>'
        +   '<div style="font-size:11px;color:#718096;margin-top:2px;">Inventory Management Department</div>'
        + '</td>'
        + '<td style="width:4%;"></td>'
        + '<td style="width:48%;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:12px 16px;vertical-align:top;">'
        +   '<div style="font-size:9px;font-weight:800;color:#718096;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:8px;border-bottom:1px solid #e2e8f0;padding-bottom:6px;">Order Summary</div>'
        +   '<table style="width:100%;font-size:11px;"><tr><td style="color:#718096;padding:2px 0;">Total Line Items:</td><td style="text-align:right;font-weight:700;">' + rows.length + ' items</td></tr>'
        +   '<tr><td style="color:#718096;padding:2px 0;">Items to Order:</td><td style="text-align:right;font-weight:700;">' + rows.reduce(function(s,x){return s+x.recommendQty;},0) + ' units total</td></tr>'
        +   '<tr><td style="color:#718096;padding:2px 0;">Estimated Total Value:</td><td style="text-align:right;font-weight:800;color:#E31E24;font-size:13px;">₱' + totalValue.toLocaleString('en-PH',{minimumFractionDigits:2}) + '</td></tr>'
        +   '</table>'
        + '</td>'
        + '</tr></table>'

        // ── Table ──
        + '<table style="width:100%;border-collapse:collapse;margin-bottom:20px;">'
        + '<thead>'
        + '<tr style="background:#1a202c;color:white;">'
        + '<th style="padding:10px 12px;text-align:center;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;width:32px;">#</th>'
        + '<th style="padding:10px 12px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;width:90px;">Item No.</th>'
        + '<th style="padding:10px 12px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;">Description</th>'
        + '<th style="padding:10px 12px;text-align:center;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;width:50px;">UOM</th>'
        + '<th style="padding:10px 12px;text-align:center;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;width:60px;">On Hand</th>'
        + '<th style="padding:10px 12px;text-align:center;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;width:60px;">Order Qty</th>'
        + '<th style="padding:10px 12px;text-align:right;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;width:80px;">Unit Cost</th>'
        + '<th style="padding:10px 12px;text-align:right;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;width:90px;">Total</th>'
        + '<th style="padding:10px 12px;text-align:center;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;width:80px;">Priority</th>'
        + '</tr>'
        + '</thead>'
        + '<tbody>' + lineItems + '</tbody>'
        + '<tfoot>'
        + '<tr style="background:#f8fafc;">'
        + '<td colspan="7" style="padding:12px;text-align:right;font-weight:700;font-size:12px;color:#4a5568;border-top:2px solid #e2e8f0;">ESTIMATED TOTAL ORDER VALUE</td>'
        + '<td style="padding:12px;text-align:right;font-weight:900;font-size:15px;color:#E31E24;border-top:2px solid #e2e8f0;">₱' + totalValue.toLocaleString('en-PH',{minimumFractionDigits:2}) + '</td>'
        + '<td style="border-top:2px solid #e2e8f0;"></td>'
        + '</tr>'
        + '</tfoot>'
        + '</table>'

        // ── Notes ──
        + '<div style="background:#fffbeb;border:1px solid #fbd38d;border-radius:8px;padding:12px 16px;margin-bottom:20px;">'
        + '<div style="font-size:10px;font-weight:800;color:#b7791f;text-transform:uppercase;letter-spacing:0.4px;margin-bottom:6px;">⚠️ Notes / Remarks</div>'
        + '<div style="font-size:11px;color:#744210;line-height:1.6;">This Purchase Order was automatically generated by the Decision Support System based on current stock levels and consumption rates. Please verify quantities before submission. Unit costs are based on last recorded prices and may vary.</div>'
        + '</div>'

        // ── Signature Block ──
        + '<table style="width:100%;border-collapse:collapse;margin-top:8px;">'
        + '<tr>'
        + '<td style="width:30%;text-align:center;padding:0 12px;">'
        +   '<div style="border-top:1.5px solid #1a202c;padding-top:8px;margin-top:40px;">'
        +   '<div style="font-size:11px;font-weight:700;">Prepared By</div>'
        +   '<div style="font-size:10px;color:#718096;margin-top:2px;">Inventory Staff</div>'
        +   '</div>'
        + '</td>'
        + '<td style="width:30%;text-align:center;padding:0 12px;">'
        +   '<div style="border-top:1.5px solid #1a202c;padding-top:8px;margin-top:40px;">'
        +   '<div style="font-size:11px;font-weight:700;">Reviewed By</div>'
        +   '<div style="font-size:10px;color:#718096;margin-top:2px;">Supervisor</div>'
        +   '</div>'
        + '</td>'
        + '<td style="width:30%;text-align:center;padding:0 12px;">'
        +   '<div style="border-top:1.5px solid #1a202c;padding-top:8px;margin-top:40px;">'
        +   '<div style="font-size:11px;font-weight:700;">Approved By</div>'
        +   '<div style="font-size:10px;color:#718096;margin-top:2px;">Manager</div>'
        +   '</div>'
        + '</td>'
        + '</tr></table>'

        // ── Footer ──
        + '<div style="margin-top:24px;padding-top:12px;border-top:1px solid #e2e8f0;display:flex;justify-content:space-between;align-items:center;">'
        + '<div style="font-size:9px;color:#a0aec0;">JA Noble Enterprise · Caltex Service Station · DSS-generated Purchase Order</div>'
        + '<div style="font-size:9px;color:#a0aec0;">' + poNumber + ' · ' + dateStr + '</div>'
        + '</div>'

        + '</div></body></html>';

    const w = window.open('', '_blank');
    w.document.write(html);
    w.document.close();
    w.focus();
    setTimeout(function(){ w.print(); }, 400);
};

// ── DSS Preventive Maintenance Scheduling ──────────────────────────────────

var _dssPmsData = [];
var _dssPmsFilter = 'all';

function dssAnalyzePMS() {
    var today = new Date();
    today = new Date(today.getFullYear(), today.getMonth(), today.getDate());

    return (window.assets || []).map(function (asset) {
        // Days until / since next PMS — midnight-to-midnight comparison
        var daysUntil = null;
        var isOverdue = false;
        if (asset.nextPMSDue) {
            var due = new Date(asset.nextPMSDue);
            var dueMidnight = new Date(due.getFullYear(), due.getMonth(), due.getDate());
            daysUntil = Math.round((dueMidnight - today) / (1000 * 60 * 60 * 24));
            isOverdue = daysUntil < 0;
        }

        // Average cost per service from serviceTransactions
        var assetSvcs = (window.serviceTransactions || []).filter(function (s) {
            return s.assetNum === asset.assetNum && s.status === 'completed';
        });
        var avgCost = 0;
        if (assetSvcs.length > 0) {
            avgCost = assetSvcs.reduce(function (sum, s) { return sum + (s.totalCost || 0); }, 0) / assetSvcs.length;
        } else if (asset.maintenanceHistory && asset.maintenanceHistory.length > 0) {
            var totalHistCost = asset.maintenanceHistory.reduce(function (sum, h) { return sum + (h.cost || 0); }, 0);
            avgCost = totalHistCost / asset.maintenanceHistory.length;
        }

        // Service interval adherence: compare actual vs expected frequency (months)
        var adherence = null;
        if (asset.lastServiceDate && asset.serviceFrequency) {
            var last = new Date(asset.lastServiceDate);
            var monthsSinceLast = (today - last) / (1000 * 60 * 60 * 24 * 30.44);
            adherence = Math.min(100, Math.round((asset.serviceFrequency / Math.max(monthsSinceLast, 0.1)) * 100));
        }

        // Urgency score (lower = more urgent)
        var urgency;
        var priorityLabel, priorityColor, statusKey;

        if (asset.status === 'maintenance') {
            urgency = 0;
            priorityLabel = 'UNDER MAINTENANCE';
            priorityColor = '#3182ce';
            statusKey = 'maintenance';
        } else if (isOverdue) {
            urgency = 1;
            priorityLabel = 'OVERDUE';
            priorityColor = '#e53e3e';
            statusKey = 'overdue';
        } else if (daysUntil !== null && daysUntil <= 7) {
            urgency = 2;
            priorityLabel = 'DUE THIS WEEK';
            priorityColor = '#dd6b20';
            statusKey = 'this-week';
        } else if (daysUntil !== null && daysUntil <= 14) {
            urgency = 3;
            priorityLabel = 'DUE SOON';
            priorityColor = '#d69e2e';
            statusKey = 'due-soon';
        } else if (daysUntil !== null && daysUntil <= 30) {
            urgency = 4;
            priorityLabel = 'SCHEDULED';
            priorityColor = '#3182ce';
            statusKey = 'scheduled';
        } else {
            urgency = 5;
            priorityLabel = 'ON TRACK';
            priorityColor = '#38a169';
            statusKey = 'on-track';
        }

        // Recommendation text
        var recommendation;
        if (asset.status === 'maintenance') {
            recommendation = 'Currently under maintenance — monitor progress';
        } else if (isOverdue) {
            recommendation = 'Schedule PMS immediately — overdue by ' + Math.abs(daysUntil) + ' day(s)';
        } else if (daysUntil !== null && daysUntil <= 7) {
            recommendation = 'Schedule PMS within this week';
        } else if (daysUntil !== null && daysUntil <= 14) {
            recommendation = 'Plan PMS within 2 weeks';
        } else if (daysUntil !== null && daysUntil <= 30) {
            recommendation = 'PMS scheduled — prepare parts & mechanic';
        } else {
            recommendation = 'No action needed — next PMS on schedule';
        }

        return {
            asset: asset,
            daysUntil: daysUntil,
            isOverdue: isOverdue,
            avgCost: avgCost,
            adherence: adherence,
            urgency: urgency,
            priorityLabel: priorityLabel,
            priorityColor: priorityColor,
            statusKey: statusKey,
            recommendation: recommendation,
            serviceCount: assetSvcs.length + (asset.maintenanceHistory ? asset.maintenanceHistory.length : 0)
        };
    }).sort(function (a, b) { return a.urgency - b.urgency; });
}

window.renderDSSPMS = function () {
    _dssPmsData = dssAnalyzePMS();
    renderDSSPMSKpis();
    renderDSSPMSTable();
    renderDSSPMSInsights();
};

function renderDSSPMSKpis() {
    var el = document.getElementById('dssPmsKpiGrid');
    if (!el) return;
    var d = _dssPmsData;

    var overdue   = d.filter(function (x) { return x.statusKey === 'overdue'; }).length;
    var thisWeek  = d.filter(function (x) { return x.statusKey === 'this-week'; }).length;
    var dueSoon   = d.filter(function (x) { return x.statusKey === 'due-soon'; }).length;
    var scheduled = d.filter(function (x) { return x.statusKey === 'scheduled'; }).length;
    var onTrack   = d.filter(function (x) { return x.statusKey === 'on-track'; }).length;

    el.innerHTML = [
        { svg: '<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>',
          label: 'Due This Week', val: thisWeek, color: '#dd6b20', bg: 'rgba(221,107,32,0.10)' },
        { svg: '<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>',
          label: 'Overdue PMS', val: overdue, color: '#e53e3e', bg: 'rgba(229,62,62,0.10)' },
        { svg: '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
          label: 'Due Soon', val: dueSoon, color: '#b7791f', bg: 'rgba(183,121,31,0.10)' },
        { svg: '<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><polyline points="9 14 11 16 15 12"/>',
          label: 'Scheduled', val: scheduled, color: '#003087', bg: 'rgba(0,48,135,0.10)' },
        { svg: '<polyline points="20 6 9 17 4 12"/>',
          label: 'On Track', val: onTrack, color: '#276749', bg: 'rgba(39,103,73,0.10)' },
    ].map(function (k) {
        return '<div class="stat-card">'
            + '<div class="stat-icon" style="background:' + k.bg + ';color:' + k.color + ';">'
            +   '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + k.svg + '</svg>'
            + '</div>'
            + '<div class="stat-number" style="color:' + k.color + ';">' + k.val + '</div>'
            + '<div class="stat-label">' + k.label + '</div>'
            + '</div>';
    }).join('');
}

function renderDSSPMSTable() {
    var body = document.getElementById('dssPmsTableBody');
    if (!body) return;

    var search = (document.getElementById('dssPmsSearch') || {}).value || '';
    var rows = _dssPmsData;

    if (_dssPmsFilter !== 'all') {
        rows = rows.filter(function (x) { return x.statusKey === _dssPmsFilter; });
    }

    if (search.trim()) {
        var q = search.toLowerCase();
        rows = rows.filter(function (x) {
            return x.asset.assetDescription.toLowerCase().includes(q)
                || x.asset.plateNumber.toLowerCase().includes(q)
                || x.asset.assetNum.toLowerCase().includes(q);
        });
    }

    if (rows.length === 0) {
        body.innerHTML = '<tr><td colspan="8" class="dss-empty">No assets match the current filter.</td></tr>';
        return;
    }

    body.innerHTML = rows.map(function (x) {
        var a = x.asset;
        var c = x.priorityColor;

        var lastSvc = a.lastServiceDate
            ? new Date(a.lastServiceDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
            : '—';
        var nextPMS = a.nextPMSDue
            ? new Date(a.nextPMSDue).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
            : '—';
        var odo = a.odometer ? a.odometer.toLocaleString() + ' km' : '—';

        var daysCell;
        if (x.daysUntil === null) {
            daysCell = '<span style="color:#a0aec0;">No PMS date</span>';
        } else if (x.isOverdue) {
            daysCell = '<span style="color:#e53e3e;font-weight:800;">⚠️ ' + Math.abs(x.daysUntil) + ' days overdue</span>';
        } else {
            daysCell = '<span style="color:' + c + ';font-weight:800;">' + x.daysUntil + ' days</span>';
        }

        var costCell = x.avgCost > 0
            ? '₱' + x.avgCost.toLocaleString('en-PH', { minimumFractionDigits: 2 })
            : '<span style="color:#a0aec0;">No data</span>';

        var badge = '<span class="dss-priority-badge" style="background:' + c + '18;color:' + c + ';border:1.5px solid ' + c + '40;">' + x.priorityLabel + '</span>';

        return '<tr class="dss-tr">'
            + '<td class="dss-td">'
            +   '<div class="dss-item-name">' + a.plateNumber + '</div>'
            +   '<div class="dss-item-sub">' + a.assetDescription + '</div>'
            + '</td>'
            + '<td class="dss-td"><div style="font-weight:600;">' + lastSvc + '</div></td>'
            + '<td class="dss-td"><div style="font-weight:600;color:' + c + ';">' + nextPMS + '</div></td>'
            + '<td class="dss-td">' + daysCell + '</td>'
            + '<td class="dss-td">' + badge + '</td>'
            + '<td class="dss-td"><div class="dss-decision">' + x.recommendation + '</div></td>'
            + '</tr>';
    }).join('');
}

function renderDSSPMSInsights() {
    var el = document.getElementById('dssPmsInsightsGrid');
    if (!el) return;
    var d = _dssPmsData;

    var mostOverdue = d.filter(function (x) { return x.isOverdue; })
                       .sort(function (a, b) { return a.daysUntil - b.daysUntil; })
                       .slice(0, 5);

    var highestCost = d.filter(function (x) { return x.avgCost > 0; })
                       .sort(function (a, b) { return b.avgCost - a.avgCost; })
                       .slice(0, 5);

    var actionNeeded = d.filter(function (x) { return x.urgency <= 3; });

    el.innerHTML = '<div class="dss-insight-card">'
        + '<div class="dss-insight-title">🔴 Most Overdue Assets</div>'
        + (mostOverdue.length === 0
            ? '<div class="dss-insight-empty" style="color:#38a169;">✅ No overdue PMS.</div>'
            : mostOverdue.map(function (x, i) {
                return '<div class="dss-insight-row">'
                    + '<span class="dss-insight-rank">' + (i + 1) + '</span>'
                    + '<span class="dss-insight-name">' + x.asset.plateNumber + '</span>'
                    + '<span class="dss-insight-val" style="color:#e53e3e;">' + Math.abs(x.daysUntil) + 'd overdue</span>'
                    + '</div>';
            }).join(''))
        + '</div>'

        + '<div class="dss-insight-card">'
        + '<div class="dss-insight-title">💰 Highest Avg. Service Cost</div>'
        + (highestCost.length === 0
            ? '<div class="dss-insight-empty">No service cost data yet.</div>'
            : highestCost.map(function (x, i) {
                return '<div class="dss-insight-row">'
                    + '<span class="dss-insight-rank">' + (i + 1) + '</span>'
                    + '<span class="dss-insight-name">' + x.asset.plateNumber + '</span>'
                    + '<span class="dss-insight-val">₱' + x.avgCost.toLocaleString('en-PH', { minimumFractionDigits: 0 }) + '</span>'
                    + '</div>';
            }).join(''))
        + '</div>'

        + '<div class="dss-insight-card">'
        + '<div class="dss-insight-title">🛠️ Immediate Action Required</div>'
        + (actionNeeded.length === 0
            ? '<div class="dss-insight-empty" style="color:#38a169;">✅ All assets are on schedule.</div>'
            : actionNeeded.map(function (x) {
                return '<div class="dss-insight-row">'
                    + '<span class="dss-priority-dot" style="background:' + x.priorityColor + ';"></span>'
                    + '<span class="dss-insight-name">' + x.asset.plateNumber + '</span>'
                    + '<span class="dss-insight-val" style="color:' + x.priorityColor + ';">' + x.priorityLabel + '</span>'
                    + '</div>';
            }).join(''))
        + '</div>';
}

window.dssPMSSetFilter = function (filter, btn) {
    _dssPmsFilter = filter;
    document.querySelectorAll('#dssPmsFilterPills .dss-pill').forEach(function (p) { p.classList.remove('active'); });
    if (btn) btn.classList.add('active');
    renderDSSPMSTable();
};

window.dssPMSApplySearch = function () { renderDSSPMSTable(); };

window.dssPMSPrintReport = function () {
    var rows = _dssPmsData.filter(function (x) { return x.urgency <= 3; });
    if (rows.length === 0) { alert('All assets are on schedule. No immediate PMS action needed.'); return; }

    var html = '<html><head><title>Preventive Maintenance Schedule Report</title>'
        + '<style>body{font-family:Arial,sans-serif;font-size:12px;padding:20px;}h1{color:#E31E24;}table{width:100%;border-collapse:collapse;margin-top:16px;}th{background:#1a202c;color:white;padding:8px 10px;text-align:left;font-size:11px;}td{padding:7px 10px;border-bottom:1px solid #e2e8f0;}tr:nth-child(even){background:#f8fafc;}.badge{padding:2px 8px;border-radius:20px;font-weight:700;font-size:10px;}</style>'
        + '</head><body>'
        + '<h1>🔧 Preventive Maintenance Schedule Report</h1>'
        + '<p style="color:#718096;">Generated: ' + new Date().toLocaleString('en-PH') + '</p>'
        + '<table><thead><tr><th>Asset</th><th>Plate No.</th><th>Last Service</th><th>Next PMS Due</th><th>Days Until/Overdue</th><th>Avg. Cost</th><th>Priority</th><th>Recommendation</th></tr></thead><tbody>'
        + rows.map(function (x) {
            var a = x.asset;
            var lastSvc = a.lastServiceDate ? new Date(a.lastServiceDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
            var nextPMS = a.nextPMSDue ? new Date(a.nextPMSDue).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
            var daysText = x.daysUntil === null ? '—' : (x.isOverdue ? Math.abs(x.daysUntil) + 'd overdue' : x.daysUntil + ' days');
            var costText = x.avgCost > 0 ? '₱' + x.avgCost.toLocaleString('en-PH', { minimumFractionDigits: 2 }) : '—';
            return '<tr>'
                + '<td><strong>' + a.assetDescription + '</strong><br><small>' + a.assetNum + '</small></td>'
                + '<td>' + a.plateNumber + '</td>'
                + '<td>' + lastSvc + '</td>'
                + '<td>' + nextPMS + '</td>'
                + '<td><strong>' + daysText + '</strong></td>'
                + '<td>' + costText + '</td>'
                + '<td><span class="badge" style="background:' + x.priorityColor + '20;color:' + x.priorityColor + ';">' + x.priorityLabel + '</span></td>'
                + '<td>' + x.recommendation + '</td>'
                + '</tr>';
        }).join('')
        + '</tbody></table></body></html>';

    var w = window.open('', '_blank');
    w.document.write(html);
    w.document.close();
    w.print();
};
