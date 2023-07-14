package social;

import java.io.DataInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.io.BufferedReader;

/**
 * Social network and user interests are available at
 * https://crawdad.org/upb/hyccups/20161017/2012/
 * 
 * Based on the UPB2012 parser available at
 * https://github.com/raduciobanu/mobemu/blob/master/src/mobemu/parsers/UPB.java#L211
 */

public class HyccupsSocialParser {
    protected static final String SOCIAL_NETWORK_PATH = "./datasets/hyccups/social_network.txt";
    protected static final String INTERESTS_PATH = "./datasets/hyccups/users_and_interests.txt";

    protected final int usersLength = 73;
    protected final int interestsLength = 5;

    protected boolean[][] socialNetwork;
    protected ArrayList<Integer>[] contacts;

    protected ArrayList<Integer>[] userInterests;
    protected ArrayList<Integer>[] interests;

    public HyccupsSocialParser() {
        socialNetwork = new boolean[usersLength][usersLength];
        contacts = new ArrayList[usersLength];
        userInterests = new ArrayList[usersLength];
        interests = new ArrayList[interestsLength];

        parseSocialNetwork();
        parseInterests();
    }


    /**
     * Parse hyccups social network file
     * Sets contacts[userId] that maps userId -> their contacts' userIds
     * Sets socialNetwork[userId][userId] boolean table
     */
    protected void parseSocialNetwork() {
        String line;
        try {
            FileInputStream fstream = new FileInputStream(SOCIAL_NETWORK_PATH);
            try (DataInputStream in = new DataInputStream(fstream)) {
                BufferedReader br = new BufferedReader(new InputStreamReader(in));

                // Initialize contacts
                for (int i = 0; i < usersLength; i++) {
                    contacts[i] = new ArrayList<Integer>();
                }

                while ((line = br.readLine()) != null) {

                    String[] tokens;
                    String delimiter = ",";

                    tokens = line.split(delimiter);

                    int userId = Integer.parseInt(tokens[0]) - 1;

                    for (int i = 1; i < tokens.length; i++) {
                        Integer contactId = Integer.parseInt(tokens[i]) - 1;
                        if (contactId != null) {
                            socialNetwork[userId][contactId] = true;
                            contacts[userId].add(contactId);
                        }
                    }
                }
            }
        } catch (IOException | NumberFormatException e) {
			System.err.println("Social Network Parser exception: " + e.getMessage());
		}
    }

    /**
     * Parse hyccups interests file.
     * Sets userInterests that maps userId -> interestIds
     * Sets interests that maps interestId -> userIds
     */
    protected void parseInterests() {
        String line;
        try {
            FileInputStream fstream = new FileInputStream(INTERESTS_PATH);
            DataInputStream in = new DataInputStream(fstream);
            BufferedReader br = new BufferedReader(new InputStreamReader(in));

            // Initialize userInterests
            for (int userId = 0; userId < usersLength; userId++) {
                userInterests[userId] = new ArrayList<Integer>();
            }

            // Initialize interests
            for (int interestId = 0; interestId < interestsLength; interestId++) {
                interests[interestId] = new ArrayList<Integer>();
            }

            while ((line = br.readLine()) != null) {

                String[] tokens;
                String delimiter = " ";

                tokens = line.split(delimiter);

                if (tokens[0] == null) {
                    // Empty line, ingore
                    continue;
                }

                int userId = Integer.parseInt(tokens[0]) - 1;

                // Ignore users with 0 interests
                if (tokens.length >= 2 && !tokens[1].equals("0")) {
                    delimiter = ",";
                    tokens = tokens[1].split(delimiter);

                    for (String interestStr : tokens) {
                        int interest = Integer.parseInt(interestStr) - 1;
                        userInterests[userId].add(interest);
                        interests[interest].add(userId);
                    }
                }
            }
        } catch (IOException | NumberFormatException e) {
			System.err.println("Interests Parser exception: " + e.getMessage());
		}
    }

    public boolean isContact(int hostId, int contactId) {
        // Connections with mailboxes are only between contacts
        if (hostId >= usersLength || contactId >= usersLength) {
            return true;
        }
        return contacts[hostId].contains(contactId);
    }
}
