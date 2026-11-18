package com.dhaba.kitchenworker;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.logging.Level;
import java.util.logging.Logger;

@Component
public class HeartbeatService {

    private static final Logger log = Logger.getLogger(HeartbeatService.class.getName());
    private static final Path LOCAL_HEARTBEAT_PATH = Path.of("/tmp/heartbeat");

    private final StringRedisTemplate redisTemplate;

    public HeartbeatService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Scheduled(fixedDelay = 10000)
    public void writeHeartbeat() {
        // 1. Update the local heartbeat file independently of Redis availability
        try {
            Files.writeString(LOCAL_HEARTBEAT_PATH, Instant.now().toString());
        } catch (IOException e) {
            log.log(Level.WARNING, "Failed to write local heartbeat file: " + e.getMessage(), e);
        }

        // 2. Update the shared Redis heartbeat key (kitchen:heartbeat with 30s TTL)
        try {
            redisTemplate.opsForValue().set(
                "kitchen:heartbeat",
                Instant.now().toString(),
                Duration.ofSeconds(30)
            );
            log.info("Heartbeat written");
        } catch (Exception e) {
            log.log(Level.WARNING, "Failed to write Redis heartbeat: " + e.getMessage(), e);
        }
    }
}
