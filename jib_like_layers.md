```
cat <<'EOF'>> build.gradle
// prepare the runtime dependencies
task copyRuntimeDependencies(type: Copy) {
    from configurations.runtimeClasspath
    into 'build/dependency'
}
build.dependsOn copyRuntimeDependencies
EOF
```
```
cat <<'EOF'> Dockerfile
FROM gcr.io/distroless/java:11
#FROM public.ecr.aws/docker/library/openjdk:11-jre
USER 999:0
WORKDIR app
COPY build/bootJarMainClassName ./main-class-file
COPY build/dependency ./libs
COPY build/resources/main ./resources
COPY build/classes/java/main ./classes
ENTRYPOINT ["/usr/bin/java", "-cp", "/app/resources:/app/classes:/app/libs/*", "@main-class-file"]
EOF
```
```
