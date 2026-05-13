# Port notebooklm-py to Common Lisp iteratively.

notebooklm-py is ../notebooklm-py/

Focus only on:
- well-designed RPC
- notebook/workspace management
- generation flows
- artifact download
- delete/remove flows

Workflow must be:
collect requirements -> inspect Python module -> design CL module -> migrate -> validate -> move to next module

Migration order:
1. RPC foundation
2. notebook/workspace management
3. artifact flows
4. client façade

For each module output:
- REQUIREMENTS
- DESIGN
- IMPLEMENTATION PLAN
- CODE
- VALIDATION NOTES
- NEXT MODULE PROPOSAL

Constraints:
- real CL implementation
- SBCL + ASDF
- no Python wrapper
- preserve exact RPC payloads where required
- stub unclear behavior explicitly

Start with module 1 only.
