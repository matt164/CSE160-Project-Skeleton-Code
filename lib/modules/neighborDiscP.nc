#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module neighborDiscP{
	provides interface neighborDisc;

	uses interface SimpleSend as Sender;
}

implemention{
	
	uint16_t maxNodes = 20;

	uint8_t* pkg;
	//dummy pointer so I can send an empty ping for the request
	pkg = &maxNodes;

	//table to store the neighbors of each node and statistics about link quality on them
	//first dimension is the ID of the owner of that row in the table
	//sencond dimmension is the ID of the node's neighbors
	//third dimmension is 0 - requests sent, 1 - replies received, 2 - # of consecutive missed replies 
	uint16_t[maxNodes][maxNodes][3] neighborTable;

	pack requestPack;
	pack replyPack;

	for(int i = 0; i < maxNodes; i++){
		for(int j = 0; j < maxNodes; j++){
			neighborTable[i][j][0] = 0;
			neighborTable[i][j][1] = 0;           //code will check this element > 0 to tell if a node is a neighbor to a given node
			neighborTable[i][j][2] = 0;
	}

	command void neighborDisc.sendRequest(uint16_t curNodeID){
		for(int i = 0; i < maxNodes; i++){
			neighborTable[curNodeID][i][0] = neighborTable[curNodeID][i][0] + 1;
			neighborTable[curNodeID][i][2] = neighborTable[curNodeID][i][2] + 1;
			if(neighborTable[curNodeID][i][2] > 5){
				neighborTable[curNodeID][i][1] = 0;
				neighborTable[curNodeID][i][2] = 0;
			}
		}
		//leveraging protocol to signify this as a request as I can't tell how to setup a Link Layer module to act as a header 1 = request 2 = reply
		makePack(requestPack, curNodeID, 0, 1, 1, 0, pkg, 0);
		call Sender.send(requestPack, AM_BROADCAST_ADDR);
	}

	command void neighborDisc.recieveRequest(pack *msg, uint16_t curNodeID){
		makePack(replyPack, curNodeID, msg->src, 1, 2, 0, pkg, 0);
		call Sender.send(replyPack, AM_BROADCAST_ADDR);
	}

	command void neighborDisc.recieveReply(pack *msg, uint16_t curNodeID){
		if(msg->dest == curNodeID){
			neighborTable[curNodeID][msg->src][1] = neighborTable[curNodeID][msg->src][1] + 1;
			neighborTable[curNodeID][msg->src][2] = 0; 
		}
	}

	command uint16_t getRequests(uint16_t nodeID, uint16_t neighborID){
		return neighborTable[nodeID][neighborID][0];
	}

	command uint16_t getReplies(uint16_t nodeID, uint16_t neighborID){
		return neighborTable[nodeID][neighborID][1];
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
