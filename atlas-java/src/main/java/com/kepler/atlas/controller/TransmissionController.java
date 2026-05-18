package com.kepler.atlas.controller;

import com.kepler.atlas.model.AtlasMessage;
import com.kepler.atlas.model.Transmission;
import com.kepler.atlas.service.AtlasService;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/atlas")
public class TransmissionController {

    private final AtlasService atlasService;

    public TransmissionController(AtlasService atlasService) {

        this.atlasService = atlasService;

    }

    @GetMapping("/")
    public String home() {

        return "ATLAS ONLINE";

    }

    @PostMapping("/transmission")
    public AtlasMessage receiveTransmission(
            @RequestBody Transmission transmission
    ) {

        return atlasService.processTransmission(transmission);

    }

}