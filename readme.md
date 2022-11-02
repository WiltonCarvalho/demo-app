### Windows
```
curl.exe -fsSL https://start.spring.io/starter.tgz -d dependencies=web,actuator,prometheus -d javaVersion=11 -d packageName=com.example -d groupId=com.example -d artifactId=demo-app -d baseDir=demo-app -d type=gradle-project -o demo-app.tar.gz
tar -zxvf demo-app.tar.gz
del demo-app.tar.gz
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
cat <<'EOF'> src/main/java/com/example/Hello.java
package com.example;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class Hello {
	@GetMapping("/")
	public String index() {
		return "Hello from Spring Boot!";
	}
}
EOF
```
```
podman run -it --rm --name builder \
  -v $PWD:/workspace \
  -w /workspace \
  -v /tmp:/tmp \
  -e GRADLE_USER_HOME=/tmp/build_cache/gradle \
  public.ecr.aws/docker/library/openjdk:11-jdk \
  sh -c './gradlew build --project-cache-dir /tmp/build_cache/gradle'
```
```
cat <<'EOF'> Dockerfile
FROM public.ecr.aws/docker/library/openjdk:11-jdk AS builder
WORKDIR workspace
ARG JAR_FILE=build/libs/*.jar
#ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
RUN java -Djarmode=layertools -jar app.jar extract

FROM gcr.io/distroless/java:11
#FROM public.ecr.aws/docker/library/openjdk:11-jre
USER 999:0
WORKDIR workspace
COPY --from=builder workspace/dependencies/ ./
COPY --from=builder workspace/spring-boot-loader/ ./
COPY --from=builder workspace/snapshot-dependencies/ ./
COPY --from=builder workspace/application/ ./
ENTRYPOINT ["/usr/bin/java", "org.springframework.boot.loader.JarLauncher"]
EOF
```
```
podman build -t app . --timestamp=0

podman run -it --rm -p 8080:8080 app

curl -fsSL http://localhost:8080
curl -fsSL http://localhost:8080/actuator/health | jq .

podman push app docker-archive:app.tar

skopeo inspect docker-archive:app.tar | jq
```
