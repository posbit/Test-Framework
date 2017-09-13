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

    $test_class->{failures} = {};
    $test_class->{counters} = {
        run => 0,
        succeeded => 0,
        failed => 0,
        scheduled => 0,
        assertions => 0,
    };

    $test_class->{name} = $test_class_name;

    $test_class->{failfast} = 0;
    $test_class->{muted_stdout} = 0;
    $test_class->{verbosity} = 0;
    $test_class->{per_test_reports} = 0;

    return bless($test_class, 'Test::Framework');
}


sub early_failures {
    # Call this function if you want to enable or
    # disable early failures.
    # If enabled, early failures make the test suite fail
    # as soon as first test failes.
    #
    # By default, calling this function will *enable*
    # early failures.
    #
    #       $suite->early_failures();   # enable early failures
    #       $suite->early_failures(1);  # enable early failures
    #       $suite->early_failures(0);  # disable early failures
    #
    my $self = shift;
    my $value = shift;

    if (not defined($value)) {
        $value = 1;
    };
    $self->{failfast} = $value;

    return $self;
}

sub verbose {
    # Call this function if you want to set verbosity level.
    #
    # By default, calling this function will set the level to 1.
    #
    my $self = shift;
    my $value = shift;

    if (not defined($value)) {
        $value = 1;
    };
    $self->{verbosity} = $value;

    return $self;
}

sub mute_stdout {
    # Call this function if you want to mute or
    # unmute stdout emitted by functions running as tests.
    # Useful if, for example, the functions you call use
    # print() for logging.
    #
    # By default, calling this function will *mute*
    # the stdout.
    #
    #       $suite->mute_stdout();   # mute standard output
    #       $suite->mute_stdout(1);  # mute standard output
    #       $suite->mute_stdout(0);  # unmute standard output
    #
    # Also, note that this function only *tries to* mute the
    # stdout and may not always succeed.
    #
    my $self = shift;
    my $value = shift;

    if (not defined($value)) {
        $value = 1;
    };
    $self->{muted_stdout} = $value;

    return $self;
}

sub running_reports {
    # Call this function if you want to enable or
    # disable per-test report lines.
    # If enabled, per-test reports print short status reports
    # for each test that is run:
    #
    #   TestClass.test_case_0 ... ok
    #   TestClass.test_case_1 ... fail: OH NOES
    #
    # By default, calling this function will *enable*
    # per-test reports.
    #
    #       $suite->running_reports();   # enable per-test reports
    #       $suite->running_reports(1);  # enable per-test reports
    #       $suite->running_reports(0);  # disable per-test reports
    #
    my $self = shift;
    my $value = shift;

    if (not defined($value)) {
        $value = 1;
    };
    $self->{per_test_reports} = $value;

    return $self;
}


######################################################################
# RUNNER INTERFACE
#
sub _capture_output {
    my ($channel, $mode, $io) = @_;
    open($io, ($mode || '>'), $channel) or die($!);
    return select($io);
}

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
        if ($_ eq $self->{name}) {
            @tests = sort(keys(%{$self->{cases}}));
            last;
        };
    }

    foreach (@tests) {
        my $test_class_name = $self->{name};
        my $test_name = $_;

        ++$self->{counters}->{scheduled};

        if ((not $test_name =~ /^test_/) && (not $test_name =~ /\./)) {
            next;
        };
        if ($test_name =~ /\./) {
            ($test_class_name, $test_name) = split(/\./, $test_name);
        };

        if ($test_class_name ne $self->{name}) {
            next;
        };

        if (not defined($self->{cases}->{$test_name})) {
            die($self->{name} . ".$_: test not registered");
        };

        ++$self->{counters}->{run};

        if ($self->{per_test_reports}) {
            print("$test_class_name.$test_name ... ");
        }

        my $captured_output = '';
        my $stdout = _capture_output(\$captured_output);
        eval {
            $self->{cases}->{$test_name}->($self);
            select($stdout);
            if ($self->{per_test_reports}) {
                say('ok');
            }
            if (not $self->{muted_stdout}) {
                say($captured_output);
            };
        };
        if ($@) {
            select($stdout);
            chomp($@);
            if ($self->{per_test_reports}) {
                say("fail: $@");
            }
            say($captured_output);

            ++$self->{counters}->{failed};
            $self->{failures}->{$test_name} = (split('at (?:lib/)?Test/Framework', $@))[0];

            if ($self->{failfast}) {
                last;
            } else {
                next;
            }
        };

        ++$self->{counters}->{succeeded};
    }

    return $self;
}

