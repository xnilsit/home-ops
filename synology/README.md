# Synology NAS

Oni, `192.168.0.200`. The Docker stacks here are deployed by [doco-cd](https://doco.cd/) running on
the NAS: it polls `main` every 5 minutes and applies the stacks listed in `.doco-cd.yml`, itself
included. Nothing has to be copied to the NAS by hand.

| Stack | What |
| ----- | ---- |
| `doco-cd/` | doco-cd itself. A bumped tag in its compose file makes it replace itself |
| `garage/` | Garage storage node, see `garage/README.md` |

## Secrets

Secrets are committed as `*.sops.env`, encrypted to the home-ops key and to the NAS's own age key
(`.sops.yaml`). doco-cd decrypts them with the NAS key; it cannot read anything else in the repo.
Edit them with `sops synology/<stack>/secret.sops.env`.

The NAS key's private half lives at `/volume1/docker/doco-cd/age.key` on the NAS and in
`.private/doco-cd/synology.age.key` (gitignored) here.

## Bootstrap

Once per NAS, as root (`sudo -i`):

1. Put the age key in place:

   ```sh
   mkdir -p /volume1/docker/doco-cd
   vi /volume1/docker/doco-cd/age.key        # contents of .private/doco-cd/synology.age.key
   chmod 600 /volume1/docker/doco-cd/age.key
   ```

2. doco-cd adopts a running Compose project by its name. Check that the existing Garage runs as
   project `garage`; if it prints anything else, remove it with `docker rm -f garage` first:

   ```sh
   docker inspect garage --format '{{ index .Config.Labels "com.docker.compose.project" }}'
   ```

3. Run the one-shot bootstrap. It deploys every stack in `.doco-cd.yml` once and exits, leaving a
   doco-cd container that manages itself from then on:

   ```sh
   docker volume create doco-cd_data
   docker run --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v doco-cd_data:/data \
     -v /volume1/docker/doco-cd/age.key:/age.key:ro \
     -e SELF_UPDATE_ENABLED=true \
     -e DEPLOY_CONFIG_BASE_DIR=synology/ \
     -e SOPS_AGE_KEY_FILE=/age.key \
     -e POLL_CONFIG='[{url: https://github.com/xnilsit/home-ops.git, reference: main}]' \
     ghcr.io/kimdre/doco-cd:0.129.0 apply-self --bootstrap
   ```

4. `docker ps` shows `doco-cd-doco-cd-1` and `garage`. `docker logs -f doco-cd-doco-cd-1` follows
   the deployments.

The old `/volume1/docker/garage/{garage.toml,docker-compose.yaml,.env}` are unused after this and
can be deleted.

## Day-to-day

- A merge to `main` reaches the NAS within 5 minutes. `docker restart doco-cd-doco-cd-1` polls
  immediately.
- doco-cd does not restart a container that was stopped by hand; the next deployment that changes
  that stack does.
- To keep doco-cd from touching anything during maintenance, `docker stop doco-cd-doco-cd-1`, and
  `docker start` it afterwards.
