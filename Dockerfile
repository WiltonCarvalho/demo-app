FROM alpine AS builder
WORKDIR workspace
RUN touch test.txt && cp test.txt /mnt

FROM scratch
COPY --from=builder /mnt ./
