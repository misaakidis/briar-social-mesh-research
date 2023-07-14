#! /bin/sh
java -Xmx2G -cp target:lib/ECLA.jar:lib/DTNConsoleConnection.jar core.DTNSim $*
