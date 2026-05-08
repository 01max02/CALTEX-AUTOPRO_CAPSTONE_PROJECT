// Page → URL mapping for navigation
const PAGE_URLS = {
    'overview':                 'admin_dashboard.html',
    'item-master':              'admin_inventory_itemaster.html',
    'inventory':                'admin_inventory_stock.html',
    'inventory-transactions':   'admin_dashboard.html#inventory-transactions',
    'assets':                   'admin_vehicle_list.html',
    'asset-servicing':          'admin_vehicle_maintenance.html',
    'issuance':                 'admin_dashboard.html#issuance',
    'dss':                      'admin_dss.html',
    'dss-pms':                  'admin_dss.html#dss-pms',
    'users':                    'admin_users.html',
    'smart-reports':            'admin_smart_reports.html',
    'domains':                  'admin_domain_management.html',
};

function navigateTo(section) {
    const url = PAGE_URLS[section];
    if (!url) return;

    // If we're navigating to a hash on the same page, update data-page and active state in place
    const currentPage = window.location.pathname.split('/').pop();
    const [targetFile, targetHash] = url.split('#');

    if (currentPage === targetFile && targetHash) {
        document.body.setAttribute('data-page', section);
        initSidebarActive();
        window.location.hash = targetHash;
        // Switch the visible section and header controls
        if (typeof switchAdminSection === 'function') switchAdminSection(section);
        if (typeof switchDSSSection === 'function') switchDSSSection(section);
        _closeSidebar();
    } else if (currentPage === targetFile && !targetHash) {
        document.body.setAttribute('data-page', section);
        initSidebarActive();
        history.pushState(null, '', window.location.pathname);
        if (typeof switchAdminSection === 'function') switchAdminSection(section);
        if (typeof switchDSSSection === 'function') switchDSSSection(section);
        _closeSidebar();
    } else {
        window.location.href = url;
    }
}

// Close sidebar + overlay after navigation (mobile)
function _closeSidebar() {
    const sidebar = document.getElementById('adminSidebar');
    const overlay = document.getElementById('adminSidebarOverlay');
    if (sidebar) sidebar.classList.remove('admin-sidebar-open');
    if (overlay) overlay.classList.remove('active');
}

function toggleAdminSidebar() {
    const sidebar = document.getElementById('adminSidebar');
    const overlay = document.getElementById('adminSidebarOverlay');
    if (!sidebar) return;
    const isOpen = sidebar.classList.toggle('admin-sidebar-open');
    if (overlay) overlay.classList.toggle('active', isOpen);
}

function initSidebarActive() {
    const page = document.body.getAttribute('data-page') || 'overview';

    document.querySelectorAll('.admin-nav-btn[data-section]').forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('data-section') === page);
    });
}

function bindHeaderControls() {
    const menuBtn = document.getElementById('adminMenuBtn');
    if (menuBtn) menuBtn.addEventListener('click', toggleAdminSidebar);

    const overlay = document.getElementById('adminSidebarOverlay');
    if (overlay) overlay.addEventListener('click', toggleAdminSidebar);

    // Apply cached notification badge count (set by admin_firebase.js onSnapshot)
    // This handles the case where the snapshot fired before the header was injected
    if (typeof window._adminUnreadCount !== 'undefined') {
        const badge = document.getElementById('adminHeaderNotifBadge');
        if (badge) {
            const unread = window._adminUnreadCount;
            badge.textContent = unread > 9 ? '9+' : unread;
            badge.style.display = unread > 0 ? 'flex' : 'none';
        }
    }

    if (typeof firebase !== 'undefined') {
        firebase.auth().onAuthStateChanged(user => {
            if (user) {
                const avatar   = document.getElementById('adminHeaderAvatar');
                const nameEl   = document.getElementById('adminAvatarName');

                // Try sessionStorage first (instant)
                const sess = JSON.parse(sessionStorage.getItem('apUser') || '{}');
                const sessName = sess.name || '';
                if (sessName && avatar) {
                    const parts = sessName.trim().split(' ').filter(Boolean);
                    avatar.textContent = parts.length >= 2
                        ? (parts[0][0] + parts[1][0]).toUpperCase()
                        : parts[0].slice(0, 2).toUpperCase();
                    if (nameEl) nameEl.textContent = sessName;
                }

                // Then update from Firestore
                firebase.firestore().collection('users').doc(user.uid).get().then(doc => {
                    const name = (doc.exists && doc.data().name) ? doc.data().name : sessName || user.email || '';
                    if (!name) return;
                    const parts = name.trim().split(' ').filter(Boolean);
                    const initials = parts.length >= 2
                        ? (parts[0][0] + parts[1][0]).toUpperCase()
                        : parts[0].slice(0, 2).toUpperCase();
                    if (avatar) avatar.textContent = initials;
                    if (nameEl) nameEl.textContent  = name;
                }).catch(() => {});
            }
        });
    }
}

