package TAP::Producer::Context;

use strict;
use warnings;
use Carp        qw< croak >;
use Time::HiRes qw<>;
use IO::Handle;

use TAP::Producer::Diagnostic;
use TAP::Producer::Plan;
use TAP::Producer::Test;

use constant {
    _CONTEXT        =>  0, # ref to parent test context.
    _DEPTH          =>  1, # ref to parent test context.
    _PLANNED_TESTS  =>  2, # plan number or undef
    _PASS_ALL       =>  3, # plan number or undef
    _TEST_COUNT     =>  4, # test results shown so far
    _START_TIME     =>  5, # time hires
    _FINISH_TIME    =>  6, # time hires
    _PASSING        =>  7, # boolean, are all tests passing so far
    _HANDLE         =>  8, # handle to emit results upon
    _INDENT         => 10, # pre-calculated indent to save time regenerating indent text.
    _DESC           =>  9, # description - used when converting subtest into a test.
    _DIRECTIVE      => 11, # directive used when converting subtest into a test.
    _EXPLANATION    => 12, # explanation - used when converting subtest into a test.
};


sub new {
    my ($class, $opt) = @_;

    my $self = bless [], $class;
    $self->[_START_TIME] = Time::HiRes::time();
    $self->[_PASSING] = 1;

    my $context = delete $opt->{context};
    $self->[_CONTEXT] = $context;
    $self->[_DEPTH]   = $context ? $context->depth()+1 : 0;
    $self->[_INDENT]  = '    ' x $self->[_DEPTH];

    my $handle =  (delete $opt->{handle} )
               || ( $context && $context->handle() )
               || \*STDOUT;
    $self->[_HANDLE] = $handle;

    {   my $dir = delete $opt->{directive};

        if ( defined $dir ) {
            $dir = uc $dir;
            croak "Test directive must be 'TODO', 'SKIP' or undefined, not $dir"
                if ($dir ne 'SKIP')
                && ($dir ne 'TODO');
        }

        $self->[_DIRECTIVE] = $dir;
    }
    $self->[_DESC] = delete $opt->{description};
    $self->[_EXPLANATION] = delete $opt->{description};

    return $self;
}

sub depth       { $_[0]->[_DEPTH]       };
sub handle      { $_[0]->[_HANDLE]      };
sub description { $_[0]->[_DESC]        };
sub directive   { $_[0]->[_DIRECTIVE]   };
sub explanation { $_[0]->[_EXPLANATION] };
sub test_count  { $_[0]->[_TEST_COUNT]  };

sub emit_bail_out {
    my ($self, $opt) = @_;

    my $bail = TAP::Producer::BailOut->new({ %$opt });

    $self->[_HANDLE]->print( $self->[_INDENT], $bail->as_tap, "\n" );

    return;
}

sub emit_plan {
    my ($self, $opt) = @_;

    my $count = $opt->{test_count};

    croak "Test plan already defined"
        if ( defined $self->[_PLANNED_TESTS] );

    $self->[_PLANNED_TESTS] = $count
        if defined $count ;

    my $plan = TAP::Producer::Plan->new({ %$opt });

    $self->[_PASS_ALL] = 1
        if $plan->skip_all() ;

    $self->[_HANDLE]->print( $self->[_INDENT], $plan->as_tap, "\n" );

    return;
}

sub emit_test_result {
    my ($self, $opt) = @_;

    # update test count
    $self->[_TEST_COUNT]++;
    my $count = $self->[_TEST_COUNT];
    # make object
    my $test = TAP::Producer::Test->new({ number => $count, %$opt });
    # update _PASSING
    $self->[_PASSING] &&= $test->passed();
    # print object
    $self->[_HANDLE]->print( $self->[_INDENT], $test->as_tap, "\n" );

    return $test->passed();
}

sub emit_diagnostics {
    my ($self, @messages ) = @_;
    my $handle = $self->[_HANDLE];
    my @diag = TAP::Producer::Diagnostic->new_batch( @messages );
    $handle->print(
        map { $self->[_INDENT], $_->as_tap(), "\n" }
        @diag
    );

    return;
}

sub tests_complete {
    my ($self, $count) = @_;

    croak "Test count conflicts with existing test plan"
        if (defined $count)
        && (defined $self->[_PLANNED_TESTS])
        && ($count != $self->[_PLANNED_TESTS]);

    $self->[_FINISH_TIME] = Time::HiRes::time();

    $self->[_PLANNED_TESTS] = $count
        if defined $count;

    return $self->passed();
}

sub begin_subtest {
    my ($self, $opt) = @_;
    # Make a new object with this one in context.
    # Depth is _depth + 1;
    my $class = ref $self;
    my $subtest = $class->new({ context => $self, %$opt });

    return $subtest;
}

sub passed {
    my ($self) = @_;

    my $pass = 1;
    # Are all tests passing?
    $pass &&= $self->[_PASSING];

    # Do we have a plan?
    # Does it match our test count?
    my $plan = $self->[_PLANNED_TESTS];
    my $count = $self->[_TEST_COUNT];

    $pass &&= 0
        if (defined $plan)
        && (defined $count)
        && ($plan != $count);

    $pass = 1 if $self->[_PASS_ALL];

    return $pass;
}

1;

__END__

=head1 NAME

TAP::Producer::Context

=head1 SYNOPSIS

See L<TAP::Producer>.

=head1 DESCRIPTION

Provides a shared context for a group of related tests.

=head1 METHODS

=head2 new

Arguments: An option hash:

  handle      - Optional. A file handle to emit output to.  defaults to STDOUT

  description - Optional. A description of the context, used when converting
                subtest contexts into a Test object.

  directive   - Optional. A string containing SKIP or TODO, used when converting
                subtest contexts into a Test object.

  explanation - Optional. A string containing a text explanation of why this
                context's tests are affected by a directive. Used when
                converting subtest contexts into a Test object.

  context     - Optional. The parent testing context.  Set this if you are
                creating a context for subtest execution.

Results: A new TAP::Producer::Context object.

=head2 depth

How many layers of parent contexts are there?

=head2 handle

=head2 description

=head2 directive

=head2 explanation

=head2 emit_bail_out

DON'T

=head2 emit_plan

Emit a TAP plan line.

Arguments: An options hash suitable for C<<TAP::Producer::Plan->new()>>;

Return: void.


=head2 emit_diagnostics

Emit one or more lines of diagnostic messages.

Arguments: A list of message strings.  Each message string will produce
one or more lines of diagnostic TAP output.  Message strings containing
a newline "\n" are split into multiple diagnostic lines.

Return: Integer - the number of diagnostic messages emitted.

=head2 tests_complete

Tell the context that all tests have been run.

Arguments: Optional integer.  Number of tests expected in this context.

Return: Boolean value. C<TRUE> if all tests in this context have passed.
C<FALSE> otherwise.


=head2 begin_subtest

Create a context to run subtests in.

Arguments: Options hash suitable for C<new>.

Returns a TAP::Producer::Context object.

=head2 passed

No arguments.

Returns true if all tests in the context are considered to have passed.

Tests that are marked as TODO or SKIP, will be considered as passing.

=head1 TODO

  * Enforce finalization of text contexts.
    * If tests_complete() has been called, croak when calling: emit_*,
      begin_subtest, and tests_complete.
  # Add DESTROY methods to check for tests_complete(), etc.


