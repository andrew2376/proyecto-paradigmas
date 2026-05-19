package com.kepler.atlas.service;

import com.kepler.atlas.model.AtlasMessage;
import com.kepler.atlas.model.Transmission;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Service
public class AtlasService {

    private final PriorityService priorityService;

    private final ExecutorService executorService =
            Executors.newFixedThreadPool(10);

    public AtlasService(PriorityService priorityService) {

        this.priorityService = priorityService;

    }

    public AtlasMessage processTransmission(Transmission transmission) {

        executorService.submit(() -> {

            System.out.println(
                    "Procesando misión: "
                            + transmission.getMissionId()
            );

        });

        AtlasMessage atlasMessage = new AtlasMessage();

        atlasMessage.setTransmission(transmission);

        atlasMessage.setPriorityLevel(
                priorityService.classifyPriority(
                        transmission.getConfidence()
                )
        );

        atlasMessage.setAgencyId("NASA-ESA-2041");

        atlasMessage.setActiveMissions(140);

        List<String> traceability = new ArrayList<>();

        traceability.add("Voyager IX");

        traceability.add("HERMES");

        traceability.add("ATLAS");

        atlasMessage.setTraceability(traceability);

        return atlasMessage;

    }

}