# PLC Co-Pilot: Engineering Handbook for the AI-First Team

## Introduction

This document outlines a set of engineering best practices and conventions for the PLC Co-Pilot project. As a small, AI-first team of three engineers, establishing a clear and consistent framework for collaboration is crucial for maintaining high velocity, code quality, and long-term maintainability. The recommendations below are based on extensive research into industry best practices for modern software development, with a specific focus on the unique opportunities and challenges of an AI-assisted workflow.

This handbook covers three core areas:
1.  **Repository Organization**: How to structure your codebase for clarity and scalability.
2.  **Naming Conventions**: A unified language for your code.
3.  **Collaborative Workflow**: A streamlined process for building and shipping features as a team.

By adopting these practices, you will create a foundation for a robust, scalable, and enjoyable development process.

---

## Part 1: Repository Organization - The Monorepo Approach

For the PLC Co-Pilot project, which consists of two tightly coupled platforms (Teachers Portal and Admins Portal) sharing a significant amount of functionality, a **monorepo** architecture is the recommended approach. A monorepo is a single repository that contains multiple related projects, which is a strategy used by companies like Google, Facebook, and Airbnb to manage large, interconnected codebases [1, 2].

### Why a Monorepo?

The decision to use a monorepo is based on several key advantages that directly address the needs of your project:

| Benefit                  | Description                                                                                                                                                                                                                                                        | Relevance to PLC Co-Pilot                                                                                                                                                                                                                               |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Simplified Code Sharing** | With a monorepo, sharing code between the Teachers Portal and Admins Portal becomes trivial. There is no need to publish and manage private packages for shared components, utilities, or types. You can simply import them directly [2, 7].                               | You have confirmed that both platforms will share user authentication, database models, AI integration code, and UI components. A monorepo makes this seamless.                                                                                      |
| **Atomic Commits & PRs**   | Changes that affect multiple parts of the system (e.g., updating a shared data model and its usage in both frontends) can be made in a single commit and pull request. This makes the history easier to understand and reduces the risk of deploying incompatible versions [2]. | When you change a shared feature, you can update both portals in one go, ensuring they are always in sync.                                                                                                                                              |
| **Unified Tooling & CI/CD** | You can have a single set of tools for linting, testing, and building the entire project. Continuous integration can be configured to run tests only for the parts of the codebase that have changed, saving time and resources [2].                                      | As a small team, managing one set of development and deployment tools is more efficient than managing separate toolchains for each platform and their frontends and backends.                                                                              |
| **Easier Collaboration**     | All team members have visibility into the entire codebase, which encourages collaboration and a holistic understanding of the system. It also simplifies dependency management, as all projects use the same versions of third-party libraries [1].                 | With a team of three, a monorepo fosters a shared sense of ownership and makes it easier for any engineer to work on any part of the project.                                                                                                            |

### Recommended Folder Structure

A clear and logical folder structure is key to a successful monorepo. The following structure is recommended, based on common industry patterns [2, 7]:

```
/plc-copilot
├── apps/
│   ├── teachers-portal/      # Frontend for the Teachers Portal
│   ├── admins-portal/        # Frontend for the Admins Portal
│   └── api/                  # Backend API (serving both portals)
├── packages/
│   ├── ui/                   # Shared UI components (e.g., buttons, forms)
│   ├── shared-utils/         # Shared utility functions (e.g., date formatters)
│   ├── auth/                 # Shared authentication logic
│   ├── db/                   # Database schema, migrations, and queries
│   ├── ai/                   # Claude integration and prompt libraries
│   └── types/                # Shared TypeScript types and interfaces
├── .gitignore
├── package.json              # Root package.json with workspace config
├── pnpm-workspace.yaml       # pnpm workspace configuration
└── README.md
```

-   **`apps/`**: This directory contains the individual applications. In your case, this would be the two frontends and the shared backend API. Each of these is a separate, runnable application.
-   **`packages/`**: This directory contains the shared code, broken down into logical units. This is the heart of the monorepo's code-sharing capability. Each subdirectory in `packages/` is a local package that can be imported by the applications in the `apps/` directory.

