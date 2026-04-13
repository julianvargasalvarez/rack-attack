#!/usr/bin/env bash
set -euo pipefail

app="rack-attack"

sites_enabled_app_green="/etc/nginx/sites-enabled/${app}-green"
sites_available_app_green="/etc/nginx/sites-available/${app}-green"

sites_enabled_app_blue="/etc/nginx/sites-enabled/${app}-blue"
sites_available_app_blue="/etc/nginx/sites-available/${app}-blue"

sites_enabled_any_color="/etc/nginx/sites-enabled/${app}-*"

if [ -z "$(ls -A ${sites_enabled_any_color} 2>/dev/null)" ]; then
  switch_to="blue"
  echo "No se encontraron sitios habalitados. Iniciando con blue"
elif [ -e "${sites_enabled_app_green}" ]; then
  switch_to="blue"
  echo "Se encontro green, cambiando a blue"
else
  switch_to="green"
  echo "Se encontro blue, cambiando a green"
fi

if [ "${switch_to}" = "blue" ]; then
  new_port="3000"
  new_color="blue"
  new_enabled_site="${sites_enabled_app_blue}"
  new_available_site="${sites_available_app_blue}"
  old_enabled_site="${sites_enabled_app_green}"
  old_color="green"
else
  new_port="3001"
  new_color="green"
  new_enabled_site="${sites_enabled_app_green}"
  new_available_site="${sites_available_app_green}"
  old_enabled_site="${sites_enabled_app_blue}"
  old_color="blue"
fi

tmux new-session -d -s "rack-attack-$new_color" -n "app" -c "/home/julian/rack-attack"
tmux send-keys -t "rack-attack-$new_color:0" "bundle exec rackup -p $new_port" Enter

for i in {1..11}; do
  if [ "$(curl -o /dev/null -s -w '%{http_code}' http://127.0.0.1:$new_port)" -eq 200 ]; then
    echo "[✓] new process ready at ${new_port}"
    break
  fi
  sleep 1
done

# --- Enable new site ---
sudo ln -sf "${new_available_site}" "${new_enabled_site}"

# --- Remove old site if present ---
if [ -e "${old_enabled_site}" ]; then
    echo "Deleting old site '${old_enabled_site}'"
    sudo rm "${old_enabled_site}"
fi

tmux kill-session -t "rack-attack-$old_color" 2>/dev/null || true

# --- Validate and reload nginx ---
sudo nginx -t
sudo systemctl reload nginx
