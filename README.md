# ansible-role-matrix-stack

> Production-ready Ansible role to deploy a **dual-homeserver Matrix Synapse infrastructure** on Debian 12 using Docker Compose.

This role deploys a complete Matrix backend composed of:

* PostgreSQL 16
* Synapse Users
* Synapse Bridges

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
        └───────────────┬───────┘
                        ▼
                   PostgreSQL 16
```

The recommended deployment uses three dedicated virtual machines:

| VM                | Purpose            |
| ----------------- | ------------------ |
| vm-matrix-db      | PostgreSQL         |
| vm-matrix-users   | User homeserver    |
| vm-matrix-bridges | Bridges homeserver |

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

* PostgreSQL 16
* Dual Synapse deployment
* Docker Compose
* Persistent volumes
* Automatic Docker installation
* Idempotent deployment
* Ready for reverse proxy integration
* Ready for OIDC integration
* Production-oriented directory layout

## Planned

* Keycloak integration
* Matrix Authentication Service (MAS)
* Mautrix WhatsApp
* Mautrix Signal
* Mautrix Telegram
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

| Value           | Deployed component |
| --------------- | ------------------ |
| postgres        | PostgreSQL         |
| synapse_users   | User homeserver    |
| synapse_bridges | Bridges homeserver |

Complete variable documentation is available in:

```
defaults/main.yml
```

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

* [x] PostgreSQL
* [x] Synapse Users
* [x] Synapse Bridges
* [x] Docker Compose deployment

## Next milestone

* [ ] Keycloak OIDC
* [ ] Matrix Authentication Service
* [ ] Existing LDAP migration
* [ ] Mautrix WhatsApp
* [ ] Mautrix Signal
* [ ] Mautrix Telegram
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