sub print_summary {
    my $self = shift;

    say("\n>>>> $self->{name}: summary");
    say(" - $self->{counters}->{run} test(s) run (out of $self->{counters}->{scheduled} scheduled)");
    say("   + $self->{counters}->{succeeded} test(s) succeeded");
    say("   + $self->{counters}->{failed} test(s) failed");
    say("   + $self->{counters}->{assertions} assertions(s) total");
    if ($self->{counters}->{failed}) {
        say('');
        say(" - failures:");
        foreach (sort(keys(%{$self->{failures}}))) {
            say("   + $_: $self->{failures}->{$_}");
        }
    };

    return $self;
}

sub run_suite {
    my $suite = shift;

    my @test_classes = @{$suite->{test_classes}};
    my @argv = undef;
    if (not defined($suite->{argv})) {
        @argv = ();
    } else {
        @argv = @{$suite->{argv}};
    }

    my $i = 0;
    my $limit = scalar(@test_classes);
    my $total_tests_run = 0;
    my $failed = 0;
    my @run_test_classes = ();
    foreach my $test_class (@test_classes) {
        push(@run_test_classes, $test_class);
        $test_class->run(@argv);
        $total_tests_run += $test_class->{counters}->{run};
        if (++$i < $limit && $test_class->{counters}->{run}) {
            print("\n");
        }
        if ($test_class->{counters}->{failed}) {
            # first failed test class fails whole suite
            $failed = 1;
            last;
        }
    }

    if ($total_tests_run) {
        print("\n");
        print("________________________________________________________________");
        print("________________________________________________________________\n");
    };
    print("== SUITE SUMMARY ===============================================");
    print("================================================================\n");

    foreach my $test_class (@run_test_classes) {
        if ($test_class->{counters}->{run}) {
            $test_class->print_summary();
        };
    }
    if ($failed) {
        exit(1);
    }
}

sub list_tests {
    my $self = shift;

    my @test_cases = keys(%{$self->{cases}});
    return \@test_cases;
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

sub register_test_assert_equal {
    my $self = shift;
    my $test_name = shift;
    my $expected = shift;
    my $producer_callback = shift;

    $self->register_test($test_name, sub {
        my $framework = shift;
        my $object = $producer_callback->($framework);
        $self->assert_numeric_eq($expected, $object);
    });

    return;
}

sub register_test_assert_not_equal {
    my $self = shift;
    my $test_name = shift;
    my $expected = shift;
    my $producer_callback = shift;

    $self->register_test($test_name, sub {
        my $framework = shift;
        my $object = $producer_callback->($framework);
        $self->assert_numeric_ne($expected, $object);
    });

    return;
}

sub register_test_assert_dies {
    # Tests for die() being called.
    #
    # Expects two parameters:
    #
    # - test name,
    # - producer function,
    #
    # Tests whether producer dies.
    #
    my $self = shift;
    my $test_name = shift;
    my $producer_callback = shift;

    $self->register_test($test_name, sub {
        my $framework = shift;

        my $error = undef;
        eval {
            $producer_callback->($framework);
        };
        if ($@) {
            $error = $@;
        };
        $framework->assert_true($error);
    });

    return;
}

sub register_test_assert_dies_with {
    # Tests for die() being called with expected result.
    #
    # Expects three parameters:
    #
    # - test name,
    # - expected die() result,
    # - producer function,
    #
    # Tests whether producer dies with expected value.
    #
    my $self = shift;
    my $test_name = shift;
    my $expected_result = shift;
    my $producer_callback = shift;

    $self->register_test($test_name, sub {
        my $framework = shift;

        my $error = undef;
        eval {
            $producer_callback->($framework);
        };
        if ($@) {
            $error = $@;
        };
        $framework->assert_true($error);
        $framework->assert_eq($expected_result, $error);
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
            $row_spec->{where} = $producer_callback->($framework);
            $row_spec->{description} = $test_name;
            $framework->assert_database_row($handle, $row_spec);
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

            my $row_spec = {};
            $row_spec->{table} = $table_name;
            $row_spec->{where} = $producer_callback->($framework);
            $row_spec->{description} = $test_name;
            $framework->assert_database_row_exists($handle, $row_spec);
        }
    );

    return;
}

sub register_test_assert_database_row_not_exists {
    # Tests whether specified database row does not exist.
    #
    # Expects four parameters:
    #
    # - test name,
    # - database table name,
    # - producer function,
    # - database handle,
    #
    # Tests whether producer function created row in a database table.
    # Test is performed by not_row_ok() function from Test::DatabaseRow.
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

            my $row_spec = {};
            $row_spec->{table} = $table_name;
            $row_spec->{where} = $producer_callback->($framework);
            $row_spec->{description} = $test_name;
            $framework->assert_database_row_not_exists($handle, $row_spec);
        }
    );

    return;
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

