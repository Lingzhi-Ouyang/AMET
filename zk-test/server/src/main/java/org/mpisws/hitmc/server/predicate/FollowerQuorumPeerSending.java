package org.mpisws.hitmc.server.predicate;

import org.mpisws.hitmc.api.NodeState;
import org.mpisws.hitmc.api.SubnodeState;
import org.mpisws.hitmc.api.SubnodeType;
import org.mpisws.hitmc.server.TestingService;
import org.mpisws.hitmc.server.state.Subnode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/***
 * For now this indicates FollowerProcessSyncMessage & FollowerProcessNEWLEADER event
 */
public class FollowerQuorumPeerSending implements WaitPredicate{
    private static final Logger LOG = LoggerFactory.getLogger(FollowerQuorumPeerSending.class);

    private final TestingService testingService;

    private final int followerId;

    public FollowerQuorumPeerSending(final TestingService testingService,
                                     final int followerId) {
        this.testingService = testingService;
        this.followerId = followerId;
    }

    @Override
    public boolean isTrue() {
        final NodeState nodeState = testingService.getNodeStates().get(followerId);
        if (NodeState.ONLINE.equals(nodeState)) {
            for (final Subnode subnode : testingService.getSubnodeSets().get(followerId)) {
                if (subnode.getSubnodeType().equals(SubnodeType.QUORUM_PEER)) {
                    return SubnodeState.SENDING.equals(subnode.getState());
                }
            }
        }
        return true;
    }

    @Override
    public String describe() {
        return " Follower " + followerId + " 's QuorumPeer subnode is sending";
    }
}