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

__END__


=head1 NAME

TAP::Producer::Test

=head1 SYNOPSIS

See L<TAP::Producer>.

=head1 METHODS

=head2 new

=head2 passed

=head2 as_tap

=head1 TODO

  * Real POD
