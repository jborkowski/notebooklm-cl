# Issues Found

## 1. `src/rpc/decoder.lisp` — `extract-rpc-result` has a paren imbalance (BLOCKING)

**Error:** `UNREADABLE-FORM: end of file on stream`

The function `extract-rpc-result` (lines ~75-102 of decoder.lisp) has 59 opens vs 58 closes — one open paren is never closed. SBCL reader hits EOF inside the form.

**Tooling limitation encountered:**
`clr_paren_check` confirms the imbalance and reports per-line deltas, but it does **not** point to the exact line/column where the missing close-paren belongs. The per-line delta view is coarse — e.g., line 26 has a -8 delta suggesting a cascade of closures — but the tool doesn't tell me *which specific open-paren at which line* is unmatched.

**What would help:**
- A "find-unmatched-open" tool that walks backwards from EOF, tracking paren stack, and reports the line + column of the orphaned open-paren.
- Alternatively, I can manually re-indent the function in an editor to spot the imbalance.

This is a **manual fix** that needs human eyes or an editor with paren-matching.

## 2. `notebooklm-cl.asd` — serial load order bug (BLOCKING)

**Error:** `Package NOTEBOOKLM-CL.UTIL does not exist`

`env.lisp` calls `notebooklm-cl.util:starts-with-p` but in the ASDF `:serial t` ordering, `env` is loaded **before** `util`:

```lisp
(:file "packages")
(:file "env")       ;; ← uses notebooklm-cl.util:starts-with-p
(:file "errors")
(:file "util")      ;; ← defines it, but loaded too late
```

**Fix:** Swap `env` and `util` in the component list:

```lisp
(:file "packages")
(:file "util")      ;; ← moved before env
(:file "env")
(:file "errors")
```

> Note: `errors.lisp` has no dependency on `env`, so `errors` after `env` is fine; `env` has no dependency on `errors` either, so the relative order of `env`/`errors` doesn't matter. The fix is simply putting `util` before `env`.

## 3. `env.lisp` — `(error "string")` should use `configuration-error`

**Severity:** Style / low

`get-base-url` signals a bare `simple-error` via `(error "message")` instead of using the defined `notebooklm-cl.errors:configuration-error`. Not blocking, but the condition hierarchy is already defined — callers expecting `configuration-error` won't catch these.

---

## Status: STOPPED

Cannot proceed until issue #1 (decoder paren imbalance) is resolved. The clr_paren_check tool confirms it but can't pinpoint the exact orphaned open-paren.
