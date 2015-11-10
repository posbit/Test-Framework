package Test::Framework;

use utf8;
use Modern::Perl;
use Test::More;
use Test::DatabaseRow;


sub new {
    # Constructor for Test::Framework class.
    #
    # It expects a single parameter - a name of the class test.
    # Example call:
    #
    #   Test::Framework->new('FooTest');
    #
    my $class = shift;
    my $test_class_name = shift;

    if ((not $test_class_name)) {
        die('test class name not specified');
    };

    my $test_class = {};
    $test_class->{cases} = {};
    $test_class->{name} = $test_class_name;

    return bless($test_class, 'Test::Framework');
}


######################################################################
# LOW LEVEL TESTING FUNCTIONS
#
sub register_test {
    # The most basic function in the framework.
    #
    # Expects two parameters:
    #
    # - test name (string),
    # - test callback (a function),
    #
    # Supplied function is responsible for calling Test::More hook functions like
    # ok(), isa_ok() etc.
    #
    my $self = shift;
    my $test_name = shift;
    my $test_callback = shift;

    if (defined($self->{cases}->{$test_name})) {
        die("Test::Framework->register_test(): fatal: $self->{name}.$test_name already registered");
    };
    $self->{cases}->{$test_name} = $test_callback;

    return;
}


######################################################################
# MIDDLE LEVEL TESTING FUNCTIONS
#
sub register_test_assert_typeof {
    # Tests type correctness.
    #
    # Expects three parameters:
    #
    # - test name (string),
    # - expected type name (string),
    # - producer callback,
    #
    # This register function will generate code that will test for
    # type correctness, i.e. whether the producer function returned
    # object of specified type.
    #
    # Producer function must return an object, but may be of arbitrary
    # complexity.
    #
    my $self = shift;
    my $test_name = shift;
    my $type_name = shift;
    my $producer_callback = shift;

    $self->register_test($test_name, sub {
        my $framework = shift;
        my $object = $producer_callback->($framework);
        $self->assert_typeof($type_name, $object);
    });

    return;
}

sub register_test_assert_not_typeof {
    # Tests type correctness.
    #
    # Expects three parameters:
    #
    # - test name (string),
    # - expected type name (string),
    # - producer callback,
    #
    # This register function will generate code that will test whether
    # the producer function DID NOT return object of specified type.
    #
    # Producer function must return an object, but may be of arbitrary
    # complexity.
    #
    my $self = shift;
    my $test_name = shift;
    my $type_name = shift;
    my $producer_callback = shift;

    $self->register_test($test_name, sub {
        my $framework = shift;
        my $object = $producer_callback->($framework);
        $self->assert_not_typeof($type_name, $object);
    });

    return;
}

sub register_test_assert_true {
    # Tests for true values.
    #
    # Expects two parameters:
    #
    # - test name,
    # - producer function,
    #
    # Tests whether producer returns true value.
    #
    my $self = shift;
    my $test_name = shift;
    my $producer_callback = shift;

    $self->register_test($test_name, sub {
        my $framework = shift;
        my $object = $producer_callback->($framework);
        $self->assert_true($object);
    });

    return;
}

sub register_test_assert_false {
    # Tests for false values.
    #
    # Expects two parameters:
    #
    # - test name,
    # - producer function,
    #
    # Tests whether producer returns false value.
    #
    my $self = shift;
    my $test_name = shift;
    my $producer_callback = shift;

    $self->register_test($test_name, sub {
        my $framework = shift;
        my $object = $producer_callback->($framework);
        $self->assert_false($object);
    });

    return;
}


######################################################################
# HIGH LEVEL TESTING FUNCTIONS
#
sub register_test_assert_database_row {
    # Tests whether specified database row matches expected state.
    #
    # Expects four parameters:
    #
    # - test name,
    # - row specification,
    # - producer function,
    # - database handle,
    #
    # Tests whether producer function created expected row in a database.
    # Test is performed by all_row_ok() function from Test::DatabaseRow.
    #
    # Supplied row specification must be a hashref which will be dereferenced
    # when passed to to all_row_ok().
    #
    # Producer function MUST return an arrayref which will be used as
    # a "where" parameter for all_row_ok().
    #
    my $self = shift;
    my $test_name = shift;
    my $row_spec  = shift;
    my $producer_callback = shift;
    my $handle = shift;

    $self->register_test(
        $test_name,
        sub {
            my $framework = shift;
            local $Test::DatabaseRow::dbh = $handle;
            $row_spec->{where} = $producer_callback->($framework);
            $row_spec->{description} = $test_name;
            all_row_ok(%$row_spec);
        }
    );

    return;
}

sub register_test_assert_database_row_exists {
    # Tests whether specified database row exists.
    #
    # Expects four parameters:
    #
    # - test name,
    # - database table name,
    # - producer function,
    # - database handle,
    #
    # Tests whether producer function created row in a database table.
    # Test is performed by all_row_ok() function from Test::DatabaseRow.
    #
    # Producer function MUST return an arrayref which will be used as
    # a "where" parameter for all_row_ok().
    #
    # Supplied database table name MUST exist in a database pointed to by
    # supplied handle.
    #
    my $self = shift;
    my $test_name = shift;
    my $table_name  = shift;
    my $producer_callback = shift;
    my $handle = shift;

    $self->register_test(
        $test_name,
        sub {
            my $framework = shift;

            local $Test::DatabaseRow::dbh = $handle;
            my $row_spec = {};
            $row_spec->{table} = $table_name;
            $row_spec->{where} = $producer_callback->($framework);
            $row_spec->{description} = $test_name;
            $row_spec->{tests} = $row_spec->{where};
            all_row_ok(%$row_spec);
        }
    );

    return;
}


