#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module neighborDiscP{
	provides interface neighborDisc;

	uses interface SimpleSend as Sender;
	
	uses interface flooding;
	
	uses interface Timer<TMilli> as discTimer;
	
	uses interface LSRouting;
}

implementation{
	
	uint16_t maxNodes = 19;
	uint16_t i;
	uint16_t j;
	uint16_t seqNum;
	uint8_t dummy = 4;

	//table to store the neighbors of each node and statistics about link quality on them
	//first dimension is the ID of the owner of that row in the table
	//sencond dimmension is the ID of the node's neighbors
	//third dimmension is 0 - requests sent, 1 - replies received, 2 - # of consecutive missed replies 
	uint16_t neighborTable[19][19][3] = {0};

	pack requestPack;
	pack replyPack;
	
	//prototypes
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
	void sendRequest();
	
	void sendRequest(){
		for(i = 0; i < maxNodes; i++){
			neighborTable[TOS_NODE_ID - 1][i][0] = neighborTable[TOS_NODE_ID - 1][i][0] + 1;
			neighborTable[TOS_NODE_ID - 1][i][2] = neighborTable[TOS_NODE_ID - 1][i][2] + 1;
			if(neighborTable[TOS_NODE_ID - 1][i][2] > 5){
				neighborTable[TOS_NODE_ID - 1][i][1] = 0;
				neighborTable[TOS_NODE_ID - 1][i][2] = 0;
			}
		}
		seqNum = call flooding.nodeSeq(TOS_NODE_ID);
		//leveraging protocol to signify this as a request as I can't tell how to setup a Link Layer module to act as a header 6 = request 7 = reply
		makePack(&requestPack, TOS_NODE_ID, maxNodes + 1, 1, 6, seqNum, (uint8_t*)dummy, 0);
		call Sender.send(requestPack, AM_BROADCAST_ADDR);
		dbg(NEIGHBOR_CHANNEL, "Request sent   src: %d\n", TOS_NODE_ID);
	}
	
	command void neighborDisc.discInit(){
		call discTimer.startPeriodic(60000);         //timer to trigger the nodes to update their neighbor table
		dbg(NEIGHBOR_CHANNEL, "Timer #%d Started\n", TOS_NODE_ID);
	}

	command void neighborDisc.receiveRequest(pack *msg, uint16_t curNodeID){
		dbg(NEIGHBOR_CHANNEL, "Before reply   src: %d   dest: %d\n", msg->src, msg->dest);
		seqNum = call flooding.nodeSeq(TOS_NODE_ID);
		makePack(&replyPack, curNodeID, msg->src, 1, 7, seqNum, msg->payload, 0);
		call Sender.send(replyPack, msg->src);
		dbg(NEIGHBOR_CHANNEL, "Reply sent   src: %d   dest: %d\n", msg->src, msg->dest);
	}

	command void neighborDisc.receiveReply(pack *msg, uint16_t curNodeID){
		dbg(NEIGHBOR_CHANNEL, "Reply Recieved src: %d   node: %d\n", msg->src, TOS_NODE_ID);
		neighborTable[curNodeID - 1][msg->src - 1][1] = neighborTable[curNodeID - 1][msg->src - 1][1] + 1;
		neighborTable[curNodeID - 1][msg->src - 1][2] = 0;
	}

	command uint16_t neighborDisc.getRequests(uint16_t nodeID, uint16_t neighborID){
		return neighborTable[nodeID - 1][neighborID - 1][0];
	}

	command uint16_t neighborDisc.getReplies(uint16_t nodeID, uint16_t neighborID){
		return neighborTable[nodeID - 1][neighborID - 1][1];
	}
	
	event void discTimer.fired(){
		sendRequest();
		dbg(NEIGHBOR_CHANNEL, "Timer #%d Ticked\n", TOS_NODE_ID);
	}

	//function borrowed from skeleton code as I couldn't figure out how to call it from node.nc in this module
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}
}
