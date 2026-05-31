// data.js — Empty stub. All data is loaded from Firebase Firestore via admin_firebase.js
// Hardcoded data removed. Do not add data here.

window.assets              = [];
window.serviceTransactions = [];
window.inventory           = [];
window.itemMaster          = [];
window.issuances           = [];
window.users               = [];
window.domains             = [];
window.deliveryRecords     = [];

// Bare aliases for legacy code that references without window. prefix
var assets              = window.assets;
var serviceTransactions = window.serviceTransactions;
var inventory           = window.inventory;
var itemMaster          = window.itemMaster;
var issuances           = window.issuances;
var users               = window.users;
var domains             = window.domains;
var deliveryRecords     = window.deliveryRecords;

window.nextAssetId = 1;
var nextAssetId    = 1;