// Load header then sidebar, bind controls after both are ready
(function init() {
    const headerContainer  = document.getElementById('headerContainer');
    const sidebarContainer = document.getElementById('sidebarContainer');

    const headerPromise = headerContainer
        ? fetch('admin_header.html').then(r => r.text()).then(html => { headerContainer.innerHTML = html; })
        : Promise.resolve();

    const sidebarPromise = sidebarContainer
        ? fetch('admin_sidebar.html').then(r => r.text()).then(html => { sidebarContainer.innerHTML = html; initSidebarActive(); })
        : Promise.resolve();

    Promise.all([headerPromise, sidebarPromise]).then(bindHeaderControls);
})();


// ── Avatar dropdown ─────────────────────────────────────────
window.toggleAvatarMenu = function(id) {
    const menu = document.getElementById(id);
    if (!menu) return;
    const isOpen = menu.style.display === 'block';
    document.querySelectorAll('.avatar-menu').forEach(m => m.style.display = 'none');
    document.querySelectorAll('.notif-panel').forEach(p => p.style.display = 'none');
    if (!isOpen) {
        menu.style.display = 'block';
        // Populate name from session
        const sess = JSON.parse(
            sessionStorage.getItem('apUser') ||
            sessionStorage.getItem('spUser') ||
            sessionStorage.getItem('cpUser') || '{}'
        );
        const nameEl = menu.querySelector('.avatar-menu-name');
        if (nameEl && sess.name) nameEl.textContent = sess.name;
    }
};

window.adminAvatarLogout = function() {
    if (!confirm('Are you sure you want to logout?')) return;
    sessionStorage.removeItem('apUser');
    sessionStorage.removeItem('spUser');
    sessionStorage.removeItem('cpUser');
    if (typeof firebase !== 'undefined' && firebase.auth) {
        firebase.auth().signOut().finally(() => {
            // Replace the entire history stack with login page so back button
            // cannot return to any authenticated page
            history.replaceState(null, '', '/login.html');
            window.location.replace('/login.html');
        });
    } else {
        history.replaceState(null, '', '/login.html');
        window.location.replace('/login.html');
    }
};

window.cuAvatarLogout = window.adminAvatarLogout;

// Close avatar menu on outside click
document.addEventListener('click', function(e) {
    const menus   = document.querySelectorAll('.avatar-menu');
    const avatars = document.querySelectorAll('[onclick*="toggleAvatarMenu"]');
    let inside = false;
    menus.forEach(m   => { if (m.contains(e.target))   inside = true; });
    avatars.forEach(a => { if (a.contains(e.target))   inside = true; });
    if (!inside) menus.forEach(m => m.style.display = 'none');
});

// ── Back/Forward navigation guard ───────────────────────────
// If the user presses the browser back button after logout,
// check auth state and redirect to login if no session exists.
window.addEventListener('pageshow', function(e) {
    // pageshow fires on back-forward cache restore too (e.persisted === true)
    const hasSession = sessionStorage.getItem('apUser') ||
                       sessionStorage.getItem('spUser') ||
                       sessionStorage.getItem('cpUser');
    if (!hasSession) {
        window.location.replace('/login.html');
        return;
    }
    // Also verify Firebase auth is still active
    if (typeof firebase !== 'undefined' && firebase.auth) {
        firebase.auth().onAuthStateChanged(function(user) {
            if (!user) {
                // Delay check — Firebase fires null first during auth restore
                setTimeout(function() {
                    if (!firebase.auth().currentUser) {
                        sessionStorage.removeItem('apUser');
                        sessionStorage.removeItem('spUser');
                        sessionStorage.removeItem('cpUser');
                        window.location.replace('/login.html');
                    }
                }, 2000);
            }
        });
    }
});