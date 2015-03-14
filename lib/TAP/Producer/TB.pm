package TAP::Producer::TB;


use strict;
use warnings;


sub new { goto &create }
sub create {
    my($class) = shift;
    return TAP::Producer->singleton();
}

sub child {}
sub subtest {}
sub finalize {}
sub parent {}
sub DESTROY {}
sub reset {}
sub plan {}
sub expected_tests {}
sub no_plan {}
sub done_testing {}
sub has_plan {}
sub skip_all {}
sub exported_to { 'Do not use this broken method' }
sub ok {}
sub is_eq {}
sub is_num {}
sub isnt_eq {}
sub isnt_num {}
sub like {}
sub unlike {}
sub cmp_ok {}
sub skip {}
sub todo_skip {}
sub maybe_regex {}
sub is_fh {}
sub use_number {}
sub no_header {}
sub no_ending {}
sub no_diag {}
sub diag {}
sub note {}
sub explain {}
sub output {}
sub failure_output {}
sub todo_output {}
sub reset_outputs {}
sub carp {}
sub croak {}


#TODO - monkey path Test::Builder::Module::builder with something that gives you an instance of this.




__END__

=head1 NAME

TAP::Producer::TB - replace Test::Builder in existing test libraries.

=head1 SYNOPSIS


=head1 DESCRIPTION

TB is a disease.  This is the cure.


