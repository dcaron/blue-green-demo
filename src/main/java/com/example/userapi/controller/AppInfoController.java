package com.example.userapi.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.info.BuildProperties;
import org.springframework.boot.info.GitProperties;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * REST Controller for application information.
 */
@RestController
@RequestMapping("/info")
@Tag(name = "Application Info", description = "APIs for application metadata")
public class AppInfoController {

    private final Optional<GitProperties> gitProperties;
    private final Optional<BuildProperties> buildProperties;
    private final Instant startTime;

    @Autowired
    public AppInfoController(
            Optional<GitProperties> gitProperties,
            Optional<BuildProperties> buildProperties) {
        this.gitProperties = gitProperties;
        this.buildProperties = buildProperties;
        this.startTime = Instant.now();
    }

    /**
     * Retrieves application information including Git commit ID and uptime.
     *
     * @return ResponseEntity containing application metadata
     */
    @Operation(
        summary = "Get application info",
        description = "Retrieves application metadata including Git commit ID, uptime, and build information"
    )
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAppInfo() {
        Map<String, Object> info = new HashMap<>();

        // Git information
        if (gitProperties.isPresent()) {
            Map<String, String> git = new HashMap<>();
            git.put("commitId", gitProperties.get().getShortCommitId());
            git.put("commitIdFull", gitProperties.get().getCommitId());
            git.put("branch", gitProperties.get().getBranch());
            git.put("commitTime", gitProperties.get().getCommitTime().toString());
            git.put("commitMessage", gitProperties.get().get("commit.message.short"));
            info.put("git", git);
        }

        // Build information
        if (buildProperties.isPresent()) {
            Map<String, String> build = new HashMap<>();
            build.put("version", buildProperties.get().getVersion());
            build.put("name", buildProperties.get().getName());
            build.put("time", buildProperties.get().getTime().toString());
            info.put("build", build);
        }

        // Uptime information
        Duration uptime = Duration.between(startTime, Instant.now());
        Map<String, Object> uptimeInfo = new HashMap<>();
        uptimeInfo.put("seconds", uptime.getSeconds());
        uptimeInfo.put("formatted", formatDuration(uptime));
        uptimeInfo.put("startTime", startTime.toString());
        info.put("uptime", uptimeInfo);

        return ResponseEntity.ok(info);
    }

    private String formatDuration(Duration duration) {
        long days = duration.toDays();
        long hours = duration.toHoursPart();
        long minutes = duration.toMinutesPart();
        long seconds = duration.toSecondsPart();

        if (days > 0) {
            return String.format("%dd %dh %dm %ds", days, hours, minutes, seconds);
        } else if (hours > 0) {
            return String.format("%dh %dm %ds", hours, minutes, seconds);
        } else if (minutes > 0) {
            return String.format("%dm %ds", minutes, seconds);
        } else {
            return String.format("%ds", seconds);
        }
    }
}
