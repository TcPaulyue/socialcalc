package POE::Queue;

use vars qw($VERSION);
$VERSION = '1.280'; # NOTE - Should be #.### (three decimal places)

use Carp qw(croak);

sub new {
  my $type = shift;
  croak "$type is a virtual base class and not meant to be used directly";
}

1;

__END__

=head1 NAME

POE::Queue - a flexible, generic priority queue API

=head1 SYNOPSIS

POE::Queue specifies additional methods not illustrated here.

  #!perl

  use warnings;
  use strict;
  use POE::Queue::Array;

  my $pqa = POE::Queue::Array->new();

  # Enqueue a few items.

  foreach my $priority (505, 404, 303, 202, 101) {
    $pqa->enqueue($priority, "payload $priority");
  }

  # Dequeue until the queue is drained.

  while (1) {
    my ($priority, $queue_id, $payload) = $pqa->dequeue_next();
    last unless defined $priority;

    print(
      "dequeued id($queue_id) ",
      "priority($priority) ",
      "payload($payload)\n",
    );
  }

Sample output:

  dequeued id(5) priority(101) payload(payload 101)
  dequeued id(4) priority(202) payload(payload 202)
  dequeued id(3) priority(303) payload(payload 303)
  dequeued id(2) priority(404) payload(payload 404)
  dequeued id(1) priority(505) payload(payload 505)

=head1 DESCRIPTION

Priority queues may be implemented a number of ways, but they tend to
behave similiar to lists that are kept in order by some kind of
"priority".  Enqueued items are stored such that the "next" item to be
retrieved is the one with the highest priority.  Subsequent fetches
return the next lowest priority, and so on, until the queue is
emptied.

Priority queues (also known as priority heaps) attempt to do this
while consuming the fewest resources.  Go read about it!  It's
fascinating stuff!

=head2 POE::Queue Items

POE::Queue items consist of three fields: A priority, a unique ID
assigned at enqueue time, and a payload.  The priority and payload are
specified by the caller, and the unique ID is generated by POE::Queue
when an item is enqueued.

POE::Queue imposes two limitations on priorities: Priorities must be
numeric, and lower numbers indicate higher priorities.  Aside from
that, POE::Queue doesn't care what the numbers mean.

Unique IDs are handles into the queue.  POE::Queue generates and
returns them as new items are enqueued.  Some methods manipulate
items, and they take IDs to identify the items to alter.

Item payloads are arbitrary application data.  POE::Queue does not
examine or alter payloads itself.  Any methods that need to examine
payloads will accept a filter function (see L<Filter Functions>).
Filter functions examine payloads so POE::Queue need not.

=head1 Public Methods

POE::Queue is an API specification.  Subclasses like
L<POE::Queue::Array> provide actual implementations.

=head2 new

Creates a new priority queue.  Returns a reference to the queue.

  my $queue = POE::Queue::Array->new();

=head2 enqueue PRIORITY, PAYLOAD

Enqueues a PAYLOAD, which can be just about anything that will fit
into a Perl scalar, at a particular PRIORITY level.  enqueue() returns
a unique ID which can be used to manipulate the payload or its
priority directly.

Following the UNIX tradition, lower priority numbers indicate higher
priorities.  The payload with the lowest priority number will be
dequeued first.  If two payloads have the same PRIORITY, then they
will be dequeued in the order in which they were enqueued.

In this example, a queue is used to manage a number of alarms.  The
"next" alarm will be the one due soonest.

  my $payload_id = $queue->enqueue($alarm_time, [ "stuff" ]);

=head2 dequeue_next

Removes the next item from the queue, returning it as three fields:
priority, ID and payloade.

The "next" item is the one with the lowest priority number.  If
multiple items exist with the same priority, dequeue_next() will
return the one that was given the priority first.

  ITEM: while (1) {
    my ($priority, $id, $payload) = $queue->dequeue_next();
    last ITEM unless defined $priority;
    ...;
  }

=head2 get_next_priority

Returns the priority of the item at the nead of the queue.  This is
the lowest numeric priority in the queue.

get_next_priority() can be useful for checking the queue to see if
it's time to dequeue some items.  In this case, the queue manages
multiple alarms, and there's nothing to do if the next alarm isn't due
yet.

  ALARM: while (1) {
    my $next_alarm_time = $queue->get_next_priority();
    last ALARM unless defined $next_alarm_time;

    if ($next_alarm_time - time() > 0) {
      sleep($next_alarm_time - time());
    }

    my ($priority, $id, $payload) = $queue->dequeue_next();
    ...;
  }

=head2 get_item_count

