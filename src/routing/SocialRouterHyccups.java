/*
 * Released under GPLv3. See LICENSE.txt for details.
 */
package routing;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import routing.ActiveRouter;

import social.HyccupsSocialParser;
import util.Tuple;

import core.Connection;
import core.DTNHost;
import core.Message;
import core.Settings;

/**
 * Message router that prioritizes messages of the node's contacts.
 */
public class SocialRouterHyccups extends ActiveRouter {

	protected static HyccupsSocialParser socialParser = new HyccupsSocialParser();

	/**
	 * Constructor. Creates a new message router based on the settings in
	 * the given Settings object.
	 * @param s The settings object
	 */
	public SocialRouterHyccups(Settings s) {
		super(s);
	}

	/**
	 * Copy constructor.
	 * @param r The router prototype where setting values are copied from
	 */
	protected SocialRouterHyccups(SocialRouterHyccups r) {
		super(r);
	}

	@Override
	public SocialRouterHyccups replicate() {
		return new SocialRouterHyccups(this);
	}

	@Override
	public void update() {
		super.update();
		if (isTransferring() || !canStartTransfer()) {
			return; // transferring, don't try other connections yet
		}

		// First, try the messages that can be delivered to final recipient
		if (exchangeDeliverableMessages() != null) {
			return; // started a transfer, don't try others (yet)
		}

		// Second, forward messages whose sender is a contact
		if (exchangeMessagesFromContacts() != null) {
			return;
		}

		// Third, forward messages relayed from contacts
		if (exchangeMessagesRelayedFromContacts() != null) {
			return;
		}

		// Finally try any/all message to any/all connection
		this.tryAllMessagesToAllConnections();
	}

	protected Connection exchangeMessagesFromContacts() {
		List<Connection> connections = getConnections();

		if (connections.size() == 0) {
			return null;
		}

		@SuppressWarnings(value = "unchecked")
		Tuple<Message, Connection> t =
			tryMessagesForConnected(sortByQueueMode(this.getMessagesFromContacts()));
		
		if (t != null) {
			return t.getValue(); // started transfer
		}
	
		// didn't start transfer to any node -> ask messages from the other node
		// originating with host's contacts
		for (Connection con : connections) {
			if (isTransferring()) {
				continue;
			}
	
			DTNHost other = con.getOtherNode(getHost());
			/* do a copy to avoid concurrent modification exceptions
			 * (startTransfer may remove messages) */
			ArrayList<Message> temp =
				new ArrayList<Message>(other.getMessageCollection());
			for (Message m : temp) {
				if (socialParser.isContact(this.getHost().getAddress(), m.getFrom().getAddress())) {
					if (startTransfer(m, con) == RCV_OK) {
						return con;
					}
				}
			}
		}

		return null;
	}

	protected List<Tuple<Message, Connection>> getMessagesFromContacts() {
		if (this.getNrofMessages() == 0 || this.getConnections().size() == 0) {
			/* no messages -> empty list */
			return new ArrayList<Tuple<Message, Connection>>(0);
		}

		List<Tuple<Message, Connection>> fromContactsTuples =
			new ArrayList<Tuple<Message, Connection>>();
		for (Message m : getMessageCollection()) {
			for (Connection con : getConnections()) {
				// Add messages where the previous hop is a contact
				if (socialParser.isContact(this.getHost().getAddress(), m.getFrom().getAddress())) {
					fromContactsTuples.add(new Tuple<Message, Connection>(m,con));
				}
			}
		}

		return fromContactsTuples;
	}


	protected Connection exchangeMessagesRelayedFromContacts() {
		List<Connection> connections = getConnections();

		if (connections.size() == 0) {
			return null;
		}

		@SuppressWarnings(value = "unchecked")
		Tuple<Message, Connection> t =
			tryMessagesForConnected(sortByQueueMode(this.getMessagesRelayedFromContacts()));
		
		if (t != null) {
			return t.getValue(); // started transfer
		}
	
		// didn't start transfer to any node -> ask messages from the other node
		// originating with host's contacts
		for (Connection con : connections) {
			if (isTransferring()) {
				continue;
			}
	
			DTNHost other = con.getOtherNode(getHost());
			/* do a copy to avoid concurrent modification exceptions
			 * (startTransfer may remove messages) */
			ArrayList<Message> temp =
				new ArrayList<Message>(other.getMessageCollection());
			for (Message m : temp) {
				if (socialParser.isContact(this.getHost().getAddress(), m.getFrom().getAddress())) {
					if (startTransfer(m, con) == RCV_OK) {
						return con;
					}
				}
			}
		}

		return null;
	}

	protected List<Tuple<Message, Connection>> getMessagesRelayedFromContacts() {
		if (this.getNrofMessages() == 0 || this.getConnections().size() == 0) {
			/* no messages -> empty list */
			return new ArrayList<Tuple<Message, Connection>>(0);
		}

		List<Tuple<Message, Connection>> relayedFromContactsTuples =
			new ArrayList<Tuple<Message, Connection>>();
		for (Message m : getMessageCollection()) {
			for (Connection con : getConnections()) {
				// Add messages where the previous hop is a contact
				List<DTNHost> messagePath = m.getHops();
				DTNHost lastHop = messagePath.get(messagePath.size() - 1);
				if (lastHop != null && socialParser.isContact(this.getHost().getAddress(), lastHop.getAddress())) {
					relayedFromContactsTuples.add(new Tuple<Message, Connection>(m,con));
				}
			}
		}

		return relayedFromContactsTuples;
	}

	/**
	 * Returns the oldest (by receive time) message in the message buffer
	 * (that is not being sent if excludeMsgBeingSent is true).
	 * Messages from contacts are not removed unless their TTL expires.
	 * @param excludeMsgBeingSent If true, excludes message(s) that are
	 * being sent from the oldest message check (i.e. if oldest message is
	 * being sent, the second oldest message is returned)
	 * @return The oldest message or null if no message could be returned
	 * (no messages in buffer or all messages in buffer are being sent and
	 * exludeMsgBeingSent is true)
	 */
	@Override
	protected Message getNextMessageToRemove(boolean excludeMsgBeingSent) {
		Collection<Message> messages = this.getMessageCollection();
		Message oldest = null;
		for (Message m : messages) {
			if (socialParser.isContact(this.getHost().getAddress(), m.getFrom().getAddress())) {
				continue; // skip messages from contacts
			}

			if (excludeMsgBeingSent && isSending(m.getId())) {
				continue; // skip the message(s) that router is sending
			}

			if (oldest == null ) {
				oldest = m;
			}
			else if (oldest.getReceiveTime() > m.getReceiveTime()) {
				oldest = m;
			}
		}

		return oldest;
	}
}
