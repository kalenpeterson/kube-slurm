FROM alpine

RUN apk add bash

RUN mkdir /workspace && \
    chmod 755 /workspace

RUN mkdir /app && \
    chmod 755 /app

ADD run.sh /app/run.sh

RUN chmod +x /app/run.sh

ENTRYPOINT ["/app/run.sh"]
