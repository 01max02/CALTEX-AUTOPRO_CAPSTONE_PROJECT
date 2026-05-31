# RAG-Based AI Assistant — System Architecture

## Overview

This document describes the system architecture of the Firestore-integrated RAG (Retrieval-Augmented Generation) AI Assistant implemented in this repository.

The system is designed to assist both customers and administrators by providing:
- contextual information retrieval
- operational assistance
- workflow guidance
- maintenance and inventory inquiries
- quick access to business records
- AI-generated responses grounded on real-time Firestore data

Unlike traditional chatbots with static responses, this system retrieves live operational data from Firebase Firestore and uses semantic retrieval techniques to generate accurate and context-aware responses.

---

# System Architecture Overview

```text
                Users
        (Customer / Admin)
                     ↓
               Frontend UI
                     ↓
                FastAPI API
                     ↓
          Conversation Manager
                     ↓
         Query Understanding Layer
                     ↓
        ┌──────────────────────┐
        │      Retriever       │
        └──────────────────────┘
              ↓          ↓
     Structured Retrieval   Semantic Retrieval
         (Firestore)         (Embeddings)
              ↓                    ↓
        Operational Data     Similarity Search
              ↓                    ↓
         Context Construction Layer
                     ↓
               Prompt Builder
                     ↓
                 LLM Service
                     ↓
         Validation & Post-processing
                     ↓
              Final AI Response

Core Architecture Components
1. User Layer
Description

Represents the end users interacting with the system.

User Types
Customers
Administrators
Staff Personnel
Responsibilities
Submit natural language queries
Receive AI-generated responses
Access operational information
Example Queries
"Show low stock brake materials"
"How do I process PMS scheduling?"
"What is the maintenance history of vehicle ABC123?"
"How do I create a service record?"
2. Frontend UI Layer
Description

Provides the user interface for interacting with the AI assistant.

Technologies
HTML
JavaScript
REST API Integration
Responsibilities
Chat interface
Message rendering
Request submission
Response display
Relevant Files
index.html
3. API Layer
Description

Acts as the communication bridge between the frontend and backend services.

Technologies
FastAPI
Uvicorn
Responsibilities
Accept user requests
Route API calls
Validate request payloads
Return AI responses
Relevant Files
api.py
main.py
4. Conversation Manager
Description

Maintains conversation context and chat history.

Responsibilities
Store session context
Track conversation flow
Preserve previous interactions
Manage response formatting
Relevant Files
conversational_responder.py
conversation_store.py
5. Query Understanding Layer
Description

Analyzes the user's query to determine intent, domain, and retrieval strategy.

Responsibilities
Intent recognition
Query preprocessing
Domain routing
Keyword extraction
NLP-based understanding
Example
User Query	Domain
"show inventory"	Inventory
"how to process PMS"	Workflow
"vehicle maintenance history"	Maintenance
Possible Techniques
NLP preprocessing
Tokenization
Query normalization
6. Retriever Layer
Description

Core retrieval engine of the RAG architecture.

The retriever searches relevant operational data from Firestore and performs semantic similarity matching using embeddings.

This layer is responsible for transforming user queries into relevant contextual information before generation.

Retrieval Types
A. Structured Retrieval

Used for:

inventory lookup
maintenance records
schedules
transactions
customer information
Source
Firebase Firestore
Example
User Query:
"show low stock brake pads"

Firestore Retrieval:
Inventory Collection → Brake Pads → Stock < 5
B. Semantic Retrieval

Used for:

workflow guidance
operational procedures
FAQs
natural language questions
Process
Convert records into embeddings
Compare semantic similarity
Retrieve top-k relevant contexts
Example
User Query:
"how do I create PMS schedule?"

Retrieved Context:
PMS workflow records and operational procedures
Relevant Files
retrieval.py
rag.py
firebase_source.py
7. Firebase Firestore Knowledge Source
Description

Acts as the centralized operational knowledge repository of the system.

Firestore stores real-time structured business data used by the AI assistant.

Stored Data Examples
Operational Data
inventory records
maintenance records
service history
schedules
transactions
Business Information
customer records
vehicle records
service requests
Workflow Information
operational procedures
service process flows
FAQs
Responsibilities
Real-time data storage
Operational data retrieval
Centralized knowledge management
8. Embedding & Semantic Search Layer
Description

Transforms Firestore records into vector embeddings for semantic retrieval.

This enables the system to understand contextual meaning instead of relying only on exact keyword matching.

Responsibilities
Data chunking
Embedding generation
Similarity search
Context ranking
Possible Technologies
SentenceTransformers
FAISS
Vector Indexing
Example Context Chunk
[Inventory Record]
Item: Bosch Brake Pad
Category: Brake System
Stock: 3

[Maintenance Record]
Vehicle: Toyota Vios ABC123
Service: Oil Change
Status: Completed
9. Context Construction Layer
Description

Converts retrieved Firestore data into AI-readable contextual prompts.

This layer prepares structured context for the language model.

Responsibilities
Context formatting
Prompt-ready conversion
Data summarization
Context filtering
10. Prompt Builder
Description

Combines:

user query
retrieved context
system instructions

into a structured prompt for the language model.

Responsibilities
Prompt templating
Grounding instructions
Response constraints
Context injection
11. LLM Service Layer
Description

Generates natural language responses using retrieved operational context.

The model does not rely solely on pretrained knowledge.

Instead, it uses retrieved Firestore context to generate grounded and domain-specific responses.

Responsibilities
AI response generation
Natural language formatting
Context-aware answering
Relevant Files
llm_service.py
12. Validation & Post-processing Layer
Description

Ensures response quality and reliability before sending the final response.

Responsibilities
Validate generated responses
Reduce hallucinations
Confidence scoring
Response cleanup
Output formatting
Relevant Files
data_validator.py
report_service.py
High-Level Data Flow
Step-by-Step Workflow
1. User submits query

Example:

"Show all low stock brake materials"
2. API receives request

Handled by:

api.py
main.py
3. Query Understanding Layer processes intent

Determines:

inventory-related query
required retrieval strategy
4. Retriever searches Firestore
structured query filtering
semantic similarity matching
5. Relevant context is extracted

Example:

Bosch Brake Pad — Stock: 3
Bendix Brake Shoe — Stock: 2
6. Prompt Builder assembles prompt

Combines:

user query
retrieved operational data
7. LLM generates grounded response

Example:

The following brake materials are currently low in stock:
- Bosch Brake Pad (3 remaining)
- Bendix Brake Shoe (2 remaining)
8. Validation layer checks response
formatting
completeness
hallucination reduction
9. Final AI response returned to user
Why the System Uses RAG
Traditional Chatbot Limitations

Traditional chatbots:

rely on static responses
cannot access live operational data
lack contextual retrieval
are prone to outdated answers
Advantages of RAG

The system uses Retrieval-Augmented Generation because:

responses are grounded on live Firestore data
operational information is dynamically retrieved
semantic similarity improves contextual understanding
AI responses become more accurate and domain-aware
System Classification

The system may be classified as:

RAG-Based AI Assistant
Firestore-Integrated Knowledge Assistant
AI-Powered Information Retrieval System
Operational Support Assistant
Context-Aware Service Assistant
Security & Compliance
Input Validation
sanitize user inputs
validate request payloads
Access Control
authentication and authorization (Bearer token)
role-based retrieval authorization (customer/staff/admin)
collection-level access policies
field-level sensitivity filtering
secure context construction before LLM prompt assembly
Prompt Injection Defense
regex-based pattern detection (26 patterns, 6 categories)
threat level assessment (NONE/LOW/MEDIUM/HIGH/CRITICAL)
blocks instruction override, data exfiltration, role escalation
blocks system prompt leak, retrieval manipulation, encoding bypass
executes BEFORE retrieval and prompt assembly
generic blocked response (no attack details leaked)
Grounding Enforcement
evidence sufficiency validation before LLM generation
minimum chunk count, confidence, and score thresholds
domain-specific fallback messages when evidence insufficient
prevents hallucinated operational claims
Rate Limiting
token-bucket algorithm with role-aware limits
customer: 15 req/min, staff: 40 req/min, admin: 80 req/min
IP-based limiting (60 req/min)
burst protection
HTTP 429 with Retry-After header
Data Protection
secure Firebase credentials
prevent unauthorized data access
secure API communication
sensitive fields stripped before prompt assembly
no internal IDs exposed in citations or responses
Structured Security Logging
audit-safe event logging (no query text, no PII)
event types: access_denied, prompt_injection, rate_limit, grounding_failure
severity classification (INFO/WARNING/HIGH/CRITICAL)
bounded in-memory buffer for /metrics exposure
Production Observability
GET /metrics endpoint with full pipeline telemetry
query counts by role and intent
latency tracking (avg, p95)
retrieval confidence monitoring
security event counters
vector index health
Firebase cache status
active session count
Deployment Considerations
Environment
Python virtual environment
requirements.txt
Backend Runtime
FastAPI
Uvicorn
Database
Firebase Firestore
Scalability Recommendations
async retrieval pipelines
managed vector database (Pinecone/Vertex AI)
Redis-backed rate limiter for multi-instance
caching layer
production-grade structured logging
Observability & Monitoring
Logging

Track:

API requests
retrieval operations
LLM calls
errors
security events (structured JSON)
prompt injection attempts
rate limit violations
grounding failures
Metrics

Monitor:

response latency (avg, p95)
retrieval accuracy and confidence
token usage
error rates
injection block rate
clarification rate
access denial rate
grounding block rate
Future Improvements
Planned Enhancements
advanced semantic ranking
hybrid retrieval optimization
multilingual support
workflow recommendation engine
feedback-based response improvement
Redis-backed distributed rate limiting
ML-based prompt injection detection
response grounding verification (post-generation)
Relevant Repository Files
File	Responsibility
api.py	API endpoints, rate limiting, /metrics
main.py	Application entry point
rag.py	RAG orchestration with prompt guard + grounding
retrieval.py	Retrieval logic
hybrid_retriever.py	Hybrid retrieval with access control
retrieval_access_control.py	Role-based retrieval authorization
secure_context_builder.py	Field filtering, text sanitization
prompt_guard.py	Prompt injection detection & defense
grounding_guard.py	Evidence sufficiency enforcement
rate_limiter.py	Token-bucket rate limiting
metrics_service.py	Production observability metrics
security_logger.py	Structured security event logging
firebase_source.py	Firestore integration
llm_service.py	LLM interaction
conversational_responder.py	Conversation handling
conversation_store.py	Chat history storage
data_validator.py	Validation layer
report_service.py	Reporting/post-processing
retrieval_ranker.py	Scoring, deduplication, confidence
retrieval_metrics.py	Retrieval monitoring primitives
query_classifier.py	Query routing and strategy selection
nlp_query_parser.py	Intent detection, entity extraction
Conclusion

The system implements a Firestore-integrated RAG architecture that combines structured operational retrieval, semantic similarity search, and AI-generated responses to provide accurate, contextual, and real-time assistance for customers and administrators.

By integrating Firebase Firestore as the operational knowledge source, the system enables grounded AI responses while maintaining flexibility, scalability, and contextual awareness for enterprise operational support.