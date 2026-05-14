# notebooklm-cl

Common Lisp client for Google NotebookLM RPC API. Port of [notebooklm-py](https://github.com/notebooklm/notebooklm-py).

## Install

Requires SBCL 2.6+. Builds a standalone arm64 macOS binary:

```bash
./build.sh
# -> notebooklm (14MB)
```

## Quick start

Get credentials from Chrome DevTools (Network tab -> any `batchexecute` request -> Copy as cURL (bash)), then:

```bash
pbpaste | ./notebooklm login --curl
./notebooklm notebooks
./notebooklm artifacts <notebook-id>
./notebooklm generate audio <notebook-id>
./notebooklm wait <notebook-id> <task-id>
./notebooklm download audio <notebook-id> output.wav
```

Credentials stored at `~/.notebooklm-cl/auth.json`.

## Commands

```
notebooks          List notebooks
create-notebook    Create notebook by title
sources            List sources in a notebook
artifacts          List artifacts [--type audio|report|quiz|...]
generate           Generate artifact (audio|report|quiz|flashcards|video|...)
download           Download artifact to file
wait               Wait for generation to complete
suggest            Get suggested reports
add-url            Add URL source to notebook
delete-artifact    Delete an artifact
delete-source      Delete a source
metadata           Notebook metadata [--json]
whoami             Show login status
```

## Library use

```lisp
(asdf:load-system :notebooklm-cl)

(let ((c (notebooklm-cl.core:make-client-core
          :auth (notebooklm-cl.core:make-auth-tokens
                 :csrf-token "..." :session-id "..."))))
  (notebooklm-cl.core:open-client c)
  (notebooklm-cl.notebooks:list-notebooks c)
  (notebooklm-cl.core:close-client c))
```

## Test

```bash
sbcl --eval '(progn (load "notebooklm-cl.asd") (asdf:test-system :notebooklm-cl))' --quit
```
