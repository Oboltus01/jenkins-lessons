#!/usr/bin/env bash
set -euo pipefail

# Lesson 5 fast setup, for ephemeral Killercoda labs only.
# Supply JENKINS_ADMIN_PASSWORD for a reusable lab password, or generate one.
# CSRF remains enabled. Never store the password in the public repository.
NAME=my-jenkins
STATE_DIR=/root/.jenkins-lesson5-fast
PASS_FILE="$STATE_DIR/admin-password"
INIT_DIR="$STATE_DIR/init.groovy.d"
mkdir -p "$INIT_DIR"
chmod 700 "$STATE_DIR"
chmod 755 "$INIT_DIR"

if docker ps -a --format '{{.Names}}' | grep -Fxq "$NAME"; then
  echo "Existing $NAME detected. Keeping its configuration (no reset)."
  if ! docker ps --format '{{.Names}}' | grep -Fxq "$NAME"; then docker start "$NAME"; fi
else
  command -v openssl >/dev/null || { echo "openssl required"; exit 1; }
  if [ -n "${JENKINS_ADMIN_PASSWORD:-}" ] && [ "${#JENKINS_ADMIN_PASSWORD}" -lt 12 ]; then
    echo "JENKINS_ADMIN_PASSWORD must be at least 12 characters." >&2
    exit 1
  fi
  if [ ! -s "$PASS_FILE" ]; then
    if [ -n "${JENKINS_ADMIN_PASSWORD:-}" ]; then
      (umask 077; printf '%s\n' "$JENKINS_ADMIN_PASSWORD" > "$PASS_FILE")
    else
      (umask 077; openssl rand -hex 20 > "$PASS_FILE")
    fi
  elif [ -n "${JENKINS_ADMIN_PASSWORD:-}" ] && [ "$(cat "$PASS_FILE")" != "$JENKINS_ADMIN_PASSWORD" ]; then
    echo "Existing password file differs; refusing to overwrite it." >&2
    exit 1
  fi
  unset JENKINS_ADMIN_PASSWORD
  chmod 600 "$PASS_FILE"
  # Container Jenkins runs as UID 1000; allow it to read the bind-mounted secret.
  chown 1000:1000 "$PASS_FILE"
  cat > "$INIT_DIR/security.groovy" <<'GROOVY'
import jenkins.model.Jenkins
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.security.csrf.DefaultCrumbIssuer

def j = Jenkins.get()
def realm = j.getSecurityRealm()
if (!(realm instanceof HudsonPrivateSecurityRealm)) {
    realm = new HudsonPrivateSecurityRealm(false)
    j.setSecurityRealm(realm)
}
if (realm.getUser('admin') == null) {
    def password = new File('/run/lesson5-admin-password').text.trim()
    if (!password) throw new IllegalStateException('Missing admin password')
    realm.createAccount('admin', password)
}
def auth = new FullControlOnceLoggedInAuthorizationStrategy()
auth.setAllowAnonymousRead(false)
j.setAuthorizationStrategy(auth)
// For Killercoda's HTTPS reverse proxy, do not bind CSRF crumbs to client IP.
// CSRF protection remains enabled.
j.setCrumbIssuer(new DefaultCrumbIssuer(true))
j.save()
println('LESSON5_FAST_ADMIN_READY')
GROOVY
  chmod 644 "$INIT_DIR/security.groovy"
  docker volume create jenkins_home >/dev/null
  docker run -d --name "$NAME" \
    -p 8080:8080 -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v "$INIT_DIR:/usr/share/jenkins/ref/init.groovy.d:ro" \
    -v "$PASS_FILE:/run/lesson5-admin-password:ro" \
    -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
    jenkins/jenkins:lts-jdk17 >/dev/null
  echo "Created Jenkins without installing suggested plugins."
fi

# Wait for full Jenkins startup and verified admin identity, not merely an HTTP login page.
# An HTTP 200 from /whoAmI alone is insufficient: anonymous can also return 200.
[ -s "$PASS_FILE" ] || { echo "Missing admin password file: $PASS_FILE" >&2; exit 1; }
ready=false
for i in $(seq 1 90); do
  if docker logs "$NAME" 2>&1 | grep -Fq 'Jenkins is fully up and running'; then
    response=$(curl -fsS --max-time 5 -u "admin:$(cat "$PASS_FILE")" \
      http://localhost:8080/whoAmI/api/json 2>/dev/null || true)
    if printf '%s' "$response" | python3 -c '
import json, sys
try:
    obj=json.load(sys.stdin)
    assert obj.get("authenticated") is True
    assert obj.get("anonymous") is False
    assert obj.get("name") == "admin"
except (ValueError, AssertionError):
    sys.exit(1)
' ; then
      ready=true
      break
    fi
  fi
  sleep 3
done
if [ "$ready" != true ]; then
  echo "Jenkins not ready or admin authentication failed." >&2
  docker logs "$NAME" --tail 50 >&2
  exit 1
fi
echo "Jenkins ready. Open port 8080 in Killercoda."
echo "Username: admin"
echo "Password is stored locally at: $PASS_FILE"
echo "To view it privately: cat $PASS_FILE"
echo "In Jenkins: admin > Security > API Token > Add new Token."
echo 'Then in terminal: read -rsp "Jenkins token: " API_TOKEN; echo; export API_TOKEN'
echo 'Restore Lesson 5 final job:'
echo 'curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5/recover.sh | bash'
