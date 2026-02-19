# PLC Co-Pilot

Monorepo for the PLC Co-Pilot platform — AI-powered tools for educators built around Professional Learning Communities (PLCs).

## Apps

| App | Description | Status |
|-----|-------------|--------|
| [`apps/api`](./apps/api) | PLC Coach Service — RAG API serving expert PLC answers from a curated book corpus | Active |
| `apps/teachers-portal` | Teacher-facing frontend | Planned |
| `apps/admins-portal` | Admin-facing frontend | Planned |

## Packages

Shared libraries (UI, auth, db, AI, types) will live in `packages/` as the platform grows.

## Getting Started

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for engineering conventions, branching workflow, and naming standards.

See [`apps/api`](./apps/api) for the PLC Coach Service setup and development instructions.
