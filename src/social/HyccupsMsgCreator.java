package social;

import java.util.Random;
import java.util.ArrayList;

import social.HyccupsSocialParser;

/*
 * Generates deterministic "create message" events for the HYCCUPS UPB 2012 traceset social network
 * 
 * Supports the simulation of hybrid nodes and mailboxes, by adding respective CONN events:
 * For hybrid nodes, it adds CONN events with their contacts who are also hybrid throughout the simulation
 * For mailboxes
 *   * it adds CONN events with their owners during night-time
 *   * it adds CONN events between mailboxes owned by contacts throughout the simulation
 * Only nodes with contacts can be randomly selected to be hybrid or to own a mailbox
 * 
 * No messages are generated during night-time
 * If using a looped traceset, make sure loop duration is a multiple of seconds in a day (= 86400)
 * 
 * Expects arguments rngSeed, numOfHybridNodes, and numOfMailboxes
 * See hardcoded constants for message creation interval, message size, and whether nodes without contacts can send messages
 * 
 * See ../../toolkit/hyccupsTraceConverter.pl for converting the hyccups traceset into the ONE Simulator format
 */
public class HyccupsMsgCreator {
    private static final int LAST_CONN_TIMESTAMP = 14106341; // For hyccups-loop-0-4838400-3. Original traceset ending at 5086078

    private static int stepMin, stepMax;
    private static int msgSizeMin, msgSizeMax;

    private static boolean onlyNodesWithContactsSendMsgs;

    private static long rngSeed;
    private static Random rndGenerator;
    private static HyccupsSocialParser socialParser;

    // Simulate hybrid nodes
    private static boolean simulateHybridNodes = false;
    private static int numOfHybridNodes;
    private static int hybridNodes[];

    // Simulate mailboxes
    private static boolean simulateMailboxes = false;
    private static int numOfMailboxes;
    private static int ownerOfMailbox[];

    public static void main(String[] args) {
        // Check if the required number of command line arguments is provided
        if (args.length < 6) {
            System.out.println("Please provide numOfHybridNodes, numOfMailboxes, rngSeed, msgSizeRange, numOfDailyMsgsPerHost, and onlyNodesWithContactsSendMsgs as command line arguments.");
            return;
        }

        // Parse the command line arguments
        numOfHybridNodes = Integer.parseInt(args[0]);
        numOfMailboxes = Integer.parseInt(args[1]);
        rngSeed = Long.parseLong(args[2]);
        String[] msgSizeRange = args[3].split(",");
        int numOfDailyMsgsPerHost = Integer.parseInt(args[4]);
        onlyNodesWithContactsSendMsgs = Boolean.parseBoolean(args[5]);

        msgSizeMin = Integer.parseInt(msgSizeRange[0]);
        msgSizeMax = Integer.parseInt(msgSizeRange[1]);

        socialParser = new HyccupsSocialParser();
        rndGenerator = new Random(rngSeed);

        int totalDailyMessages = socialParser.usersLength * numOfDailyMsgsPerHost;
        int msgInterval = 17 * 60 * 60 / totalDailyMessages; // Messages are generated within the 17 hours day time window
        int threshold = (int) msgInterval / 5;
        stepMin = msgInterval - threshold;
        stepMax = msgInterval + threshold;

        if (numOfHybridNodes > 0) {
            simulateHybridNodes = true;
            hybridNodes = new int[numOfHybridNodes];
        }

        if (numOfMailboxes > 0) {
            simulateMailboxes = true;
            ownerOfMailbox = new int[numOfMailboxes];
        }

        String eventsConnHybrid = "";
        String eventsConnMailboxes = "";

        if (simulateHybridNodes) {
            for (int i = 0; i < numOfHybridNodes; i++) {
                hybridNodes[i] = _getRndNodeWithContacts();
            }

            // Connect hybrid nodes who are contacts throughout the whole duration of the simulation
            for (int hybridNodeId = 0; hybridNodeId < numOfHybridNodes; hybridNodeId++ ) {
                for (int connHybridNodeId = hybridNodeId + 1; connHybridNodeId < numOfHybridNodes; connHybridNodeId++) {
                    if (socialParser.isContact(hybridNodes[hybridNodeId], hybridNodes[connHybridNodeId])) {
                        eventsConnHybrid += "0\t\t\tCONN\t" + hybridNodeId + "\t" + connHybridNodeId + "\tup\n";
                        eventsConnHybrid += LAST_CONN_TIMESTAMP + "\t\tCONN\t" + hybridNodeId + "\t" + connHybridNodeId + "\tdown\n";
                    }
                }
            }
        }

        if (simulateMailboxes) {
            for (int i = 0; i < numOfMailboxes; i++) {
                ownerOfMailbox[i] = _getRndNodeWithContacts();
            }

            // Connect mailboxes whose owners are contacts throughout the whole duration of the simulation
            for (int mailboxId = 0; mailboxId < numOfMailboxes; mailboxId++) {
                for (int connMailboxId = mailboxId + 1; connMailboxId < numOfMailboxes; connMailboxId++) {
                    // If mailbox owners are contacts, add CONN event between mailboxes throughout the duration of the simulation
                    if (socialParser.isContact(ownerOfMailbox[mailboxId], ownerOfMailbox[connMailboxId])) {
                        eventsConnMailboxes += "0\t\t\tCONN\t" + (mailboxId + socialParser.usersLength) +
                            "\t" + (connMailboxId + socialParser.usersLength) + "\tup\n";
                        eventsConnMailboxes += LAST_CONN_TIMESTAMP + "\t\tCONN\t" + (mailboxId + socialParser.usersLength) +
                            "\t" + (connMailboxId + socialParser.usersLength) + "\tdown\n";
                    }
                }
            }
        }

        System.out.print(eventsConnHybrid + eventsConnMailboxes + _createMsgs());
    }