Returns the number of items in the queue.  It's another way to tell
whether the queue has been fully drained.  Here's an alternative
version of the example for get_next_priority().

  ALARM: while ($queue->get_item_count()) {
    my $next_alarm_time = $queue->get_next_priority();
    if ($next_alarm_time - time() > 0) {
      sleep($next_alarm_time - time());
    }

    my ($priority, $id, $payload) = $queue->dequeue_next();
    ...;
  }

=head2 remove_item ITEM_ID, FILTER_FUNCTION

Removes a single item by its ID, but only if a FILTER_FUNCTION
approves of the item's payload.

If a payload is found with the given ITEM_ID, it is passed to
FILTER_FUNCTION for examination.  If FILTER_FUNCTION returns true, the
item is removed from the queue and is returned as three fields.

  my ($priority, $id, $payload) = $queue->remove_item(
    $target_id, \&monkeys
  );

  sub monkeys {
    my $payload = shift;
    $payload->{type} eq "monkey";
  }

The returned $priority will be undef on failure, and $! will be set to
the reason why the item couldn't be removed.  That will be ESRCH if
the ITEM_ID was not found in the queue, or EPERM if the filter
function returned false.

=head2 remove_items FILTER_FUNCTION [, MAX_ITEM_COUNT ]

Removes and returns items from the queue that match a FILTER_FUNCTION.
remove_items() will return immediately if MAX_ITEM_COUNT items is
specified and that many items have been removed from the queue.
MAX_ITEM_COUNT is a bit of optimization if the application knows in
advance how many items will match the FILTER_FUNCTION.

Returns a list of items that were removed.  Each item is an array
reference containing a priority, item ID, and payload.  Returns
nothing if FILTER_FUNCTION matched nothing.

  # Remove up to 12 monkeys.
  my @monkeys = $queue->remove_items(\&monkeys, 12);
  foreach my $monkey (@monkeys) {
    my ($priority, $id, $payload) = @$monkey;
    print(
      "Removed monkey:\n",
      "  priority = $priority\n",
      "  queue id = $id\n",
      "  payload  = $payload\n",
    );
  }

There is no guarantee which items will be removed if MAX_ITEM_COUNT is
specified too low.

See L<Filter Functions> for more details about filter functions.

=head2 peek_items FILTER_FUNCTION [, MAX_ITEM_COUNT ]

peek_items() returns up to MAX_ITEM_COUNT items that match a given
FILTER_FUNCTION without removing them from the queue.

  my @entire_queue = $queue->peek_items(sub { 1 });
  foreach my $item (@entire_queue) {
    my ($priority, $id, $payload) = @$item;
    print(
      "Item:\n",
      "  priority = $priority\n",
      "  queue id = $id\n",
      "  payload  = $payload\n",
    );
  }

=head2 adjust_priority ITEM_ID, FILTER_FUNCTION, DELTA

Changes the priority of an item by DELTA.  The item is identified by
its ITEM_ID, and the change will only happen if the item's payload
satisfies a FILTER_FUNCTION.  Returns the new priority, which is the
previous priority + DELTA.  DELTA may be negative.

  my $new_priority = $queue->adjust_priority(
    $item_id, \&one_of_mine, 100
  );

  sub one_of_mine {
    my $payload = shift;
    return $payload->{owner} == $me;
  }

Returns undef if the item's priority could not be adjusted, and sets
$! to explain why: ESRCH means that the ITEM_ID could not be found,
and EPERM means that the FILTER_FUNCTION was not satsified.

=head2 set_priority ITEM_ID, FILTER_FUNCTION, ABSOLUTE_PRIORITY

Sets an item's priority to a new ABSOLUTE_PRIORITY.  The item is
identified by its ITEM_ID, and the change will only be allowed to
happen if the item's payload satisfies a FILTER_FUNCTION.  Returns the
new priority, which should match ABSOLUTE_PRIORITY.

Returns undef if the item's priority could not be set, and sets $! to
explain why: ESRCH means that the ITEM_ID could not be found, and
EPERM means that the FILTER_FUNCTION was not satsified.

  my $new_priority = $queue->set_priority(
    $item_id, \&one_of_mine, time() + 60
  );

  unless (defined $new_priority) {
    die "one of our submarines is missing: $item_id" if $! == ESRCH;
    die "set_priority disallowed for item $item_id" if $! == EPERM;
    die $!;
  }

  sub one_of_mine {
    $_[0]{owner} == $me;
  }

=head1 SEE ALSO

L<POE>, L<POE::Queue::Array>

=head1 BUGS

None known.

TODO - Should set_priority return the old priority instead of the new
one?

TODO - Rename and repackage as its own distribution.

=head1 AUTHORS & COPYRIGHTS

Please see L<POE> for more information about authors, contributors,
and POE's licensing.

=cut

# rocco // vim: ts=2 sw=2 expandtab
# TODO - Edit.
