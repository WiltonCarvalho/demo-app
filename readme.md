### Windows
```
curl.exe -fsSL https://start.spring.io/starter.tgz -d dependencies=web,actuator,prometheus -d javaVersion=11 -d packageName=com.example -d groupId=com.example -d artifactId=demo-app -d baseDir=demo-app -d type=gradle-project -o demo-app.tar.gz
tar -zxvf demo-app.tar.gz
```

### Linux
```
curl -fsSL https://start.spring.io/starter.tgz \
  -d dependencies=web,actuator,prometheus \
  -d javaVersion=11 \
  -d packageName=com.example \
  -d groupId=com.example \
  -d artifactId=demo-app \
  -d baseDir=demo-app \
  -d type=gradle-project | tar -xzvf -
```
```
cd demo-app
```
```
cat <<'EOF'> Dockerfile
FROM docker.io/library/openjdk:11-jdk AS builder
WORKDIR /code
COPY . .
RUN set -ex \
    && dpkg --print-architecture \
    && ./gradlew build -i

FROM docker.io/library/openjdk:11-jre AS final
WORKDIR /app
COPY --from=builder /code/build/libs/*.jar app.jar
USER 1000:0
ENTRYPOINT [ "java", "-jar", "app.jar" ]
EOF
```
```
podman build -t app .

podman run -it --rm -p 8080:8080 app

curl -fsSL http://localhost:8080/actuator/health | jq .
```
