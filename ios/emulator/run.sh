#!/bin/bash
# Runs the Firebase client tests against local emulators of a throwaway demo
# project, so they never touch real data. Needs Java: brew install openjdk
set -euo pipefail
cd "$(dirname "$0")"
export JAVA_HOME="${JAVA_HOME:-$(brew --prefix openjdk)}"
export PATH="$JAVA_HOME/bin:$PATH"

exec firebase emulators:exec --project demo-system --only auth,firestore "bash ./steps.sh"
