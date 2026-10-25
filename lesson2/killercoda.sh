#!/usr/bin/env bash
# One-command launcher for a fresh Killercoda session.
set -euo pipefail

REPO="https://github.com/Oboltus01/jenkins-lesson-2.git"
DIR="$HOME/jenkins-lesson-2"

echo "=== Jenkins Killercoda launcher ==="

if [ -d "$DIR/.git" ]; then
  echo "Repository already exists. Updating..."
  git -C "$DIR" pull --ff-only
else
  echo "Cloning repository..."
  git clone "$REPO" "$DIR"
fi

cd "$DIR"

echo "Starting Jenkins bootstrap..."
bash bootstrap-killercoda.sh
