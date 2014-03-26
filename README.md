TAP-Producer
============

A class that supports emitting correct Test Anything Protocol output

One of the things I love about Perl is the great testing culture it has nourished.
We have an amaing set of tools that make writing and  running tests easy.

All that changed when I decided to write my own testing library based on Test::Builder.

On the amazing side, Test::Builder formed the foundation of modern Perl's deep history of testing and broad range of testing tools.  It has been an incredibly successful library from that standpoint.

On the less amazing side, Test::Builder is extremely complex and difficult to use to make testing libraries.  It contains features for creating TAP output, running tests is various forms, parallel and signle threaded.  The interface shows this.  `local $Level = $Level+1;` Really?

This situation lead me to rethink what should be involved in writing a Test library.  TAP::Producer is the result.



