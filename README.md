# ansible-role-matrix-stack

> Production-ready Ansible role to deploy a **dual-homeserver Matrix Synapse infrastructure** on Debian 12 using Docker Compose.

This role deploys a complete Matrix backend composed of:

* PostgreSQL 16 (generic, multi-component database management)
* Synapse Users
* Synapse Bridges
* Matrix bridges (mautrix-whatsapp, mautrix-telegram, mautrix-signal, and any future bridge described purely through variables)

It is designed to be integrated into a larger infrastructure repository responsible for inventories, secrets, DNS, reverse proxy and environment-specific configuration.

---

# Why this role exists

Most Matrix deployments combine multiple responsibilities into a single project:

* Synapse
* PostgreSQL
* Reverse Proxy
* DNS
* TLS certificates
* Identity Provider
* Infrastructure inventory

This project deliberately separates those concerns.

The Matrix stack becomes an independent Ansible role that can be reused across staging, production or customer infrastructures while remaining completely infrastructure-agnostic.

---

# Architecture

```text
                           Internet
                                │
                                ▼
                       Reverse Proxy
                     (Caddy / nginx)
                                │
        ┌───────────────────────┼────────────────────────┐
        │                       │                        │
        ▼                       ▼                        ▼
   Synapse Users         Synapse Bridges            Keycloak
        │                       │
        │                       ▼
        │              mautrix-whatsapp
        │              mautrix-telegram
        │              mautrix-signal
        │                       │
        └───────────────┬───────┘
                        ▼
                   PostgreSQL 16
             (one database per component)
```

The recommended deployment uses four dedicated virtual machines:

| VM                     | Purpose                                             |
| ---------------------- | ---------------------------------------------------- |
| vm-matrix-postgresql   | PostgreSQL — every Matrix database (`matrix_db` group) |
| vm-matrix-users        | User homeserver only                                |
| vm-matrix-bridges      | Synapse Bridges + all bridge containers             |
| vm-proxy / vm-keycloak | External infrastructure (Caddy, Keycloak) — not managed by this role |

Bridges run **only** on `vm-matrix-bridges`, never on `vm-matrix-users`. Each
bridge gets its own Docker container, its own dedicated PostgreSQL database
and role on `vm-matrix-postgresql`, its own `config.yaml`/`registration.yaml`,
and its own persistent directory under `/opt/matrix/bridges/<bridge_name>/`.
No bridge ever embeds its own database, uses SQLite, or connects to
`localhost` — every bridge connects to the central PostgreSQL VM.

> Note: the inventory group backing "vm-matrix-postgresql" is named
> `matrix_db` for backward compatibility with existing inventories — it is
> the same central PostgreSQL VM described above.

---

# Separation of responsibilities

This role intentionally deploys **only the Matrix stack**.

| Component        | Managed by              |
| ---------------- | ----------------------- |
| PostgreSQL       | ✅ This role             |
| Synapse Users    | ✅ This role             |
| Synapse Bridges  | ✅ This role             |
| Docker / Compose | ✅ This role             |
| Reverse Proxy    | External infrastructure |
| DNS              | External infrastructure |
| TLS certificates | External infrastructure |
| Ansible Vault    | External infrastructure |
| Inventory        | External infrastructure |
| CI/CD            | External infrastructure |

This separation keeps the role reusable while allowing different infrastructure repositories to consume it.

---

# Features

## Current

* PostgreSQL 16 with generic, idempotent database/role/privilege management (`matrix_postgresql_databases`) — any future component adds one list entry, no new task file
* Dual Synapse deployment
* Generic Matrix bridges deployment (`matrix_bridges`) — mautrix-whatsapp, mautrix-telegram, mautrix-signal today, any future bridge by adding a variable entry
* Docker Compose
* Persistent volumes
* Automatic Docker installation
* Idempotent deployment
* Persistent, never-regenerated Application Service tokens, stored per-environment
* Ready for reverse proxy integration
* Ready for OIDC integration
* Production-oriented directory layout

## Planned

* Keycloak integration
* Matrix Authentication Service (MAS)
* Sliding Sync
* Hookshot
* Sygnal
* LiveKit
* Draupnir moderation
* MatrixToken invitation workflow
* Automated backup role

---

# Repository structure

```
ansible-role-matrix-stack/

├── defaults/
├── handlers/
├── meta/
├── tasks/
├── templates/
├── examples/
└── README.md
```

The `examples/` directory exists only to validate the role independently.

Production deployments are expected to consume this role from a dedicated infrastructure repository.

---

# Installation

## Recommended (production)

Install the role as a Git dependency.

requirements.yml

```yaml
roles:
  - src: https://github.com/sepp67/ansible-role-matrix-stack.git
    scm: git
    version: main
    name: matrix_stack
```

