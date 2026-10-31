# Unraid server

`192.168.0.250`. The Docker stacks here are deployed by [doco-cd](https://doco.cd/) running on
Unraid: it polls `main` every 5 minutes and applies the stacks listed in `.doco-cd.yml`, itself
included. They show up in the Docker tab without a template; change them here, not in the webgui.

| Stack | What |
| ----- | ---- |
| `doco-cd/` | doco-cd itself. A bumped tag in its compose file makes it replace itself |
| `garage/` | Garage storage node, see `garage/README.md` |

## Secrets

Secrets are committed as `*.sops.env`, encrypted to the home-ops key and to Unraid's own age key
(`.sops.yaml`). doco-cd decrypts them with the Unraid key; it cannot read anything else in the
repo. Edit them with `sops unraid/<stack>/secret.sops.env`.

The Unraid key's private half lives at `/mnt/user/appdata/doco-cd/age.key` on Unraid and in
`.private/doco-cd/unraid.age.key` (gitignored) here.

## Bootstrap

Once, as root:

1. Put the age key in place:

   ```sh
   mkdir -p /mnt/user/appdata/doco-cd
   nano /mnt/user/appdata/doco-cd/age.key    # contents of .private/doco-cd/unraid.age.key
   chmod 600 /mnt/user/appdata/doco-cd/age.key
   ```

2. Run the one-shot bootstrap. It deploys every stack in `.doco-cd.yml` once and exits, leaving a
   doco-cd container that manages itself from then on:

   ```sh
   docker volume create doco-cd_data
   docker run --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v doco-cd_data:/data \
     -v /mnt/user/appdata/doco-cd/age.key:/age.key:ro \
     -e SELF_UPDATE_ENABLED=true \
     -e DEPLOY_CONFIG_BASE_DIR=unraid/ \
     -e SOPS_AGE_KEY_FILE=/age.key \
     -e POLL_CONFIG='[{url: https://github.com/xnilsit/home-ops.git, reference: main}]' \
     ghcr.io/kimdre/doco-cd:0.129.0 apply-self --bootstrap
   ```

3. `docker ps` shows `doco-cd-doco-cd-<n>`. `docker logs -f $(docker ps -aq -f label=com.docker.compose.service=doco-cd)` follows the
   deployments.

## Day-to-day

doco-cd's container is `doco-cd-doco-cd-<n>`, and `<n>` goes up with every self-update, so the
commands below select it by its Compose service label.

- A merge to `main` reaches Unraid within 5 minutes. `docker restart $(docker ps -aq -f label=com.docker.compose.service=doco-cd)` polls
  immediately.
- doco-cd redeploys a stack whose `unless-stopped`/`always` containers are not running at its next
  poll, so a container stopped by hand comes back within 5 minutes.
- doco-cd has `restart: always`, so it starts with the Docker daemon after an array stop or a
  reboot and its first poll starts the other stacks again.
- To keep doco-cd from touching anything during maintenance, `docker stop $(docker ps -aq -f label=com.docker.compose.service=doco-cd)`, and
  `docker start` it afterwards. Stopping the array or rebooting starts it again.
