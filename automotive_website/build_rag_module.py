# -*- coding: utf-8 -*-
"""
Build script: Converts the combined reference rag_ai.py into a working
single-file module by removing inter-module imports (since all classes
are already defined in the same file).

Run once: python build_rag_module.py
Produces: rag_module.py (importable single-file RAG engine)
"""

import re
import os

SOURCE = os.path.join(os.path.dirname(__file__), '..', 'AI_ASSISTANT', 'rag_ai.py')
OUTPUT = os.path.join(os.path.dirname(__file__), 'rag_module.py')

# These are the "module names" that exist as sections within the combined file.
# Imports from these should be removed since the classes are already in scope.
INTERNAL_MODULES = {
    'conversation_store',
    'firebase_source',
    'grounding_guard',
    'llm_service',
    'metrics_service',
    'nlp_query_parser',
    'conversational_responder',
    'prompt_guard',
    'rate_limiter',
    'report_service',
    'retrieval',
    'retrieval_access_control',
    'retrieval_metrics',
    'retrieval_ranker',
    'secure_context_builder',
    'security_logger',
    'rag',
    'query_classifier',
    'hybrid_retriever',
    'data_normalizer',
    'data_validator',
}

# Pattern to match: from <internal_module> import ...
IMPORT_PATTERN = re.compile(
    r'^from\s+(' + '|'.join(re.escape(m) for m in INTERNAL_MODULES) + r')\s+import\s+'
)

# Stop marker — we don't need the FastAPI api.py section
API_SECTION_MARKER = '# FILE: api.py'


def build():
    with open(SOURCE, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()

    output_lines = []
    skip_multiline_import = False
    in_api_section = False

    for i, line in enumerate(lines):
        # Stop including lines once we hit the api.py section
        if API_SECTION_MARKER in line:
            in_api_section = True
            break

        # If we're skipping a multi-line import, check for closing paren
        if skip_multiline_import:
            if ')' in line:
                skip_multiline_import = False
            continue

        # Remove inter-module imports (classes are already defined above)
        stripped = line.strip()
        if IMPORT_PATTERN.match(stripped):
            # Check if it's a multi-line import (has opening paren but no closing)
            if '(' in stripped and ')' not in stripped:
                skip_multiline_import = True
            continue

        output_lines.append(line)

    # Deduplicate `from __future__ import annotations`
    seen_future = False
    final_lines = []
    for line in output_lines:
        if 'from __future__ import annotations' in line:
            if seen_future:
                continue
            seen_future = True
        final_lines.append(line)

    # Write header + cleaned content
    header = '''# -*- coding: utf-8 -*-
# ============================================================================
# RAG AI MODULE — Auto-generated working single-file version
# ============================================================================
# Generated from AI_ASSISTANT/rag_ai.py by build_rag_module.py
# This file is importable and provides the EnhancedRag class directly.
#
# Usage:
#   from rag_module import EnhancedRag
#   rag = EnhancedRag()
#   result = rag.ask("What materials do we have?", session_id="abc", user_type="admin")
# ============================================================================

'''

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write(header)
        f.writelines(final_lines)

    print(f'✅ Built {OUTPUT}')
    print(f'   Source: {SOURCE}')
    print(f'   Lines: {len(final_lines)}')


if __name__ == '__main__':
    build()
