
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /app

# Copy Maven configuration first for better layer caching
COPY pom.xml .

# Resolve dependencies and refresh cached failures
RUN mvn -B -U dependency:go-offline

# Copy application source
COPY src ./src

# Build the application
RUN mvn -B -U clean package -DskipTests

FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

RUN useradd --create-home appuser

COPY --from=builder \
    /app/target/kitchen-worker-0.0.1-SNAPSHOT.jar \
    /app/app.jar

RUN chown appuser:appuser /app/app.jar

USER appuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
