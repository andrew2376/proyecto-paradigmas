package com.kepler.atlas.model;

public class Transmission {

    private String missionId;

    private String coordinates;

    private String spectralData;

    private double confidence;

    private String timestamp;

    private String ruleChain;

    private String satelliteId;

    private String hash;

    public Transmission() {
    }

    public String getMissionId() {
        return missionId;
    }

    public void setMissionId(String missionId) {
        this.missionId = missionId;
    }

    public String getCoordinates() {
        return coordinates;
    }

    public void setCoordinates(String coordinates) {
        this.coordinates = coordinates;
    }

    public String getSpectralData() {
        return spectralData;
    }

    public void setSpectralData(String spectralData) {
        this.spectralData = spectralData;
    }

    public double getConfidence() {
        return confidence;
    }

    public void setConfidence(double confidence) {
        this.confidence = confidence;
    }

    public String getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }

    public String getRuleChain() {
        return ruleChain;
    }

    public void setRuleChain(String ruleChain) {
        this.ruleChain = ruleChain;
    }

    public String getSatelliteId() {
        return satelliteId;
    }

    public void setSatelliteId(String satelliteId) {
        this.satelliteId = satelliteId;
    }

    public String getHash() {
        return hash;
    }

    public void setHash(String hash) {
        this.hash = hash;
    }

}