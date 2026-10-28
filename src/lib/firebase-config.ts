// Firebase Console -> Project settings -> General -> Your apps -> SDK setup and
// configuration. Web app config is public client config: the data is protected
// by Firebase Auth and Firestore rules (see FIREBASE_SETUP.md).
export const firebaseConfig = {
  apiKey: "AIzaSyAmEyvqbZDNedW-r9-WzrRODoQZQjKts-g",
  authDomain: "game-7487d.firebaseapp.com",
  projectId: "game-7487d",
  storageBucket: "game-7487d.firebasestorage.app",
  messagingSenderId: "397232358844",
  appId: "1:397232358844:web:977107e839d8a155d1d7b9",
  measurementId: "G-E4XHB4NK83",
}

// All of your devices read/write the same personal app records.
export const firebaseSyncId = "main"

// Optional aliases for Firebase Auth email accounts. You can also type the full
// Firebase Auth email in the sign-in form.
export const firebaseLoginUsers: Record<string, string> = {
  admin: "admin@app.local",
}