This structure provides a clear separation of concerns while making it easy to share code and manage the project as a whole.


---

## Part 2: Naming Conventions - A Unified Language for Your Code

In a collaborative project, and especially in an AI-first workflow, a consistent naming strategy is not a trivial matter—it is a fundamental aspect of writing clean, readable, and maintainable code. The names you choose for variables, functions, classes, and files should clearly communicate their purpose and usage, reducing cognitive load and making the codebase easier to navigate for both human and AI developers [5].

### Core Naming Principles

Before diving into specific conventions, it is important to internalize a set of guiding principles. Every name in your codebase should adhere to the following ideals:

1.  **Reveal Intent**: A name should immediately answer the questions: *Why does it exist? What does it do? How is it used?* [5]. Avoid generic names like `data`, `temp`, or `item` in favor of descriptive names that provide context. For example, instead of `let list;`, use `let userList;` or `let activeUsers;`.

2.  **Be Consistent**: If you use a certain word for a concept, use it consistently throughout the project. For example, if you use `fetch` for data retrieval in one place, do not use `get` or `retrieve` in another. This consistency makes the code predictable and easier to understand [5].

3.  **Be Searchable**: Use names that are easy to search for. Single-letter variable names (except for loop counters like `i`) and overly generic names are difficult to find in a large codebase. A name like `MAX_LOGIN_ATTEMPTS` is much easier to find than the number `3` [5].

4.  **Be Pronounceable**: Code is not just written; it is also read and discussed. Use names that are easy to pronounce and talk about. This facilitates communication during code reviews and pair programming sessions [5].

5.  **Avoid Disinformation**: Do not use names that are misleading. For example, do not name a variable `userList` if it is not actually a list. Also, avoid using abbreviations or acronyms that might have multiple meanings [5].

### Formatting Conventions

To ensure consistency across the codebase, the following formatting conventions should be adopted. These are based on widely accepted standards in the JavaScript/TypeScript community.

| Element Type             | Case Convention      | Example                        |
| ------------------------ | -------------------- | ------------------------------ |
| Variables & Functions    | `camelCase`          | `const userCount = 10;`        |
|                          |                      | `function getUserProfile() {}` |
| Classes & Components     | `PascalCase`         | `class User {}`                |
|                          |                      | `function UserProfileCard() {}`|
| Constants                | `UPPER_SNAKE_CASE`   | `const MAX_USERS = 100;`       |
| Files & Directories      | `kebab-case`         | `user-profile.tsx`             |
|                          |                      | `shared-utils/`                |

### Specific Naming Guidelines

Building on the core principles and formatting conventions, here are specific guidelines for different types of code elements:

-   **Variables**: Should be descriptive nouns. For example, `const user = ...` or `const userList = ...`.
-   **Booleans**: Should be prefixed with `is`, `has`, or `should` to make them read like a question. For example, `const isVisible = true;` or `const hasPermission = false;`.
-   **Functions/Methods**: Should be verbs or verb phrases that describe the action they perform. For example, `function createUser() {}` or `function deleteUserProfile() {}`.
-   **Classes/Components**: Should be nouns or noun phrases that describe the object or UI element they represent. For example, `class User {}` or `function UserProfileCard() {}`.
-   **Files and Directories**: Should be named using `kebab-case` and be all lowercase. This is a common convention that improves readability and avoids issues with case-sensitive file systems.




---

## Part 3: Collaborative Workflow - The GitHub Flow Model

A well-defined workflow is essential for a small, fast-moving team. It ensures that everyone is on the same page, code quality remains high, and features are delivered smoothly. For the PLC Co-Pilot project, we recommend the **GitHub Flow** model, adapted for an AI-first team. This model is simple, effective, and widely used in the industry for teams that prioritize rapid iteration and continuous delivery [6, 8].

### Why GitHub Flow over Git Flow?

