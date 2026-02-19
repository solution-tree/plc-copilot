**FERPA Compliance Report for PLC Coach Platform** 

Prepared for: Solution Tree PLC Coach Development Team 

Date: February ,  

Purpose: Comprehensive analysis of FERPA requirements and compliance strategy for a teacher-focused PLC collaboration platform that processes student names and is grounded in the PLC at Work® framework. 

Executive Summary 

The PLC Coach platform, designed to facilitate Professional Learning Community (PLC) meetings through AI-powered transcription and analysis, will handle education records subject to the Family Educational Rights and Privacy Act (FERPA). This report provides a comprehensive analysis of FERPA requirements and a compliance strategy based on all confirmed policy decisions. 

Key Compliance Pillars 

. School Official Exception: PLC Coach qualifies as a "school official" under FERPA, allowing access to student data without separate parental consent by meeting all four legal requirements through a comprehensive Data Processing Agreement (DPA). 

. Role-Based Access Control (RBAC): The platform's primary privacy safeguard is strict RBAC. Identifiable data (with real student names) is visible only to the teachers on that student's PLC team. Anonymized data (aggregated, no names) is visible to administrators. De-identified data (with consistent pseudonyms) is used for internal platform improvement. 

. Retrieval-Augmented Generation (RAG) Architecture: The AI coach is grounded in the  official Solution Tree PLC at Work® books using a RAG architecture. This ensures methodological fidelity and eliminates privacy risks associated with training AI models on student data. 

. Purpose Limitation: Data is used only for authorized purposes: facilitating PLC meetings for teachers, providing aggregated quality indicators for admins, and measuring PLC fidelity for platform improvement. Commercial use, advertising, or building student profiles is strictly prohibited. 

. Data Minimization and Retention: Raw recordings are retained for a \-day quality assurance period during the beta phase, then immediately deleted after full rollout. De-  
identification keys are encrypted and deleted after analysis. This minimizes data exposure while supporting operational needs. 

. Understanding FERPA and Education Records 

What is FERPA? 

The Family Educational Rights and Privacy Act ( U.S.C. § g;  CFR Part ) is a federal law that protects the privacy of student education records. FERPA applies to all schools that receive funds under applicable federal programs, which includes virtually all public K- schools and most private schools. 

FERPA grants parents (and students over ) the right to access education records, request corrections, and control disclosure of personally identifiable information (PII) from those records. Schools must generally obtain written consent before disclosing education records, with specific exceptions outlined in the regulations. 

Definition of "Education Records" 

Under  CFR § ., education records are defined as records that are directly related to a student and maintained by an educational agency or institution, or by a party acting for or on behalf of the agency. These records include grades, transcripts, class lists, student course schedules, health records (K-), student financial information (postsecondary), and discipline files. Critically, the format does not matter—education records can be handwriting, print, computer media, videotape, audiotape, film, microfilm, microfiche, or e mail. 

Do PLC Meeting Transcripts Qualify as Education Records? 

Yes. When PLC meetings involve discussions of specific students, their academic performance, behavioral observations, or intervention strategies, the resulting recordings and transcripts are directly related to students and maintained by the school (or a party acting on behalf of the school). Therefore, they qualify as education records subject to FERPA. 

Data Classification in PLC Coach 

PLC Coach uses three distinct types of data, each with its own purpose and privacy controls: Data Type Who Sees It Example Purpose  
Identifiable Teachers (Team)"Claudia needs help with reading" 

"% of teams   
Take action on 

specific students Monitor school-wide   
Anonymized Admins 

De-identifiedPlatform Improvement   
discussed 

interventions" 

"Student A → 

Student A → Student A" 

quality 

Measure PLC cycle completion

Exemptions That Do NOT Apply to PLC Coach 

Sole Possession Records: Records kept in the sole possession of the maker, used only as a personal memory aid, and not accessible to others are exempt from FERPA. However, PLC meeting recordings fail all three criteria—they are shared with the team, stored on a centralized platform, and processed by AI. This exemption does not apply. 

