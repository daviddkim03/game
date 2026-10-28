import { useState, type FormEvent, type ReactNode } from "react"
import { LuCircleAlert } from "react-icons/lu"

import { BrandMark } from "@/components/brand-mark"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Spinner } from "@/components/ui/spinner"
import { signIn, useAuth } from "@/lib/sync"

/** Renders the page only once the person is signed in (when cloud sync is on). */
export function AuthGate({ children }: { children: ReactNode }) {
  const auth = useAuth()

  if (auth.status === "loading") {
    return (
      <div className="flex min-h-svh items-center justify-center">
        <Spinner className="size-5 text-muted-foreground" />
      </div>
    )
  }
  if (auth.status === "signed-out") return <SignIn />
  return children
}

function SignIn() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [pending, setPending] = useState(false)

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    setPending(true)
    try {
      await signIn(email, password)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
      setPending(false)
    }
  }

  return (
    <main className="flex min-h-svh flex-col items-center justify-center gap-6 bg-muted p-6 md:p-10">
      <div className="flex w-full max-w-sm flex-col gap-6">
        <div className="flex items-center gap-2 self-center text-sm font-semibold tracking-tight">
          <BrandMark />
          System
        </div>
        <Card>
          <CardHeader className="text-center">
            <CardTitle className="text-xl">Sign in</CardTitle>
            <CardDescription>
              Use your Firebase account to sync this workspace across your
              devices.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} noValidate>
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="sign-in-email">Email</FieldLabel>
                  <Input
                    id="sign-in-email"
                    type="email"
                    autoComplete="username"
                    autoFocus
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="sign-in-password">Password</FieldLabel>
                  <Input
                    id="sign-in-password"
                    type="password"
                    autoComplete="current-password"
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                  />
                </Field>
                {error && (
                  <Alert variant="destructive">
                    <LuCircleAlert />
                    <AlertDescription>{error}</AlertDescription>
                  </Alert>
                )}
                <Button type="submit" size="lg" disabled={pending}>
                  {pending && <Spinner />}
                  Sign in
                </Button>
              </FieldGroup>
            </form>
          </CardContent>
        </Card>
        <p className="text-center text-xs text-balance text-muted-foreground">
          You stay signed in on this device until you sign out.
        </p>
      </div>
    </main>
  )
}