You may have heard of another popular model called **Git Flow**, which uses a `develop` branch in addition to `main`. While powerful, Git Flow was designed for more traditional, release-based projects and introduces complexity that is unnecessary for a small, agile team like yours.

Here is a quick comparison:

| Aspect              | GitHub Flow (Recommended)                               | Git Flow                                                              |
| ------------------- | ------------------------------------------------------- | --------------------------------------------------------------------- |
| **Primary Branches**| `main`                                                  | `main` and `develop`                                                  |
| **Feature Branches**| Created from `main`                                     | Created from `develop`                                                |
| **Best For**        | Small teams, web apps, continuous delivery            | Large teams, projects with scheduled releases                         |
| **Complexity**      | Low - easy to learn and manage                          | High - requires more discipline and branch management                 |

For your team of three engineers focused on rapid, AI-assisted development, the simplicity and speed of **GitHub Flow** is the clear winner. It reduces overhead and allows you to focus on what matters most: building and shipping features.



### Core Principles of GitHub Flow

1.  **`main` is always deployable**: The `main` branch is the single source of truth. All code on the `main` branch should be stable, tested, and ready to be deployed at any time. Direct pushes to `main` are strictly prohibited [6].

2.  **One Issue, One Branch, One PR**: Every new feature, bug fix, or piece of work should start as an issue in your project management tool (e.g., GitHub Issues). For each issue, you will create a dedicated feature branch. This keeps work isolated and makes it easy to track progress. The branch is then merged back into `main` via a pull request (PR) [6].

3.  **Short-Lived Branches**: Feature branches should be short-lived, ideally lasting no more than a few days. This minimizes the risk of merge conflicts and encourages smaller, more frequent updates [6].

### The GitHub Flow in 6 Steps

Here is a step-by-step guide to the recommended workflow:

**Step 1: Create an Issue and a Branch**

-   Before starting any work, create a detailed issue that describes the feature or bug. This serves as the single source of truth for the task.
-   Create a new branch from the `main` branch. Name the branch using the format `{issue-number}/{descriptive-name}`. For example: `17/add-user-profile-page`.

**Step 2: Develop**

-  Write code, create assets, and build the feature.

**Step 3: Commit Early and Often**

-   As you make progress, make small, atomic commits. Write clear and descriptive commit messages that explain the *why* behind the change, not just the *what*.
-   Periodically pull the latest changes from the `main` branch into your feature branch to stay up-to-date and resolve any potential conflicts early.

**Step 4: Open a Pull Request (PR)**

-   When your work is complete and tested, open a pull request to merge your feature branch into `main`.
-   The PR description should be detailed. Link to the original issue and provide a clear summary of the changes. If the changes are visual, include screenshots or GIFs.

**Step 5: Conduct a Code Review**

-   At least one other team member must review and approve the PR before it can be merged.
-   The reviewer should focus on the overall architecture, logic, and adherence to the project's conventions. They should not just be looking for typos.
-   The author of the PR is responsible for addressing all feedback and ensuring that all automated checks (e.g., tests, linting) are passing.

**Step 6: Merge and Clean Up**

-   Once the PR is approved and all checks have passed, merge it into the `main` branch.
-   After merging, delete the feature branch. This keeps the repository clean and signals that the work is complete [6].

### Pull Request Template

To ensure consistency and high-quality PRs, use the following template for all pull requests:

```markdown
**Issue:** #[issue_number]

**Description:**
A brief summary of the changes in this PR.

**Changes Made:**
- A bulleted list of the key changes.
- ...

**Screenshots/GIFs:**
(If applicable, add screenshots or GIFs to demonstrate the changes.)

**Checklist:**
- [ ] My code follows the style guide of this project.
- [ ] I have performed a self-review of my own code.
- [ ] I have commented my code, particularly in hard-to-understand areas.
- [ ] I have made corresponding changes to the documentation.
- [ ] My changes generate no new warnings.
- [ ] I have added tests that prove my fix is effective or that my feature works.
- [ ] New and existing unit tests pass locally with my changes.
```

