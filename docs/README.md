# Documentation

## Current authority

These six describe how the product and the codebase are meant to work, and
are kept up to date:

| File | What it covers |
|---|---|
| `PRODUCT_CONSTITUTION.md` | What the product is for; the six domains; what not to build yet |
| `ARCHITECTURE.md` | Security model, domain boundaries, table groups, integration boundary |
| `DOMAIN_RULES.md` | Business rules for leads, packages, quotes, bookings, consent, safety, finance, AI |
| `IMPLEMENTATION_ROADMAP.md` | Phase order and the dependency chain |
| `CURRENT_MILESTONE.md` | Where the build actually stands right now, and what is next |
| `DEFINITION_OF_DONE.md` | The bar a module must clear before it counts as finished |

`../AGENTS.md` sits above all of these and sets the working agreement for the
repository.

## Frozen historical record

The following were produced under the previous owner's development process,
which ran AI coding agents against a live production database under a strict
per-sprint approval regime. They are preserved because they explain why the
schema and the stage gates are shaped the way they are.

They are **not instructions** and are not maintained:

- `governance/` — 25 records: scope freezes, technical design freezes and
  their amendments, post-release reconciliations, and the T1 training
  milestone approval (August–September 2026)
- `releases/` — two production release records for sprints 10 and 11
- `SPRINT_MASTER_REGISTER.md` — a 320 KB running register of every sprint

Read them for archaeology. Do not treat a dated approval, a pull request
number, a deployment ID, a Supabase project reference or a role-permission
count in these files as describing the current system — all of them refer to
the previous repository and the previous database. `CURRENT_MILESTONE.md` is
the only file that describes the system as it stands.