Install the dependencies:

```bash
ansible-galaxy install -r requirements.yml
```

Deploy:

```bash
ansible-playbook playbooks/deploy-matrix-stack.yml
```

---

## Standalone (development)

For development or testing purposes, the role can also be executed independently.

Clone the repository:

```bash
git clone https://github.com/sepp67/ansible-role-matrix-stack.git
```

Run the example playbook:

```bash
ansible-playbook examples/deploy-matrix-stack.yml
```

---

# Main configuration

The role deploys one component depending on the variable:

```yaml
matrix_component:
```

Possible values:

| Value           | Deployed component               |
| --------------- | --------------------------------- |
| postgres        | PostgreSQL                        |
| synapse_users   | User homeserver                   |
| synapse_bridges | Bridges homeserver                |
| bridges         | Matrix bridges (VM matrix_bridges, after synapse_bridges) |

Complete variable documentation is available in:

```
defaults/main.yml
```

---

# PostgreSQL — generic database management

Every PostgreSQL database used by the stack — Synapse Users, Synapse Bridges,
each bridge, and any future component — is declared in a single generic
variable:

```yaml
matrix_postgresql_databases:
  - name: synapse_users
    user: synapse_users
    password: "{{ vault_matrix_postgres_password_users }}"

  - name: synapse_bridges
    user: synapse_bridges
    password: "{{ vault_matrix_postgres_password_bridges }}"

  - name: mautrix_whatsapp
    user: mautrix_whatsapp
    password: "{{ vault_matrix_bridge_whatsapp_db_password }}"

  - name: mautrix_telegram
    user: mautrix_telegram
    password: "{{ vault_matrix_bridge_telegram_db_password }}"

  - name: mautrix_signal
    user: mautrix_signal
    password: "{{ vault_matrix_bridge_signal_db_password }}"
```

`tasks/postgresql_databases.yml` loops over this list and, for each entry,
idempotently ensures the role, the database (UTF8 / `C` collation, owned by
its role) and the privileges exist, using `community.postgresql.postgresql_user`,
`postgresql_db` and `postgresql_privs` over a local TCP connection
(`127.0.0.1:{{ matrix_postgres_port }}`) authenticated as the `postgres`
superuser. This task file is completely generic — it has no notion of
"bridge" and must never be edited to add a new component.

This replaces the previous `docker-entrypoint-initdb.d` SQL script, which
only ran once at first container boot and could not create new databases on
an already-running server. The new mechanism is idempotent and safely
re-runnable at any time, which is what lets a new component be onboarded by
adding one list entry — no new task, no server restart, no data loss for
existing databases.

Adding a future Matrix component that needs PostgreSQL (Sliding Sync, Matrix
Authentication Service, Hookshot, ...) means adding one entry to
`matrix_postgresql_databases` in the consuming inventory. Nothing in the role
itself changes.

---

# Matrix bridges

Bridges are deployed on `matrix_component: bridges`, targeting the
`matrix_bridges` inventory group, **after** the `synapse_bridges` play (the
Application Service registration files must exist before Synapse Bridges is
restarted to load them).

```yaml
matrix_bridges_enabled: true

# Environment-specific — no default in this role, must be set by the
# consuming inventory (never 127.0.0.1: Synapse Bridges and every bridge run
# in separate docker-compose projects even though they share the same VM).
# See "Network topology" below. The `bridges` play fails fast via an
# ansible.builtin.assert if either is missing.
matrix_synapse_internal_url: "http://192.168.1.77:{{ matrix_bridges_http_port }}"
matrix_appservice_base_url: "http://192.168.1.77"

matrix_bridges:
  - name: whatsapp
    image: dock.mau.dev/mautrix/whatsapp
    tag: latest
    container_name: mautrix-whatsapp
    appservice_id: whatsapp
    appservice_port: 29317
    bot_username: whatsappbot
    database_name: mautrix_whatsapp
    database_user: mautrix_whatsapp
    database_password: "{{ vault_matrix_bridge_whatsapp_db_password }}"
    # Optional per-bridge overrides:
    # permissions: {}      # merged over matrix_bridges_default_permissions
    # extra_config: {}     # merged into config.yaml for bridge-specific business config

  - name: telegram
    image: dock.mau.dev/mautrix/telegram
    tag: latest
    container_name: mautrix-telegram
    appservice_id: telegram
    appservice_port: 29318
    bot_username: telegrambot
    database_name: mautrix_telegram
    database_user: mautrix_telegram
    database_password: "{{ vault_matrix_bridge_telegram_db_password }}"
    # mautrix-telegram requires api_id/api_hash (https://my.telegram.org/apps).
    # extra_config is merged as-is at the root of config.yaml — only the
    # telegram entry sets this key, so whatsapp/signal are never impacted.
    extra_config:
      telegram:
        api_id: "{{ vault_matrix_telegram_api_id }}"
        api_hash: "{{ vault_matrix_telegram_api_hash }}"
```

