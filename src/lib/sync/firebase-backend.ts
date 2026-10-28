import { getApps, initializeApp } from "firebase/app"
import {
  browserLocalPersistence,
  indexedDBLocalPersistence,
  initializeAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from "firebase/auth"
import {
  doc,
  getDoc,
  getFirestore,
  onSnapshot,
  serverTimestamp,
  setDoc,
} from "firebase/firestore"

import { firebaseConfig, firebaseSyncId } from "@/lib/firebase-config"
import type { SyncBackend } from "@/lib/sync/types"

const APP_NAME = "personal-game-sync"
const COLLECTION = "personal_app_state"

export function createFirebaseBackend(): SyncBackend {
  const app =
    getApps().find((existing) => existing.name === APP_NAME) ??
    initializeApp(firebaseConfig, APP_NAME)
  // Keeps people signed in until they sign out. Earlier versions of these
  // pages stored the session in localStorage; one left in IndexedDB is found
  // and moved over too.
  const auth = initializeAuth(app, {
    persistence: [browserLocalPersistence, indexedDBLocalPersistence],
  })
  const db = getFirestore(app)
  const docRef = (pageId: string) =>
    doc(db, COLLECTION, `${firebaseSyncId}_${pageId}`)

  return {
    watchAuth(listener) {
      return onAuthStateChanged(auth, (user) =>
        listener(user ? { uid: user.uid, email: user.email } : null)
      )
    },
    async signIn(email, password) {
      await signInWithEmailAndPassword(auth, email, password)
    },
    signOut() {
      return signOut(auth)
    },
    async load(pageId) {
      const snap = await getDoc(docRef(pageId))
      return snap.exists() ? (snap.get("data") ?? null) : null
    },
    async save(pageId, data) {
      await setDoc(
        docRef(pageId),
        { data, updatedAt: serverTimestamp() },
        { merge: true }
      )
    },
    subscribe(pageId, onData, onError) {
      return onSnapshot(
        docRef(pageId),
        (snap) => {
          // Local writes show up here before the server confirms them.
          if (snap.metadata.hasPendingWrites || !snap.exists()) return
          const data = snap.get("data")
          if (data) onData(data)
        },
        onError
      )
    },
  }
}
