#!/bin/bash
# Build notebooklm binary for macOS arm64
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="${OUTPUT:-$SCRIPT_DIR/notebooklm}"

echo "🔨 Building notebooklm for macOS arm64..."
echo "   Output: $OUTPUT"

cd "$SCRIPT_DIR"

sbcl --non-interactive \
     --eval '(progn (load "notebooklm-cl.asd") (asdf:load-system :notebooklm-cl))' \
     --eval '(format t "~&System loaded. Compressing binary...~%")' \
     --eval "(sb-ext:save-lisp-and-die \"$OUTPUT\"
               :executable t
               :compression t
               :toplevel #'notebooklm-cl.cli:main
               :purify t)" \
     --eval '(format t "~&✅ Binary ready: $OUTPUT~%")'

echo ""
echo "Done. Binary at: $OUTPUT"
ls -lh "$OUTPUT"
echo ""
echo "Try: ./notebooklm --help"
