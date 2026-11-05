// Plays the website against the emulators, using the same Firebase SDK calls
// as src/lib/sync/firebase-backend.ts. Run through run.sh.
import { createRequire } from "node:module"
import { resolve } from "node:path"

const require = createRequire(resolve(process.cwd(), "../../package.json"))
const { initializeApp } = require("firebase/app")
const { connectAuthEmulator, getAuth, signInWithEmailAndPassword } = require("firebase/auth")
const {
  connectFirestoreEmulator,
  doc,
  getDoc,
  getFirestore,
  serverTimestamp,
  setDoc,
  terminate,
} = require("firebase/firestore")

const app = initializeApp({ apiKey: "emulator", projectId: "demo-system", appId: "1:1:web:1" })
const auth = getAuth(app)
connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true })
const db = getFirestore(app)
connectFirestoreEmulator(db, "127.0.0.1", 8181)
await signInWithEmailAndPassword(auth, "owner@example.com", "emulator-only")
const ref = doc(db, "personal_app_state", "main_schedule")
const step = process.argv[2]

if (step === "seed") {
  await setDoc(
    ref,
    {
      data: {
        blocks: [{ id: 1, day: 0, start: 4, end: 6, label: "saved by the website", color: "#5aab3f" }],
        nextId: 2,
        selColor: "#5aab3f",
        hStart: 6,
        webOnlySetting: "keep me",
      },
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  )
  console.log("website saved the schedule")
} else {
  const snap = await getDoc(ref)
  const data = snap.get("data")
  const labels = data.blocks.map((b) => b.label)
  const ok =
    labels.includes("saved by the website") &&
    labels.includes("saved by the phone") &&
    data.webOnlySetting === "keep me" &&
    data.nextId === 3 &&
    Number.isInteger(data.blocks[1].start) &&
    typeof snap.get("updatedAt")?.toDate === "function"
  console.log("website read back:", JSON.stringify({ labels, nextId: data.nextId, updatedAt: !!snap.get("updatedAt") }))
  if (!ok) {
    console.error("The website could not read what the phone saved")
    process.exitCode = 1
  }
}
await terminate(db)
process.exit(process.exitCode ?? 0)
