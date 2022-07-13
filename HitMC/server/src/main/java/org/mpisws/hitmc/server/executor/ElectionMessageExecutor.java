package org.mpisws.hitmc.server.executor;

import org.mpisws.hitmc.server.TestingService;
import org.mpisws.hitmc.server.event.ElectionMessageEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;

public class ElectionMessageExecutor extends BaseEventExecutor {

    private static final Logger LOG = LoggerFactory.getLogger(ElectionMessageExecutor.class);

    private final TestingService testingService;

    public ElectionMessageExecutor(final TestingService testingService) {
        this.testingService = testingService;
    }

    @Override
    public boolean execute(final ElectionMessageEvent event) throws IOException {
        if (event.isExecuted()) {
            LOG.info("Skipping an executed message event: {}", event.toString());
            return false;
        }
        LOG.debug("Releasing message: {}", event.toString());
        testingService.releaseMessage(event);
        testingService.waitAllNodesSteady();
        event.setExecuted();
        LOG.debug("Message executed: {}\n\n\n", event.toString());
        return true;
    }
}