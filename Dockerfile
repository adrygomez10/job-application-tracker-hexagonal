FROM maven:3.9.12-eclipse-temurin-25 AS dependencies
WORKDIR /workspace
COPY pom.xml .
RUN mvn -B -ntp dependency:go-offline

FROM dependencies AS quality
COPY config config
COPY src src
ENTRYPOINT ["mvn", "-B", "-ntp", "-Dtest=ArchitectureTest", "-DskipITs=true", "-Djacoco.skip=true", "verify"]

FROM dependencies AS browser
RUN mvn -B -ntp org.codehaus.mojo:exec-maven-plugin:3.6.3:java -Dexec.mainClass=com.microsoft.playwright.CLI -Dexec.classpathScope=test -Dexec.args="install --with-deps chromium"
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

FROM browser AS tests
COPY config config
COPY src src
ENTRYPOINT ["mvn", "-B", "-ntp", "verify"]

FROM dependencies AS build
COPY config config
COPY src src
RUN mvn -B -ntp verify -DskipTests -DskipITs=true

FROM eclipse-temurin:25-jre-noble AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/* && groupadd --system tracker && useradd --system --gid tracker tracker
WORKDIR /app
COPY --from=build /workspace/target/tracker.jar app.jar
USER tracker
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s CMD curl --fail --silent http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
