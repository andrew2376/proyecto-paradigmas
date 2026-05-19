package com.kepler.atlas.service;

import org.springframework.stereotype.Service;

@Service
public class PriorityService {

    public String classifyPriority(double confidence) {

        if (confidence >= 0.95) {
            return "MAXIMUM";
        }

        if (confidence >= 0.80) {
            return "HIGH";
        }

        if (confidence >= 0.60) {
            return "MEDIUM";
        }

        return "LOW";

    }

}