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
  -d bootVersion=2.7.6 \
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
# Hello
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
# CORS
cat <<'EOF'> src/main/java/com/example/WebConfig.java
package com.example;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.beans.factory.annotation.Value;

@Configuration
@EnableWebMvc
public class WebConfig implements WebMvcConfigurer {
    @Value("${cors.allowedOrigin:*}")
    private String corsAllowedOrigin;
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**").allowedOrigins(corsAllowedOrigin);
    }
}
EOF
```
```
# Build Info
cat <<'EOF'>> build.gradle
def buildTime() {
  final dateFormat = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ssZ")
  dateFormat.timeZone = TimeZone.getTimeZone('America/Sao_Paulo')
  dateFormat.format(new Date())
}
def gitAuthor = 'git show -q --format=%an'.execute().text.trim()
def gitCommitHash = 'git rev-parse --verify --short HEAD'.execute().text.trim()
springBoot {
  buildInfo {
    properties {
      name = null
      group = null
      time = null
      additional = [
        'author': gitAuthor,
        'revision': gitCommitHash,
        'buildTime': buildTime()
      ]
    }
  }
}
EOF
```
```
cat <<'EOF'> src/main/resources/application.properties
server.port=8080
management.endpoints.web.exposure.include=info,health,prometheus
EOF
```
```
# Json Logs
// implementation 'ch.qos.logback:logback-classic:1.2.6'
// implementation 'ch.qos.logback.contrib:logback-json-classic:0.1.5'
// implementation 'ch.qos.logback.contrib:logback-jackson:0.1.5'
// implementation 'com.fasterxml.jackson.core:jackson-core:2.12.0'
// implementation 'com.fasterxml.jackson.core:jackson-databind:2.12.0'
// implementation 'org.slf4j:slf4j-api:1.7.25'

cat <<'EOF'> src/main/resources/logback.xml
<configuration>
    <appender name="stdout" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%date [%thread] %-5level %logger - %msg%n</pattern>
        </encoder>
        <encoder class="ch.qos.logback.core.encoder.LayoutWrappingEncoder">
            <layout class="ch.qos.logback.contrib.json.classic.JsonLayout">
                <timestampFormat>yyyy-MM-dd'T'HH:mm:ss.SSSX</timestampFormat>
                <timestampFormatTimezoneId>Etc/UTC</timestampFormatTimezoneId>
                <jsonFormatter class="ch.qos.logback.contrib.jackson.JacksonJsonFormatter"/>
                <appendLineSeparator>true</appendLineSeparator>
            </layout>
        </encoder>
    </appender>
    <root level="info">
        <appender-ref ref="stdout"/>
    </root>
</configuration>
EOF
```
```
podman run -it --rm --name builder \
  -v $PWD:/workspace \
  -w /workspace \
  -v /tmp:/tmp \
  -e GRADLE_USER_HOME=/tmp/build_cache/gradle \
  public.ecr.aws/docker/library/openjdk:11-jdk \
  sh -c './gradlew build'
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
