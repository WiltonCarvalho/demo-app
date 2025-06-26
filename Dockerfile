# syntax=docker/dockerfile:1.4
# MySQL & Redis
# docker run -it --rm --name mysql -e MYSQL_DATABASE=test -e MYSQL_ROOT_PASSWORD=test -p 3306:3306 mysql:lts
# docker run -it --rm --name redis -p 6379:6379 redis:7-alpine

# Build
# docker build -t demo-app . --progress=plain

# Run Demo App
# docker run -it --rm --name demo-app  -p 8080:8080 -p 8081:8081 -e "cors.allowedOrigins=https://cors.allowed1.com,https://cors.allowed2.com" demo-app
# curl -s localhost:8080
# curl -s localhost:8081/actuator/health | jq .
# curl -s localhost:8081/actuator/prometheus

# CORS
# curl -H 'Origin: https://cors.allowed1.com' -i -f http://localhost:8080
# curl -H 'Origin: https://cors.allowed2.com' -i -f http://localhost:8080
# curl -H 'Origin: https://cors.denied.com' -i -f http://localhost:8080 -v
FROM alpine/curl AS start
WORKDIR /code
RUN set -ex \
  && curl -fsSL https://start.spring.io/starter.tgz \
  -d dependencies=web,actuator,prometheus,data-redis,data-jpa,mysql \
  -d packageName=com.example \
  -d groupId=com.example \
  -d artifactId=demo-app \
  -d baseDir=. \
  -d type=gradle-project | tar -xzvf -

COPY <<'EOF' src/main/java/com/example/Hello.java
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

COPY <<'EOF' src/main/java/com/example/WebConfig.java
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

COPY <<'EOF' src/main/resources/application.properties
server.port=8080
management.server.port=8081
management.endpoints.web.exposure.include=info,health,prometheus
spring.datasource.url=jdbc:mysql://172.17.0.1:3306/test
spring.datasource.username=root
spring.datasource.password=test
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
spring.data.redis.host=172.17.0.1
logging.level.org.springframework.web=DEBUG
EOF

FROM eclipse-temurin:17-jdk AS builder
WORKDIR /code
COPY --from=start /code .
ARG JAR_FILE=build/libs/*.jar
ARG GRADLE_USER_HOME=/tmp/build_cache/gradle
RUN --mount=type=cache,target=/tmp/build_cache/gradle \
    set -ex \
    && chmod +x gradlew \
    && ./gradlew build -i -x jar \
    && java -Djarmode=layertools -jar $JAR_FILE extract

FROM eclipse-temurin:17-jre
USER 999:0
WORKDIR /app
COPY --from=builder /code/dependencies/ ./
COPY --from=builder /code/spring-boot-loader/ ./
COPY --from=builder /code/snapshot-dependencies/ ./
COPY --from=builder /code/application/ ./
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
ENV spring_backgroundpreinitializer_ignore="true"
ENV TZ="America/Sao_Paulo"
ENV server_port="8080"
ENV management_server_port="8081"
ENV management_endpoints_enabledByDefault="false"
ENV management_endpoint_health_enabled="true"
ENV management_endpoint_info_enabled="true"
ENV management_endpoint_prometheus_enabled="true"
ENV management_endpoints_web_exposure_include="info,health,prometheus"
ENV management_endpoints_web_basePath="/actuator"
ENV management_endpoint_health_probes_enabled="true"
ENV management_endpoint_health_showDetails="always"
ENV management_endpoint_health_group_startup_include="livenessState,ping,diskSpace,redis,db"
ENV management_endpoint_health_group_liveness_include="livenessState,ping,diskSpace"
ENV management_endpoint_health_group_readiness_include="readinessState,ping,diskSpace,redis,db"
ENV management_health_defaults_enabled="false"
ENV management_health_ping_enabled="true"
ENV management_health_diskspace_enabled="true"
ENV management_health_redis_enabled="true"
ENV management_health_db_enabled="true"
ENV management_health_mail_enabled="false"
