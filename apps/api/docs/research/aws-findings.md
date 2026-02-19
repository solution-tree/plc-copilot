# PLC Coach — Tenant Enclave (AWS) Findings & Recommendations
*Summary of conclusions from our chat (MVP books-only → later transcripts + student-specific coaching).*

## Context & Goals
You’re building a FERPA-aligned coaching service where:

- **MVP**: answers based on proprietary **PLC books only** (no student data).
- **Shortly after MVP**: ingest **PLC meeting transcripts/notes**, allow teachers to ask about **specific students** by name for coaching help grounded in the books.
- Target architecture: **AWS tenant enclave** — “data doesn’t leave the tenant boundary,” while still enabling collaboration.

---

## Key Concepts We Aligned On

### 1) “Private hosting” (llmsherpa / layout parsing)
“Private hosting” means you **run the llmsherpa parser as a service inside your AWS environment** (your VPC) instead of sending PDFs to a vendor-hosted multi-tenant API.

Why it matters:
- Reduces third-party disclosure risk and procurement friction.
- Keeps PDF ingestion inside your controlled boundary.

Operationally, the work is less “can we deploy it?” and more:
- **hardening** (auth, mTLS/API keys, rate limits, disabling payload logs),
- **reliability** (queues, retries, timeouts),
- **observability without data leakage** (metrics/traces without content).

---

### 2) VPC vs server vs Docker
- **VPC** = the private network boundary (subnets, routing, security groups, egress controls).
- **Server/VM** = compute running *inside* the VPC.
- **Container/Docker** = packaging/runtime unit that runs on compute (VMs or managed services like ECS/EKS).

Rule of thumb:
- VPC is the **fenced yard**, servers are the **buildings**, containers are the **rooms**.

---

### 3) Why “tenant enclave” beats “on-device only” for schools
True “on-device only” (nothing leaves teacher laptop) is possible, but fights:
- PLC collaboration,
- cross-device access,
- centralized retention/deletion,
- auditing and policy enforcement.

A tenant enclave is the best practical balance:
- preserves collaboration,
- supports district-friendly security controls,
- creates a clean compliance boundary.

---

## Critical Compliance Insight: “Zero retention” ≠ “no disclosure”
Even with “Zero Data Retention / no training,” sending identifiable student content to a third-party LLM is typically treated as a **vendor disclosure** (not automatically noncompliant, but it usually triggers contractual + technical controls).

So the engineering posture should be:
- minimize what leaves the enclave,
- treat prompts as potentially disclosable,
- implement de-identification + RBAC + audit as first-class controls.

---

## Recommended AWS Tenant-Enclave Architecture

### Data zoning (the big lever)
To support “three pipelines that can talk but not share raw storage,” define explicit zones:

#### Zone A — Content Zone (Books/IP)
Stores:
- PLC book PDFs, parsed text, embeddings

Notes:
- llmsherpa parsing belongs here and should be self-hosted in your VPC.
- Lower sensitivity than student/meeting content, but still proprietary.

#### Zone B — Meeting/Transcript Zone (Education record risk)
Stores:
- raw audio (short retention), transcripts, meeting notes, embeddings

Controls:
- strict RBAC (district → school → PLC team → teacher)
- audit logging for access
- retention policies and deletion workflows
- *tokenized/redacted* transcript text for retrieval + model context assembly

#### Zone C — Identity/Student Directory Zone
Stores:
- roster data, student identifiers, PLC membership
- tokenization + detokenization services and (optionally) mapping store

Controls:
- narrowest access (only identity/token services)
- heavy auditing

**Interoperability rule:** zones “talk” via **IDs/tokens and references**, not shared raw text storage.

---

## Student Aliasing / Tokenization (Where the Key Lives & Leak Paths)

### The right way to do aliases
Aliases help, but only if you avoid the “string replace” trap.

Best practice: **tokenization service** inside the tenant enclave.

#### Deterministic tokenization
Generate stable student tokens so retrieval and Q&A can stay consistent:

- `token = HMAC(K, canonical_student_identifier)`

Where:
- `K` is a secret protected by **AWS KMS** (customer-managed key).
- Only the tokenization service role can use it.

### Where the key should live
- **In AWS KMS**, not in app config, not in client code, not in plaintext env vars.
- Use envelope encryption / derived data keys so services never persist `K` in plaintext.

### Where the mapping should live (two options)

#### Option 1 — No mapping table (min leakage)
- Don’t store token → name mapping.
- Recompute tokens deterministically when you have the identifier.
- Harder to “reverse” token → name later.

#### Option 2 — Mapping table (more practical)
- Store `token -> student_id` (NOT token -> full name) in a restricted datastore.
- UI can join `student_id -> name` via SIS/directory with RBAC checks.
- Only a tightly scoped service can detokenize for display.

Most real products end up with Option 2, but lock it down hard.

---

## “Can it still leak?” Yes — Here’s how to prevent it

### Leakage Path A — Teacher’s prompt includes student name
Risk:
- “How do I support John Smith…” sent externally.

Control:
- **Prompt firewall** at query time:
  - detect identifiers,
  - replace with token before any external call,
  - optionally show UX: “Student names will be masked for privacy.”

### Leakage Path B — Context re-identifies via details
Risk:
- Even tokenized, the excerpt contains enough to identify a student.

Controls:
- retrieval minimization (only the smallest excerpt),
- redact high-risk fields (DOB, address, IDs),
- “least necessary” prompt assembly policy.

### Leakage Path C — Logs, analytics, traces
Risk:
- The most common real-world leak.

Controls:
- **no payload logging** policy by default,
- audit logs store IDs, timestamps, decision metadata (not text),
- debug logs are redacted, time-limited, tenant-controlled, and OFF by default.

---

## PRD Alignment: What’s strong and what to add

### Already strong direction (from what you described)
- corpus-first RAG approach
- self-hosted vector DB (e.g., Qdrant)
- RBAC + audit posture

### Add these explicitly to the PRD
1. **Tenant isolation & data boundary** section:
   - zones, allowed cross-zone calls, egress allowlist, payload logging ban
2. **Prompt firewall** requirement (tokenize/redact before model calls)
3. **Web fallback controls**:
   - tenant configurable (off by default), allowlisted sources, sanitized query behavior
4. **Two-tier logging policy**:
   - Security/Audit: immutable, no content
   - Debug: redacted, time-limited, tenant-controlled

---

## Suggested Next Steps
1. Decide inference posture:
   - self-hosted LLM in enclave (cleanest), or
   - external LLM with strict minimization + tokenization + contract controls
2. Implement tokenization service + KMS-backed key strategy
3. Add prompt firewall + retrieval minimization policies
4. Formalize zone boundaries and “allowed calls” between pipelines
5. Lock down observability: no payload logs, audited detokenization

---

## Quick glossary
- **Tenant enclave**: per-district (or strongly isolated) environment where sensitive data is stored/processed.
- **Tokenization**: replacing identifiers with stable tokens.
- **Detokenization**: converting tokens back to display names (RBAC-gated).
- **Prompt firewall**: pre-model step that removes identifiers and limits context exposure.
