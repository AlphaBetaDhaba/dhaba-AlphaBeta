FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /app

COPY pom.xml .
RUN mvn dependency:go-offline

COPY src ./src

RUN mvn -B clean package -DskipTests



FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

RUN useradd --create-home appuser

COPY --from=builder \
    /app/target/kitchen-worker-0.0.1-SNAPSHOT.jar \
    /app/app.jar

RUN chown appuser:appuser /app/app.jar

USER appuser

CMD ["java", "-jar", "/app/app.jar"]
