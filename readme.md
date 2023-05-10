### Windows
```
curl.exe -fsSL https://start.spring.io/starter.tgz -d dependencies=web,actuator,prometheus -d bootVersion=2.7.6 -d javaVersion=11 -d packageName=com.example -d groupId=com.example -d artifactId=demo-app -d baseDir=demo-app -d type=gradle-project -o demo-app.tar.gz
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

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@EnableWebMvc
public class WebConfig {
  @Value("${cors.allowedOrigins:*}")
  public String[] allowedOrigins;
  @Bean
  public WebMvcConfigurer corsConfigurer() {
    return new WebMvcConfigurer() {
      @Override
      public void addCorsMappings(CorsRegistry registry) {
        registry
            .addMapping("/**")
            .allowedMethods("HEAD", "OPTIONS", "GET", "POST")
            .allowedOrigins(allowedOrigins)
            .allowCredentials(false)
            .allowedHeaders(
                "X-Requested-With",
                "Origin",
                "Content-Type",
                "Accept",
                "Authorization",
                "Access-Control-Request-Method")
            .exposedHeaders(
                "Access-Control-Request-Headers",
                "Access-Control-Allow-Origin",
                "Access-Control-Allow-Headers")
            .maxAge(3600L);
      }
    };
  }
}
EOF
```
```
# Disable '*-plain.jar'
cat <<'EOF'>> build.gradle
jar {
  enabled = false
}
bootJar {
  enabled = true
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
cat <<'EOF'> Dockerfile
FROM public.ecr.aws/docker/library/openjdk:11-jdk AS builder
WORKDIR workspace
COPY . .
ARG JAR_FILE=build/libs/*.jar
RUN set -ex \
    && ./gradlew build -i \
    && java -Djarmode=layertools -jar $JAR_FILE extract

FROM gcr.io/distroless/java:11
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
curl -H 'Origin: https://cors.test.com' -I -f http://localhost:8080

podman push app docker-archive:app.tar

skopeo inspect docker-archive:app.tar | jq
```
