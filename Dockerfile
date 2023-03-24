FROM public.ecr.aws/amazoncorretto/amazoncorretto:11 AS builder
WORKDIR workspace
COPY . .
RUN ./gradlew build && cp build/libs/*.jar /mnt

FROM scratch
COPY --from=builder /mnt ./
