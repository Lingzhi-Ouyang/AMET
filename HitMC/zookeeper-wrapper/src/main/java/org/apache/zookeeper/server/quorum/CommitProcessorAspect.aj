package org.apache.zookeeper.server.quorum;

import org.apache.zookeeper.ZooDefs;
import org.apache.zookeeper.server.Request;
import org.mpisws.hitmc.api.SubnodeType;
import org.mpisws.hitmc.api.TestingRemoteService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.rmi.RemoteException;
import java.util.LinkedList;

public aspect CommitProcessorAspect {
    private static final Logger LOG = LoggerFactory.getLogger(CommitProcessorAspect.class);

    private final QuorumPeerAspect quorumPeerAspect = QuorumPeerAspect.aspectOf();

    private TestingRemoteService testingService;

    private int subnodeId;

    // Intercept starting the CommitProcessor thread

    pointcut runCommitProcessor(): execution(* CommitProcessor.run());

    before(): runCommitProcessor() {
        LOG.debug("-------before runCommitProcessor. Thread {}: {}------",Thread.currentThread().getId(), Thread.currentThread().getName());
        testingService = quorumPeerAspect.createRmiConnection();
        subnodeId = quorumPeerAspect.registerSubnode(testingService, SubnodeType.COMMIT_PROCESSOR);
        try {
//            intercepter.getTestingService().setReceivingState(intercepter.getSubnodeId());
            testingService.setReceivingState(subnodeId);
        } catch (final RemoteException e) {
            LOG.debug("Encountered a remote exception", e);
            throw new RuntimeException(e);
        }

    }

    after(): runCommitProcessor() {
        LOG.debug("after runCommitProcessor");
        quorumPeerAspect.deregisterSubnode(testingService, subnodeId, SubnodeType.COMMIT_PROCESSOR);
    }

    // intercept getting the request from the queue committedRequests
    // This method is called by the quorumPeer thread

    pointcut commit(LinkedList queue, Request request):
            withincode(void CommitProcessor.commit(Request))
                && call(* LinkedList.add(..))
                && target(queue) && args(request);

    before(LinkedList queue, Request request): commit(queue, request) {
        final long threadId = Thread.currentThread().getId();
        final String threadName = Thread.currentThread().getName();
        LOG.debug("before advice of CommitProcessor.commit()-------QuorumPeer Thread: {}, {}------", threadId, threadName);
//        QuorumPeerAspect.SubnodeIntercepter intercepter = quorumPeerAspect.getIntercepter(threadId);
        LOG.debug("--------------Before adding commit request {}: My commitRequests has {} element. commitSubnode: {}",
                request.type, queue.size(), subnodeId);
        final int type =  request.type;
        switch (type) {
            case ZooDefs.OpCode.notification:
            case ZooDefs.OpCode.create:
            case ZooDefs.OpCode.delete:
            case ZooDefs.OpCode.createSession:
            case ZooDefs.OpCode.exists:
            case ZooDefs.OpCode.check:
            case ZooDefs.OpCode.multi:
            case ZooDefs.OpCode.sync:
            case ZooDefs.OpCode.getACL:
            case ZooDefs.OpCode.setACL:
            case ZooDefs.OpCode.getChildren:
            case ZooDefs.OpCode.getChildren2:
            case ZooDefs.OpCode.ping:
            case ZooDefs.OpCode.closeSession:
            case ZooDefs.OpCode.setWatches:
                LOG.debug("Won't intercept commit request: {} ", request);
                return;
            default:
        }
        try {
            // before offerMessage: increase sendingSubnodeNum
            quorumPeerAspect.setSubnodeSending();
            final String payload = quorumPeerAspect.constructRequest(request);
            LOG.debug("-----before getting this pointcut in the synchronized method: " + request);
//            int lastCommitRequestId = intercepter.getTestingService().commit(subnodeId, payload, type);
            final int lastCommitRequestId =
                    testingService.offerRequestProcessorMessage(subnodeId, SubnodeType.COMMIT_PROCESSOR, payload);
            LOG.debug("lastCommitRequestId = {}", lastCommitRequestId);
            // after offerMessage: decrease sendingSubnodeNum and shutdown this node if sendingSubnodeNum == 0
            quorumPeerAspect.postSend(subnodeId, lastCommitRequestId);
            // TODO: is there any better position to set receiving state?
//            intercepter.getTestingService().setReceivingState(subnodeId);
            testingService.setReceivingState(subnodeId);
        } catch (final RemoteException e) {
            LOG.debug("Encountered a remote exception", e);
            throw new RuntimeException(e);
        }
    }
}
