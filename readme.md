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
  -d packageName=com.example \
  -d groupId=com.example \
  -d artifactId=demo-app \
  -d baseDir=demo-app \
  -d type=gradle-project | tar -xzvf -
```
```
# Hello
cat <<'EOF'> demo-app/src/main/java/com/example/Hello.java
package com.example;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class Hello {
	@GetMapping("/")
	public String index() {
		return "Hello from Spring Boot!\n";
	}
}
EOF
```
```
# CORS
cat <<'EOF'> demo-app/src/main/java/com/example/WebConfig.java
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
# Health check and Prometheus metrics via management port
cat <<'EOF'>> demo-app/src/main/resources/application.properties
server.port=8080
management.server.port=8081
management.endpoints.web.exposure.include=info,health,prometheus
EOF
```
```
# Docker staged build with Spring Boot layers
cat <<'EOF'> demo-app/Dockerfile
FROM eclipse-temurin:17-jdk AS builder
WORKDIR workspace
COPY . .
ARG JAR_FILE=build/libs/*.jar
ARG GRADLE_USER_HOME=/tmp/build_cache/gradle
RUN --mount=type=cache,target=/tmp/build_cache/gradle \
    set -ex \
    && chmod +x gradlew \
    && ./gradlew build -i -x jar \
    && java -Djarmode=layertools -jar $JAR_FILE extract
FROM eclipse-temurin:17-jre
USER 999:0
WORKDIR workspace
COPY --from=builder workspace/dependencies/ ./
COPY --from=builder workspace/spring-boot-loader/ ./
COPY --from=builder workspace/snapshot-dependencies/ ./
COPY --from=builder workspace/application/ ./
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
EOF
```
```
# Build
docker build -t demo-app demo-app --progress=plain

# Run Demo App
docker run -it --rm -p 8080:8080 -p 8081:8081 demo-app

curl -s localhost:8080

curl -s localhost:8081/actuator/health | jq .
curl -s localhost:8081/actuator/prometheus
```
```
# Run Demo App with CORS
docker run -it --rm -e "cors.allowedOrigins=https://cors.allowed1.com,https://cors.allowed2.com" \
  -p 8080:8080 -p 8081:8081 demo-app

curl -H 'Origin: https://cors.allowed1.com' -i -f http://localhost:8080
curl -H 'Origin: https://cors.allowed2.com' -i -f http://localhost:8080
curl -H 'Origin: https://cors.denied.com' -i -f http://localhost:8080 -v
```
```
```
```
```
```
# TODO Build Info
cat <<'EOF'>> demo-app/build.gradle
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
# TODO Json Logs
// implementation 'ch.qos.logback:logback-classic:1.2.6'
// implementation 'ch.qos.logback.contrib:logback-json-classic:0.1.5'
// implementation 'ch.qos.logback.contrib:logback-jackson:0.1.5'
// implementation 'com.fasterxml.jackson.core:jackson-core:2.12.0'
// implementation 'com.fasterxml.jackson.core:jackson-databind:2.12.0'
// implementation 'org.slf4j:slf4j-api:1.7.25'

cat <<'EOF'> demo-app/src/main/resources/logback.xml
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