Other FERPA exemptions (law enforcement records, employment records, medical treatment records, alumni records, peer-graded papers) are also not relevant to PLC Coach's use case. 

. The School Official Exception: Legal Pathway for PLC Coach 

Overview 

FERPA generally requires schools to obtain written parental consent before disclosing education records. However,  CFR § .(a)() provides an exception: schools may disclose education records to "school officials" with "legitimate educational interest" without consent. 

Critically, FERPA § .(a)()(i)(B) explicitly permits schools to outsource institutional services to contractors, consultants, volunteers, or other third parties, treating them as "school officials" if four requirements are met. 

The Four Requirements for Third-Party "School Official" Status 

Requirement : Institutional Service or Function 

Requirement: The vendor performs an institutional service or function for which the agency or institution would otherwise use employees.   
PLC Coach Analysis: ✓ MEETS REQUIREMENT 

Schools would otherwise employ instructional coaches, PLC facilitators, or administrators to facilitate PLC meetings, document discussions, and track action items. PLC Coach performs this institutional function by automating meeting facilitation, documentation, and quality monitoring. This is clearly a service the school would otherwise perform with employees. 

Requirement : Direct Control 

Requirement: The vendor is under the direct control of the agency or institution with respect to the use and maintenance of education records. 

PLC Coach Analysis: ✓ MEETS REQUIREMENT (through DPA) 

"Direct control" is achieved through a comprehensive Data Processing Agreement (DPA) that specifies: 

• Authorized Purposes: Facilitating PLC meetings (identifiable data), providing quality indicators (anonymized data), and measuring PLC fidelity (de-identified data). • Prohibited Uses: Advertising, selling data, building profiles for non-educational purposes. 

• Data Security: Encryption, RBAC, audit logging, and specific security controls for de identification keys. 

• Data Retention: \-day deletion of raw recordings during beta, immediate deletion after full rollout. Deletion of de-identification keys after analysis. 

• School's Rights: Right to audit, data portability, and termination provisions. This DPA must be executed with every school customer before any data processing begins. 

Requirement : Purpose Limitation and Redisclosure Restrictions 

Requirement: The vendor is subject to  CFR § .(a), which requires that PII from education records may be used only for the purposes for which disclosure was made and prohibits redisclosure without authorization. 

PLC Coach Analysis: ✓ MEETS REQUIREMENT 

PLC Coach uses student data only for three authorized purposes: 

. Facilitating PLC meetings (Identifiable Data): Transcription, summarization, and action item tracking with student names visible to the PLC team. 

. Providing quality indicators to administrators (Anonymized Data): Aggregated data with no individual student or team identification.  
. Improving the platform (De-identified Data): Measuring team fidelity to the  Critical Questions using de-identified data with consistent pseudonyms. 

All other uses are strictly prohibited. PLC Coach will not use student data for marketing, selling data, or training AI models. 

Requirement : Annual Notification 

Requirement: The vendor must meet the criteria specified in the school's annual notification of FERPA rights for being a school official with legitimate educational interest. 

PLC Coach Analysis: ✓ MEETS REQUIREMENT (with school cooperation) 

Schools are required to provide an annual notification to parents explaining FERPA rights. For PLC Coach to qualify as a school official, the school must include language in its annual FERPA notice that covers third-party service providers. 

PLC Coach will: 

. Provide schools with template language for their annual FERPA notice that describes PLC Coach as a school official. 

. Verify during onboarding that schools have updated their annual FERPA notice. 

. Provide schools with a parent notification letter explaining how PLC Coach supports teacher collaboration while protecting student privacy. 

Example Template Language for School FERPA Notice: 

"School officials include third-party service providers that perform institutional services or functions for which the school would otherwise use employees, such as professional development platforms, data analysis tools, and instructional support systems. These service providers have legitimate educational interest in student information necessary to fulfill their contracted services and operate under the direct control of the school with respect to the use and maintenance of education records."

