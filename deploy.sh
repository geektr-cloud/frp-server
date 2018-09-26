#!/usr/bin/env bash

frp-server::utils::let-dir-empty() {
  target_path="$1"
  # lesson written in blood
  # it's dangdangerous if $service_dir unset (following rm command will remove '/*' dir)
  if [ ! -n "$target_path" ]; then exit 1; fi

  if [ -d "$target_path" ]; then
    rm -rf "$target_path"/* "$target_path"/.*
  elif [ -f "$target_path" ]; then
    mv "$target_path" "$target_path.bak"
    mkdir -p "$target_path"
  else
    mkdir -p "$target_path"
  fi
}

frp-server::utils::sync() {
  source_path="$1"
  target_path="$2"

  frp-server::utils::let-dir-empty "$target_path"
  cp -r "$source_path/." "$target_path"
}

# constants
git_repo=https://github.com/geektr-cloud/frp-server.git
default_deploy_dir=/srv/geektr.cloud
default_backup_dir=/srv/geektr.cloud/.backups
default_project_name=frp-server

# set variables
# frp-server::set_deploy_conf [deploy_dir] [project_name] [deploy_dist]
frp-server::set_deploy_conf() {
  deploy_dist="${1:-$default_deploy_dir}"

  export project_name="${2:-$default_project_name}"
  export backups_dir="${3:-$default_backup_dir}"

  export service_dir="$deploy_dist/$project_name"

  export secrets_src="$deploy_dist/$project_name/secrets"
  export secrets_dir="$deploy_dist/$project_name.secrets"
  export secrets_bak="$backups_dir/$project_name.secrets"

  export data_src="$deploy_dist/$project_name/data"
  export data_dir="$deploy_dist/$project_name.data"
  export data_bak="$backups_dir/$project_name.data"
}

# shellcheck disable=SC2119
frp-server::set_deploy_conf

frp-server::dev_update() {
  if [ -d "$service_dir" ]; then
    pushd "$service_dir"
    docker-compose down || echo "already down"
    popd
  fi

  frp-server::utils::sync "$(pwd)" "$service_dir"
  find "$service_dir" -name ".gitkeep" -exec rm -rf '{}' +
}

# remove old project & get latest project by git
frp-server::update() {
  if [ -d "$service_dir" ]; then
    pushd "$service_dir"
    docker-compose down || echo "already down"
    popd
  fi

  frp-server::utils::let-dir-empty "$service_dir"
  git clone --depth=1 "$git_repo" "$service_dir"

  find "$service_dir" -name ".gitkeep" -exec rm -rf '{}' +
}

frp-server::backup-secrets() {
  mkdir -p "$backups_dir"

  backup_dir="$secrets_bak-$(date '+%y%m%d%H%M%S')"

  frp-server::utils::sync "$secrets_dir" "$backup_dir"
}

# initialize secret directory
frp-server::init-secrets() {
  # if secrets dir already exist, backup it and then remove
  if [ -d "$secrets_dir" ]; then
    frp-server::backup-secrets
    echo "$secrets_dir will be removed, you can find the backup in $backups_dir"
  fi

  frp-server::utils::sync "$secrets_src" "$secrets_dir"
}

frp-server::backup-data() {
  mkdir -p "$backups_dir"

  backup_file="$data_bak-$(date '+%y%m%d%H%M%S').zip"

  zip -rq "$backup_file" "$data_dir"
}

# initialize data directory
frp-server::init-data() {
  # if data dir already exist, backup it and then remove
  if [ -d "$data_dir" ]; then
    docker run --rm -it -v "$data_dir:/data" alpine:3.8 chown -R "$UID:$GID" /data
    frp-server::backup-data
    echo "$data_dir will be removed, you can find the backup in $backups_dir"
  fi

  frp-server::utils::sync "$data_src" "$data_dir"
}

frp-server::up() {
  envsubst < "$service_dir/.env.template" > "$service_dir/.env"

  pushd "$service_dir"
  docker-compose up -d
  popd
}
