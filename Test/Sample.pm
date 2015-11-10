#! /usr/bin/perl

use utf8;

use Test::More;
use Test::Framework;


my $test_class = Test::Framework->new('FrameworkTest');


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

$test_class->register_test('test_assert_typeof', sub {
    my $framework = shift;
    $framework->assert_typeof('Test::Framework', $framework);
});

$test_class->register_test_assert_typeof('test_reigster_test_assert_typeof', 'Test::Framework', sub {
    my $framework = shift;
    return $framework;
});


$test_class->run(@ARGV);
done_testing();
