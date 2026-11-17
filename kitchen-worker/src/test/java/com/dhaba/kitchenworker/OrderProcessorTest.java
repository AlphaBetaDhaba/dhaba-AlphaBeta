package com.dhaba.kitchenworker;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.ListOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.Duration;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderProcessorTest {

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private JdbcTemplate jdbcTemplate;

    @Mock
    private ListOperations<String, String> listOperations;

    @InjectMocks
    private OrderProcessor orderProcessor;

    @Test
    void whenBlpopReturnsNull_noDbUpdateIsMade() {
        when(redisTemplate.opsForList()).thenReturn(listOperations);
        when(listOperations.leftPop(anyString(), any(Duration.class))).thenReturn(null);

        orderProcessor.processNextOrder();

        verify(jdbcTemplate, never()).update(anyString(), (Object[]) any());
    }
}