sub _increase_assertion_counter {
    my $self = shift;

    ++$self->{counters}->{assertions};
}

sub assert_true {
    my $self = shift;
    my $value = shift;

    $self->_increase_assertion_counter();
    my $result = $self->to_boolean($value);
    if ((not $result)) {
        die("assert_true() expected true, got: $value");
    };

    return;
}

sub assert_false {
    my $self = shift;
    my $value = shift;

    $self->_increase_assertion_counter();
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

    $self->_increase_assertion_counter();
    if ((not ($left_value eq $right_value))) {
        die("assert_eq() failed: `$left_value` eq `$right_value`");
    };

    return;
}

sub assert_ne {
    my $self = shift;
    my $left_value = shift;
    my $right_value = shift;

    $self->_increase_assertion_counter();
    if ((not ($left_value ne $right_value))) {
        die("assert_ne() failed: `$left_value` ne `$right_value`");
    };

    return;
}

sub assert_numeric_eq {
    my $self = shift;
    my $left_value = shift;
    my $right_value = shift;

    $self->_increase_assertion_counter();
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

    $self->_increase_assertion_counter();
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

    $self->_increase_assertion_counter();
    my $object_type_name = $self->get_typeof($object, @_);
    if ($expected_type_name ne $object_type_name) {
        die("assert_typeof() failed: $expected_type_name != $object_type_name");
    };
}

sub assert_not_typeof {
    my $self = shift;
    my $expected_type_name = shift;
    my $object = shift;

    $self->_increase_assertion_counter();
    my $object_type_name = $self->get_typeof($object, @_);
    if ($expected_type_name eq $object_type_name) {
        die("assert_not_typeof() failed: $expected_type_name == $object_type_name");
    };
}

sub assert_database_row {
    my $self = shift;
    my $handle = shift;
    my $row_spec = shift;

    $self->_increase_assertion_counter();
    local $Test::DatabaseRow::dbh = $handle;

    my $result = all_row_ok(%{$row_spec});
    if ($result == 0) {
        die("assert_database_row() failed");
    };
}

sub assert_database_row_exists {
    my $self = shift;
    my $handle = shift;
    my $row_spec = shift;

    $self->_increase_assertion_counter();
    local $Test::DatabaseRow::dbh = $handle;
    $row_spec->{tests} = $row_spec->{where};

    my $result = all_row_ok(%{$row_spec});
    if ($result == 0) {
        die("assert_database_row_exists() failed");
    };
}

sub assert_database_row_not_exists {
    my $self = shift;
    my $handle = shift;
    my $row_spec = shift;

    $self->_increase_assertion_counter();
    local $Test::DatabaseRow::dbh = $handle;
    $row_spec->{tests} = $row_spec->{where};

    my $result = not_row_ok(%{$row_spec});
    if ($result == 0) {
        die("assert_database_row_not_exists() failed");
    };
}

sub assert_dies {
    my $self = shift;
    my $expected_value = shift;
    my $producer = shift;

    $self->_increase_assertion_counter();
    eval {
        $producer->($self);
    };
    if ($@) {
        if ($@ ne $expected_value) {
            die("assert_dies() failed: `$expected_value` eq `$@`");
        }
    } else {
        die("assert_dies() failed: producer didn't die");
    };

    return;
}

1;
