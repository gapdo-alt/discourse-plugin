#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DISCOURSE_DIR="${DISCOURSE_DIR:-$ROOT/discourse-docker}"
PLUGIN_DIR="$ROOT/discourse-ip-watchlist"
APP_YML_SRC="$(dirname "$0")/local-discourse-app.yml"
APP_YML_DEST="$DISCOURSE_DIR/containers/app.yml"
DOCKER_DAEMON_JSON="/etc/docker/daemon.json"

echo "==> Discourse local test setup"
echo "    Plugin: $PLUGIN_DIR"
echo "    Docker dir: $DISCOURSE_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi

if ! docker info >/dev/null 2>&1; then
  echo "Starting Docker daemon..."
  sudo service docker start || true
fi

# Cloud Agent / nested Docker: overlayfs whiteout fails; use native snapshotter.
if docker info 2>/dev/null | grep -q 'Storage Driver: overlayfs'; then
  echo "Configuring Docker native storage driver (required in nested/containerized environments)..."
  echo '{"storage-driver":"native"}' | sudo tee "$DOCKER_DAEMON_JSON" >/dev/null
  sudo service docker restart
  sleep 2
fi

if [[ ! -d "$DISCOURSE_DIR/launcher" ]]; then
  echo "Cloning discourse_docker..."
  git clone --depth 1 https://github.com/discourse/discourse_docker.git "$DISCOURSE_DIR"
fi

mkdir -p "$DISCOURSE_DIR/shared/standalone/log/var-log"
cp "$APP_YML_SRC" "$APP_YML_DEST"

# Adjust plugin mount path if repo is not at /workspace
if [[ "$ROOT" != "/workspace" ]]; then
  sed -i "s|/workspace/discourse-ip-watchlist|$PLUGIN_DIR|g" "$APP_YML_DEST"
  sed -i "s|/workspace/discourse-docker|$DISCOURSE_DIR|g" "$APP_YML_DEST"
fi

cd "$DISCOURSE_DIR"
LAUNCHER=(sudo ./launcher)
if docker info 2>/dev/null | grep -qE 'Storage Driver: (native|vfs)'; then
  LAUNCHER+=(--skip-prereqs)
fi

if docker ps -a --format '{{.Names}}' | grep -qx 'app'; then
  echo "Container 'app' already exists."
  echo "  Start:  cd $DISCOURSE_DIR && sudo ./launcher start app --skip-prereqs"
  echo "  Rebuild: cd $DISCOURSE_DIR && sudo ./launcher rebuild app --skip-prereqs"
else
  echo "Bootstrapping Discourse (first run: 20–60 min with native storage driver)..."
  "${LAUNCHER[@]}" bootstrap app
  echo "Starting Discourse..."
  "${LAUNCHER[@]}" start app
fi

echo
echo "==> Done"
echo "    URL: http://localhost:8080"
echo "    Plugin UI: http://localhost:8080/admin/plugins/ip-watchlist"
echo "    API: http://localhost:8080/admin/ip-watchlist.json"
echo
echo "First visit completes the setup wizard, or create admin manually:"
echo "  sudo docker exec -u discourse app bash -c 'cd /var/www/discourse && RAILS_ENV=production bundle exec rails runner \"u=User.find_by_email(\\\"admin@example.com\\\")||User.create!(email:\\\"admin@example.com\\\",username:\\\"admin\\\",password:\\\"adminpass12345678\\\",active:true,approved:true,trust_level:4); u.grant_admin!; u.email_tokens.update_all(confirmed:true)\"'"
