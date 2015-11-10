#! /usr/bin/perl

use utf8;

use Test::More;
use Test::Framework;


my $test_class = Test::Framework->new('FrameworkTests');
$test_class->early_failures(1);

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
my $boolean_test_class = Test::Framework->new('BooleanTests');
$boolean_test_class->register_test('test_positive_boolean_assertion', sub {
    my $framework = shift;
    $framework->assert_true(1);
});
$boolean_test_class->register_test_assert_true('test_register_positive_boolean_assertion', sub {
    return 'true-looking value';
});

$boolean_test_class->register_test('test_negative_boolean_assertion', sub {
    my $framework = shift;
    $framework->assert_false(0);
});
$boolean_test_class->register_test_assert_false('test_register_negative_boolean_assertion', sub {
    return '';  # false-looking value
});

# failing tests
$boolean_test_class->register_test_assert_true('test_register_failing_positive_boolean_assertion', sub {
    return '';  # false-looking value
});
$boolean_test_class->register_test_assert_false('test_register_failing_negative_boolean_assertion', sub {
    return 'true';  # true-looking value
});



Test::Framework::run_suite({
    test_classes => [$test_class, $boolean_test_class],
    argv => @ARGV,
});
