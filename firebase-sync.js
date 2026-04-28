(function () {
  const APP_NAME = 'personal-game-sync';
  const COLLECTION = 'personal_app_state';
  const PLACEHOLDER = /^PASTE_|firebase_project_id/i;

  let app = null;
  let db = null;
  let auth = null;
  let firestore = null;
  let authMod = null;
  let initPromise = null;
  let authReadyPromise = null;
  const lastSent = new Map();
  const status = new Map();

  function emit(pageId, state, message, error) {
    const detail = {
      pageId: pageId || null,
      state,
      message,
      error: error ? String(error.message || error) : null,
      at: new Date().toISOString()
    };
    if (pageId) status.set(pageId, detail);
    updateStatusElement(detail);
    window.dispatchEvent(new CustomEvent('firebase-sync-status', { detail }));
    if (error) console.warn('Firebase sync:', detail);
    else console.info('Firebase sync:', detail);
  }

  function updateStatusElement(detail) {
    const el = document.querySelector('[data-firebase-sync-status]') || document.getElementById('sync-status');
    if (!el) return;
    el.textContent = detail.error ? `${detail.message}: ${detail.error}` : detail.message;
    el.style.color = detail.state === 'error' ? '#b42318' : '';
  }

  function config() {
    return window.firebaseSyncConfig || {};
  }

  function isConfigured() {
    const c = config();
    return !!(c.apiKey && c.projectId && c.appId) &&
      !PLACEHOLDER.test(c.apiKey) &&
      !PLACEHOLDER.test(c.projectId) &&
      !PLACEHOLDER.test(c.appId);
  }

  async function ensureFirebase() {
    if (!isConfigured()) {
      emit(null, 'disabled', 'Firebase config is not filled in');
      return null;
    }
    if (initPromise) return initPromise;

    emit(null, 'connecting', 'Connecting to Firebase');
    initPromise = Promise.all([
      import('https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js'),
      import('https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js'),
      import('https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js')
    ]).then(([appMod, firestoreMod, authModule]) => {
      firestore = firestoreMod;
      authMod = authModule;
      app = appMod.getApps().find(x => x.name === APP_NAME) ||
        appMod.initializeApp(config(), APP_NAME);
      db = firestoreMod.getFirestore(app);
      auth = authModule.getAuth(app);
      authModule.setPersistence(auth, authModule.browserLocalPersistence).catch(() => { });
      initAuthUi();
      authReadyPromise = new Promise(resolve => {
        const off = authModule.onAuthStateChanged(auth, user => {
          off();
          resolve(user || null);
        });
      });
      emit(null, 'ready', 'Firebase connected');
      return db;
    }).catch(err => {
      emit(null, 'error', 'Firebase could not connect', err);
      return null;
    });

    return initPromise;
  }

  async function ensureSignedIn() {
    if (!await ensureFirebase()) return null;
    await authReadyPromise;
    if (auth.currentUser) return auth.currentUser;
    initAuthUi();
    showAuthUi();
    emit(null, 'auth', 'Sign in to sync');
    return new Promise(resolve => {
      const off = authMod.onAuthStateChanged(auth, user => {
        if (!user) return;
        off();
        resolve(user);
      });
    });
  }

  function loginEmail(username) {
    const key = username.trim();
    const users = window.firebaseLoginUsers || {};
    return users[key] || key;
  }

  function authErrorMessage(err) {
    const code = err?.code || '';
    const suffix = code ? ` (${code})` : '';
    if (code === 'auth/invalid-credential' || code === 'auth/wrong-password' || code === 'auth/user-not-found') {
      return `Login failed. Check that this exact email exists in Firebase Authentication and the password is correct.${suffix}`;
    }
    if (code === 'auth/operation-not-allowed') {
      return `Email/password sign-in is not enabled in Firebase Authentication.${suffix}`;
    }
    if (code === 'auth/invalid-email') {
      return `Enter the full Firebase Auth email address.${suffix}`;
    }
    if (code === 'auth/unauthorized-domain') {
      return `This website domain is not authorized in Firebase Authentication settings.${suffix}`;
    }
    if (code === 'auth/network-request-failed') {
      return `Firebase Auth could not reach the network.${suffix}`;
    }
    return err ? `${err.message || err}${suffix}` : '';
  }

  function currentUser() {
    return auth?.currentUser || null;
  }

  function initAuthUi() {
    if (document.getElementById('firebase-auth-panel')) return;
    const style = document.createElement('style');
    style.textContent = `
      #firebase-auth-panel{position:fixed;inset:0;background:#181713;z-index:10000;display:none;align-items:center;justify-content:center;padding:22px;color:#f4efe5;font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
      #firebase-auth-card{width:min(408px,100%);background:#222018;border:1px solid #3a352a;border-radius:8px;padding:26px;box-shadow:0 28px 90px rgba(0,0,0,.42)}
      #firebase-auth-kicker{font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:#a9c47a;margin-bottom:10px}
      #firebase-auth-card h2{font-size:24px;line-height:1.15;margin:0 0 7px;font-weight:650;color:#fff8eb}
      #firebase-auth-card p{font-size:13px;line-height:1.5;margin:0 0 20px;color:#bcb4a5}
      #firebase-auth-card label{display:block;font-size:12px;color:#d7cfbf;margin:14px 0 6px;font-weight:550}
      #firebase-auth-card input{width:100%;padding:11px 12px;border:1px solid #4a4437;border-radius:7px;font-size:14px;background:#171610;color:#fff8eb;outline:none}
      #firebase-auth-card input:focus{border-color:#a9c47a;box-shadow:0 0 0 3px rgba(169,196,122,.16)}
      #firebase-auth-card button{width:100%;margin-top:17px;padding:12px;border:1px solid #a9c47a;border-radius:7px;background:#a9c47a;color:#171610;font-size:14px;font-weight:650;cursor:pointer}
      #firebase-auth-card button:hover{background:#bdd98d}
      #firebase-auth-error{min-height:18px;margin-top:12px;color:#ff9b8f;font-size:12px;line-height:1.4}
      #firebase-auth-bar{position:fixed;right:14px;bottom:14px;z-index:9999;display:none;gap:8px;align-items:center;background:#222018;border:1px solid #3a352a;border-radius:8px;padding:7px 8px 7px 10px;box-shadow:0 12px 36px rgba(0,0,0,.24);font:12px Inter,system-ui,sans-serif;color:#d7cfbf}
      #firebase-auth-user{max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
      #firebase-auth-bar button{border:1px solid #4a4437;background:#171610;border-radius:6px;padding:5px 9px;font-size:12px;cursor:pointer;color:#f4efe5}
      #firebase-auth-bar button:hover{border-color:#a9c47a;color:#fff8eb}
      @media (max-width: 640px){#firebase-auth-bar{left:12px;right:12px;bottom:12px;justify-content:space-between}#firebase-auth-user{max-width:calc(100vw - 116px)}}
    `;
    document.head.appendChild(style);

    const panel = document.createElement('div');
    panel.id = 'firebase-auth-panel';
    panel.innerHTML = `
      <div id="firebase-auth-card">
        <div id="firebase-auth-kicker">Private Sync</div>
        <h2>Sign in</h2>
        <p>Use your Firebase account to sync this workspace across your devices.</p>
        <label>Email</label>
        <input id="firebase-auth-username" type="email" autocomplete="email">
        <label>Password</label>
        <input id="firebase-auth-password" type="password" autocomplete="current-password">
        <button id="firebase-auth-signin">Sign in</button>
        <div id="firebase-auth-error"></div>
      </div>
    `;
    document.body.appendChild(panel);

    const bar = document.createElement('div');
    bar.id = 'firebase-auth-bar';
    bar.innerHTML = `<span id="firebase-auth-user"></span><button id="firebase-auth-signout">Sign out</button>`;
    document.body.appendChild(bar);

    const username = panel.querySelector('#firebase-auth-username');
    const password = panel.querySelector('#firebase-auth-password');
    const error = panel.querySelector('#firebase-auth-error');
    const setError = err => { error.textContent = authErrorMessage(err); };

    panel.querySelector('#firebase-auth-signin').addEventListener('click', async () => {
      setError('');
      const email = loginEmail(username.value);
      if (!email || !password.value) {
        setError('Enter your Firebase Auth email and password.');
        return;
      }
      try {
        await authMod.signInWithEmailAndPassword(auth, email, password.value);
        updateAuthBar();
        hideAuthUi();
        emit(null, 'auth', 'Signed in');
      } catch (err) {
        setError(err);
      }
    });

    password.addEventListener('keydown', e => {
      if (e.key === 'Enter') panel.querySelector('#firebase-auth-signin').click();
    });

    bar.querySelector('#firebase-auth-signout').addEventListener('click', async () => {
      await authMod.signOut(auth);
      location.reload();
    });

    authMod.onAuthStateChanged(auth, updateAuthBar);
    updateAuthBar();
  }

  function updateAuthBar() {
    const bar = document.getElementById('firebase-auth-bar');
    const userEl = document.getElementById('firebase-auth-user');
    if (!bar || !userEl) return;
    if (auth?.currentUser) {
      const aliases = Object.entries(window.firebaseLoginUsers || {});
      const alias = aliases.find(([, email]) => email === auth.currentUser.email)?.[0];
      userEl.textContent = alias || auth.currentUser.email || 'Signed in';
      bar.style.display = 'flex';
    } else {
      bar.style.display = 'none';
    }
  }

  function showAuthUi() {
    const panel = document.getElementById('firebase-auth-panel');
    if (panel) panel.style.display = 'flex';
  }

  function hideAuthUi() {
    const panel = document.getElementById('firebase-auth-panel');
    if (panel) panel.style.display = 'none';
  }

  function docRef(pageId) {
    const syncId = window.firebaseSyncId || 'main';
    return firestore.doc(db, COLLECTION, `${syncId}_${pageId}`);
  }

  async function load(pageId) {
    if (!await ensureSignedIn()) return null;
    try {
      emit(pageId, 'loading', 'Loading from Firebase');
      const snap = await firestore.getDoc(docRef(pageId));
      emit(pageId, snap.exists() ? 'loaded' : 'empty', snap.exists() ? 'Loaded from Firebase' : 'No Firebase document yet');
      return snap.exists() ? snap.data().data || null : null;
    } catch (err) {
      emit(pageId, 'error', 'Firebase load failed', err);
      throw err;
    }
  }

  async function save(pageId, data) {
    if (!await ensureSignedIn()) return false;
    try {
      const serialized = JSON.stringify(data);
      if (lastSent.get(pageId) === serialized) return true;
      emit(pageId, 'saving', 'Saving to Firebase');
      await firestore.setDoc(docRef(pageId), {
        data,
        updatedAt: firestore.serverTimestamp()
      }, { merge: true });
      lastSent.set(pageId, serialized);
      emit(pageId, 'saved', 'Saved to Firebase');
      return true;
    } catch (err) {
      emit(pageId, 'error', 'Firebase save failed', err);
      throw err;
    }
  }

  async function subscribe(pageId, onData) {
    if (!await ensureSignedIn()) return function () { };
    return firestore.onSnapshot(docRef(pageId), snap => {
      if (!snap.exists()) return;
      const data = snap.data().data || null;
      if (!data) return;
      lastSent.set(pageId, JSON.stringify(data));
      emit(pageId, 'live', 'Received Firebase update');
      onData(data);
    }, err => emit(pageId, 'error', 'Firebase listener failed', err));
  }

  window.FirebaseSync = {
    isConfigured,
    showLogin: showAuthUi,
    currentUser,
    getStatus(pageId) { return status.get(pageId) || null; },
    load,
    save,
    subscribe
  };
})();
