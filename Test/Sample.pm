#! /usr/bin/perl

use utf8;

use Test::More;
use Test::Framework;


# create test class
my $test_class = Test::Framework->new('FrameworkTest');


######################################################################
# POSITIVE TYPE ASSERTIONS
#
$test_class->register_test('test_assert_not_typeof', sub {
    my $framework = shift;
    $framework->assert_not_typeof('Test::Foo', undef);
    $framework->assert_not_typeof('Test::Foo', 0);
    $framework->assert_not_typeof('Test::Foo', '0b0');
    $framework->assert_not_typeof('Test::Foo', ['0b0']);
    $framework->assert_not_typeof('Test::Foo', { n => '0b0'});
    $framework->assert_not_typeof('Test::Foo', sub { return 0; });
    $framework->assert_not_typeof('Test::Foo', $framework);
    $framework->assert_not_typeof('Test::Foo', (0, 1, 2, 3));
    $framework->assert_not_typeof('Test::Foo', (a => 0, b => 1));
});
$test_class->register_test_assert_not_typeof('test_reigster_test_assert_not_typeof', 'Test::Foo', sub {
    my $framework = shift;
    return $framework;
});


######################################################################
# NEGATIVE TYPE ASSERTIONS
#
$test_class->register_test('test_assert_typeof', sub {
    my $framework = shift;
    $framework->assert_typeof('Test::Framework', $framework);
});
$test_class->register_test_assert_typeof('test_reigster_test_assert_typeof', 'Test::Framework', sub {
    my $framework = shift;
    return $framework;
});


######################################################################
# SIMPLE BOOLEAN ASSERTIONS
#
$test_class->register_test('test_positive_boolean_assertion', sub {
    my $framework = shift;
    $framework->assert_true(1);
});
$test_class->register_test_assert_true('test_register_positive_boolean_assertion', sub {
    return 'true-looking value';
});

$test_class->register_test('test_negative_boolean_assertion', sub {
    my $framework = shift;
    $framework->assert_false(0);
});
$test_class->register_test_assert_false('test_register_negative_boolean_assertion', sub {
    return '';  # false-looking value
});

# failing tests
$test_class->register_test_assert_true('test_register_failing_positive_boolean_assertion', sub {
    return '';  # false-looking value
});
$test_class->register_test_assert_false('test_register_failing_negative_boolean_assertion', sub {
    return 'true';  # true-looking value
});


# set early failures
#$test_class->early_failures();

# run tests and print summary
$test_class->run(@ARGV);
print("\n");
$test_class->print_summary();


done_testing();
