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
	void sendRequest(uint16_t curNodeID);
	
	void sendRequest(uint16_t curNodeID){
		for(i = 0; i < maxNodes; i++){
			neighborTable[curNodeID - 1][i][0] = neighborTable[curNodeID - 1][i][0] + 1;
			neighborTable[curNodeID - 1][i][2] = neighborTable[curNodeID - 1][i][2] + 1;
			if(neighborTable[curNodeID - 1][i][2] > 5){
				neighborTable[curNodeID - 1][i][1] = 0;
				neighborTable[curNodeID - 1][i][2] = 0;
			}
		}
		seqNum = call flooding.nodeSeq(curNodeID);
		//leveraging protocol to signify this as a request as I can't tell how to setup a Link Layer module to act as a header 1 = request 2 = reply
		makePack(&requestPack, curNodeID, 0, 1, 1, seqNum, (uint8_t*)dummy, 0);
		call Sender.send(requestPack, AM_BROADCAST_ADDR);
		dbg(NEIGHBOR_CHANNEL, "Request sent   src: %d\n", curNodeID);
	}
	
	command void neighborDisc.discInit(){
		call discTimer.startPeriodic(20000);         //timer to trigger the nodes to update their neighbor table
	}

	command void neighborDisc.receiveRequest(pack *msg, uint16_t curNodeID){
		msg->dest = msg->src;
		msg->src = curNodeID;
		msg->TTL = 1;
		call Sender.send(*msg, AM_BROADCAST_ADDR);
		dbg(NEIGHBOR_CHANNEL, "Reply sent   src: %d\n", curNodeID);
	}

	command void neighborDisc.receiveReply(pack *msg, uint16_t curNodeID){
		if(msg->dest == curNodeID){
			neighborTable[curNodeID - 1][msg->src - 1][1] = neighborTable[curNodeID - 1][msg->src - 1][1] + 1;
			neighborTable[curNodeID - 1][msg->src - 1][2] = 0; 
		}
	}

	command uint16_t neighborDisc.getRequests(uint16_t nodeID, uint16_t neighborID){
		return neighborTable[nodeID - 1][neighborID - 1][0];
	}

	command uint16_t neighborDisc.getReplies(uint16_t nodeID, uint16_t neighborID){
		//return neighborTable[nodeID - 1][neighborID - 1][1];
		return 1;
	}
	
	event void discTimer.fired(){
		for(j = 1; j <= 3; j++){
			sendRequest(j);
		}
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
