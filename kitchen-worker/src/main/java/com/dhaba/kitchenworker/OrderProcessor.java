package com.dhaba.kitchenworker;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.logging.Logger;

@Component
public class OrderProcessor {

    private static final Logger log = Logger.getLogger(OrderProcessor.class.getName());

    private final StringRedisTemplate redisTemplate;
    private final JdbcTemplate jdbcTemplate;

    public OrderProcessor(StringRedisTemplate redisTemplate, JdbcTemplate jdbcTemplate) {
        this.redisTemplate = redisTemplate;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Scheduled(fixedDelay = 2000)
    public void processNextOrder() {
        String value = redisTemplate.opsForList().leftPop("orders:pending", Duration.ofSeconds(1));
        if (value == null) {
            return;
        }

        String id = value.trim();
        log.info("Processing order " + id);

        try {
            // Simulate cooking start
            Thread.sleep(2000);
            jdbcTemplate.update(
                "UPDATE orders SET status='cooking', updated_at=NOW() WHERE id=?",
                id
            );

            // Simulate cooking completion
            Thread.sleep(3000);
            jdbcTemplate.update(
                "UPDATE orders SET status='ready', updated_at=NOW() WHERE id=?",
                id
            );

            log.info("Order " + id + " is ready");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.warning("Order processing interrupted for order " + id);
        }
    }
}
