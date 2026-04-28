# Firebase Sync Setup

1. Create a Firebase project.
2. Add a Web app in Firebase project settings.
3. Create a Firestore database.
4. Enable Firebase Auth:
   - Firebase Console -> Authentication -> Sign-in method
   - Enable Email/Password
5. Create the admin user:
   - Firebase Console -> Authentication -> Users -> Add user
   - Email: `admin@app.local`
   - Password: `admin`
   - Copy that user's UID
6. Copy `firebase-config.example.js` to `firebase-config.js`.
7. Paste the Web app config into `firebase-config.js`.
   - For GitHub Pages, `firebase-config.js` must be committed because the browser loads it directly.
   - Firebase Web app config is public client config. Protect the data with Firebase Auth and Firestore rules.
8. Open the same hosted files on each device and sign in with your Firebase Auth email/password.

The pages sync these Firestore documents:

- `personal_app_state/main_game_tracker`
- `personal_app_state/main_payment_report`
- `personal_app_state/main_company_finances`
- `personal_app_state/main_schedule`

The login screen accepts a Firebase Auth email. Optional aliases can be configured in `firebase-config.js`.

Use UID-locked Firestore rules. Replace `YOUR_FIREBASE_AUTH_UID` with the UID from Authentication -> Users:

```txt
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /personal_app_state/{docId} {
      allow read, write: if request.auth != null
        && request.auth.uid == "YOUR_FIREBASE_AUTH_UID";
    }
  }
}
```

Firebase Auth keeps the browser signed in until you explicitly click `Sign out`, unless browser storage is cleared.

If you host through GitHub Pages, add your GitHub Pages domain in:

Firebase Console -> Authentication -> Settings -> Authorized domains
