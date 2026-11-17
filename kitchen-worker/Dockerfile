FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B clean package -DskipTests

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
RUN useradd --system --create-home --uid 10001 appuser
COPY --from=builder --chown=appuser:appuser\
    /app/target*.jar app.jar
USER appuser
ENTRYPOINT ["java", "-jar", "app.jar"]