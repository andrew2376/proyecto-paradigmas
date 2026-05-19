package com.kepler.atlas.model;

import java.util.List;

public class AtlasMessage {

    private Transmission transmission;

    private String priorityLevel;

    private String agencyId;

    private int activeMissions;

    private List<String> traceability;

    public AtlasMessage() {
    }

    public Transmission getTransmission() {
        return transmission;
    }

    public void setTransmission(Transmission transmission) {
        this.transmission = transmission;
    }

    public String getPriorityLevel() {
        return priorityLevel;
    }

    public void setPriorityLevel(String priorityLevel) {
        this.priorityLevel = priorityLevel;
    }

    public String getAgencyId() {
        return agencyId;
    }

    public void setAgencyId(String agencyId) {
        this.agencyId = agencyId;
    }

    public int getActiveMissions() {
        return activeMissions;
    }

    public void setActiveMissions(int activeMissions) {
        this.activeMissions = activeMissions;
    }

    public List<String> getTraceability() {
        return traceability;
    }

    public void setTraceability(List<String> traceability) {
        this.traceability = traceability;
    }

}