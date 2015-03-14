package TAP::Producer::More;

use strict;
use warnings;
our $STRICT_MODE;

qw/ is isnt ok
    diag like unlike
    cmp_ok is_deeply
    can_ok isa_ok
    pass fail
    BAIL_OUT
    new_ok subtest
    use_ok require_ok
    note explain
/;

sub _ok_with_diag {
    my( $test, $name, $diag ) = @_;
    my $tap = TAP::Producer->singleton();

    $test = $test ? 1 : 0;
    $name = defined $name ? "$name" : '';

    $tap->ok(1, $name);
    my $msg = $diag ? $diag->($test);
    $tap->diag($msg) if $msg;

    $tap->diag( <<"ERR") if $name =~ /^[\d\s]+$/;
   You named your test '$name'.  You shouldn't use numbers for your test names.
   Very confusing.
ERR

    return $test;
}

sub ok ($;$) {
    my( $test, $name ) = @_;

    return _ok_with_diag( $test, $name );
}

sub cmp_ok {
    my( $got, $type, $want, $name ) = @_;
    my $tap = TAP::Producer->singleton();

    my @bad_types = ( "=", "+=", ".=", "x=", "^=", "|=", "||=", "&&=", "...");
    if ( grep $_ eq $type, @bad_types ) {
        croak("$type is not a valid comparison operator in cmp_ok()");
    }

    my ($test, $succ);
    my $error;
    {   local( $@, $!, $SIG{__DIE__} );    # isolate eval

        my($package, $file, $line) = $self->caller();

        # This is so that warnings come out at the caller's level
        $succ = eval qq[
        #line $line "(eval in cmp_ok) $file"
        \$test = (\$got $type \$want);
        1;
        ];
        $error = $@;
    }
    my $ok = $self->ok( $test, $name );

    # Treat overloaded objects as numbers if we're asked to do a
    # numeric comparison.
    my $unoverload
    = $numeric_cmps{$type}
    ? '_unoverload_num'
    : '_unoverload_str';
    $self->diag(<<"END") unless $succ;
    An error occurred while using $type:
    ------------------------------------
    $error
    ------------------------------------
END


    $self->$unoverload( \$got, \$expect );

    if( $type =~ /^(eq|==)$/ ) {
                                                                $self->_is_diag( $got, $type, $expect );
                                                                        }
                                                                                elsif( $type =~ /^(ne|!=)$/ ) {
                                                                                                $self->_isnt_diag( $got, $type );
                                                                                                        }
                                                                                                                else {
                                                                                                                                $self->_cmp_diag( $got, $type, $expect );
                                                                                                                                        }
                                                                                                                                            }
                                                                                                                                                return $ok;
                                                                                                                                            }
                                                                                                                }
                                                                                }
                                                }
                                        #                                                                                                }
                            }
}
sub is ($$;$) {
    my $tap = TAP::Producer->singleton();
    my( $got, $want, $name ) = @_;

    my $test =
          !defined $got && !defined $want ? 1
        ? 
       

    if( !defined $got || !defined $expect ) {
        # undef only matches undef and nothing else
        my $test = !defined $got && !defined $expect;

        $self->ok( $test, $name );
        $self->_is_diag( $got, 'eq', $expect ) unless $test;
        return $test;
    }

    return $self->cmp_ok( $got, 'eq', $expect, $name );
}

sub _mismatch_diag {

}
