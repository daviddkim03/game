export type AuthUser = {
  uid: string
  email: string | null
}

/** Where page documents live. Firebase in production, in-memory under e2e. */
export interface SyncBackend {
  /** Calls `listener` once the signed-in user is known, then on every change. */
  watchAuth(listener: (user: AuthUser | null) => void): () => void
  signIn(email: string, password: string): Promise<void>
  signOut(): Promise<void>
  load(pageId: string): Promise<unknown>
  save(pageId: string, data: unknown): Promise<void>
  /** Delivers changes made elsewhere; echoes of this tab's own writes are skipped. */
  subscribe(
    pageId: string,
    onData: (data: unknown) => void,
    onError: (error: unknown) => void
  ): () => void
}
