#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration neighborDiscC{
	Provides interface neighborDisc;
}

implementation{
	components neighborDiscP;
	neighborDisc = neighborDiscP.neighborDisc;

	components new SimpleSendC(AM_PACK);
	neighborDiscP.Sender -> SimpleSendC;
}