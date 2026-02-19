# The PLC Coach Service: DevOps for Dummies

This document explains the infrastructure decisions for the Minimum Viable Product (MVP) of the PLC Coach service. The goal is to make these technical choices clear and understandable. Our approach is guided by three core principles:

1.  **Security and Compliance First**: Every decision is made through the lens of FERPA and protecting student data, even for features that will be implemented after the MVP.
2.  **Start Simple, Evolve Gracefully**: For the MVP, we will choose the simplest, most cost-effective solution that meets the requirements. We will ensure this simple start can evolve into a more robust, scalable architecture in the future without a complete rewrite.
3.  **No Black Boxes**: You should understand what each component does, why it's there, and what it costs. This guide is the first step in ensuring that.

---

## Part 1: The Big Picture - "Self-Hosted" vs. "Managed"

Nearly every infrastructure decision comes down to a trade-off between control and convenience. We can frame this as the difference between a "managed" service and a "self-hosted" one.

*   **Managed Service (The Fully-Furnished Apartment)**: This is like renting an apartment where the landlord handles all maintenance, security, and utilities. You just move in and use the space. In the cloud, this means using a service like Amazon's RDS for a database. Amazon manages the servers, patching, and backups. It's convenient, reliable, and lets your team focus on building the application, not managing servers.

*   **Self-Hosted (Owning the House)**: This is like owning a house. You have complete control over everything—the layout, the security system, the plumbing—but you are also responsible for all maintenance and repairs. In our case, this means running software on a virtual server (an EC2 instance) in AWS. We have to install, configure, secure, and maintain it ourselves.

For the PLC Coach, we will use a **hybrid approach**, using managed services where it makes sense for convenience and cost, and self-hosting only when we need the control for security and compliance.

---

## Part 2: Your MVP Infrastructure Decisions

Here is a breakdown of each piece of the infrastructure, the decision we've made for the MVP, and the reasoning in plain English.

| Component | What It Is | MVP Recommendation | Why This Choice? |
| :--- | :--- | :--- | :--- |
| **Compute (API)** | The engine that runs the main application code (the FastAPI server). | **AWS Fargate (Managed)** | Fargate is a "serverless" compute engine. We give it our application's container, and it runs it for us. We don't have to manage the underlying server. For the MVP, we'll run a single instance, which is cheap and sufficient for internal testing. It can easily scale up later. |
| **Vector Database** | The specialized database that stores the book content (as vectors) and allows the AI to find relevant information quickly. This is the AI's long-term memory. | **Qdrant on EC2 (Self-Hosted)** | This is our most critical data store. By self-hosting it on our own virtual server (EC2), we ensure no data ever leaves our secure AWS environment. This gives us maximum control for FERPA compliance. We are choosing control over convenience here because it's the safest path. |
| **PDF Parser** | The tool (`llmsherpa`) that reads the PDFs, understands the layout (headings, tables, etc.), and prepares the content for the AI. | **`llmsherpa` on Fargate (Self-Hosted)** | Just like the vector database, we want to control the parsing process. We will run the `llmsherpa` software as its own service inside our AWS environment. This means the PDFs are never sent to a third-party service for processing, which is a critical security and compliance win. |
| **Relational Database** | A standard database for storing user information, chat history, and other application data. | **Amazon RDS (Managed)** | This is a classic managed service. Amazon handles the database for us, making it reliable and low-maintenance. It's perfect for standard application data that isn't the core AI-related content. |
| **File Storage** | Where the source PDF files (the books) will be stored. | **Amazon S3 (Managed)** | S3 is the standard for file storage in AWS. It's cheap, incredibly durable, and secure. We'll create a "private" S3 bucket, meaning only our application can access the files. This is the perfect place to store the books so the PDF Parser can access them. |
| **Cache** | A super-fast, temporary memory store used to speed up the application, for example by storing active chat sessions. | **Amazon ElastiCache (Managed)** | This is another managed service that provides a fast in-memory cache. It's a standard component for making web applications responsive and is a low-maintenance, cost-effective choice. |

---

## Part 3: Why Data is "Zoned" (and Why "Students" are Special)

You asked why we need to think about data zones, and specifically why "Students" would be its own data type. This is the most important concept for the long-term security and compliance of the service.

Think of your application's data like different types of assets in a secure facility. You wouldn't store paper records, gold bars, and computer servers in the same room with the same lock. You'd put them in different vaults with different levels of security and access rules. That's what data zoning is.

Even though the MVP will only use Zone A, we are designing the architecture to support all three zones from day one. It is very difficult and risky to add these boundaries later.

Here are the three zones for the PLC Coach service:

*   **Zone A: The Library (Book Content)**
    *   **What's inside:** The PLC book PDFs, the parsed text, and the vector embeddings.
    *   **Sensitivity:** Proprietary intellectual property. It's valuable, but it contains no student information.
    *   **Access Rules:** The API and the ingestion pipeline can read from this zone to answer general questions.

*   **Zone B: The Meeting Room (Transcript Data)**
    *   **What's inside:** Meeting transcripts and notes, which may contain sensitive details about student performance or teacher discussions.
    *   **Sensitivity:** High. This is an "education record" under FERPA.
    *   **Access Rules:** Access must be strictly controlled and audited. We can't just mix this data with the general book content. The AI can use this data, but only under strict conditions and with the user's explicit permission.

*   **Zone C: The Registrar's Office (Student Identity)**
    *   **What's inside:** The link between a real student's name and an anonymized token (e.g., `STUDENT_123`).
    *   **Sensitivity:** Extreme. This is the key that can unlock anonymized data.
    *   **Access Rules:** This zone is the most restricted. Only a special, highly-audited "tokenization service" can access it. The main application will work with the anonymized tokens, not real names. When a teacher's query mentions a student by name, a "prompt firewall" will intercept the query, swap the name for a token, and then pass the anonymized query to the AI. This prevents student names from ever being sent to the AI model or being stored in logs.

By separating data this way, we create strong, defensible boundaries that make it much easier to prove compliance and protect sensitive information. It's the foundation of a trustworthy, enterprise-ready AI service.

I am now ready to write the PRD with these decisions locked in. Do you have any other questions before I proceed?
