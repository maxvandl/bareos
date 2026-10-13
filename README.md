# bareos

![License badge][license-img]
![Based OS][os-based-ubuntu]
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fmaxvandl%2Fbareos.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Fmaxvandl%2Fbareos?ref=badge_shield)

Docker images and a docker-compose stack for [Bareos][bareos-href] 25
(director, storage daemon, file daemon, web UI, REST API) with a PostgreSQL
catalog and a Postfix relay for job reports.

## Stack

| Service        | Build context      | Purpose                             | Published port         |
| -------------- | ------------------ | ----------------------------------- | ---------------------- |
| `bareos-dir`   | `./director-pgsql` | Bareos director                     | none (9101 internal)   |
| `bareos-sd`    | `./storage`        | Storage daemon, volumes on disk     | `${SD_BIND}:9103`      |
| `bareos-fd`    | `./client`         | File daemon (also backs up catalog) | none (9102 internal)   |
| `bareos-webui` | `./webui`          | Web UI (Apache + PHP-FPM)           | `${WEBUI_BIND}:8080`   |
| `bareos-db`    | `postgres:18`      | Catalog database                    | none, internal network |
| `smtpd`        | `./smtpd`          | Postfix relay for job reports       | none (8025 internal)   |
| `bareos-api`   | `./api`            | REST API                            | `127.0.0.1:8000`       |
| `bareos-exporter` | `vierbergenlars/bareos_exporter` | Prometheus metrics       | `127.0.0.1:9625`       |

### Image variants

Every image is built from Ubuntu in two flavours, selected with the
`UBUNTU_VERSION` build argument (`.env` → `UBUNTU_VERSION`):

| Variant          | Base image     | Note                                      |
| ---------------- | -------------- | ----------------------------------------- |
| `*-ubuntu26.04`  | `ubuntu:26.04` | Latest release, default, also tagged bare |
| `*-ubuntu24.04`  | `ubuntu:24.04` | Previous LTS                              |

Bareos packages come from the official repository
`download.bareos.org/current/xUbuntu_<version>` (stable branch; amd64 only).
The PostgreSQL client in the director and file daemon images comes from
`apt.postgresql.org` and matches the catalog server major (`PG_CLIENT_VERSION`,
default `18`) so `pg_dump` for the catalog backup is compatible.

To build against the Bareos subscription repository instead:

```bash
printf 'machine download.bareos.com login <user> password <token>\n' > auth.conf
docker compose build \
  --build-arg BAREOS_REPO=https://download.bareos.com/bareos/release/25/xUbuntu_26.04/ \
  --secret id=bareos_auth,src=auth.conf
```

## Requirements

- [Docker][docker-href] with [Compose v2][docker-compose-href]
- On Apple Silicon: director, storage and client run as `linux/amd64` under
  emulation (Bareos ships amd64 packages only). Web UI, API, Postfix and
  PostgreSQL run natively. Enabling _Use Rosetta for x86_64/amd64 emulation_
  in Docker Desktop makes emulated containers faster and more stable.

## Quick start

```bash
cp .env.dist .env
# replace every "changeme" and set ADMIN_MAIL, e.g.:
#   openssl rand -hex 24
docker compose build
docker compose up -d
```

On the first start the containers generate their configuration in
`./data/bareos/config/*`, substitute the passwords from `.env`, rotate every
password the Bareos packages generated at build time, point job reports and
the `BackupCatalog` bootstrap mail at the relay, and the director creates the
catalog database.

Check that everything is running:

```bash
docker compose ps          # all services should be "healthy"
printf 'status client=bareos-fd\nstatus storage=File\n' \
  | docker compose exec -T bareos-dir bconsole
```

## Configuration (`.env`)

