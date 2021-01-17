TODO
=====

Here are some things that needs to be done at some point:

- Store pending transactions in a database.
- Whenever the node is started, it is a very good idea to look through the last few blocks to see if
  they contain transactions that we are interested in. Otherwise, we might miss transactions during
  an outage. Currently, this applies if the Node process crashes (it will try to restore from the
  state in Transactions). If a DB is present, it also applies if the entire server crashes for some
  reason, or during a planned outage.
- Test the double spend logic.
- The verification of transactions is currently a bit naive, even if we don't use zero-conf. The system
  looks at if the transaction was accepted into a block (1 conf, this is entirely fine), and if the height
  of the blockchain then increases. We don't actually check if the blockchain continued from the block
  our transaction was accepted into.
- Timeout transactions that are not fulfilled after 24h or so?
