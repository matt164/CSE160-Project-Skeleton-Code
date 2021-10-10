#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module LSRoutingP{
	provides interface LSRouting;

	uses interface SimpleSend as Sender;

	uses interface Timer<TMilli> as LSTimer;
}

implementation{
	
	uint16_t maxNodes = 19;
	uint8_t buffer[19];
	uint16_t i, j, k, min, minIndex, v;
	bool considered[19] = {0};	

	//first dimmension is the node who owns that particular routing table
	//second dimmension is the node to which you wish to route
	//first element of third dimmension is next hop, second is path cost currently using hop count, third element is the highest seq number LS packet received 
	uint16_t routingTable[19][19][3] = {0};

	//first dimmension is the owner of that Distance Vector Table
	//second dimmension is the source node of the Link State Announcement
	//third dimmension is the distances to each node from that node
	uint16_t DVTable[19][19][19] = {0};

	uint16_t minNode();
	void calculatePaths(uint16_t curNodeID);

	void calculatePaths(uint16_t curNodeID){
		for(i = 0; i < maxNodes; i++){
			routingTable[curNodeID - 1][i][1] = maxNodes + 1;
		}
		routingTable[curNodeID - 1][curNodeID - 1][1] = 0;

		for(i = 0; i < maxNodes - 1; i++){

			v = minNode(curNodeID);
			considered[v] = true;

			for(j = 0; j < maxNodes; j++){

				if(!considered[j] && DVTable[curNodeID - 1][v][j] < maxNodes + 1 && routingTable[curNodeID - 1][v][1] + DVTable[curNodeID - 1][v][j] < routingTable[curNodeID - 1][j][1]){

					routingTable[curNodeID - 1][j][1] = routingTable[curNodeID - 1][v][1] + DVTable[curNodeID - 1][v][j];
					if(v == curNodeID - 1)
						routingTable[curNodeID - 1][j][0] = j;
					else
						routingTable[curNodeID - 1][j][0] = routingTable[curNodeID - 1][v][0]; 
				}
			}
		}
	}

	command void LSRouting.LSInit(){
		call LSTimer.startPeriodic(20000);
	}

	command void LSRouting.updateNeighbors(pack *msg, uint16_t curNodeID){
		if(msg->seq > routingTable[curNodeID - 1][msg->src - 1][2]){
			uint8_t *buffer = msg->payload;
			for(i = 0; i < maxNodes; i++){
				DVTable[curNodeID - 1][msg->src - 1][i] = buffer + i;
			}
		}
	}

	command uint16_t LSRouting.getNextHop(uint16_t curNodeID, uint16_t destNodeID){
		return routingTable[curNodeID][destNodeID][0];
	}

	event LSTimer.fired(){
		calculatePaths(TOS_NODE_ID);
	}

	uint16_t minNode(uint16_t curNodeID){
		min = maxNodes + 1;
		for(k = 0; k < maxNodes; k++){
			if(!considered[k] && routingTable[curNodeID - 1][k][1] <= min){
				min = routingTable[curNodeID - 1][k][1];
				minIndex = k
			}
		}
		return minIndex;
	}
}