######################################################################
# RUNNER INTERFACE
#
sub run {
    # Main function of the test framework.
    #
    # Expects one optional parameter:
    #
    # - an array of test names to run,
    #
    # Usually, supplied array is @ARGV of invoked script.
    # When the array is empty, this function assumes that
    # all tests should be run.
    #
    # Every test function receives one parameter - the
    # Test::Framework object that the test is being run by.
    # Test functions may then use helper functions like
    # "assert_true", "assert_false", "assert_integer" etc.
    # to assist themselves in their work.
    #
    my $self = shift;
    my @tests = @_;

    if (scalar(@tests) == 0) {
        @tests = sort(keys(%{$self->{cases}}));
    }

    foreach (@tests) {
        if (not defined($self->{cases}->{$_})) {
            die($self->{name} . ".$_: test not registered");
        }
        say("$self->{name}.$_");
        $self->{cases}->{$_}->($self);
    }
}


######################################################################
# HELPER FUNCTIONS
#
# These functions do nothing on success and
# die on failure.
#
sub to_boolean {
    my $self = shift;
    my $value = shift;
    return (not (not $value));
}

sub is_numeric {
    my $self = shift;
    my $value = shift;

    my $looks_good = 0;
    if ($value =~ /^-?(?:0|[1-9])[0-9]*(?:\.[0-9]+)?([eE][-+]?[0-9]+)?$/) {
        $looks_good = 1;
    };
    return $looks_good;
}

sub get_typeof {
    # In Perl, there is only a rough approximation of the type.
    # Expects one parameter which can be anything.
    #
    # WARNING!!!
    #   Perl does not have sane lists or dictionaries (arrays and
    #   hashes are a bad joke).
    #   Thus, this function cannot support type detection for them and
    #   it cannot guarantee predictable behaviour when passed an
    #   array or a hash.
    #   Arrays and hashes MUST be passed as references.
    #
    # Possible return values are:
    #
    # - undef: for undefined values,
    # - ARRAY: for array references,
    # - HASH: for hash references,
    # - CODE: for function refences,
    # - <REF>: where "<REF>" is the name given by bless() for other types of references,
    # - SCALAR: for either hashes or arrays (returned when above types did not match and
    #   the function has a non-empty @_ after two calls to shift),
    # - NUMBER: for numeric-looking values,
    # - STRING: for anything else,
    #
    my $self = shift;
    my $object = shift;

    my $object_type_name = '';
    if (not defined($object)) {
        $object_type_name = 'undef';
    } elsif (ref($object)) {
        $object_type_name = ref($object);
    } elsif (scalar(@_) > 0) {
        $object_type_name = 'SCALAR';
    } elsif ($self->is_numeric($object)) {
        $object_type_name = 'NUMBER';
    } else {
        $object_type_name = 'STRING';
    }

    return $object_type_name;
}

sub assert_true {
    my $self = shift;
    my $value = shift;

    my $result = $self->to_boolean($value);
    if ((not $result)) {
        die("assert_true() expected true, got: $value");
    };

    return;
}

sub assert_false {
    my $self = shift;
    my $value = shift;

    my $result = $self->to_boolean($value);
    if ($result) {
        die("assert_false() expected false, got: $value");
    };

    return;
}

sub assert_eq {
    my $self = shift;
    my $left_value = shift;
    my $right_value = shift;

    if ((not ($left_value eq $right_value))) {
        die("assert_eq() failed: `$left_value` eq `$right_value`");
    };

    return;
}

sub assert_ne {
    my $self = shift;
    my $left_value = shift;
    my $right_value = shift;

    if ((not ($left_value ne $right_value))) {
        die("assert_ne() failed: `$left_value` ne `$right_value`");
    };

    return;
}

sub assert_numeric_eq {
    my $self = shift;
    my $left_value = shift;
    my $right_value = shift;

    if (not $self->is_numeric($left_value)) {
        die("assert_numeric_eq() failed: lhs value not numeric `$left_value`");
    }
    if (not $self->is_numeric($right_value)) {
        die("assert_numeric_eq() failed: rhs value not numeric `$right_value`");
    }

    if ((not ($left_value == $right_value))) {
        die("assert_numeric_eq() failed: $left_value == $right_value");
    };

    return;
}

sub assert_numeric_ne {
    my $self = shift;
    my $left_value = shift;
    my $right_value = shift;

    if (not $self->is_numeric($left_value)) {
        die("assert_numeric_ne() failed: lhs value not numeric `$left_value`");
    }
    if (not $self->is_numeric($right_value)) {
        die("assert_numeric_ne() failed: rhs value not numeric `$right_value`");
    }

    if ((not ($left_value != $right_value))) {
        die("assert_numeric_ne() failed: $left_value != $right_value");
    };

    return;
}

sub assert_typeof {
    my $self = shift;
    my $expected_type_name = shift;
    my $object = shift;

    my $object_type_name = $self->get_typeof($object, @_);
    if ($expected_type_name ne $object_type_name) {
        die("assert_typeof() failed: $expected_type_name != $object_type_name");
    };
}

sub assert_not_typeof {
    my $self = shift;
    my $expected_type_name = shift;
    my $object = shift;

    my $object_type_name = $self->get_typeof($object, @_);
    if ($expected_type_name eq $object_type_name) {
        die("assert_not_typeof() failed: $expected_type_name == $object_type_name");
    };
}


1;