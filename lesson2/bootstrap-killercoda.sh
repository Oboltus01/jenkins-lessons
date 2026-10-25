#!/usr/bin/env bash
# Automatic Jenkins recovery for a fresh Killercoda session.
set -euo pipefail

REPOSITORY_URL="https://github.com/Oboltus01/jenkins-lesson-2.git"
JENKINS_URL="http://localhost:8080"

if docker ps -a --format '{{.Names}}' | grep -qx jenkins; then
  echo "Removing existing Jenkins container..."
  docker rm -f jenkins
fi

echo "Starting Jenkins..."
docker volume create jenkins_home >/dev/null

docker run -d \
  --name jenkins \
  --restart always \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true" \
  jenkins/jenkins:lts-jdk17

echo "Waiting for Jenkins..."
until curl -fsS "${JENKINS_URL}/login" >/dev/null 2>&1; do
  sleep 2
done

echo "Installing Docker in Jenkins..."
docker exec -u 0 jenkins sh -c \
  'apt-get update && apt-get install -y docker.io && chmod 666 /var/run/docker.sock'

echo "Installing Jenkins plugins..."
docker exec jenkins jenkins-plugin-cli \
  --plugins workflow-aggregator git docker-workflow

echo "Restarting Jenkins..."
docker restart jenkins >/dev/null
sleep 25

create_job() {
  local job_name="$1"
  local script_path="$2"
  local config_file

  config_file="$(mktemp)"

  cat > "${config_file}" <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition>
  <description>Pipeline restored automatically from GitHub.</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${REPOSITORY_URL}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>${script_path}</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

  curl -fsS -X POST "${JENKINS_URL}/createItem?name=${job_name}" \
    --data-binary "@${config_file}" \
    -H "Content-Type: application/xml" >/dev/null

  rm -f "${config_file}"
  echo "Created job: ${job_name}"
}

echo "Creating jobs from GitHub..."
create_job "Git-Pipeline" "Jenkinsfile"
create_job "docker-multi-agent" "jenkinsfiles/docker-multi-agent.Jenkinsfile"
create_job "docker-build-job" "jenkinsfiles/docker-build.Jenkinsfile"
create_job "practice-lab-4" "jenkinsfiles/practice-lab-4.Jenkinsfile"

echo
echo "Done. Open port 8080 in Killercoda."
