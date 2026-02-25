# PLC Co-Pilot

Monorepo for the PLC Co-Pilot platform — AI-powered tools for educators built around Professional Learning Communities (PLCs).

## Current Focus: PLC Coach Service (MVP)

The current development focus is the **PLC Coach Service**, a Retrieval-Augmented Generation (RAG) API that provides educators with expert answers to PLC questions by querying a curated corpus of approximately 25 proprietary books from Solution Tree's PLC @ Work® series.

The primary goal is to validate that a high-quality, book-only RAG service can provide more useful and accurate answers than a general-purpose chatbot. The long-term vision is a full-featured, FERPA-compliant coaching platform with teacher and admin portals, so all architectural decisions in this MVP are made with that future state in mind.

## Documentation

| Document | Location | Description |
|---|---|---|
| **Product Requirements (PRD)** | `apps/api/docs/prd-v4.md` | The full, self-contained specification for the PLC Coach Service MVP. **This is the source of truth for the engineering team.** |
| **AI Development Rules** | `CLAUDE.md` | Rules and context for AI-powered development on this repository. |
| **Engineering Handbook** | `CONTRIBUTING.md` | Branching workflow, naming standards, and other engineering conventions. |

## Apps

| App | Description | Status |
|---|---|---|
| `apps/api` | PLC Coach Service — RAG API serving expert PLC answers from a curated book corpus | Active |
| `apps/teachers-portal` | Teacher-facing frontend | Planned |
| `apps/admins-portal` | Admin-facing frontend | Planned |

## Packages

Shared libraries (UI, auth, db, AI, types) will live in `packages/` as the platform grows.

## Getting Started

See `CONTRIBUTING.md` for engineering conventions.

See `apps/api` for the PLC Coach Service setup and development instructions.
