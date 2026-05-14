# Reproducible build
#
#   docker build -t notebooklm-cl .
#   docker run --rm -v ./out:/out notebooklm-cl
#   file out/notebooklm

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    sbcl libssl-dev curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sOL https://beta.quicklisp.org/quicklisp.lisp \
    && sbcl --non-interactive --load quicklisp.lisp \
       --eval '(quicklisp-quickstart:install)' --eval '(quit)' \
    && rm quicklisp.lisp

WORKDIR /src
COPY . .

RUN ln -s /src ~/quicklisp/local-projects/notebooklm-cl \
    && sbcl --non-interactive \
       --eval '(ql:quickload :notebooklm-cl)' \
       --eval '(sb-ext:save-lisp-and-die "/out/notebooklm" :executable t :compression t :toplevel (quote notebooklm-cl.cli:main) :purify t)'
