# frp-server

## Deploy

```bash
# source deploy script first
source <(wget -qO- https://raw.githubusercontent.com/geektr-cloud/frp-server/master/deploy.sh)

# update (init) project to local enviroment
frp-server::update

# when first run this init data directory and secrets directory
frp-server::init-secrets

# edit secrets files
# vim xxxxxx

# up the services
frp-server::up
```

## Backup

```bash
source /srv/geektr.cloud/frp-server/deploy.sh

frp-server::backup-data
```
