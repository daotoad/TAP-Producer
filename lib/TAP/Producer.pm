package TAP::Producer;

use strict;
use warnings;
use constant;
use Carp      qw< croak >;

my $singleton;
sub singleton {
    my ($class, $opt) = @_;
    return $singleton if $singleton;
    $singleton = $class->new($opt);
    return $singleton;
}

sub new {
    my ($class, $opt) = @_;
    my $context = TAP::Producer::Context->new($opt);
    my $self = bless [$context], $class;
    return $self;
}

sub plan {
    my ($self, $count, $opt) = @_;
    $opt ||= {};
    my $arg = ref $count ? $count : { test_count => $count };

    $self->[0]->emit_plan( { %$arg, %$opt } );

    return;
}

sub begin_subtest {
    my ($self, $name, $opt) = @_;
    $opt ||= {};

    my $subtest = $self->[0]->begin_subtest({%$opt, description => $name });
    unshift @$self, $subtest;

    return;
}

sub pass { shift->ok(1, @_) }
sub fail { shift->ok(0, @_) }
sub ok {
    my ($self, $bool, $name, $opt) = @_;
    $opt ||= {};
    my $arg = ref $bool ? $bool
         : ref $name    ? { status => $bool ? 'PASS' : 'FAIL',  %$name }
         : {    status      => ( $bool ? 'PASS' : 'FAIL'),
                description => $name,
         };

    $self->[0]->emit_test_result({ %$arg, %$opt });
    return $bool;
}

sub diag {
    my ($self, @msg) = @_;
    $self->[0]->emit_diagnostics(@msg);
}

sub bail_out {
    my ($self, $explanation, $opt) = @_;
    $opt ||= {};
    my $arg = ref $explanation ? $explanation : { explanation => $explanation };

    $self->[-1]->emit_bail_out({ %$arg, %$arg });
    while ( @$self ) {
        $self->done_testing();
    }

}

sub done_testing {
    my ($self, $count) = @_;

    my $context = shift @$self;
    $context->tests_complete($count);

    # If we are on the last item exit() appropriately
    # Else emit a test with the appropriate result.
    if (@$self) {
        return $self->ok(
            $context->passed(),
            $context->description(),
            {   directive   => $context->directive(),
                explanation => $context->explanation()
            },
        );
    }
    else {
        exit ($context->passed() ? 0 : 255);
    }
}

# TODO - DESTROY

BEGIN {
package TAP::Producer::Context;
use strict;
use warnings;
use Carp        qw< croak >;
use Time::HiRes qw<>;

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

}