    // Returns the Id of a random node out of those who have contacts
    private static int _getRndNodeWithContacts() {
        int rndNodeId;
        do {
            rndNodeId = rndGenerator.nextInt(socialParser.usersLength);
        } while (socialParser.contacts[rndNodeId].size() == 0);
        return rndNodeId;
    }

    private static String _createMsgs() {
        // Based on the CONN patterns of the traceset, we observe that night starts ~6 hours after timestamp 0
        int nextSleep = 21600;
        int sleepCount = 0;
        int msgCount = 0;
        String msgsString = "";

        for (int time = 0; time < LAST_CONN_TIMESTAMP; time += rndGenerator.nextInt(stepMax - stepMin) + stepMin) {
            // Select random sender. Enforces the check about whether senders without contacts can send messages
            int sender;
            ArrayList<Integer> sendersContacts;
            do {
                sender = rndGenerator.nextInt(socialParser.usersLength);
                sendersContacts = socialParser.contacts[sender];
            } while (onlyNodesWithContactsSendMsgs && sendersContacts.size() == 0);
            
            int receiver;
            if (sendersContacts.size() > 0) {
                // Randomly select a receiver from sender's contacts
                receiver = sendersContacts.get(rndGenerator.nextInt(sendersContacts.size()));
            } else {
                // Sender does not have any contacts, choose random receiver
                receiver = rndGenerator.nextInt(socialParser.usersLength);
            }
            
            int msgSize = rndGenerator.nextInt(msgSizeMax - msgSizeMin) + msgSizeMin;
            msgsString += time + "\t\tC\tM" + (++msgCount) + "\t" + sender + "\t" + receiver + "\t" + msgSize  + "\n";

            if (time > nextSleep) {
                int sleepTime = rndGenerator.nextInt(7200) + 21600; // Sleep for 6-8 hours

                // Connect users to their mailboxes during night-time
                if (simulateMailboxes) {
                    for (int mailboxId = 0; mailboxId < numOfMailboxes; mailboxId++) {
                        msgsString += time + "\t\tCONN\t" + ownerOfMailbox[mailboxId] + "\t" +
                            (mailboxId + socialParser.usersLength) + "\tup\n";
                        msgsString += (time + sleepTime) + "\t\tCONN\t" + ownerOfMailbox[mailboxId] + "\t" +
                            (mailboxId + socialParser.usersLength) + "\tdown\n";
                    }
                }

                time += sleepTime;
                sleepCount++;
                nextSleep = 21600 + sleepCount*86400;
            }
        }
        return msgsString;
    }
}