Passwords must contain only `[A-Za-z0-9]`: entrypoints substitute them with
`sed`, so characters like `#`, `'`, `"`, `&`, `\` break the configuration.

Passwords are handed to the containers as [compose secrets][compose-secrets]
sourced from `.env` (`secrets: … environment: DB_PASSWORD`) and mounted under
`/run/secrets/`; the entrypoints read `*_FILE` variables and remove every
secret from the environment before starting the daemon. Only
`bareos-exporter` keeps `DB_PASSWORD` in its environment (the image supports
nothing else) and `WEBHOOK_URL` stays in the director's environment because
`webhook-notify` runs as its child.

| Variable                | Required | Description                                                       |
| ----------------------- | :------: | ----------------------------------------------------------------- |
| `UBUNTU_VERSION`        |          | Image variant: `26.04` (default) or `24.04`                       |
| `DB_ADMIN_USER`         |   yes    | PostgreSQL superuser, used to create the catalog                  |
| `DB_ADMIN_PASSWORD`     |   yes    | PostgreSQL superuser password                                     |
| `DB_NAME`               |          | Catalog database name (default `bareos`)                          |
| `DB_USER`               |          | Catalog database user (default `bareos`)                          |
| `DB_PASSWORD`           |   yes    | Catalog database user password                                    |
| `BAREOS_DIR_PASSWORD`   |          | Director console (`bconsole`) password; random when empty         |
| `BAREOS_SD_PASSWORD`    |   yes    | Director ↔ storage daemon password                                |
| `BAREOS_FD_PASSWORD`    |   yes    | Director ↔ file daemon password                                   |
| `BAREOS_WEBUI_PASSWORD` |   yes    | Password of the `admin` web UI console                            |
| `ADMIN_MAIL`            |   yes    | Recipient of job reports                                          |
| `SENDER_MAIL`           |          | Sender address of job reports                                     |
| `SMTP_HELO_NAME`        |          | Hostname the relay announces (default `bareos.local`)             |
| `SMTP_SMARTHOST`        |          | Upstream SMTP `host:port`, e.g. `smtp.example.com:587`            |
| `SMTP_USERNAME`         |          | Smarthost login (enables SASL auth)                               |
| `SMTP_PASSWORD`         |          | Smarthost password                                                |
| `WEBHOOK_NOTIFICATION`  |          | `true` sends reports to Slack/Telegram instead of mail            |
| `WEBHOOK_TYPE`          |          | `slack` or `telegram`                                             |
| `WEBHOOK_URL`           |          | Slack webhook URL or Telegram bot API URL (HTTPS only)            |
| `WEBHOOK_CHAT_ID`       |          | Telegram chat id                                                  |
| `BAREOS_API_SECRET`     |          | JWT signing key of the REST API; random per start when empty      |
| `SD_BIND`               |          | Bind address for port 9103 (default `127.0.0.1`)                  |
| `WEBUI_BIND`            |          | Bind address for port 8080 (default `127.0.0.1`)                  |

Without `SMTP_SMARTHOST` Postfix delivers mail directly, which requires
outbound port 25 to be open. With a smarthost TLS is mandatory
(`smtp_tls_security_level=encrypt`); port 465 switches to implicit TLS.

:warning: Passwords, mail and webhook settings are applied **only on the first
start**, while `./data/bareos/config/<service>/bareos-config.control` does not
exist. To apply new values, stop the stack and remove the configuration
(back it up first if it contains your own jobs):

```bash
docker compose down
rm -rf data/bareos/config/*
docker compose up -d
```

The catalog database is initialized by the director when
`data/bareos/config/director/bareos-db.control` is missing. The step is
idempotent: an existing role gets its password synced from `.env`, an
existing database is kept, privileges are re-granted. Resetting
`data/bareos/config` therefore does not require resetting `data/pgsql`, and a
changed `DB_PASSWORD` is applied on the next first start.

## Access

### Web UI

Open <http://localhost:8080> (redirects to `/bareos-webui/`) and sign in as
`admin` with `BAREOS_WEBUI_PASSWORD`.

### bconsole

```bash
docker compose exec bareos-dir bconsole
```

The console password is `BAREOS_DIR_PASSWORD` or, when it was left empty, the
random value written to `data/bareos/config/director/bconsole.conf`.

### REST API

Open <http://localhost:8000/docs> (the root `/` answers `404`, only `/docs`,
`/redoc` and the API routes exist). It authenticates with the web UI console
credentials (`admin` / `BAREOS_WEBUI_PASSWORD`). Set `BAREOS_API_SECRET` to
keep JWT tokens valid across restarts.

### Prometheus metrics

<http://localhost:9625/metrics>, exported by
[bareos_exporter][bareos-exporter-href] from the catalog database.

### Backing up host paths

By default `bareos-fd` runs as the unprivileged `bareos` user and only backs
up what that user can read (the catalog dump and `/etc/bareos`). To back up
host directories, mount them read-only into `bareos-fd`, set
`FORCE_ROOT=true` and add `DAC_READ_SEARCH` to its `cap_add`, then create a
fileset for the mounted paths.

## Data layout

| Path                          | Content                                      |
| ----------------------------- | -------------------------------------------- |
| `data/bareos/config/director` | Director configuration (`/etc/bareos`)       |
| `data/bareos/config/storage`  | Storage daemon configuration                 |
| `data/bareos/config/client`   | File daemon configuration                    |
| `data/bareos/config/webui`    | Web UI configuration (`directors.ini`)       |
| `data/bareos/data/director`   | Director state and catalog dump              |
| `data/bareos/data/storage`    | Backup volumes                               |
| `data/pgsql`                  | PostgreSQL data (`/var/lib/postgresql`)      |

`data/` is ignored by git: it contains generated passwords.

## Security notes

- Do not commit `.env` or `data/`.
- Only `bareos` (two networks) and `catalog` (internal, no egress) exist; the
  database is reachable from the director only and is not published.
- All published ports default to `127.0.0.1`. Set `SD_BIND=0.0.0.0` only when
  file daemons on other hosts back up to this storage daemon. Publish the web
  UI through an HTTPS reverse proxy or VPN — the web UI console uses
  `TLS Enable = No` because PHP does not support TLS-PSK.
- Containers run with `cap_drop: ALL` plus the few capabilities the entrypoints
  need to fix file ownership and drop privileges, `no-new-privileges`, memory
  and PID limits and log rotation. Without `CAP_SYS_PTRACE` even root inside a
  container cannot read another process's `/proc/<pid>/environ`.
- Passwords generated by the Bareos packages at build time (director console,
  `bareos-mon`) are rotated at first start, so containers built from the same
  image never share secrets. Previously committed configuration with such
  passwords still exists in git history (commit `4b9041a`); treat those values
  as compromised.
- Repository signing keys (Bareos, PGDG) are verified against pinned
  fingerprints at build time (`BAREOS_KEY_FPR`, empty disables the check for
  the subscription repository).
- Images are pinned by digest, scanned with Trivy before push, signed with
  cosign and published with SBOM and provenance. See [SECURITY.md](SECURITY.md).

## PostgreSQL upgrade

The stack uses `postgres:18`, which stores data in
`/var/lib/postgresql/18/docker` inside the mounted `data/pgsql`. Major upgrades
require migrating the data directory, e.g. with
[postgresql-upgrade][psql-upgrade-href] or `pg_dump`/`pg_restore`. Bump
`PG_CLIENT_VERSION` in `director-pgsql/Dockerfile` and `client/Dockerfile`
accordingly.

After upgrading Bareos itself, start the director once with
`DB_UPDATE=true` to update the catalog schema, then set it back to `false`.

## Troubleshooting

- **`bareos-fd` restarts with `fatal error: taggedPointerPack`** – a Go
  binary crashed under amd64 emulation. The client uses `setpriv` instead of
  `gosu` for this reason; rebuild the image with `docker compose build bareos-fd`.
- **Web UI returns 503** – PHP-FPM is not running. Check
  `docker compose logs bareos-webui`; the web UI must not run with
  `platform: linux/amd64` on Apple Silicon.
- **Director cannot connect to the catalog** – the configuration in
  `data/bareos/config/director` was created with other passwords than `.env`.
  See the reset procedure above.
- **No mail arrives** – `docker compose logs smtpd`; without a smarthost the
  host needs outbound port 25, and providers reject direct mail that fails the
  sender domain's DMARC/SPF policy (`status=bounced … 5.7.26`). Configure
  `SMTP_SMARTHOST` with credentials of the sender domain's mail provider, or
  use a `SENDER_MAIL` address whose domain allows it.
- **`ERROR: role "bareos" already exists` during DB init** – printed by the
  Bareos `grant_bareos_privileges` script when the role exists; harmless.
- **Exporter shows no `bareos_*` metrics** – it needs at least one finished
  job in the catalog; run `BackupCatalog` once.

## Development

### Repository layout

| Path              | Content                                                |
| ----------------- | ------------------------------------------------------ |
| `director-pgsql/` | Director image, entrypoint, `admin.conf`, `webhook-notify` |
| `storage/`        | Storage daemon image                                   |
| `client/`         | File daemon image                                      |
| `webui/`          | Web UI image (Apache + PHP-FPM)                        |
| `api/`            | REST API image (`bareos-restapi` in a venv)            |
| `smtpd/`          | Postfix relay image                                    |

Each Bareos entrypoint unpacks the default configuration from a tarball
created at build time (`/bareos-*.tgz`), rotates build-time passwords, applies
environment variables with `sed` and writes `bareos-config.control` so it runs
only once. All scripts run with `set -euo pipefail`.

### Checks

```bash
pre-commit install   # gitleaks, shellcheck, hadolint, yaml and whitespace checks
pre-commit run --all-files
```

### CI and updates

- `docker-publish.yml` builds every component × Ubuntu variant on pushes, PRs,
  tags and weekly; scans each image with Trivy (fixable `CRITICAL` fails the
  build, results go to code scanning); starts the whole stack per Ubuntu
  variant (`compose-test`) and checks director ↔ sd/fd connectivity, a web UI
  login and a rendered `/bareos-webui/dashboard/`, that no password is left in
  any daemon's environment, a successful `BackupCatalog` job and mail hand-over
  to Postfix; only then pushes to
  `ghcr.io/<owner>/bareos-{dir,sd,fd,webui,api,smtpd}` with tags
  `ubuntu26.04`, `ubuntu24.04`, `<version>-ubuntu<ver>`, `sha-*`, `latest`
  (26.04), signs with cosign and attaches SBOM + provenance.
- `security-scan.yml` scans the repository (misconfig, secrets) on every push
  and re-scans published images daily.
- `pre-commit.yml`, CodeQL (workflows), dependency review and OpenSSF
  Scorecard run on pull requests.
- Renovate keeps base image digests, Actions, pre-commit hooks,
  `bareos-restapi` and `PG_CLIENT_VERSION` up to date; minor/patch and digest
  updates are auto-merged, majors need a review.

## Documentation

- [Bareos documentation][bareos-doc]

## License

MIT, see [LICENSE](LICENSE).

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fmaxvandl%2Fbareos.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fmaxvandl%2Fbareos?ref=badge_large)

[bareos-href]: https://www.bareos.org
[bareos-doc]: https://docs.bareos.org
[bareos-exporter-href]: https://github.com/vierbergenlars/bareos_exporter
[docker-compose-href]: https://docs.docker.com/compose
[docker-href]: https://docs.docker.com/get-docker
[compose-secrets]: https://docs.docker.com/compose/how-tos/use-secrets/
[license-img]: https://img.shields.io/badge/License-MIT-yellow.svg
[os-based-ubuntu]: https://img.shields.io/badge/os-ubuntu%2024.04%20%7C%2026.04-9cf
[psql-upgrade-href]: https://github.com/barcus/postgresql-upgrade
