package TAP::Producer;

use strict;
use warnings;
use constant;
use Carp      qw< croak >;

use TAP::Producer::Context;

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

sub test_count {
    my ($self) = @_;

    return $self->[0]->test_count();
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

# TODO - DESTROY / END blocks

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

__END__

=head1 NAME

TAP::Producer

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Philosophy

=head1 METHODS

=head2 singleton

=head2 new

=head2 plan

=head2 begin_subtest

=head2 pass

=head2 fail

=head2 ok

=head2 diag

=head2 bail_out

=head2 done_testing

=head1 TODO
=head1 LICENSE
=head1 ACKNOLWEDGEMENTS

