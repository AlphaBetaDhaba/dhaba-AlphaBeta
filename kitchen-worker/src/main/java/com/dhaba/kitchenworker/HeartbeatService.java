package com.dhaba.kitchenworker;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.logging.Logger;

@Component
public class HeartbeatService {

    private static final Logger log = Logger.getLogger(HeartbeatService.class.getName());

    private final StringRedisTemplate redisTemplate;

    public HeartbeatService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Scheduled(fixedDelay = 10000)
    public void writeHeartbeat() {
        redisTemplate.opsForValue().set(
            "kitchen:heartbeat",
            Instant.now().toString(),
            Duration.ofSeconds(30)
        );
        log.info("Heartbeat written");
    }
}
