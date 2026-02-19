_# Ingestion Pipeline Rules_

- **Source of Truth:** The ingestion pipeline must read source PDFs exclusively from the designated AWS S3 bucket. Do not process local files.

- **Self-Hosted Parsing:** All PDF parsing must be done by calling the internal, self-hosted `llmsherpa` service running on Fargate. Do not send raw PDF content to any external third-party service.

- **Vision for Reproducibles:** The pipeline must identify landscape-oriented pages or pages marked as reproducibles, render them as images, and use the GPT-4o Vision API to generate structured descriptions. This is a critical step for capturing the content of non-textual assets.

- **Metadata Integrity:** Every vector created must have metadata that strictly conforms to the `MetadataSchema` TypedDict. No missing fields are allowed (except for optional ones, which should be `None`).

- **Asynchronous Execution:** The ingestion process should be designed to run asynchronously (e.g., as a triggered Fargate task) and should not be part of the synchronous API request/response cycle.
