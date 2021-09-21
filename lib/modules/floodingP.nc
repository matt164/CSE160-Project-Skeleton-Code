#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module floodingP{
	provides interface flooding;

	uses interface SimpleSend as Sender;
	
	uses interface neighborDisc;
}

implementation{
	
	//node table to hold the highest seq num flood packet recieved by each node in the network from each flood source
	//first dimmension is the owner of that corresponding array of data
	//second dimmension corresponds to the node ID of the flood src and stores the highest recieved seq
	//nodeTable[i][i] corresponds to the sequence number of a given node i
	uint16_t maxNodes = 19;
	uint16_t nodeTable[maxNodes][maxNodes] = {0,0};
	uint16_t i;
	uint16_t j;

	//packet to send out for flooding
	pack floodPack;

	//Prototypes
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

	//passed in a msg to forward and the ID of the node that is to flood it.
	command void flooding.flood(pack *msg, uint16_t curNodeID){
		if(msg->seq > nodeTable[curNodeID - 1][msg->src - 1]){  //if seq of recieved higher than stored new flood so forward
			nodeTable[curNodeID - 1][msg->src - 1] = msg->seq;					//store the seq of the new most recent flood in the node table
			if(msg->TTL - 1 > 0){                                   //if the TTL of the flood is not yet 0 forward an updated packet to all neighbors
				dbg(FLOODING_CHANNEL, "Packet received\nnode: %d\nsrc: %d\n",curNodeID,msg->src);
				makePack(&floodPack, msg->src, msg->dest, msg->TTL - 1, msg->seq, msg->protocol, msg->payload, PACKET_MAX_PAYLOAD_SIZE);
				call Sender.send(floodPack, AM_BROADCAST_ADDR);
				dbg(FLOODING_CHANNEL, "Packet sent\nnode: %d", curNodeID);
			}
			else{
				if(msg->protocol == 1){
					call neighborDisc.receiveRequest(msg, curNodeID);
				}
				if(msg->protocol == 2){
					call neighborDisc.receiveReply(msg, curNodeID);
				}
			}
		}
	}

	//passed in a node id increments the seq number stored for that node and returns it, for use when a node makes the initial ping that triggers a flood 
	command uint16_t flooding.nodeSeq(uint16_t nodeID){
		nodeTable[nodeID-1][nodeID-1] = nodeTable[nodeID-1][nodeID-1] + 1;
		return nodeTable[nodeID-1][nodeID-1];
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

