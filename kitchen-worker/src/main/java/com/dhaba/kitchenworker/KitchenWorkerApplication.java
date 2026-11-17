package com.dhaba.kitchenworker;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class KitchenWorkerApplication {

    public static void main(String[] args) {
        SpringApplication.run(KitchenWorkerApplication.class, args);
    }
}
