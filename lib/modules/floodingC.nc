#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration floodingC{
	Provides interface flooding;
}

implementation{
	components floodingP;
	flooding = floodingP.flooding;

	components new SimpleSendC(AM_PACK);
	floodingP.Sender -> SimpleSendC;
}