. COPPA Applicability Analysis 

What is COPPA? 

The Children's Online Privacy Protection Act (COPPA) is a federal law that governs the online collection of personal information from children under . It requires website and online service operators to obtain verifiable parental consent before collecting, using, or disclosing personal information from children. 

Why COPPA Does NOT Apply to PLC Coach   
COPPA does not apply because the users of PLC Coach are teachers, not students. Students do not create accounts, log in, or interact with the platform in any way. While student data is discussed, the platform is not directed at children under , and it does not collect personal information directly from them. 

. State Student Privacy Laws 

Overview 

At least  states have enacted student privacy laws that are often stricter than FERPA. These laws impose additional requirements on vendors regarding data security, commercial use prohibitions, transparency, and data breach notification. 

Confirmed Strategy: PLC Coach will be designed to comply with the strictest state laws from day one, including California (SOPIPA), New York (Education Law § \-d), and Illinois (ISSRA). This ensures a high standard of privacy that will meet or exceed requirements in all other states. 

Key State Law Requirements 

State Key Requirements for Vendors 

\- Prohibits using student data for targeted 

advertising, building profiles for non 

California (SOPIPA) New York (Ed Law § \-d)   
educational purposes, or selling student data. \- Requires reasonable security procedures. \- Requires deletion of student data upon request from the school. 

\- Requires a "Parent's Bill of Rights for Data Privacy and Security." 

\- Mandates encryption of all student data at rest and in transit. 

\- Requires vendors to provide training to employees on data privacy and security. \- Imposes strict data breach notification requirements (-hour notification to schools).

Illinois (ISSRA)   
\- Requires a written agreement with schools that outlines data use, security, and breach notification procedures. 

\- Prohibits using student data for commercial purposes. 

\- Requires vendors to delete student data within  days of a school's request. 

. Data Processing, Privacy Controls, and Technical Architecture 

Role-Based Access Control (RBAC) 

The platform's primary privacy safeguard is strict RBAC, ensuring that users can only access data they are authorized to see.   
Role Access to Identifiable Student Data 

Team Member ✅Yes (their team's   
Access to Identifiable Team Data   
Access Aggreg 

students only) ✅Yes (their team only) ❌No 

School Admin ❌No ❌No ✅Yes teams 

District Admin ❌No ❌No ✅Yes schoo

Key Principles: 

• A teacher can only see data for students they teach and PLC teams they belong to. • Administrators receive only aggregated, anonymized quality indicators (e.g., "% of teams are meeting weekly"). 

• No drill-down capability for administrators to view individual team discussions or student names. 

• Minimum aggregation level of  teams to prevent re-identification. 

Retrieval-Augmented Generation (RAG) for AI Insights   
To ensure all AI-generated advice is grounded in approved methodology, PLC Coach uses a RAG architecture that keeps student data and knowledge base content completely separate. 

RAG Workflow: 

. Indexing (One-Time Setup): The  Solution Tree PLC at Work® books are converted to text, chunked into sections, and stored as vector embeddings in a secure vector database. 

. Retrieval (During Meeting Analysis): When processing a PLC meeting, the system identifies key concepts from the teacher discussion and queries the vector database to find the most relevant passages from the  books. 

. Augmentation & Generation: The retrieved passages are inserted into a prompt for a large language model (GPT-) along with the meeting transcript. The prompt instructs the model to generate a summary and recommendations based only on the provided book excerpts and the meeting context. 

. Output: The final output is a summary grounded in and often citing the official PLC at Work® methodology. 

Privacy Benefits of RAG: 

• The  books are public content with no student data. 

• The vector database contains only book content, not student information. • Student data and book content remain in separate systems. 

• No training or fine-tuning on student data is required. 

Data Flow Architecture 

Plain Text 

\+---------------------------+ \+-----------------------------+ | PLC Meeting Recording | | 22 Solution Tree PLC Books | | (Contains Student Names) | | (Public Content) | \+---------------------------+ \+-----------------------------+  | | 

 v v 

