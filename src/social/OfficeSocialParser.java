package social;

import java.io.DataInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.io.BufferedReader;

public class OfficeSocialParser {
    protected static final String INTERESTS_PATH = "./datasets/sociopatterns/office_interests.txt";

    protected final int usersLength = 93;
    protected final int interestsLength = 12;

    protected ArrayList<Integer>[] userInterests;
    protected ArrayList<Integer>[] interests;

    public OfficeSocialParser() {
        userInterests = new ArrayList[usersLength];
        interests = new ArrayList[interestsLength];

        parseInterests();
    }

   /**
     * Parse sociopatterns/office interests file.
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
}