# Test Plan diagnostic
# Bail version
BEGIN {
package TAP::Producer::Diagnostic;
# # blah blah blah;
use strict;
use warnings;

use Carp      qw< croak >;

sub new {
    my ($class, $opt) = @_;
    my $msgs = delete $opt->{message};
    my @messages = @{ ref $msgs ? @$msgs : [$msgs] };

    my $message = join "", @messages;

    my $self = \$message;
    bless $self, $class;

    croak "No new lines allowed in diagnostic messages"
        if $message =~ /\n/s;

    croak "Invalid options in $class constructor: ", join " ", keys %$opt
        if %$opt;

    return $self;
}

sub new_batch {
    my ($class, @messages) = @_;

    my @objects =
        map { $class->new({%$_}) }
        map { ref() ? $_ : { message => $_ } }
        map { ref() ? $_ : split /\n/ }
        @messages;

    return @objects;
}

sub as_tap {
    my ($self) = @_;
    my $string = join ' ', '#', $$self;
    return $string;
}

1;

}
BEGIN {
package TAP::Producer::Plan;
# 1..7 # Skipped: blah blah

use strict;
use warnings;
use Carp        qw< croak >;

use constant {
    _TESTS          => 1,
    _DIRECTIVE      => 2,
    _EXPLANATION    => 3,
};

sub new {
    my ($class, $opt) = @_;

    my $self = [];
    bless $self, $class;

    my $count = delete $opt->{test_count};
    my $dir = delete $opt->{directive};
    my $exp = delete $opt->{explanation};

    if ( defined $count ) {
        croak "Plan test_count must be a positive integer, not '$count'"
            if ($count =~ /[^0-9]/)
            || ($count == 0 );
    }
    $self->[_TESTS] = $count;

    if( defined $dir && defined $exp ) {
        $dir = uc $dir;
        croak "Plan directive must be 'SKIP' or undefined, not $dir"
            if ($dir ne 'SKIP');
    }

    croak "Plan explanation must be defined if directive is defined"
        if !(defined $exp) && (defined $dir);


    $self->[_DIRECTIVE] = $dir;
    $self->[_EXPLANATION] = $exp;

    croak "Invalid options in $class constructor: ", join " ", keys %$opt
        if %$opt;

    return $self;
}

sub skip_all {
    my  ($self) = @_;
    return $self->[_DIRECTIVE] eq 'SKIP';
}

sub as_tap {
    my ($self) = @_;

    no warnings 'uninitialized';

    my $string = join ' ', (
        ( $self->_show_count() ? ("1..$self->[_TESTS]") : () ),
        ( $self->_show_skip()  ? ('1..0', '#', 'Skipped:', $self->[_EXPLANATION]) : ()),
    );

    return $string;
}

sub _show_count { ! $_[0]->[_DIRECTIVE] }
sub _show_skip {
       (defined $_[0]->[_DIRECTIVE])
    && ($_[0]->[_DIRECTIVE] eq 'SKIP')
}


1;
}
BEGIN {
package TAP::Producer::Test;

use strict;
use warnings;
use Carp        qw< croak >;

use constant {
    _PASS           => 0,
    _NUMBER         => 1,
    _DESC           => 2,
    _DIRECTIVE      => 3,
    _EXPLANATION    => 4,
};

sub new {
    my ($class, $opt) = @_;

    my $self = [];
    bless $self, $class;

    {   croak "No status supplied for test."
            unless defined $opt->{status};
        my $pass = uc delete $opt->{status};
        croak "Test status must be 'PASS' or 'FAIL', not $pass"
            if ($pass ne 'PASS')
            && ($pass ne 'FAIL');
        $pass = $pass eq 'PASS';

        $self->[_PASS]      = $pass;
    }

    {   my $number = delete $opt->{number};
        if (defined $number) {
            croak "Optional test number must be a positive integer, not '$number'"
                if $number =~ /[^0-9]/;

            $self->[_NUMBER]=$number;
        }
    }


    {   my $dir = delete $opt->{directive};

        if ( defined $dir ) {
            $dir = uc $dir;
            croak "Test directive must be 'TODO', 'SKIP' or undefined, not $dir"
                if ($dir ne 'SKIP')
                && ($dir ne 'TODO');
        }

        $self->[_DIRECTIVE] = $dir;
    }

    $self->[_EXPLANATION] = delete $opt->{explanation} // '';
    $self->[_DESC] = delete $opt->{description};

    croak "Invalid options in $class constructor: ", join " ", keys %$opt
        if %$opt;

    return $self;
}

sub as_tap {
    my ($self) = @_;

    no warnings 'uninitialized';

    my $string = join ' ', (
        ( $self->_show_pass()   ? ($self->_emit_ok() ? 'ok' : 'not ok') : () ),
        ( $self->_show_number()         ? ($self->[_NUMBER])            : () ),
        ( $self->_show_description()    ? ('-', $self->[_DESC])         : () ),
        ( $self->_show_todo()           ? ('#', 'TODO')                 : () ),
        ( $self->_show_skip()           ? ('#', 'skip')                 : () ),
        ( $self->_show_explanation()    ? ($self->[_EXPLANATION])       : () ),
    );

    return $string;
}

sub _emit_ok { $_[0]->[_PASS] || ($_[0]->[_DIRECTIVE] eq 'SKIP') }
sub passed {
    my ($self) = @_;
    return ( $self->[_PASS] || $self->[_DIRECTIVE] ) && 1;
}

sub failed { ! $_[0]->passed() }

sub _show_pass {1}
sub _show_number { defined $_[0]->[_NUMBER] }
sub _show_description {
       (defined $_[0]->[_DESC])
    && ( ($_[0]->[_DIRECTIVE]//'') ne 'SKIP')
}
sub _show_skip {
       (defined $_[0]->[_DIRECTIVE])
    && ($_[0]->[_DIRECTIVE] eq 'SKIP')
}
sub _show_todo {
       (defined $_[0]->[_DIRECTIVE])
    && ($_[0]->[_DIRECTIVE] eq 'TODO')
}
sub _show_explanation {
       (defined $_[0]->[_DIRECTIVE])
    && (defined $_[0]->[_EXPLANATION])
}

1;
}

BEGIN {
package TAP::Producer::BailOut;
# BailOut!

use strict;
use warnings;
use Carp        qw< croak >;

use constant {
    _EXPLANATION    => 1,
};

sub new {
    my ($class, $opt) = @_;

    my $self = [];
    bless $self, $class;

    my $exp = delete $opt->{explanation};

    $self->[_EXPLANATION] = $exp;

    return $self;
}


sub as_tap {
    my ($self) = @_;

    no warnings 'uninitialized';

    my $string = join ' ', (
        "Bail out!",
        ( $self->_show_explanation()  ? ($self->[_EXPLANATION]) : ()),
    );

    return $string;
}

sub _show_explanation {
       (defined $_[0]->[_EXPLANATION])
}


1;
}

1;