\+---------------------------+ \+-----------------------------+ | Transcription Service | | Vector Database | | (Student Names Preserved) | | (Book Embeddings) | \+---------------------------+ \+-----------------------------+ 

 | | (Retrieval)  v v 

\+---------------------------------------------------------------+ | LLM Prompt (to GPT-4 via API) | |---------------------------------------------------------------|  
| "Using the following context from our PLC books and the | | meeting transcript, generate a summary and action items." | | | | Context from Books: "\[...passages from Learning by Doing...\]" | | Transcript: "\[...teachers discussing Claudia's reading...\]" | \+---------------------------------------------------------------+  |  

 v  

\+---------------------------+ \+-----------------------------+ | Meeting Summary & Actions| | Aggregated Admin Data | | (Contains Student Names) | | (Anonymized) | \+---------------------------+ \+-----------------------------+  | | 

 v v 

\+---------------------------+ \+-----------------------------+ | PLC Team View (Secure) | | Admin Dashboard | | \- Claudia needs help | | \- 75% of teams meeting | | \- Follow up on reading | | \- Quality indicators | \+---------------------------+ \+-----------------------------+ 

De-Identification for Platform Improvement 

Purpose: To measure team fidelity to the PLC at Work® framework, specifically whether teams systematically address the Four Critical Questions. 

Data Processing: 

• Student names are replaced with consistent pseudonyms (e.g., "Student A") across multiple meetings. 

• This allows measurement of whether teams complete the intervention cycle (identify need → implement intervention → monitor progress → adjust). 

• Re-identification keys are maintained by PLC Coach and not shared with schools or third parties. 

• Data is used solely to improve the platform's ability to support high-fidelity PLC implementation. 

What is NOT tracked: 

• Individual student academic outcomes or achievement data. 

• Specific student identities in platform improvement datasets. 

Re-Identification Key Management: 

• Confirmed Policy: Re-identification keys will be encrypted and stored separately from the de-identified data. Access will be restricted to specific, authorized engineers for the  
sole purpose of quality assurance and analysis. Keys will be permanently deleted within  days of creation, rendering the data permanently anonymized. 

. Third-Party Vendor Requirements (AWS, OpenAI) 

AWS FERPA Compliance 

Overview: AWS provides infrastructure and services that can be used in a FERPA-compliant manner, but compliance is a shared responsibility between AWS and the customer. 

Shared Responsibility Model: 

• AWS Responsibility: Security of the cloud (physical infrastructure, network, hypervisor, managed services). 

• Customer Responsibility: Security in the cloud (data encryption, access controls, application security, data classification, FERPA compliance). 

Recommendation: Use AWS as the infrastructure provider with proper security configurations, including encryption at rest and in transit, least-privilege access controls via IAM, and comprehensive audit logging via CloudTrail. 

OpenAI FERPA Compliance 

Confirmed Strategy: PLC Coach will use OpenAI as the exclusive AI vendor for the MVP, relying on their Student Data Privacy Agreement (SDPA) and a zero-retention configuration. 

Shared Responsibility with OpenAI: 

Responsibility OpenAI PLC Coach Secure infrastructure ✅OpenAI 

Not training on your data ✅OpenAI 

Deleting per retention policy ✅OpenAI 

Deciding what data to send ✅PLC Coach Configuring API properly ✅PLC Coach Access controls to API ✅PLC Coach

Implementation: 

. Execute SDPA: PLC Coach will execute OpenAI's Student Data Privacy Agreement.   
. Zero-Retention Configuration: The OpenAI API will be configured for zero data retention before any production use. This is a mandatory requirement. 

. Send Full Transcripts: To ensure the highest quality AI outputs, full meeting transcripts (including student names) will be sent to the OpenAI API for processing. This is justified by the strong contractual protections of the SDPA and the zero-retention policy. 

. Justification: This approach is simpler and provides better AI quality than a complex redact-and-re-insert workflow. The risk is mitigated by the SDPA and zero-retention configuration. This can be revisited post-MVP if necessary. 

