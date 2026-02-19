# API Design & Data Contract Rules

- **Endpoint:** The service must expose a single `POST /query` endpoint.

- **Two-Step Clarification Loop:** The query interaction must follow the two-step, session-based clarification flow defined in the PRD. The first request returns a `needs_clarification` status, and the second request (with a valid `session_id`) returns the final answer.

- **Response Schemas:** All API responses must conform to the Pydantic schemas defined in `src/schemas/`. The final successful response must include `status`, `session_id`, `answer`, and `sources` fields.

- **Source Citation Schema:** The `sources` array in the final response must be a list of objects, each containing `book_title`, `authors`, `sku`, `page_number`, and `excerpt`.

- **Vector Node Metadata:** The metadata for each vector stored in Qdrant must conform to the `MetadataSchema` TypedDict defined in `src/schemas/metadata.py`. This includes `book_title`, `authors`, `sku`, `chapter`, `section`, `page_number`, `chunk_type`, and `reproducible_id`.
