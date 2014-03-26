package TAP::Producer::Diagnostic;

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

__END__

=head1 NAME

TAP::Producer::Diagnostic

=head1 SYNOPSIS

See L<TAP::Producer>.

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=head2 new_batch

=head2 as_tap

=head1 TODO

  * Real POD
