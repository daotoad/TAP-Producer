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

__END__

=head1 NAME

TAP::Producer::Plan

=head1 SYNOPSIS

See L<TAP::Producer>.

=head1 METHODS

=head2 new

=head2 skip_all

=head2 as_tap

=head1 TODO

  * Real POD