By following this workflow, your team can move quickly and confidently, leveraging the power of AI while maintaining a high standard of code quality and collaboration.

### Safety Nets: Moving Fast Without Breaking Things

Your concern about pull requests going directly to production is not just valid—it is essential. The principle of GitHub Flow is that **`main` is always *deployable*, not that it is *automatically deployed***. The distinction is crucial and is managed by implementing a series of safety nets that provide control and confidence without sacrificing speed.

Here is the recommended safety net strategy for the PLC Co-Pilot project:

**1. Branch Protection Rules for `main`**

First, you will configure branch protection rules in GitHub for your `main` branch. This is a non-negotiable step that enforces quality and prevents accidental or unapproved changes. The following rules should be enabled [9]:

-   **Require a pull request before merging**: This disables direct pushes to `main`, forcing all changes to go through the PR process.
-   **Require approvals (1)**: Require at least one approving review from another team member before a PR can be merged. Since you are a team of three, one approval is a good starting point.
-   **Dismiss stale pull request approvals when new commits are pushed**: If a developer pushes new changes to a PR after it has been approved, the approval is dismissed. This ensures that the final version of the code is always reviewed.
-   **Require status checks to pass before merging**: This is your automated quality gate. All automated tests (unit, integration, etc.) and linting checks must pass before a PR can be merged.
-   **Require branches to be up to date before merging**: This forces feature branches to be synced with `main` before merging, which helps to catch integration issues early.

**2. A Staging Environment for Testing**

Instead of deploying directly to production, you will have a **staging environment** that mirrors your production setup. Here is how it fits into the workflow:

-   When a PR is merged into `main`, it is **automatically deployed to the staging environment**.
-   This gives your team a live environment to test and validate the new feature, ensuring that it works as expected and does not introduce any regressions.

**3. Manual and Gated Production Deployment**

This is the final and most important safety net. Deploying to production is a **manual, deliberate action**, not an automatic one.

-   After a feature has been tested and verified in the staging environment, the team can decide to deploy it to production.
-   This can be done via a manual trigger in your CI/CD tool (e.g., a button in GitHub Actions) or a ChatOps command (e.g., a Slack command).
-   Crucially, you can configure this deployment to require an **approval from a specific person or team**. For example, you could require that two of the three engineers approve the production deployment before it proceeds.

This combination of automated checks, a staging environment, and a manual production gate gives you the best of both worlds: you can move quickly and merge code frequently, but you have full control over what goes to production and when.



---

## References

[1] Thoughtworks. (2023, September 20). *Monorepo vs. multi-repo: Different strategies for organizing repositories*. https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/monorepo-vs-multirepo

[2] Graphite. (n.d.). *Best practices for managing frontend and backend in a single monorepo*. https://graphite.com/guides/monorepo-frontend-backend-best-practices



[3] Graphite. (n.d.). *Creating a coding style guide for your team*. https://graphite.com/guides/creating-coding-style-guide

[4] Basic Dev. (2023, November 20). *Writing Clean Code — Naming Variables, Functions, Methods, and Classes*. Medium. https://medium.com/@mikhailhusyev/writing-clean-code-naming-variables-functions-methods-and-classes-6074a6796c7b

[5] Drake, V. (2022, May 23). *Git branching for small teams*. DEV Community. https://dev.to/victoria/git-branching-for-small-teams-2n64

[6] Tomar, S. (2025, May 10). *The Ultimate Guide to Building a Monorepo in 2026: Sharing Code Like the Pros*. Medium. https://medium.com/@sanjaytomar717/the-ultimate-guide-to-building-a-monorepo-in-2025-sharing-code-like-the-pros-ee4d6d56abaa

[7] Harness. (2023, November 10). *Github Flow vs. Git Flow: What's the Difference?*. https://www.harness.io/blog/github-flow-vs-git-flow-whats-the-difference

[8] GitHub. (n.d.). *About protected branches*. GitHub Docs. https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
