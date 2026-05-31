/**
 * Google Sign-In Handler Module
 * Provides reusable functions for Google authentication with Firebase
 * 
 * Usage: Include this script in your HTML file and call GoogleSignInModule.init()
 */

const GoogleSignInModule = {
  /**
   * Initialize Google Sign-In
   * Call this once when the page loads
   */
  init: function() {
    console.log('GoogleSignInModule initialized');
    this.setupGoogleButton();
  },

  /**
   * Setup Google Sign-In button event listener
   */
  setupGoogleButton: function() {
    const googleBtn = document.getElementById('googleBtn');
    if (!googleBtn) {
      console.warn('Google button not found');
      return;
    }

    googleBtn.addEventListener('click', () => {
      this.handleGoogleSignIn();
    });
    console.log('Google button event listener attached');
  },

  /**
   * Main Google Sign-In handler
   */
  handleGoogleSignIn: async function() {
    console.log('=== Starting Google Sign-In ===');
    
    const googleBtn = document.getElementById('googleBtn');
    const googleDefault = this.getGoogleButtonHTML();
    
    console.log('Google button found:', !!googleBtn);
    this.setButtonLoading(googleBtn, true);

    try {
      // Step 1: Create Google provider
      console.log('Step 1: Creating Google provider...');
      console.log('Firebase object exists:', !!window.firebase);
      console.log('Firebase auth exists:', !!firebase.auth);
      
      const provider = new firebase.auth.GoogleAuthProvider();
      provider.addScope('profile');
      provider.addScope('email');
      console.log('Step 1: Google provider created successfully');

      // Step 2: Sign in with popup
      console.log('Step 2: Opening Google Sign-In popup...');
      const result = await firebase.auth().signInWithPopup(provider);
      const user = result.user;
      
      console.log('Step 3: Google authentication successful');
      console.log('  - UID:', user.uid);
      console.log('  - Email:', user.email);
      console.log('  - Display Name:', user.displayName);

      // Step 4: Get or create user in Firestore
      console.log('Step 4: Checking Firestore for user...');
      const userData = await this.getOrCreateUser(user);
      
      console.log('Step 5: User data retrieved');
      console.log('  - Role:', userData.role);
      console.log('  - Status:', userData.status);

      // Step 6: Validate user status
      if (userData.status === 'inactive') {
        console.warn('User account is inactive');
        await firebase.auth().signOut();
        this.showToast('Your account has been deactivated. Please contact the administrator.', 'error');
        this.setButtonLoading(googleBtn, false);
        return;
      }

      // Step 7: Store user session
      console.log('Step 6: Storing user session...');
      this.storeUserSession(user, userData);

      // Step 8: Redirect
      console.log('Step 7: Redirecting to dashboard...');
      this.redirectByRole(userData.role);

    } catch (error) {
      console.error('=== Google Sign-In Error ===');
      console.error('Error Code:', error.code);
      console.error('Error Message:', error.message);
      
      let errorMsg = 'Sign-in failed. Please try again.';
      
      // Custom error messages
      if (error.message && error.message.includes('not found')) {
        errorMsg = 'User account not found. Please contact the administrator to register your account.';
      } else if (error.code === 'auth/popup-closed-by-user') {
        console.log('User closed the sign-in popup');
        this.setButtonLoading(googleBtn, false);
        return;
      } else if (error.message && error.message.includes('inactive')) {
        errorMsg = 'Your account has been deactivated. Please contact the administrator.';
      }
      
      this.showToast(errorMsg, 'error');
      this.setButtonLoading(googleBtn, false);
    }
  },

  /**
   * Get existing user or create new user in Firestore
   */
  getOrCreateUser: async function(googleUser) {
    const uid = googleUser.uid;
    const email = googleUser.email;
    const db = firebase.firestore();

    try {
      // Try to get user by UID first
      console.log('  - Checking by UID:', uid);
      let doc = await db.collection('users').doc(uid).get();

      if (doc.exists) {
        console.log('  - User found by UID');
        return doc.data();
      }

      // Fallback: check by email
      console.log('  - User not found by UID, checking by email:', email);
      const snapshot = await db.collection('users')
        .where('email', '==', email)
        .limit(1)
        .get();

      console.log('  - Email query returned', snapshot.size, 'documents');
      if (!snapshot.empty) {
        console.log('  - User found by email');
        return snapshot.docs[0].data();
      }

      // User not found - throw error instead of auto-registering
      console.log('  - User not found in Firestore');
      throw new Error('User account not found. Please contact the administrator to register your account.');

    } catch (error) {
      console.error('Error getting/creating user:', error);
      console.error('Error Code:', error.code);
      console.error('Error Message:', error.message);
      console.error('Full Error:', error);
      throw new Error('Failed to retrieve user information: ' + error.message);
    }
  },

  /**
   * Store user data in session storage
   */
  storeUserSession: function(googleUser, userData) {
    const sessionData = {
      uid: googleUser.uid,
      email: googleUser.email,
      name: googleUser.displayName || userData.name || '',
      role: userData.role || 'customer',
      photoUrl: googleUser.photoURL || userData.photoUrl || '',
    };

    console.log('Storing session data:', sessionData);

    // Store based on role
    if (sessionData.role === 'admin') {
      sessionStorage.setItem('apUser', JSON.stringify(sessionData));
      console.log('Stored as admin user (apUser)');
    } else if (sessionData.role === 'staff') {
      sessionStorage.setItem('spUser', JSON.stringify(sessionData));
      console.log('Stored as staff user (spUser)');
    } else {
      sessionStorage.setItem('cpUser', JSON.stringify(sessionData));
      console.log('Stored as customer user (cpUser)');
    }
  },

  /**
   * Redirect user based on role
   */
  redirectByRole: function(role) {
    const roleMap = {
      admin: 'admin_dashboard.html',
      staff: 'staff_dashboard.html',
      customer: 'customer_dashboard.html',
    };

    const target = roleMap[role] || 'customer_dashboard.html';
    console.log('Redirecting to:', target);
    
    // Use a small delay to ensure all logs are flushed
    setTimeout(() => {
      window.location.href = target;
    }, 100);
  },

  /**
   * Show toast notification
   */
  showToast: function(message, type = 'error') {
    const toast = document.getElementById('toast');
    if (!toast) {
      console.warn('Toast element not found');
      return;
    }

    toast.textContent = message;
    toast.className = type === 'success' ? 'show success' : 'show';
    
    clearTimeout(toast._timer);
    toast._timer = setTimeout(() => {
      toast.className = '';
    }, 3500);

    console.log('Toast shown:', message, '(' + type + ')');
  },

  /**
   * Set button loading state
   */
  setButtonLoading: function(btn, loading) {
    if (!btn) return;

    btn.disabled = loading;
    if (loading) {
      btn.innerHTML = `<span class="spinner dark"></span>`;
    } else {
      btn.innerHTML = this.getGoogleButtonHTML();
    }
  },

  /**
   * Get Google button HTML
   */
  getGoogleButtonHTML: function() {
    return `<svg class="g-logo" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
      <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
      <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
      <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
      <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.18 1.48-4.97 2.31-8.16 2.31-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
      <path fill="none" d="M0 0h48v48H0z"/>
    </svg>Continue with Google`;
  },
};

// Auto-initialize when DOM is ready
console.log('google_signin.js loaded');

if (document.readyState === 'loading') {
  console.log('DOM still loading, waiting for DOMContentLoaded');
  document.addEventListener('DOMContentLoaded', () => {
    console.log('DOMContentLoaded fired, initializing GoogleSignInModule');
    GoogleSignInModule.init();
  });
} else {
  console.log('DOM already loaded, initializing GoogleSignInModule immediately');
  GoogleSignInModule.init();
}