. Finalized Policy Decisions 

All key policy decisions have been confirmed. The following table summarizes PLC Coach's data governance framework: 

Policy Area Decision Rationale 

Data Retention (Raw Recordings)   
 days during beta (\~ 

months, duration TBD), then immediate deletion after full rollout.   
Allows quality assurance during the beta phase, framed as a QA period for beta testers. 

Data Retention (Summaries)Retain indefinitely with student names for team. 

Full access for current \+    
Teachers need student names to take action; access 

restricted by RBAC. 

Balances utility with privacy; 

Historical Data Access 

AI Model Training 

Platform Improvement Data Use 

Team Opt-Out of 

Improvement 

prior school year, then anonymized. 

No training on student data; RAG architecture with  PLC books. 

De-identified data to track team fidelity to  Critical Questions. 

Opt-in required (teams must actively consent to 

contribute).   
older data anonymized (student names → 

pseudonyms). 

Eliminates privacy risk; ensures methodology fidelity; uses public content only. 

Allows measurement of intervention cycle 

completion, which is core to the product's value. 

Respects team autonomy and provides maximum 

transparency. 

Team Conflict Resolution Majority vote required to delete meeting (with reason);   
Protects team's collaborative work; respects individual  
individual redaction allowed. privacy. 

Data PortabilityYes, export in multiple formats (PDF, JSON, CSV). 

No direct access; receive   
Prevents vendor lock-in; supports team autonomy. 

Protects teacher 

Parent Access   
summary letters ("Your child's teachers are working on...").   
collaboration space; provides transparency without 

exposing details. 

Teacher Transitions\-day grace period, then access revoked. 

Student TransitionsData stays (school's institutional record). 

Student Privacy Pledge 

strongly recommended   
Protects institutional 

continuity; reasonable transition period. 

Reflects school's record of teacher collaboration; not subject to deletion on student transfer. 

The Pledge is free, builds trust, and is a competitive 

Third-Party Certification 

before launch; iKeepSafe after traction.   
requirement. iKeepSafe is a valuable but costly audit best pursued after initial traction. 

Consent for RecordingAll participants must consent; guests/substitutes included.   
Non-negotiable FERPA requirement; protects all participants. 

Simplest and lowest-risk 

Non-Consenting Participants   
Meeting not recorded if any participant declines.   
consent model. One refusal blocks recording for that meeting.

. Data Breach Notification Requirements 

FERPA Requirements 

FERPA does NOT require schools to notify parents of data breaches. However, many state laws do. 

State Law Requirements 

PLC Coach will comply with all state data breach notification laws, including the \-hour notification requirement in New York.   
PLC Coach Breach Response Plan 

Phase : Detection and Containment (- hours) 

• Detect breach through security monitoring, user report, or third-party notification. • Activate incident response team. 

• Contain breach and preserve evidence. 

Phase : Assessment and Notification (- hours) 

• Assess scope of breach. 

• Notify affected schools with preliminary information. 

• Engage legal counsel and cybersecurity experts if needed. 

Phase : School Support and Remediation ( hours \-  days) 

• Provide schools with detailed incident report. 

• Assist schools in determining notification obligations under state laws. • Provide template notification letters for schools to use. 

. Conclusion and Next Steps 

PLC Coach has a clear and robust pathway to FERPA compliance by implementing the strategies outlined in this report. The combination of a strong DPA, strict RBAC, a privacy preserving RAG architecture, and clear data handling policies provides a strong foundation for building a trusted and effective platform for teacher collaboration. 

Immediate Next Steps 

. Legal Review: Share this report and the accompanying DPA with legal counsel for review. 

. Technical Implementation: Begin building the RBAC system, RAG architecture, and data retention automation based on these specifications. 

. Sign Student Privacy Pledge: Complete the free online pledge to demonstrate commitment to privacy before launch. 

. Onboarding Materials: Develop the parent notification letter and FERPA notice template language for schools.