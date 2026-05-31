// staff_mobileview.js — Staff Portal Mobile View
// Depends on script.js (provides: assets, inventory, serviceTransactions, issuances)

(function () {

    // ── Auth guard ──────────────────────────────────────────
    var stored = sessionStorage.getItem('spUser');
    if (!stored) { window.location.href = 'index.html'; return; }
    var spUser = JSON.parse(stored);
    window.currentUser = spUser;

    // ── Shared data counters ────────────────────────────────
    var nextAssetId = window.nextAssetId || (window.assets ? window.assets.length + 1 : 6);

    // ── Init UI ─────────────────────────────────────────────
    document.getElementById('smAvatar').textContent = spUser.avatar || spUser.name.charAt(0).toUpperCase();

    // ── Section switching ───────────────────────────────────
    window.smSwitchSection = function (sectionId, btn) {
        document.querySelectorAll('.sm-section').forEach(function (s) { s.classList.remove('active'); });
        document.querySelectorAll('.sm-nav-btn').forEach(function (b) { b.classList.remove('active'); });
        var sec = document.getElementById(sectionId);
        if (sec) sec.classList.add('active');
        if (btn) btn.classList.add('active');
        if (sectionId === 'sm-dashboard')    smRenderDashboard();
        if (sectionId === 'sm-inventory')    smRenderInventory();
        if (sectionId === 'sm-maintenance')  smRenderServices();
        if (sectionId === 'sm-assets')       smRenderAssets();
        if (sectionId === 'sm-profile')      smRenderProfile();
    };

    // ── Dashboard ───────────────────────────────────────────
    function smRenderDashboard() {
        var today = new Date(); today.setHours(0,0,0,0);
        var ongoing   = serviceTransactions.filter(function (s) { return s.status === 'ongoing'; }).length;
        var lowStock  = inventory.filter(function (i) { return i.status === 'low_stock'; }).length;
        var overdue   = assets.filter(function (a) {
            if (!a.nextPMSDue || a.status === 'maintenance' || a.status === 'inactive') return false;
            var due = new Date(a.nextPMSDue); due.setHours(0,0,0,0);
            return due < today;
        }).length;

        var statsEl = document.getElementById('smDashStats');
        if (statsEl) {
            statsEl.innerHTML = [
                { icon: '📋', label: 'Total Services', num: serviceTransactions.length, sub: 'All time' },
                { icon: '🔄', label: 'In Service Now', num: ongoing, sub: 'Ongoing' },
                { icon: '⚠️', label: 'Low Stock Items', num: lowStock, sub: 'Need reorder' },
                { icon: '🚨', label: 'PMS Overdue', num: overdue, sub: 'Needs attention' }
            ].map(function (s) {
                return '<div class="sm-stat-card"><div class="sm-stat-bg">' + s.icon + '</div>'
                    + '<div class="sm-stat-label">' + s.label + '</div>'
                    + '<div class="sm-stat-num">' + s.num + '</div>'
                    + '<div class="sm-stat-sub">' + s.sub + '</div></div>';
            }).join('');
        }

        var schedEl = document.getElementById('smTodaySchedule');
        if (!schedEl) return;
        var todaySvcs = serviceTransactions.filter(function (s) {
            if (!s.dateServiced) return false;
            var d = new Date(s.dateServiced); d.setHours(0,0,0,0);
            return d.getTime() === today.getTime();
        });
        if (todaySvcs.length === 0) {
            schedEl.innerHTML = '<div class="sm-empty">No services scheduled for today.</div>';
            return;
        }
        var statusColors = { pending: 'orange', ongoing: 'blue', complete: 'gray' };
        schedEl.innerHTML = todaySvcs.map(function (s) {
            var color = statusColors[s.status] || 'gray';
            return '<div class="sm-list-item ' + color + '">'
                + '<div class="sm-list-title">' + s.assetNum + ' — ' + (s.assetDescription || '') + '</div>'
                + '<div class="sm-list-sub">Mechanic: ' + (s.mechanicName || '—') + '</div>'
                + '<div class="sm-list-meta"><span class="sm-list-tag ' + color + '">' + s.status + '</span>'
                + '<span class="sm-list-tag">₱' + parseFloat(s.totalCost || 0).toLocaleString() + '</span></div>'
                + '</div>';
        }).join('');
    }

    // ── Inventory ───────────────────────────────────────────
    window.smRenderInventory = function () {
        var search = (document.getElementById('smInvSearch') || { value: '' }).value.toLowerCase();
        var filtered = inventory.filter(function (i) {
            return i.itemNum.toLowerCase().includes(search)
                || i.itemName.toLowerCase().includes(search)
                || (i.commodityGroup || '').toLowerCase().includes(search);
        });

        var lowStock = inventory.filter(function (i) { return i.status === 'low_stock'; }).length;
        var inStock  = inventory.filter(function (i) { return i.status === 'in_stock'; }).length;
        var statsEl  = document.getElementById('smInvStats');
        if (statsEl) {
            statsEl.innerHTML = [
                { icon: '📦', label: 'Total Items', num: inventory.length, sub: 'In master list' },
                { icon: '⚠️', label: 'Low Stock', num: lowStock, sub: 'Need reorder' },
                { icon: '✅', label: 'In Stock', num: inStock, sub: 'Available' }
            ].map(function (s) {
                return '<div class="sm-stat-card"><div class="sm-stat-bg">' + s.icon + '</div>'
                    + '<div class="sm-stat-label">' + s.label + '</div>'
                    + '<div class="sm-stat-num">' + s.num + '</div>'
                    + '<div class="sm-stat-sub">' + s.sub + '</div></div>';
            }).join('');
            statsEl.style.gridTemplateColumns = 'repeat(3,1fr)';
        }

        var listEl = document.getElementById('smInventoryList');
        if (!listEl) return;
        if (filtered.length === 0) { listEl.innerHTML = '<div class="sm-empty">No items found.</div>'; return; }

        var statusConfig = {
            low_stock:    { label: 'Low Stock',    color: '#ed8936', bg: '#fffbeb', border: '#fbd38d', dot: '#ed8936' },
            in_stock:     { label: 'In Stock',     color: '#38a169', bg: '#f0fff4', border: '#9ae6b4', dot: '#38a169' },
            out_of_stock: { label: 'Out of Stock', color: '#e53e3e', bg: '#fff5f5', border: '#feb2b2', dot: '#e53e3e' }
        };

        listEl.innerHTML = filtered.map(function (item) {
            var sc = statusConfig[item.status] || { label: item.status, color: '#718096', bg: '#f7fafc', border: '#e2e8f0', dot: '#a0aec0' };
            var maxLevel = item.maxLevel || 50;
            var pct = Math.min(100, Math.round((item.stock / maxLevel) * 100));
            var barColor = item.status === 'in_stock' ? '#38a169' : item.status === 'low_stock' ? '#ed8936' : '#e53e3e';

            return '<div class="sm-inv-card">'
                // Header row
                + '<div class="sm-inv-card-header">'
                + '<div class="sm-inv-icon-wrap">📦</div>'
                + '<div class="sm-inv-header-info">'
                + '<div class="sm-inv-name">' + item.itemName + '</div>'
                + '<div class="sm-inv-num">' + item.itemNum + ' · ' + item.commodityGroup + '</div>'
                + '</div>'
                + '<span class="sm-inv-status-badge" style="background:' + sc.bg + ';color:' + sc.color + ';border:1px solid ' + sc.border + ';">'
                + '<span style="width:6px;height:6px;border-radius:50%;background:' + sc.dot + ';display:inline-block;flex-shrink:0;"></span>'
                + sc.label + '</span>'
                + '</div>'
                // Stock bar
                + '<div class="sm-inv-stock-row">'
                + '<div class="sm-inv-stock-label">Stock Level</div>'
                + '<div class="sm-inv-stock-val">' + item.stock + ' / ' + maxLevel + ' ' + item.unit + '</div>'
                + '</div>'
                + '<div class="sm-inv-bar-track"><div class="sm-inv-bar-fill" style="width:' + pct + '%;background:' + barColor + ';"></div></div>'
                // Details row
                + '<div class="sm-inv-details-row">'
                + '<div class="sm-inv-detail-chip"><span class="sm-inv-detail-label">Min</span><span class="sm-inv-detail-val">' + (item.minLevel || item.reorderLevel || '—') + '</span></div>'
                + '<div class="sm-inv-detail-chip"><span class="sm-inv-detail-label">Max</span><span class="sm-inv-detail-val">' + (item.maxLevel || '—') + '</span></div>'
                + '<div class="sm-inv-detail-chip"><span class="sm-inv-detail-label">Price</span><span class="sm-inv-detail-val">₱' + (item.price || 0).toLocaleString() + '</span></div>'
                + '</div>'
                // View button
                + '<div class="sm-svc-actions" style="margin-top:0.75rem;">'
                + '<button class="sm-svc-btn view" onclick="smViewItemMaster(\'' + item.itemNum + '\')">📋 View Details</button>'
                + '</div>'
                + '</div>';
        }).join('');
    };

    // ── Item Master Modal ────────────────────────────────────
    window.smViewItemMaster = function (itemNum) {
        var item = inventory.find(function (i) { return i.itemNum === itemNum; });
        if (!item) return;

        document.getElementById('smItemMasterName').textContent = item.itemName;
        document.getElementById('smItemMasterNum').textContent = item.itemNum + (item.itemId ? ' · ' + item.itemId : '');

        var sc = {
            low_stock:    { label: 'Low Stock',    color: '#ed8936', bg: '#fffbeb', border: '#fbd38d' },
            in_stock:     { label: 'In Stock',     color: '#38a169', bg: '#f0fff4', border: '#9ae6b4' },
            out_of_stock: { label: 'Out of Stock', color: '#e53e3e', bg: '#fff5f5', border: '#feb2b2' }
        }[item.status] || { label: item.status, color: '#718096', bg: '#f7fafc', border: '#e2e8f0' };

        var maxLevel = item.maxLevel || 50;
        var pct = Math.min(100, Math.round((item.stock / maxLevel) * 100));
        var barColor = item.status === 'in_stock' ? '#38a169' : item.status === 'low_stock' ? '#ed8936' : '#e53e3e';
        var lastCount = item.lastPhysicalCount ? new Date(item.lastPhysicalCount).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';

        document.getElementById('smItemMasterBody').innerHTML =
            // Status badge
            '<div style="display:flex;justify-content:center;margin-bottom:1rem;">'
            + '<span style="display:inline-flex;align-items:center;gap:0.4rem;padding:0.4rem 1rem;border-radius:20px;font-size:0.82rem;font-weight:700;background:' + sc.bg + ';color:' + sc.color + ';border:1.5px solid ' + sc.border + ';">'
            + '<span style="width:8px;height:8px;border-radius:50%;background:' + sc.color + ';display:inline-block;"></span>' + sc.label + '</span></div>'

            // Stock bar
            + '<div class="sm-detail-section">'
            + '<div class="sm-detail-section-title">Stock Level</div>'
            + '<div style="display:flex;justify-content:space-between;font-size:0.85rem;margin-bottom:0.5rem;">'
            + '<span style="color:#718096;">Current</span><span style="font-weight:800;color:#1a202c;">' + item.stock + ' / ' + maxLevel + ' ' + item.unit + '</span></div>'
            + '<div class="sm-inv-bar-track" style="margin-bottom:0;"><div class="sm-inv-bar-fill" style="width:' + pct + '%;background:' + barColor + ';"></div></div>'
            + '</div>'

            // Item info
            + '<div class="sm-detail-section">'
            + '<div class="sm-detail-section-title">Item Info</div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Item No.</span><span class="sm-detail-val">' + item.itemNum + '</span></div>'
            + (item.itemId ? '<div class="sm-detail-row"><span class="sm-detail-key">Item ID</span><span class="sm-detail-val">' + item.itemId + '</span></div>' : '')
            + '<div class="sm-detail-row"><span class="sm-detail-key">Category</span><span class="sm-detail-val">' + (item.commodityGroup || '—') + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Unit</span><span class="sm-detail-val">' + item.unit + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Unit Price</span><span class="sm-detail-val">₱' + (item.price || 0).toLocaleString('en-PH', { minimumFractionDigits: 2 }) + '</span></div>'
            + '</div>'

            // Stock levels
            + '<div class="sm-detail-section">'
            + '<div class="sm-detail-section-title">Stock Levels</div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Min Level</span><span class="sm-detail-val">' + (item.minLevel || item.reorderLevel || '—') + ' ' + item.unit + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Reorder Level</span><span class="sm-detail-val">' + (item.reorderLevel || '—') + ' ' + item.unit + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Max Level</span><span class="sm-detail-val">' + (item.maxLevel || '—') + ' ' + item.unit + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Last Count</span><span class="sm-detail-val">' + lastCount + '</span></div>'
            + '</div>'

            // Barcode / QR
            + '<div class="sm-detail-section">'
            + '<div class="sm-detail-section-title">Identification</div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Barcode</span><span class="sm-detail-val" style="font-family:monospace;font-size:0.8rem;">' + (item.barcode || '—') + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">QR Code</span><span class="sm-detail-val" style="font-family:monospace;font-size:0.8rem;">' + (item.qrcode || '—') + '</span></div>'
            + '</div>'

            // Description
            + (item.longDescription
                ? '<div class="sm-detail-section"><div class="sm-detail-section-title">Description</div>'
                  + '<div style="font-size:0.85rem;color:#4a5568;line-height:1.6;">' + item.longDescription + '</div></div>'
                : '');

        smOpenModal('smItemMasterModal');
    };

    // ── Receive Items Modal ─────────────────────────────────
    var smReceiveItem = null;

    window.smOpenReceiveModal = function () {
        smReceiveItem = null;
        document.getElementById('smReceiveSearch').value = '';
        document.getElementById('smReceiveQty').value = '';
        document.getElementById('smReceiveItemInfo').style.display = 'none';
        smOpenModal('smReceiveModal');
    };

    window.smSearchReceiveItem = function () {
        var q = document.getElementById('smReceiveSearch').value.toLowerCase().trim();
        if (!q) { document.getElementById('smReceiveItemInfo').style.display = 'none'; smReceiveItem = null; return; }
        var found = inventory.find(function (i) {
            return i.itemNum.toLowerCase().includes(q) || i.itemName.toLowerCase().includes(q)
                || (i.barcode || '').toLowerCase().includes(q);
        });
        if (found) {
            smReceiveItem = found;
            document.getElementById('smReceiveItemName').textContent = found.itemName;
            document.getElementById('smReceiveCurrentStock').textContent = found.stock + ' ' + found.unit;
            document.getElementById('smReceiveUnit').textContent = found.unit;
            document.getElementById('smReceiveItemInfo').style.display = 'block';
        } else {
            smReceiveItem = null;
            document.getElementById('smReceiveItemInfo').style.display = 'none';
        }
    };

    window.smSubmitReceive = function () {
        if (!smReceiveItem) { alert('Please search and select an item first.'); return; }
        var qty = parseInt(document.getElementById('smReceiveQty').value);
        if (!qty || qty < 1) { alert('Please enter a valid quantity.'); return; }
        smReceiveItem.stock += qty;
        if (smReceiveItem.stock > (smReceiveItem.minLevel || smReceiveItem.reorderLevel || 0)) {
            smReceiveItem.status = 'in_stock';
        }
        if (typeof deliveryRecords !== 'undefined') {
            deliveryRecords.push({ date: new Date().toISOString().split('T')[0], itemNum: smReceiveItem.itemNum, itemName: smReceiveItem.itemName, quantityReceived: qty, receivedBy: spUser.name });
        }
        alert('✅ Stock updated! ' + smReceiveItem.itemName + ' now has ' + smReceiveItem.stock + ' ' + smReceiveItem.unit + '.');
        smCloseModal('smReceiveModal');
        smRenderInventory();
    };

    // ── Services ────────────────────────────────────────────
    window.smRenderServices = function () {
        var search = (document.getElementById('smSvcSearch') || { value: '' }).value.toLowerCase();
        var total     = serviceTransactions.length;
        var ongoing   = serviceTransactions.filter(function (s) { return s.status === 'ongoing'; }).length;
        var completed = serviceTransactions.filter(function (s) { return s.status === 'complete'; }).length;
        var pending   = serviceTransactions.filter(function (s) { return s.status === 'pending'; }).length;

        var statsEl = document.getElementById('smMaintStats');
        if (statsEl) {
            statsEl.innerHTML = [
                { icon: '📋', label: 'Total', num: total, sub: 'All services' },
                { icon: '🔄', label: 'Ongoing', num: ongoing, sub: 'In progress' },
                { icon: '✅', label: 'Completed', num: completed, sub: 'Done' },
                { icon: '⏳', label: 'Pending', num: pending, sub: 'Waiting' }
            ].map(function (s) {
                return '<div class="sm-stat-card"><div class="sm-stat-bg">' + s.icon + '</div>'
                    + '<div class="sm-stat-label">' + s.label + '</div>'
                    + '<div class="sm-stat-num">' + s.num + '</div>'
                    + '<div class="sm-stat-sub">' + s.sub + '</div></div>';
            }).join('');
        }

        var listEl = document.getElementById('smServicesList');
        if (!listEl) return;

        var filtered = serviceTransactions.filter(function (s) {
            return !search || (s.assetNum || '').toLowerCase().includes(search)
                || (s.assetDescription || '').toLowerCase().includes(search)
                || (s.mechanicName || '').toLowerCase().includes(search);
        });

        if (filtered.length === 0) { listEl.innerHTML = '<div class="sm-empty">No services found.</div>'; return; }

        var statusConfig = {
            pending:  { label: 'Pending',   color: '#ed8936', bg: '#fffbeb', border: '#fbd38d', dot: '#ed8936', icon: '⏳' },
            ongoing:  { label: 'Ongoing',   color: '#3182ce', bg: '#ebf8ff', border: '#bee3f8', dot: '#3182ce', icon: '🔄' },
            complete: { label: 'Completed', color: '#718096', bg: '#f7fafc', border: '#e2e8f0', dot: '#a0aec0', icon: '✅' }
        };

        listEl.innerHTML = filtered.map(function (svc) {
            var sc   = statusConfig[svc.status] || statusConfig.complete;
            var date = svc.dateServiced ? new Date(svc.dateServiced).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
            var cost = parseFloat(svc.totalCost || 0);
            var svcCount = (svc.servicesRendered || []).length;
            var partCount = (svc.spareParts || []).length;

            return '<div class="sm-svc-card">'
                // Header row
                + '<div class="sm-svc-card-header">'
                + '<div class="sm-svc-icon-wrap" style="background:' + sc.bg + ';border:1px solid ' + sc.border + ';">' + sc.icon + '</div>'
                + '<div class="sm-svc-header-info">'
                + '<div class="sm-svc-name">' + (svc.assetDescription || svc.assetNum) + '</div>'
                + '<div class="sm-svc-id">' + svc.serviceId + ' · ' + svc.assetNum + '</div>'
                + '</div>'
                + '<span class="sm-svc-status-badge" style="background:' + sc.bg + ';color:' + sc.color + ';border:1px solid ' + sc.border + ';">'
                + '<span style="width:6px;height:6px;border-radius:50%;background:' + sc.dot + ';display:inline-block;flex-shrink:0;"></span>'
                + sc.label + '</span>'
                + '</div>'
                // Info chips
                + '<div class="sm-svc-chips-row">'
                + '<div class="sm-svc-chip"><span class="sm-svc-chip-label">Mechanic</span><span class="sm-svc-chip-val">' + (svc.mechanicName || '—') + '</span></div>'
                + '<div class="sm-svc-chip"><span class="sm-svc-chip-label">Date</span><span class="sm-svc-chip-val">' + date + '</span></div>'
                + '</div>'
                // Stats row
                + '<div class="sm-svc-stats-row">'
                + '<div class="sm-svc-stat"><span class="sm-svc-stat-num">' + svcCount + '</span><span class="sm-svc-stat-label">Services</span></div>'
                + '<div class="sm-svc-stat-div"></div>'
                + '<div class="sm-svc-stat"><span class="sm-svc-stat-num">' + partCount + '</span><span class="sm-svc-stat-label">Parts</span></div>'
                + '<div class="sm-svc-stat-div"></div>'
                + '<div class="sm-svc-stat"><span class="sm-svc-stat-num" style="color:#E31E24;">₱' + cost.toLocaleString('en-PH', { minimumFractionDigits: 2 }) + '</span><span class="sm-svc-stat-label">Total Cost</span></div>'
                + '</div>'
                // Actions
                + '<div class="sm-svc-actions">'
                + '<button class="sm-svc-btn view" onclick="smViewService(\'' + svc.serviceId + '\')">👁️ View</button>'
                + '<button class="sm-svc-btn edit" onclick="smEditService(\'' + svc.serviceId + '\')">✏️ Edit</button>'
                + (svc.status === 'ongoing' ? '<button class="sm-svc-btn done" onclick="smCompleteService(\'' + svc.serviceId + '\')">🏁 Done</button>' : '')
                + '</div>'
                + '</div>';
        }).join('');
    };

    window.smViewService = function (serviceId) {
        var svc = serviceTransactions.find(function (s) { return s.serviceId === serviceId; });
        if (!svc) return;
        document.getElementById('smSvcDetailId').textContent = svc.serviceId;
        document.getElementById('smSvcDetailAsset').textContent = svc.assetDescription || svc.assetNum;

        var date = svc.dateServiced ? new Date(svc.dateServiced).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
        var servicesHtml = (svc.servicesRendered || []).map(function (r) {
            return '<div class="sm-detail-row"><span class="sm-detail-key">' + r.description + '</span><span class="sm-detail-val">₱' + (r.cost || 0).toLocaleString() + '</span></div>';
        }).join('') || '<div style="color:#718096;font-size:0.82rem;">None</div>';

        var partsHtml = (svc.spareParts || []).map(function (p) {
            return '<div class="sm-detail-row"><span class="sm-detail-key">' + p.name + ' x' + p.quantity + '</span><span class="sm-detail-val">₱' + (p.cost || 0).toLocaleString() + '</span></div>';
        }).join('') || '<div style="color:#718096;font-size:0.82rem;">None</div>';

        document.getElementById('smSvcDetailBody').innerHTML =
            '<div class="sm-detail-section">'
            + '<div class="sm-detail-section-title">Details</div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Date</span><span class="sm-detail-val">' + date + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Mechanic</span><span class="sm-detail-val">' + (svc.mechanicName || '—') + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Status</span><span class="sm-detail-val">' + svc.status + '</span></div>'
            + '</div>'
            + '<div class="sm-detail-section"><div class="sm-detail-section-title">🔧 Services Rendered</div>' + servicesHtml + '</div>'
            + '<div class="sm-detail-section"><div class="sm-detail-section-title">📦 Materials Used</div>' + partsHtml + '</div>'
            + '<div class="sm-detail-section red"><div class="sm-detail-row"><span class="sm-detail-key" style="font-weight:700;">Total Cost</span><span class="sm-detail-val" style="color:#E31E24;font-size:1.1rem;">₱' + parseFloat(svc.totalCost || 0).toLocaleString() + '</span></div></div>';

        smOpenModal('smServiceDetailModal');
    };

    window.smCompleteService = function (serviceId) {
        var svc = serviceTransactions.find(function (s) { return s.serviceId === serviceId; });
        if (!svc) return;
        if (confirm('Mark ' + svc.serviceId + ' as completed?')) {
            svc.status = 'complete';
            var asset = assets.find(function (a) { return a.assetNum === svc.assetNum; });
            if (asset && asset.status === 'maintenance') { asset.status = 'active'; asset.completedAt = new Date().toISOString(); }
            smRenderServices();
        }
    };

    var smEditingServiceId = null;

    window.smEditService = function (serviceId) {
        var svc = serviceTransactions.find(function (s) { return s.serviceId === serviceId; });
        if (!svc) return;

        smEditingServiceId = serviceId;
        smSvcRowCount = 0; smMatRowCount = 0;

        // Find asset
        smSvcAsset = assets.find(function (a) { return a.assetNum === svc.assetNum; }) || null;
        document.getElementById('smSvcPlate').value = svc.assetNum;
        document.getElementById('smSvcAssetDisplay').value = (svc.assetDescription || '') + ' (' + svc.assetNum + ')';
        document.getElementById('smSvcMechanic').value = svc.mechanicName || '';
        document.getElementById('smSvcDate').value = svc.dateServiced || new Date().toISOString().split('T')[0];
        document.getElementById('smPlateSuggestions').style.display = 'none';

        // Pre-fill service rows
        document.getElementById('smSvcRows').innerHTML = '';
        (svc.servicesRendered || []).forEach(function (r) {
            smAddSvcRow({ description: r.description, quantity: r.quantity, uom: r.uom, cost: r.cost });
        });
        if (smSvcRowCount === 0) smAddSvcRow();

        // Pre-fill material rows
        document.getElementById('smMatRows').innerHTML = '';
        (svc.spareParts || []).forEach(function (p) {
            smAddMatRow({ itemNum: p.itemNum, name: p.name, quantity: p.quantity, uom: p.uom, cost: p.cost });
        });
        if (smMatRowCount === 0) smAddMatRow();

        // Update modal title to show Edit mode
        var titleEl = document.querySelector('#smNewServiceModal .sm-modal-title');
        var subEl   = document.querySelector('#smNewServiceModal .sm-modal-sub');
        if (titleEl) titleEl.textContent = '✏️ Edit Service';
        if (subEl)   subEl.textContent   = 'Editing ' + serviceId;

        smCalcTotal();
        smOpenModal('smNewServiceModal');
    };
    var smSvcAsset = null;
    var smSvcRowCount = 0;
    var smMatRowCount = 0;

    window.smOpenNewServiceModal = function () {
        smEditingServiceId = null;
        smSvcAsset = null; smSvcRowCount = 0; smMatRowCount = 0;
        document.getElementById('smSvcPlate').value = '';
        document.getElementById('smSvcAssetDisplay').value = '';
        document.getElementById('smSvcMechanic').value = '';
        document.getElementById('smSvcDate').value = new Date().toISOString().split('T')[0];
        document.getElementById('smSvcRows').innerHTML = '';
        document.getElementById('smMatRows').innerHTML = '';
        document.getElementById('smSvcTotal').textContent = '₱0.00';
        document.getElementById('smPlateSuggestions').style.display = 'none';
        var titleEl = document.querySelector('#smNewServiceModal .sm-modal-title');
        var subEl   = document.querySelector('#smNewServiceModal .sm-modal-sub');
        if (titleEl) titleEl.textContent = '🔧 New Service';
        if (subEl)   subEl.textContent   = 'Create service transaction';
        smAddSvcRow(); smAddMatRow();
        smOpenModal('smNewServiceModal');
    };

    window.smSearchPlate = function (val) {
        var q = val.toUpperCase().trim();
        var sugEl = document.getElementById('smPlateSuggestions');
        if (!q) { sugEl.style.display = 'none'; return; }
        var matches = assets.filter(function (a) { return a.plateNumber.toUpperCase().includes(q); }).slice(0, 5);
        if (matches.length === 0) { sugEl.style.display = 'none'; return; }
        sugEl.innerHTML = matches.map(function (a) {
            return '<div class="sm-suggestion-item" onclick="smSelectPlate(\'' + a.plateNumber + '\')">'
                + '<strong>' + a.plateNumber + '</strong> — ' + a.assetDescription + '</div>';
        }).join('');
        sugEl.style.display = 'block';
    };

    window.smSelectPlate = function (plate) {
        var asset = assets.find(function (a) { return a.plateNumber === plate; });
        if (!asset) return;
        smSvcAsset = asset;
        document.getElementById('smSvcPlate').value = plate;
        document.getElementById('smSvcAssetDisplay').value = asset.assetDescription + ' (' + asset.assetNum + ')';
        document.getElementById('smPlateSuggestions').style.display = 'none';
    };

    // ── Helper: build options ────────────────────────────────
    function smGetServiceOptions(selected) {
        // Services: items from itemMaster where commodityGroup is AutoService or itemType is Service
        var serviceItems = (typeof itemMaster !== 'undefined' ? itemMaster : []).filter(function (i) {
            return (i.commodityGroup || '').toLowerCase() === 'autoservice'
                || (i.itemType || '').toLowerCase() === 'service';
        });
        var opts = '<option value="">Select service...</option>';
        serviceItems.forEach(function (i) {
            var sel = selected && selected === i.itemName ? ' selected' : '';
            opts += '<option value="' + i.itemName + '" data-uom="' + (i.uom || 'Service') + '" data-cost="' + (i.cost || 0) + '"' + sel + '>' + i.itemName + '</option>';
        });
        return opts;
    }

    function smGetInventoryOptions(selected) {
        var opts = '<option value="">Select item...</option>';
        inventory.forEach(function (i) {
            var sel = selected && (selected === i.itemNum || selected === i.itemName) ? ' selected' : '';
            opts += '<option value="' + i.itemNum + '" data-name="' + i.itemName + '" data-uom="' + i.unit + '" data-cost="' + (i.price || 0) + '" data-stock="' + i.stock + '"' + sel + '>' + i.itemName + '</option>';
        });
        return opts;
    }

    var smUomList = ['Each', 'Set', 'Hour', 'Piece', 'Liters', 'Gallon', 'pcs', 'units', 'sets', 'liters'];
    function smGetUomOptions(selected) {
        // Also include item units from inventory
        var units = smUomList.slice();
        inventory.forEach(function (i) { if (i.unit && units.indexOf(i.unit) === -1) units.push(i.unit); });
        return units.map(function (u) {
            return '<option value="' + u + '"' + (selected === u ? ' selected' : '') + '>' + u + '</option>';
        }).join('');
    }

    window.smOnSvcItemChange = function (sel) {
        var id = sel.dataset.rowid;
        var opt = sel.options[sel.selectedIndex];
        var uom  = opt ? (opt.dataset.uom || '') : '';
        var cost = opt ? parseFloat(opt.dataset.cost || 0) : 0;
        var uomEl  = document.getElementById('smSvcUom' + id);
        var costEl = document.getElementById('smSvcCost' + id);
        var qtyEl  = document.getElementById('smSvcQty' + id);
        if (uomEl)  uomEl.value  = uom;
        if (costEl) costEl.value = cost > 0 ? (cost * (parseFloat((qtyEl || {}).value) || 1)).toFixed(2) : '';
        smCalcTotal();
    };

    window.smOnMatItemChange = function (sel) {
        var id = sel.dataset.rowid;
        var opt = sel.options[sel.selectedIndex];
        var uom  = opt ? (opt.dataset.uom || '') : '';
        var cost = opt ? parseFloat(opt.dataset.cost || 0) : 0;
        var uomEl  = document.getElementById('smMatUom' + id);
        var costEl = document.getElementById('smMatCost' + id);
        var qtyEl  = document.getElementById('smMatQty' + id);
        if (uomEl)  uomEl.value  = uom;
        if (costEl) costEl.value = cost > 0 ? (cost * (parseFloat((qtyEl || {}).value) || 1)).toFixed(2) : '';
        smCalcTotal();
    };

    window.smOnSvcQtyChange = function (input) {
        var id = input.dataset.rowid;
        var sel  = document.getElementById('smSvcItem' + id);
        var opt  = sel ? sel.options[sel.selectedIndex] : null;
        var cost = opt ? parseFloat(opt.dataset.cost || 0) : 0;
        var costEl = document.getElementById('smSvcCost' + id);
        if (costEl && cost > 0) costEl.value = (cost * (parseFloat(input.value) || 1)).toFixed(2);
        smCalcTotal();
    };

    window.smOnMatQtyChange = function (input) {
        var id = input.dataset.rowid;
        var sel  = document.getElementById('smMatItem' + id);
        var opt  = sel ? sel.options[sel.selectedIndex] : null;
        var cost = opt ? parseFloat(opt.dataset.cost || 0) : 0;
        var costEl = document.getElementById('smMatCost' + id);
        if (costEl && cost > 0) costEl.value = (cost * (parseFloat(input.value) || 1)).toFixed(2);
        smCalcTotal();
    };

    window.smAddSvcRow = function (prefill) {
        var id = ++smSvcRowCount;
        prefill = prefill || {};
        var row = document.createElement('div');
        row.className = 'sm-svc-row-new'; row.id = 'smSvcRow' + id;
        row.innerHTML =
            '<div class="sm-row-line">'
            + '<select class="sm-row-select" id="smSvcItem' + id + '" data-rowid="' + id + '" onchange="smOnSvcItemChange(this)">'
            + smGetServiceOptions(prefill.description) + '</select>'
            + '<button type="button" class="sm-row-remove" onclick="this.closest(\'.sm-svc-row-new\').remove();smCalcTotal();">✕</button>'
            + '</div>'
            + '<div class="sm-row-line">'
            + '<input class="sm-row-input sm-row-qty" type="number" id="smSvcQty' + id + '" data-rowid="' + id + '" placeholder="Qty" min="1" value="' + (prefill.quantity || 1) + '" oninput="smOnSvcQtyChange(this)">'
            + '<select class="sm-row-select sm-row-uom" id="smSvcUom' + id + '"><option value="">UOM</option>' + smGetUomOptions(prefill.uom) + '</select>'
            + '<input class="sm-row-input sm-row-cost" type="number" id="smSvcCost' + id + '" placeholder="Cost" min="0" value="' + (prefill.cost || '') + '" oninput="smCalcTotal()" style="background:#f7fafc;">'
            + '</div>';
        document.getElementById('smSvcRows').appendChild(row);
    };

    window.smAddMatRow = function (prefill) {
        var id = ++smMatRowCount;
        prefill = prefill || {};
        var row = document.createElement('div');
        row.className = 'sm-mat-row-new'; row.id = 'smMatRow' + id;
        row.innerHTML =
            '<div class="sm-row-line">'
            + '<select class="sm-row-select" id="smMatItem' + id + '" data-rowid="' + id + '" onchange="smOnMatItemChange(this)">'
            + smGetInventoryOptions(prefill.itemNum || prefill.name) + '</select>'
            + '<button type="button" class="sm-row-scan-btn" onclick="smOpenMatScanModal(' + id + ')" title="Scan">📷</button>'
            + '<button type="button" class="sm-row-remove" onclick="this.closest(\'.sm-mat-row-new\').remove();smCalcTotal();">✕</button>'
            + '</div>'
            + '<div class="sm-row-line">'
            + '<input class="sm-row-input sm-row-qty" type="number" id="smMatQty' + id + '" data-rowid="' + id + '" placeholder="Qty" min="1" value="' + (prefill.quantity || 1) + '" oninput="smOnMatQtyChange(this)">'
            + '<input class="sm-row-input sm-row-uom-text" id="smMatUom' + id + '" placeholder="UOM" value="' + (prefill.uom || '') + '" readonly style="background:#f7fafc;">'
            + '<input class="sm-row-input sm-row-cost" type="number" id="smMatCost' + id + '" placeholder="Cost" min="0" value="' + (prefill.cost || '') + '" oninput="smCalcTotal()" style="background:#f7fafc;">'
            + '</div>';
        document.getElementById('smMatRows').appendChild(row);
    };

    window.smCalcTotal = function () {
        var total = 0;
        document.querySelectorAll('[id^="smSvcCost"]').forEach(function (el) { total += parseFloat(el.value) || 0; });
        document.querySelectorAll('[id^="smMatCost"]').forEach(function (el) { total += parseFloat(el.value) || 0; });
        document.getElementById('smSvcTotal').textContent = '₱' + total.toLocaleString('en-PH', { minimumFractionDigits: 2 });
        return total;
    };

    window.smSubmitService = function () {
        if (!smSvcAsset) { alert('Please select an asset by plate number.'); return; }
        var mechanic = document.getElementById('smSvcMechanic').value.trim();
        var date     = document.getElementById('smSvcDate').value;
        if (!mechanic || !date) { alert('Please fill in all required fields.'); return; }

        var services = [], parts = [], total = 0;
        for (var i = 1; i <= smSvcRowCount; i++) {
            var itemSel = document.getElementById('smSvcItem' + i);
            if (!itemSel) continue;
            var itemName = itemSel.value;
            if (!itemName) continue;
            var qty  = parseFloat((document.getElementById('smSvcQty' + i) || {}).value) || 1;
            var uom  = (document.getElementById('smSvcUom' + i) || {}).value || 'Service';
            var cost = parseFloat((document.getElementById('smSvcCost' + i) || {}).value) || 0;
            services.push({ description: itemName, quantity: qty, uom: uom, cost: cost });
            total += cost;
        }
        for (var j = 1; j <= smMatRowCount; j++) {
            var matSel = document.getElementById('smMatItem' + j);
            if (!matSel) continue;
            var itemNum = matSel.value;
            if (!itemNum) continue;
            var opt  = matSel.options[matSel.selectedIndex];
            var mname = opt ? opt.dataset.name || opt.text : itemNum;
            var mqty  = parseFloat((document.getElementById('smMatQty' + j) || {}).value) || 1;
            var muom  = (document.getElementById('smMatUom' + j) || {}).value || 'pcs';
            var mcost = parseFloat((document.getElementById('smMatCost' + j) || {}).value) || 0;
            parts.push({ itemNum: itemNum, name: mname, quantity: mqty, uom: muom, cost: mcost });
            total += mcost;
        }

        if (smEditingServiceId) {
            // Edit mode — update existing record
            var svc = serviceTransactions.find(function (s) { return s.serviceId === smEditingServiceId; });
            if (svc) {
                svc.dateServiced      = date;
                svc.mechanicName      = mechanic;
                svc.servicesRendered  = services;
                svc.spareParts        = parts;
                svc.totalCost         = total;
                svc.assetNum          = smSvcAsset.assetNum;
                svc.assetDescription  = smSvcAsset.assetDescription;
            }
            alert('✅ Service ' + smEditingServiceId + ' updated successfully.');
            smEditingServiceId = null;
        } else {
            // Create mode
            var newId = 'SVC-' + String(serviceTransactions.length + 1).padStart(3, '0');
            serviceTransactions.push({
                serviceId: newId, dateServiced: date, assetNum: smSvcAsset.assetNum,
                assetDescription: smSvcAsset.assetDescription, mechanicName: mechanic,
                servicesRendered: services, spareParts: parts, status: 'ongoing',
                totalCost: total, createdBy: spUser.name, createdOn: new Date().toISOString()
            });
            smSvcAsset.status = 'maintenance';
            smSvcAsset.lastServiceDate = date;
            alert('✅ Service ' + newId + ' created successfully.');
        }

        smCloseModal('smNewServiceModal');
        smRenderServices();
    };

    // ── Assets ──────────────────────────────────────────────
    window.smRenderAssets = function () {
        var search = (document.getElementById('smAssetSearch') || { value: '' }).value.toLowerCase();
        var today  = new Date(); today.setHours(0, 0, 0, 0);
        var listEl = document.getElementById('smAssetsList');
        if (!listEl) return;

        // Stats
        var statsEl = document.getElementById('smAssetStats');
        if (statsEl) {
            var total      = assets.length;
            var active     = assets.filter(function (a) { return a.status === 'active'; }).length;
            var inMaint    = assets.filter(function (a) { return a.status === 'maintenance'; }).length;
            var overdue    = assets.filter(function (a) {
                if (!a.nextPMSDue || a.status === 'maintenance' || a.status === 'inactive') return false;
                var d = new Date(a.nextPMSDue); d.setHours(0,0,0,0); return d < today;
            }).length;
            statsEl.innerHTML = [
                { icon: '🚗', label: 'Total Assets',  num: total,   sub: 'Registered' },
                { icon: '✅', label: 'Active',         num: active,  sub: 'In service' },
                { icon: '🔧', label: 'In Maintenance', num: inMaint, sub: 'Being serviced' },
                { icon: '🚨', label: 'PMS Overdue',    num: overdue, sub: 'Needs attention' }
            ].map(function (s) {
                return '<div class="sm-stat-card"><div class="sm-stat-bg">' + s.icon + '</div>'
                    + '<div class="sm-stat-label">' + s.label + '</div>'
                    + '<div class="sm-stat-num">' + s.num + '</div>'
                    + '<div class="sm-stat-sub">' + s.sub + '</div></div>';
            }).join('');
        }

        var filtered = assets.filter(function (a) {
            return !search || a.assetNum.toLowerCase().includes(search)
                || a.plateNumber.toLowerCase().includes(search)
                || a.owner.toLowerCase().includes(search)
                || a.assetDescription.toLowerCase().includes(search);
        });

        if (filtered.length === 0) { listEl.innerHTML = '<div class="sm-empty">No assets found.</div>'; return; }

        var statusConfig = {
            maintenance: { label: 'Under Maintenance', color: '#3182ce', bg: '#ebf8ff', border: '#bee3f8', dot: '#3182ce' },
            inactive:    { label: 'Inactive',          color: '#718096', bg: '#f7fafc', border: '#e2e8f0', dot: '#a0aec0' }
        };

        function getPmsConfig(asset) {
            if (asset.status === 'maintenance') return statusConfig.maintenance;
            if (asset.status === 'inactive')    return statusConfig.inactive;
            if (asset.nextPMSDue) {
                var due = new Date(asset.nextPMSDue); due.setHours(0,0,0,0);
                var diff = Math.ceil((due - today) / 86400000);
                if (diff < 0)   return { label: 'PMS Overdue',  color: '#e53e3e', bg: '#fff5f5', border: '#feb2b2', dot: '#e53e3e', diff: diff };
                if (diff <= 14) return { label: 'PMS Due Soon', color: '#ed8936', bg: '#fffbeb', border: '#fbd38d', dot: '#ed8936', diff: diff };
            }
            return { label: 'Active', color: '#38a169', bg: '#f0fff4', border: '#9ae6b4', dot: '#38a169' };
        }

        listEl.innerHTML = filtered.map(function (asset) {
            var sc      = getPmsConfig(asset);
            var nextPMS = asset.nextPMSDue ? new Date(asset.nextPMSDue).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
            var lastSvc = asset.lastServiceDate ? new Date(asset.lastServiceDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
            var odo     = asset.odometer ? asset.odometer.toLocaleString() + ' km' : '—';
            var lastOdoRec = (asset.maintenanceHistory || []).slice().sort(function(a,b){ return new Date(b.date)-new Date(a.date); });
            var lastOdo = lastOdoRec.length && lastOdoRec[0].km ? lastOdoRec[0].km.toLocaleString() + ' km' : '—';

            // PMS days indicator text
            var pmsNote = '';
            if (typeof sc.diff !== 'undefined') {
                pmsNote = sc.diff < 0
                    ? '<span class="sm-asset-pms-note red">Overdue by ' + Math.abs(sc.diff) + ' day(s)</span>'
                    : '<span class="sm-asset-pms-note orange">Due in ' + sc.diff + ' day(s)</span>';
            }

            return '<div class="sm-asset-card">'
                // Header
                + '<div class="sm-asset-card-header">'
                + '<div class="sm-asset-icon-wrap" style="background:' + sc.bg + ';border:1px solid ' + sc.border + ';">' + (asset.icon || '🚗') + '</div>'
                + '<div class="sm-asset-header-info">'
                + '<div class="sm-asset-name">' + asset.assetDescription + '</div>'
                + '<div class="sm-asset-sub">' + asset.plateNumber + ' · ' + asset.assetNum + '</div>'
                + '</div>'
                + '<span class="sm-asset-status-badge" style="background:' + sc.bg + ';color:' + sc.color + ';border:1px solid ' + sc.border + ';">'
                + '<span style="width:6px;height:6px;border-radius:50%;background:' + sc.dot + ';display:inline-block;flex-shrink:0;"></span>'
                + sc.label + '</span>'
                + '</div>'
                // Info chips
                + '<div class="sm-asset-chips-row">'
                + '<div class="sm-asset-chip"><span class="sm-asset-chip-label">Last Svc Odometer</span><span class="sm-asset-chip-val">' + lastOdo + '</span></div>'
                + '<div class="sm-asset-chip"><span class="sm-asset-chip-label">Current Odometer</span><span class="sm-asset-chip-val">' + odo + '</span></div>'
                + '</div>'
                // PMS row
                + '<div class="sm-asset-pms-row">'
                + '<div class="sm-asset-pms-block"><span class="sm-asset-pms-label">Last Service</span><span class="sm-asset-pms-val">' + lastSvc + '</span></div>'
                + '<div class="sm-asset-pms-arrow">→</div>'
                + '<div class="sm-asset-pms-block"><span class="sm-asset-pms-label">Next PMS</span><span class="sm-asset-pms-val" style="color:' + sc.color + ';">' + nextPMS + '</span></div>'
                + '</div>'
                + (pmsNote ? '<div style="margin-bottom:0.75rem;">' + pmsNote + '</div>' : '')
                // Actions
                + '<div class="sm-svc-actions">'
                + '<button class="sm-svc-btn view" onclick="smViewAsset(\'' + asset.assetNum + '\')">👁️ View</button>'
                + '<button class="sm-svc-btn edit" onclick="smEditAsset(\'' + asset.assetNum + '\')">✏️ Edit</button>'
                + '</div>'
                + '</div>';
        }).join('');
    };

    window.smViewAsset = function (assetNum) {
        var asset = assets.find(function (a) { return a.assetNum === assetNum; });
        if (!asset) return;
        document.getElementById('smAssetDetailName').textContent = asset.assetDescription;
        document.getElementById('smAssetDetailPlate').textContent = asset.plateNumber;

        var lastSvc = asset.lastServiceDate ? new Date(asset.lastServiceDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
        var nextPMS = asset.nextPMSDue ? new Date(asset.nextPMSDue).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
        var lastOdoRec = (asset.maintenanceHistory || []).slice().sort(function(a,b){ return new Date(b.date)-new Date(a.date); });
        var lastOdo = asset.lastServiceOdometer
            ? asset.lastServiceOdometer.toLocaleString() + ' km'
            : (lastOdoRec.length && lastOdoRec[0].km ? lastOdoRec[0].km.toLocaleString() + ' km' : '—');

        var historyHtml = (!asset.maintenanceHistory || asset.maintenanceHistory.length === 0)
            ? '<div style="color:#718096;font-size:0.82rem;">No history yet.</div>'
            : asset.maintenanceHistory.slice(0, 5).map(function (r) {
                return '<div class="sm-detail-row">'
                    + '<span class="sm-detail-key">' + new Date(r.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) + ' — ' + r.service + '</span>'
                    + '<span class="sm-detail-val">₱' + r.cost.toLocaleString() + '</span></div>';
            }).join('');

        document.getElementById('smAssetDetailBody').innerHTML =
            '<div class="sm-detail-section">'
            + '<div class="sm-detail-section-title">Asset Info</div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Asset No.</span><span class="sm-detail-val">' + asset.assetNum + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Owner</span><span class="sm-detail-val">' + asset.owner + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Last Svc Odometer</span><span class="sm-detail-val">' + lastOdo + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Current Odometer</span><span class="sm-detail-val">' + (asset.odometer ? asset.odometer.toLocaleString() + ' km' : '—') + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Status</span><span class="sm-detail-val">' + asset.status + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Last Service</span><span class="sm-detail-val">' + lastSvc + '</span></div>'
            + '<div class="sm-detail-row"><span class="sm-detail-key">Next PMS</span><span class="sm-detail-val">' + nextPMS + '</span></div>'
            + '</div>'
            + '<div class="sm-detail-section"><div class="sm-detail-section-title">📋 Maintenance History</div>' + historyHtml + '</div>';

        smOpenModal('smAssetDetailModal');
    };

    window.smEditAsset = function (assetNum) {
        var asset = assets.find(function (a) { return a.assetNum === assetNum; });
        if (!asset) return;

        // Reuse Add Asset modal in edit mode
        document.getElementById('smAssetNum').value       = asset.assetNum;
        document.getElementById('smAssetPlate').value     = asset.plateNumber;
        document.getElementById('smAssetDesc').value      = asset.assetDescription;
        document.getElementById('smAssetType').value      = asset.type || '';
        document.getElementById('smAssetOwner').value     = asset.owner || '';
        document.getElementById('smAssetOdometer').value  = asset.odometer || '';
        var histLastOdo = (asset.maintenanceHistory || []).slice().sort(function(a,b){ return new Date(b.date)-new Date(a.date); });
        document.getElementById('smAssetLastOdo').value   = asset.lastServiceOdometer || (histLastOdo.length && histLastOdo[0].km ? histLastOdo[0].km : '') || '';
        document.getElementById('smAssetLastSvc').value   = asset.lastServiceDate || '';
        document.getElementById('smAssetFreq').value      = asset.serviceFrequency || '';

        // Mark as editing
        document.getElementById('smAddAssetTitle').textContent = '✏️ Edit Asset';
        document.getElementById('smAssetNum').readOnly = true;
        document.getElementById('smAssetPlate').readOnly = true;

        // Swap save button to update
        var saveBtn = document.querySelector('#smAddAssetModal .sm-btn-primary');
        if (saveBtn) {
            saveBtn.textContent = '💾 Update Asset';
            saveBtn.onclick = function () { smSubmitEditAsset(assetNum); };
        }

        smOpenModal('smAddAssetModal');
    };

    window.smSubmitEditAsset = function (assetNum) {
        var asset = assets.find(function (a) { return a.assetNum === assetNum; });
        if (!asset) return;

        var desc  = document.getElementById('smAssetDesc').value.trim();
        var type  = document.getElementById('smAssetType').value;
        var owner = document.getElementById('smAssetOwner').value.trim();
        var odo   = parseInt(document.getElementById('smAssetOdometer').value) || 0;
        var lastOdo = parseInt(document.getElementById('smAssetLastOdo').value) || null;
        var lastSvc = document.getElementById('smAssetLastSvc').value || null;
        var freq  = parseInt(document.getElementById('smAssetFreq').value) || null;

        if (!desc)  { alert('Please enter an asset description.'); return; }
        if (!type)  { alert('Please select an asset type.'); return; }
        if (!owner) { alert('Please enter an owner.'); return; }

        var typeIcons = { truck: '🚛', car: '🚗' };
        var nextPMS = null;
        if (lastSvc && freq) {
            var d = new Date(lastSvc);
            d.setMonth(d.getMonth() + freq);
            nextPMS = d.toISOString().split('T')[0];
        }

        asset.assetDescription = desc;
        asset.type             = type;
        asset.icon             = typeIcons[type] || '🚗';
        asset.owner            = owner;
        asset.odometer         = odo;
        asset.lastServiceOdometer = lastOdo;
        asset.lastServiceDate  = lastSvc;
        asset.serviceFrequency = freq;
        asset.nextPMSDue       = nextPMS;

        alert('✅ Asset ' + assetNum + ' updated successfully.');
        smCloseModal('smAddAssetModal');
        // Reset modal back to Add mode
        document.getElementById('smAddAssetTitle').textContent = '➕ Add New Asset';
        document.getElementById('smAssetNum').readOnly = false;
        document.getElementById('smAssetPlate').readOnly = false;
        var saveBtn = document.querySelector('#smAddAssetModal .sm-btn-primary');
        if (saveBtn) { saveBtn.textContent = '💾 Save Asset'; saveBtn.onclick = smSubmitAddAsset; }
        smRenderAssets();
    };

    // ── Notifications ────────────────────────────────────────
    function smBuildNotifications() {
        var today = new Date(); today.setHours(0, 0, 0, 0);
        var notifs = [];

        assets.forEach(function (a) {
            if (!a.nextPMSDue || a.status === 'maintenance' || a.status === 'inactive') return;
            var due = new Date(a.nextPMSDue); due.setHours(0, 0, 0, 0);
            var diff = Math.ceil((due - today) / 86400000);
            if (diff < 0) {
                notifs.push({ icon: '🔴', title: 'PMS Overdue', msg: a.assetDescription + ' (' + a.plateNumber + ') — overdue by ' + Math.abs(diff) + ' day(s)', time: 'Due: ' + due.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }), unread: true });
            } else if (diff <= 14) {
                notifs.push({ icon: '🟡', title: 'PMS Due Soon', msg: a.assetDescription + ' (' + a.plateNumber + ') — due in ' + diff + ' day(s)', time: 'Due: ' + due.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }), unread: true });
            }
        });

        inventory.filter(function (i) { return i.status === 'low_stock'; }).forEach(function (i) {
            notifs.push({ icon: '📦', title: 'Low Stock', msg: i.itemName + ' — only ' + i.stock + ' ' + i.unit + ' remaining', time: 'Reorder level: ' + (i.minLevel || i.reorderLevel), unread: true });
        });

        serviceTransactions.filter(function (s) { return s.status === 'ongoing'; }).forEach(function (s) {
            notifs.push({ icon: '🔧', title: 'Ongoing Service', msg: s.assetNum + ' — ' + (s.assetDescription || '') + ' is being serviced', time: 'Mechanic: ' + (s.mechanicName || '—'), unread: false });
        });

        return notifs;
    }

    function smRenderNotifications() {
        var notifs = smBuildNotifications();
        var unread = notifs.filter(function (n) { return n.unread; }).length;
        var b1 = document.getElementById('smNotifBadge');
        var b2 = document.getElementById('smNavNotifBadge');
        if (b1) { b1.textContent = unread; b1.style.display = unread > 0 ? 'flex' : 'none'; }
        if (b2) { b2.textContent = unread; b2.style.display = unread > 0 ? 'flex' : 'none'; }

        var listEl = document.getElementById('smNotifList');
        if (!listEl) return;
        if (notifs.length === 0) {
            listEl.innerHTML = '<div class="sm-notif-empty"><div class="sm-notif-empty-icon">🔔</div><div class="sm-notif-empty-text">No notifications</div></div>';
            return;
        }
        listEl.innerHTML = notifs.map(function (n) {
            return '<div class="sm-notif-item' + (n.unread ? ' unread' : '') + '">'
                + '<div class="sm-notif-icon">' + n.icon + '</div>'
                + '<div><div class="sm-notif-title">' + n.title + '</div>'
                + '<div class="sm-notif-msg">' + n.msg + '</div>'
                + '<div class="sm-notif-time">' + n.time + '</div></div>'
                + '</div>';
        }).join('');
    }

    window.smClearNotifications = function () {
        var listEl = document.getElementById('smNotifList');
        if (listEl) listEl.innerHTML = '<div class="sm-notif-empty"><div class="sm-notif-empty-icon">🔔</div><div class="sm-notif-empty-text">No notifications</div></div>';
        var b1 = document.getElementById('smNotifBadge');
        var b2 = document.getElementById('smNavNotifBadge');
        if (b1) b1.style.display = 'none';
        if (b2) b2.style.display = 'none';
    };

    // ── Profile ─────────────────────────────────────────────
    function smRenderProfile() {
        var s = function (id, val) { var el = document.getElementById(id); if (el) el.textContent = val; };
        s('smProfileAvatar', spUser.avatar || spUser.name.charAt(0).toUpperCase());
        s('smProfileName', spUser.name);
        s('smProfileFullName', spUser.name);
        s('smProfileUsername', spUser.username || 'staff');
        s('smProfileSvcTotal', serviceTransactions.length);
        s('smProfileSvcOngoing', serviceTransactions.filter(function (s) { return s.status === 'ongoing'; }).length);
        s('smProfileLowStock', inventory.filter(function (i) { return i.status === 'low_stock'; }).length);

        var logoutBtn = document.getElementById('smProfileLogoutBtn');
        if (logoutBtn && !logoutBtn._bound) {
            logoutBtn._bound = true;
            logoutBtn.addEventListener('click', function () {
                sessionStorage.removeItem('spUser');
                window.location.href = 'index.html';
            });
        }
    }

    // ── Add Asset Modal ──────────────────────────────────────
    window.smOpenAddAssetModal = function () {
        // Reset to Add mode
        document.getElementById('smAddAssetTitle').textContent = '➕ Add New Asset';
        document.getElementById('smAssetNum').readOnly = false;
        document.getElementById('smAssetPlate').readOnly = false;
        var saveBtn = document.querySelector('#smAddAssetModal .sm-btn-primary');
        if (saveBtn) { saveBtn.textContent = '💾 Save Asset'; saveBtn.onclick = smSubmitAddAsset; }

        document.getElementById('smAssetNum').value = 'ASSET-' + String(nextAssetId).padStart(3, '0');
        document.getElementById('smAssetPlate').value = '';
        document.getElementById('smAssetDesc').value = '';
        document.getElementById('smAssetType').value = '';
        document.getElementById('smAssetOdometer').value = '';
        document.getElementById('smAssetLastOdo').value = '';
        document.getElementById('smAssetLastSvc').value = '';
        document.getElementById('smAssetFreq').value = '';
        document.getElementById('smAssetOwner').value = '';

        smOpenModal('smAddAssetModal');
    };

    window.smSubmitAddAsset = function () {
        var plate    = document.getElementById('smAssetPlate').value.trim().toUpperCase();
        var desc     = document.getElementById('smAssetDesc').value.trim();
        var type     = document.getElementById('smAssetType').value;
        var owner    = document.getElementById('smAssetOwner').value;
        var odo      = parseInt(document.getElementById('smAssetOdometer').value) || 0;
        var lastOdo  = parseInt(document.getElementById('smAssetLastOdo').value) || null;
        var lastSvc  = document.getElementById('smAssetLastSvc').value || null;
        var freq     = parseInt(document.getElementById('smAssetFreq').value) || null;
        var assetNum = document.getElementById('smAssetNum').value;

        if (!plate)  { alert('Please enter a plate number.'); return; }
        if (!desc)   { alert('Please enter an asset description.'); return; }
        if (!type)   { alert('Please select an asset type.'); return; }
        if (!owner)  { alert('Please select an owner.'); return; }

        if (assets.find(function (a) { return a.plateNumber === plate; })) {
            alert('❌ An asset with this plate number already exists.'); return;
        }

        var typeIcons = { truck: '🚛', car: '🚗' };
        var nextPMS = null;
        if (lastSvc && freq) {
            var d = new Date(lastSvc);
            d.setMonth(d.getMonth() + freq);
            nextPMS = d.toISOString().split('T')[0];
        }

        assets.push({
            id: nextAssetId++,
            assetNum: assetNum,
            plateNumber: plate,
            assetDescription: desc,
            type: type,
            icon: typeIcons[type] || '🚗',
            brand: '', model: '', yearModel: null,
            engineNo: '', chassisNo: '',
            dateAcquired: new Date().toISOString().split('T')[0],
            owner: owner,
            odometer: odo,
            lastServiceOdometer: lastOdo,
            lastServiceDate: lastSvc,
            nextPMSDue: nextPMS,
            serviceFrequency: freq,
            status: 'active',
            assignedMechanic: null,
            image: null,
            meters: odo ? [{ name: 'Odometer', type: 'continuous', value: String(odo), unit: 'km' }] : [],
            maintenanceHistory: []
        });

        alert('✅ Asset ' + assetNum + ' added successfully!');
        window.nextAssetId = nextAssetId; // sync counter
        smCloseModal('smAddAssetModal');
        smRenderAssets();
    };

    // ── Plate Number Scan Modal ──────────────────────────────
    var smPlateScanStream = null;
    var smPlateScanFoundAsset = null;

    window.smOpenPlateScanModal = function () {
        smPlateScanFoundAsset = null;
        document.getElementById('smPlateScanInput').value = '';
        document.getElementById('smPlateScanResult').style.display = 'none';
        document.getElementById('smPlateScanNotFound').style.display = 'none';
        document.getElementById('smPlateScanConfirmBtn').style.display = 'none';
        document.getElementById('smPlateScanSearchBtn').style.display = 'block';
        smOpenModal('smPlateScanModal');
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
                .then(function (stream) {
                    smPlateScanStream = stream;
                    var v = document.getElementById('smPlateScanVideo');
                    if (v) v.srcObject = stream;
                }).catch(function () {});
        }
    };

    window.smClosePlateScanModal = function () {
        if (smPlateScanStream) { smPlateScanStream.getTracks().forEach(function (t) { t.stop(); }); smPlateScanStream = null; }
        var v = document.getElementById('smPlateScanVideo');
        if (v) v.srcObject = null;
        smCloseModal('smPlateScanModal');
    };

    window.smApplyPlateScan = function () {
        var q = document.getElementById('smPlateScanInput').value.trim().toUpperCase();
        if (!q) { alert('Please enter a plate number.'); return; }
        var found = assets.find(function (a) { return a.plateNumber.toUpperCase() === q; })
                 || assets.find(function (a) { return a.plateNumber.toUpperCase().includes(q); });
        smPlateScanFoundAsset = found || null;
        if (found) {
            document.getElementById('smPlateScanResultName').textContent = found.assetDescription;
            document.getElementById('smPlateScanResultSub').textContent = found.plateNumber + ' · ' + found.assetNum + ' · ' + found.owner;
            document.getElementById('smPlateScanResult').style.display = 'flex';
            document.getElementById('smPlateScanNotFound').style.display = 'none';
            document.getElementById('smPlateScanConfirmBtn').style.display = 'block';
            document.getElementById('smPlateScanSearchBtn').style.display = 'none';
        } else {
            document.getElementById('smPlateScanResult').style.display = 'none';
            document.getElementById('smPlateScanNotFound').style.display = 'block';
            document.getElementById('smPlateScanConfirmBtn').style.display = 'none';
        }
    };

    window.smConfirmPlateScan = function () {
        if (!smPlateScanFoundAsset) return;
        smSvcAsset = smPlateScanFoundAsset;
        document.getElementById('smSvcPlate').value = smPlateScanFoundAsset.plateNumber;
        document.getElementById('smSvcAssetDisplay').value = smPlateScanFoundAsset.assetDescription + ' (' + smPlateScanFoundAsset.assetNum + ')';
        document.getElementById('smPlateSuggestions').style.display = 'none';
        smClosePlateScanModal();
    };

    // ── Material Row Scan Modal ──────────────────────────────
    var smMatScanStream = null;
    var smMatScanFoundItem = null;
    var smMatScanTargetRowId = null;

    window.smOpenMatScanModal = function (rowId) {
        smMatScanTargetRowId = rowId;
        smMatScanFoundItem = null;
        document.getElementById('smMatScanInput').value = '';
        document.getElementById('smMatScanResult').style.display = 'none';
        document.getElementById('smMatScanNotFound').style.display = 'none';
        document.getElementById('smMatScanConfirmBtn').style.display = 'none';
        smOpenModal('smMatScanModal');
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
                .then(function (stream) {
                    smMatScanStream = stream;
                    var v = document.getElementById('smMatScanVideo');
                    if (v) v.srcObject = stream;
                }).catch(function () {});
        }
    };

    window.smCloseMatScanModal = function () {
        if (smMatScanStream) { smMatScanStream.getTracks().forEach(function (t) { t.stop(); }); smMatScanStream = null; }
        var v = document.getElementById('smMatScanVideo');
        if (v) v.srcObject = null;
        smCloseModal('smMatScanModal');
    };

    window.smApplyMatScan = function () {
        var code = document.getElementById('smMatScanInput').value.trim();
        if (!code) { alert('Please enter a barcode or QR code.'); return; }
        var item = smFindItemByCode(code);
        smMatScanFoundItem = item;
        if (item) {
            document.getElementById('smMatScanResultName').textContent = item.itemName;
            document.getElementById('smMatScanResultSub').textContent = item.itemNum + ' · Stock: ' + item.stock + ' ' + item.unit;
            document.getElementById('smMatScanResult').style.display = 'flex';
            document.getElementById('smMatScanNotFound').style.display = 'none';
            document.getElementById('smMatScanConfirmBtn').style.display = 'block';
        } else {
            document.getElementById('smMatScanResult').style.display = 'none';
            document.getElementById('smMatScanNotFound').style.display = 'block';
            document.getElementById('smMatScanConfirmBtn').style.display = 'none';
        }
    };

    window.smConfirmMatScan = function () {
        if (!smMatScanFoundItem || !smMatScanTargetRowId) return;
        var id = smMatScanTargetRowId;
        var sel = document.getElementById('smMatItem' + id);
        if (sel) {
            // Select the matching option by itemNum
            for (var i = 0; i < sel.options.length; i++) {
                if (sel.options[i].value === smMatScanFoundItem.itemNum) {
                    sel.selectedIndex = i;
                    break;
                }
            }
            smOnMatItemChange(sel);
        }
        smCloseMatScanModal();
    };

    // ── Scan Receive Modal ───────────────────────────────────
    var smScanStream = null;
    var smScanFoundItem = null;

    window.smOpenScanReceiveModal = function () {
        smScanFoundItem = null;
        document.getElementById('smScanManualInput').value = '';
        document.getElementById('smScanResult').style.display = 'none';
        document.getElementById('smScanNotFound').style.display = 'none';
        document.getElementById('smScanConfirmBtn').style.display = 'none';
        smOpenModal('smScanReceiveModal');
        smStartCamera();
    };

    window.smCloseScanReceiveModal = function () {
        smStopCamera();
        smCloseModal('smScanReceiveModal');
    };

    function smStartCamera() {
        var video = document.getElementById('smScanVideo');
        if (!video) return;
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return;
        navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
            .then(function (stream) {
                smScanStream = stream;
                video.srcObject = stream;
            })
            .catch(function () {
                // Camera not available — user can still use manual input
            });
    }

    function smStopCamera() {
        if (smScanStream) {
            smScanStream.getTracks().forEach(function (t) { t.stop(); });
            smScanStream = null;
        }
        var video = document.getElementById('smScanVideo');
        if (video) video.srcObject = null;
    }

    function smFindItemByCode(code) {
        var q = code.toLowerCase().trim();
        return inventory.find(function (i) {
            return (i.barcode || '').toLowerCase() === q
                || (i.qrcode || '').toLowerCase() === q
                || i.itemNum.toLowerCase() === q
                || i.itemName.toLowerCase().includes(q);
        }) || null;
    }

    function smShowScanResult(item) {
        smScanFoundItem = item;
        var resultEl = document.getElementById('smScanResult');
        var notFoundEl = document.getElementById('smScanNotFound');
        var confirmBtn = document.getElementById('smScanConfirmBtn');
        if (item) {
            document.getElementById('smScanResultName').textContent = item.itemName;
            document.getElementById('smScanResultSub').textContent = item.itemNum + ' · Stock: ' + item.stock + ' ' + item.unit;
            resultEl.style.display = 'flex';
            notFoundEl.style.display = 'none';
            confirmBtn.style.display = 'block';
        } else {
            resultEl.style.display = 'none';
            notFoundEl.style.display = 'block';
            confirmBtn.style.display = 'none';
        }
    }

    window.smApplyScanReceive = function () {
        var code = document.getElementById('smScanManualInput').value.trim();
        if (!code) { alert('Please enter a barcode or QR code.'); return; }
        smShowScanResult(smFindItemByCode(code));
    };

    window.smConfirmScanReceive = function () {
        if (!smScanFoundItem) return;
        smReceiveItem = smScanFoundItem;
        document.getElementById('smReceiveSearch').value = smScanFoundItem.itemName;
        document.getElementById('smReceiveItemName').textContent = smScanFoundItem.itemName;
        document.getElementById('smReceiveCurrentStock').textContent = smScanFoundItem.stock + ' ' + smScanFoundItem.unit;
        document.getElementById('smReceiveUnit').textContent = smScanFoundItem.unit;
        document.getElementById('smReceiveItemInfo').style.display = 'block';
        smCloseScanReceiveModal();
    };

    // ── Modal helpers ────────────────────────────────────────
    window.smOpenModal = function (id) { var m = document.getElementById(id); if (m) m.classList.add('active'); };
    window.smCloseModal = function (id) { var m = document.getElementById(id); if (m) m.classList.remove('active'); };

    // ── Boot ─────────────────────────────────────────────────
    smRenderDashboard();
    smRenderNotifications();

})();
