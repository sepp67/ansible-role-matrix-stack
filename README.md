ansible-role-matrix-stack
Deploy a production-ready dual Matrix Synapse infrastructure with Ansible.
This role deploys a complete Matrix backend composed of:
    • PostgreSQL 
    • Synapse Users 
    • Synapse Bridges 
using Docker Compose on Debian 12.
The role is designed to be integrated into a larger infrastructure repository responsible for inventories, secrets, DNS, reverse proxy and environment-specific configuration.

Why this role exists
Many Matrix deployments mix together:
    • Synapse 
    • Bridges 
    • Reverse proxy 
    • DNS 
    • Identity provider 
This project deliberately separates those responsibilities.
The Matrix stack becomes an independent Ansible role that can be reused in staging, production or customer infrastructures.

Architecture
                        Internet
                             │
                             ▼
                    Reverse Proxy
                   (Caddy / nginx)
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
   Synapse Users      Synapse Bridges      Keycloak
         │                   │
         └─────────────┬─────┘
                       ▼
                 PostgreSQL 16

Responsibilities:
Component    Managed by
Matrix       this role
PostgreSQL   this role
Docker       this role

Reverse proxy     infrastructure repository
DNS               infrastructure repository
TLS certificates  infrastructure repository
Ansible Vault     infrastructure repository
Inventory         infrastructure repository

Features
Current
    • PostgreSQL 16 
    • Dual Synapse deployment 
    • Docker Compose 
    • Persistent volumes 
    • Idempotent deployment 
    • Ready for reverse proxy 
    • Ready for OIDC 
    • Ready for Mautrix 
Planned
    • Keycloak integration 
    • Matrix Authentication Service 
    • Mautrix WhatsApp 
    • Mautrix Signal 
    • Mautrix Telegram 
    • Draupnir 
    • MatrixToken 
    • Automated backup 

Repository layout
defaults/
handlers/
meta/
tasks/
templates/
examples/
The examples/ directory exists only to demonstrate standalone usage.
Production deployments are expected to consume this role from an infrastructure repository.

Installation
Recommended (production)
requirements.yml
roles:
  - src: https://github.com/sepp67/ansible-role-matrix-stack.git
    scm: git
    version: main
    name: matrix_stack
Install
ansible-galaxy install -r requirements.yml
Deploy
ansible-playbook playbooks/deploy-matrix-stack.yml

Standalone (development)
Clone
git clone ...
Run
ansible-playbook examples/deploy-matrix-stack.yml
This mode is intended only for testing the role independently.

Variables
Au lieu des énormes tableaux, je ne garderais que les variables principales.
Puis :
See defaults/main.yml for the complete list.
Ton defaults/main.yml est déjà auto-documenté.
Le README n'a pas besoin de dupliquer ces 150 lignes.

Deployment
Très simple.
matrix_db
↓
PostgreSQL
matrix_users
↓
Synapse Users
matrix_bridges
↓
Synapse Bridges
Puis
ansible-playbook ...

Validation
Seulement :
docker compose ps
curl /_matrix/client/versions
Puis
For detailed validation procedures,
see docs/validation.md

Integration
Nouvelle section.
This role intentionally does NOT configure:
• Caddy
• nginx
• DNS
• TLS
• Let's Encrypt
• Inventories
• Vault
Those responsibilities belong to the surrounding infrastructure repository.
Je trouve cette partie très importante.

Roadmap
Je transformerais la roadmap en cases à cocher.
Current milestone
[x] PostgreSQL
[x] Synapse Users
[x] Synapse Bridges
Next
[ ] Keycloak
[ ] OIDC
[ ] Matrix Authentication Service
[ ] Mautrix WhatsApp
[ ] Mautrix Signal
[ ] Mautrix Telegram
[ ] Draupnir
[ ] MatrixToken