The role contains **no reference to any bridge by name**. `image` and `tag`
fully describe the container; `config.yaml`, `registration.yaml` and
`docker-compose.yml` are rendered from one shared, generic template per file
type. Adding a new bridge (Discord, Facebook, Slack, Instagram, ...) means
adding one entry to `matrix_bridges` (plus its database entry in
`matrix_postgresql_databases`) — no template or task changes.

## Network topology

Synapse Bridges and every bridge run on the same VM (`matrix_bridges` group)
but in **separate docker-compose projects**, so `127.0.0.1` inside one
container never reaches another. Traffic between them flows in both
directions, each with its own dedicated URL:

- **Bridge → Synapse** (`matrix_synapse_internal_url`, used as
  `homeserver.address` in each bridge's `config.yaml`):
  `http://<matrix_bridges VM IP>:{{ matrix_bridges_http_port }}`.
- **Synapse → bridge** (`matrix_appservice_base_url`, used as `url` in
  `registration.yaml` and `appservice.address` in `config.yaml`):
  `http://<matrix_bridges VM IP>` — each bridge's own
  `appservice_port` is appended to it. The port is published on the VM's
  network interface by `docker-compose` (`mautrix-bridge-compose.yml.j2`),
  which is what makes it reachable from the Synapse Bridges container.

Both variables are **environment-specific and have no default in this
role** — this role must stay generic and never ship an example address that
could be used by accident. They are set once in the consuming inventory
(e.g. the `devops_staging_prod_infra` repo's `group_vars`), never inside
`ansible-role-matrix-stack` itself and never per-bridge. If either is
missing, the `bridges` play fails immediately with an explicit
`ansible.builtin.assert` (see `tasks/bridges.yml`) instead of silently
falling back to a placeholder IP.

## Database connection

Every bridge connects to the central PostgreSQL VM, never to a local or
embedded database:

```
postgres://<database_user>:<database_password>@{{ matrix_postgres_host }}:{{ matrix_postgres_port }}/<database_name>?sslmode={{ matrix_bridges_postgres_sslmode }}
```

`matrix_bridges_postgres_sslmode` defaults to `disable` (our central
PostgreSQL VM does not run SSL). It lives once in `defaults/main.yml` and is
applied by the shared `config.yaml` template to every bridge, current and
future — never set per bridge. Override it in the inventory if the
PostgreSQL VM starts requiring SSL.

## Permissions

Restrictive by default, overridable globally or per bridge:

```yaml
matrix_bridges_default_permissions:
  "*": ""
  "matrix-users.local": "user"
  "@bridge-master:matrix-bridges.local": "admin"
```

## Application Service tokens

`as_token`/`hs_token` are generated once via the `ansible.builtin.password`
lookup and persisted **on the Ansible control node**, under
`matrix_bridge_tokens_dir` (default: `{{ inventory_dir }}/generated`) — so
staging and production naturally get distinct tokens. They are never
regenerated on subsequent runs. A consolidated, human-readable
`generated/bridge_tokens.yml` is also written per environment for
convenience; the individual per-token files remain the source of truth for
idempotency.

This directory contains secrets and must be excluded from version control
and backed up — see `.gitignore` (`examples/inventories/*/generated/` for
the bundled example inventories).

## Registration flow

Each bridge has a single logical `registration.yaml`, rendered once from the
shared template and then copied byte-for-byte (same `as_token`/`hs_token`) to
its two other locations — never re-rendered:

1. `{{ _bridge_dir }}/registration.yaml` — rendered from the template; source
   of truth for the two copies below.
2. `{{ _bridge_data_dir }}/registration.yaml` — inside the bridge's own data
   directory (`/data` in its container).
3. `{{ matrix_base_dir }}/bridges/data/appservices/<bridge_name>-registration.yaml`
   — Synapse Bridges' appservices directory. `homeserver.yaml` for
   `synapse_bridges` lists every enabled bridge under
   `app_service_config_files`.

Synapse Bridges is restarted first when a registration file changes, then
the bridge itself — so Synapse Bridges has already reloaded the new
`as_token`/`hs_token` by the time the bridge reconnects.

## Scope of this first sprint

This first iteration focuses on plumbing, not bridge business configuration:
PostgreSQL databases created, containers started, appservices registered in
Synapse, bots visible and responding to `/help` in Matrix. Bridge-specific
setup (WhatsApp QR login, Signal linking, ...) is deliberately left to
`matrix_bridge.extra_config` and a later sprint — the config template is
intentionally generic and may need minor adjustment against the exact
`example-config.yaml` shipped by each bridge image/version. Telegram's
mandatory `api_id`/`api_hash` are the one exception already wired through
`matrix_bridge.extra_config` (see the `telegram` entry above) since the
bridge won't start without them.

---

# Validation

Basic deployment validation:

```bash
docker compose ps
```

Check the Matrix Client API:

```bash
curl https://matrix-users.example.com/_matrix/client/versions
```

Check federation:

```bash
curl https://matrix-bridges.example.com/_matrix/federation/v1/version
```

## Bridges

On `vm-matrix-postgresql`, confirm every database was created:

```bash
sudo docker exec -it matrix-postgres \
  psql -U postgres \
  -c "\l"
```

Expected: `synapse_users`, `synapse_bridges`, `mautrix_whatsapp`,
`mautrix_telegram`, `mautrix_signal`.

On `vm-matrix-bridges`, confirm the containers are running:

```bash
sudo docker ps | grep mautrix
```

Confirm Synapse Bridges loaded the appservices:

```bash
sudo grep -n "app_service_config_files" -A10 \
  /opt/matrix/bridges/data/homeserver.yaml
```

Check the bridge and Synapse Bridges logs:

```bash
sudo docker logs synapse-bridges --tail=100
sudo docker logs mautrix-whatsapp --tail=100
sudo docker logs mautrix-telegram --tail=100
sudo docker logs mautrix-signal --tail=100
```

From Element, as a user allowed by `matrix_bridges_default_permissions`:

* Search `@whatsappbot:matrix-bridges.local`, `@telegrambot:matrix-bridges.local`, `@signalbot:matrix-bridges.local`
* Open a DM with each bot
* Send `/help` and confirm each bot responds

---

# CA trust for internal TLS (staging)

In staging environments using Caddy with `tls internal`, Synapse must trust the Caddy local CA to establish TLS federation connections to other homeservers through the proxy.

## Why not a custom Docker image

Building a custom Docker image with the CA baked in is an anti-pattern for a local CA:

* The Caddy CA changes whenever the proxy is reinstalled
* Rebuilding and pushing an image on every CA rotation is fragile
* The CA is an infrastructure artifact, not an application component

## Why a dedicated entrypoint script

The role ships `files/synapse-entrypoint.sh`:

```sh
#!/bin/sh
set -e
update-ca-certificates
exec /start.py "$@"
```

This script is copied to the Synapse compose directory by Ansible and mounted read-only into the container. It runs `update-ca-certificates` (which picks up any cert in `/usr/local/share/ca-certificates/`) then immediately delegates to the official `/start.py` with all original arguments preserved (`"$@"` receives Docker's CMD, which is `start`).

This approach:

* avoids putting shell logic inside `docker-compose.yml`
* keeps the behavior readable and debuggable
* requires no custom image

## How to enable

Set `matrix_ca_cert_path` to the absolute path of the CA certificate on the host.
The certificate must already exist on the host before Ansible runs the Matrix role — it is written by the separate `caddy_ca` role.

```yaml
# In staging group_vars (empty string = disabled)
matrix_ca_cert_path: /opt/caddy-ca/caddy-root.crt
```

When `matrix_ca_cert_path` is empty (default), the entrypoint and cert mount are omitted and the official Synapse image runs without modification.

---

# Integration philosophy

This role intentionally **does not** configure:

* Reverse proxy
* DNS
* TLS certificates
* Let's Encrypt
* Inventories
* Ansible Vault
* CI/CD

These responsibilities belong to the surrounding infrastructure repository.

This design keeps the role portable and reusable.

---

# Roadmap

## Current milestone

* [x] PostgreSQL (generic, idempotent database management)
* [x] Synapse Users
* [x] Synapse Bridges
* [x] Docker Compose deployment
* [x] Generic Matrix bridges deployment
* [x] Mautrix WhatsApp
* [x] Mautrix Telegram
* [x] Mautrix Signal

## Next milestone

* [ ] Bridge business configuration (WhatsApp login, Telegram API credentials, Signal linking)
* [ ] Keycloak OIDC
* [ ] Matrix Authentication Service
* [ ] Existing LDAP migration
* [ ] Sliding Sync
* [ ] Hookshot
* [ ] Draupnir
* [ ] MatrixToken integration

---

# Related repositories

This role is part of a larger infrastructure ecosystem.

| Repository                | Purpose                                                                        |
| ------------------------- | ------------------------------------------------------------------------------ |
| devops_staging_prod_infra | Infrastructure orchestration (inventories, Caddy, Vault, staging & production) |
| ansible-role-matrix-stack | Matrix deployment                                                              |
| website-lavallee          | Technical documentation and portfolio                                          |

---

# License

MIT

---

# Author

**Sébastien Lavallée**

Linux • DevOps • IAM • Open Source
